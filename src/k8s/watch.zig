const std = @import("std");
const client_mod = @import("client.zig");
const K8sClient = client_mod.K8sClient;
const StreamResponseMeta = client_mod.StreamResponseMeta;
const types = @import("types.zig");
const ResourceClient = @import("resources.zig").ResourceClient;
const QueryWriter = @import("query.zig").QueryWriter;

/// Spin-wait until the mutex is acquired.
/// std.atomic.Mutex in 0.16 only provides tryLock; there is no blocking lock().
/// The informer holds this lock only briefly (cache reads/writes), so a short spin
/// is acceptable.
fn lockMutex(m: *std.atomic.Mutex) void {
    while (!m.tryLock()) {
        std.atomic.spinLoopHint();
    }
}

/// Watch event type
pub const EventType = enum {
    ADDED,
    MODIFIED,
    DELETED,
    ERROR,
    BOOKMARK,

    pub fn fromString(s: []const u8) ?EventType {
        if (std.mem.eql(u8, s, "ADDED")) return .ADDED;
        if (std.mem.eql(u8, s, "MODIFIED")) return .MODIFIED;
        if (std.mem.eql(u8, s, "DELETED")) return .DELETED;
        if (std.mem.eql(u8, s, "ERROR")) return .ERROR;
        if (std.mem.eql(u8, s, "BOOKMARK")) return .BOOKMARK;
        return null;
    }
};

/// Watch event that owns its parsed JSON memory.
/// Caller MUST call deinit() when done processing the event.
pub fn WatchEvent(comptime T: type) type {
    return struct {
        type_: EventType,
        object: T,
        /// Holds the parsed JSON arena — must be freed via deinit().
        _parsed: std.json.Parsed(Watcher(T).WatchEnvelope),

        pub fn deinit(self: *@This()) void {
            self._parsed.deinit();
        }
    };
}

/// Watch options for filtering events
pub const WatchOptions = struct {
    /// Resource version to start watching from
    resource_version: ?[]const u8 = null,
    /// Timeout for the watch in seconds
    timeout_seconds: ?u32 = null,
    /// Label selector for filtering resources
    label_selector: ?[]const u8 = null,
    /// Field selector for filtering resources
    field_selector: ?[]const u8 = null,
    /// Allow watch bookmarks
    allow_watch_bookmarks: bool = true,
};

/// Inline-owned, bounded diagnostics for a terminal watch outcome.
pub const WatchErrorDetail = struct {
    code: ?u16 = null,
    reason_len: u8 = 0,
    reason: [64]u8 = [_]u8{0} ** 64,
    reason_truncated: bool = false,
    message_len: u16 = 0,
    message: [256]u8 = [_]u8{0} ** 256,
    message_truncated: bool = false,
    payload_len: u16 = 0,
    payload: [256]u8 = [_]u8{0} ** 256,
    payload_truncated: bool = false,

    /// Return the copied Kubernetes `Status.reason`.
    pub fn reasonSlice(self: *const WatchErrorDetail) []const u8 {
        return self.reason[0..self.reason_len];
    }

    /// Return the copied diagnostic or Kubernetes `Status.message`.
    pub fn messageSlice(self: *const WatchErrorDetail) []const u8 {
        return self.message[0..self.message_len];
    }

    /// Return the copied prefix of a malformed payload.
    pub fn payloadSlice(self: *const WatchErrorDetail) []const u8 {
        return self.payload[0..self.payload_len];
    }

    fn fromMalformed(err: anyerror, payload: []const u8) WatchErrorDetail {
        var detail: WatchErrorDetail = .{};
        const message = @errorName(err);
        detail.message_len = @intCast(@min(message.len, detail.message.len));
        @memcpy(detail.message[0..detail.message_len], message[0..detail.message_len]);
        detail.payload_len = @intCast(@min(payload.len, detail.payload.len));
        @memcpy(detail.payload[0..detail.payload_len], payload[0..detail.payload_len]);
        detail.payload_truncated = payload.len > detail.payload.len;
        return detail;
    }

    fn fromStatus(code: ?i64, reason: ?[]const u8, message: ?[]const u8) WatchErrorDetail {
        var detail: WatchErrorDetail = .{};
        if (code) |value| detail.code = std.math.cast(u16, value);
        if (reason) |value| {
            detail.reason_len = @intCast(@min(value.len, detail.reason.len));
            @memcpy(detail.reason[0..detail.reason_len], value[0..detail.reason_len]);
            detail.reason_truncated = value.len > detail.reason.len;
        }
        if (message) |value| {
            detail.message_len = @intCast(@min(value.len, detail.message.len));
            @memcpy(detail.message[0..detail.message_len], value[0..detail.message_len]);
            detail.message_truncated = value.len > detail.message.len;
        }
        return detail;
    }
};

/// Describes why one watch stream stopped without borrowing response memory.
pub const WatchOutcome = union(enum) {
    eof,
    canceled,
    http_unauthorized,
    http_forbidden,
    http_gone,
    http_throttled: struct { retry_after_seconds: ?u32 },
    http_server_error: std.http.Status,
    http_error: std.http.Status,
    malformed_event: WatchErrorDetail,
    status_expired: WatchErrorDetail,
    status_error: WatchErrorDetail,
    transport_error: anyerror,
    decode_error: WatchErrorDetail,
};

const max_watch_event_bytes = 4 << 20;

/// Watcher for streaming resource changes
pub fn Watcher(comptime T: type) type {
    return struct {
        client: *K8sClient,
        api_path: []const u8,
        resource: []const u8,
        namespace: ?[]const u8,
        options: WatchOptions,
        resource_version: ?[]const u8,
        /// True once `resource_version` points at an allocation this watcher owns
        /// (set when a BOOKMARK advances it). The initial value is borrowed from
        /// `WatchOptions` and must not be freed.
        resource_version_owned: bool,

        const Self = @This();

        /// Watch event envelope for JSON parsing.
        ///
        /// `object` is optional rather than `undefined`: a line whose `object` key is
        /// absent must not leave this field holding uninitialised memory, since the
        /// event type is only known after parsing.
        pub const WatchEnvelope = struct {
            type: []const u8 = "",
            object: ?T = null,
        };

        /// Type-only view, parsed first so control events (BOOKMARK / ERROR) are
        /// dispatched without ever binding their `object` to `T`. A BOOKMARK's object
        /// carries only `resourceVersion`, and an ERROR's is a `Status` -- neither
        /// satisfies `ObjectMeta.name`, so binding either to `T` fails outright.
        const TypeEnvelope = struct {
            type: []const u8 = "",
        };

        /// Minimal view for extracting a BOOKMARK's resourceVersion.
        const BookmarkEnvelope = struct {
            object: struct {
                metadata: struct {
                    resourceVersion: ?[]const u8 = null,
                } = .{},
            } = .{},
        };

        const StatusEnvelope = struct {
            object: ?struct {
                status: ?[]const u8 = null,
                message: ?[]const u8 = null,
                reason: ?[]const u8 = null,
                code: ?i64 = null,
            } = null,
        };

        pub fn init(
            client: *K8sClient,
            api_path: []const u8,
            resource: []const u8,
            namespace: ?[]const u8,
            options: WatchOptions,
        ) Self {
            return .{
                .client = client,
                .api_path = api_path,
                .resource = resource,
                .namespace = namespace,
                .options = options,
                .resource_version = options.resource_version,
                .resource_version_owned = false,
            };
        }

        /// Free the resourceVersion if this watcher owns it. Safe to call when it
        /// does not, and safe to call more than once.
        pub fn deinit(self: *Self) void {
            if (self.resource_version_owned) {
                if (self.resource_version) |rv| self.client.allocator.free(rv);
                self.resource_version = null;
                self.resource_version_owned = false;
            }
        }

        /// Replace `resource_version` with an owned copy of `rv`.
        ///
        /// The source slice lives in a parse arena that is freed as soon as the event
        /// is released, so storing it directly would dangle -- and the stale pointer
        /// would then be interpolated into the next watch URL.
        fn setResourceVersion(self: *Self, rv: []const u8) !void {
            const owned = try self.client.allocator.dupe(u8, rv);
            self.deinit();
            self.resource_version = owned;
            self.resource_version_owned = true;
        }

        /// Start watching for resource changes (stateless callback).
        /// Callback receives a WatchEvent that owns its memory — caller must
        /// call event.deinit() inside the callback when done.
        pub fn watch(
            self: *Self,
            callback: *const fn (*WatchEvent(T)) anyerror!void,
        ) !void {
            return compatibility(try self.watchOutcome(callback));
        }

        /// Watch until the stream terminates and return its structured outcome.
        ///
        /// Callback failures and allocation failures remain errors.
        pub fn watchOutcome(
            self: *Self,
            callback: *const fn (*WatchEvent(T)) anyerror!void,
        ) !WatchOutcome {
            const Cb = *const fn (*WatchEvent(T)) anyerror!void;
            return self.watchOutcomeImpl(Cb, callback, struct {
                fn cb(cb_fn: Cb, event: *WatchEvent(T)) anyerror!void {
                    return cb_fn(event);
                }
            }.cb);
        }

        /// Start watching with a context pointer (for stateful callbacks like Informer).
        /// Standard Zig pattern: context + fn(context, event) for closure-like behavior.
        pub fn watchWithContext(
            self: *Self,
            comptime Ctx: type,
            context: Ctx,
            callback: *const fn (Ctx, *WatchEvent(T)) anyerror!void,
        ) !void {
            return compatibility(try self.watchWithContextOutcome(Ctx, context, callback));
        }

        /// Context-carrying form of `watchOutcome`.
        pub fn watchWithContextOutcome(
            self: *Self,
            comptime Ctx: type,
            context: Ctx,
            callback: *const fn (Ctx, *WatchEvent(T)) anyerror!void,
        ) !WatchOutcome {
            return self.watchOutcomeImpl(Ctx, context, callback);
        }

        fn compatibility(outcome: WatchOutcome) !void {
            return switch (outcome) {
                .eof => {},
                .canceled => error.Canceled,
                .http_gone, .status_expired => error.ExpiredResourceVersion,
                .transport_error => |err| err,
                .http_unauthorized,
                .http_forbidden,
                .http_throttled,
                .http_server_error,
                .http_error,
                .malformed_event,
                .status_error,
                .decode_error,
                => error.WatchFailed,
            };
        }

        fn classifyHttp(meta: StreamResponseMeta) WatchOutcome {
            return switch (meta.status) {
                .unauthorized => .http_unauthorized,
                .forbidden => .http_forbidden,
                .gone => .http_gone,
                .too_many_requests => .{ .http_throttled = .{
                    .retry_after_seconds = meta.retry_after_seconds,
                } },
                else => if (meta.status.class() == .server_error)
                    .{ .http_server_error = meta.status }
                else
                    .{ .http_error = meta.status },
            };
        }

        fn watchOutcomeImpl(
            self: *Self,
            comptime Ctx: type,
            context: Ctx,
            callback: *const fn (Ctx, *WatchEvent(T)) anyerror!void,
        ) !WatchOutcome {
            const path = try self.buildWatchPath();
            defer self.client.allocator.free(path);

            const State = struct {
                watcher: *Self,
                context: Ctx,
                callback: *const fn (Ctx, *WatchEvent(T)) anyerror!void,
                outcome: ?WatchOutcome = null,
                callback_error: ?anyerror = null,

                fn onResponse(
                    state: *@This(),
                    meta: StreamResponseMeta,
                    reader: *std.Io.Reader,
                ) anyerror!void {
                    if (meta.status != .ok) {
                        state.outcome = classifyHttp(meta);
                        return;
                    }
                    state.outcome = try state.watcher.consumeEvents(
                        Ctx,
                        state.context,
                        state.callback,
                        reader,
                        &state.callback_error,
                    );
                }
            };

            var state: State = .{
                .watcher = self,
                .context = context,
                .callback = callback,
            };
            self.client.streamGet(
                self.client.io,
                path,
                .{},
                &state,
                State.onResponse,
            ) catch |err| {
                if (state.callback_error) |callback_error| return callback_error;
                if (err == error.OutOfMemory) return err;
                if (err == error.Canceled) return .canceled;
                return .{ .transport_error = err };
            };
            return state.outcome orelse .{ .transport_error = error.WatchFailed };
        }

        fn consumeEvents(
            self: *Self,
            comptime Ctx: type,
            context: Ctx,
            callback: *const fn (Ctx, *WatchEvent(T)) anyerror!void,
            reader: *std.Io.Reader,
            callback_error: *?anyerror,
        ) !WatchOutcome {
            const line_storage = try self.client.allocator.alloc(u8, max_watch_event_bytes + 1);
            defer self.client.allocator.free(line_storage);

            while (true) {
                var line_writer: std.Io.Writer = .fixed(line_storage);
                const line_len = reader.streamDelimiterLimit(
                    &line_writer,
                    '\n',
                    .limited(line_storage.len),
                ) catch |err| switch (err) {
                    error.ReadFailed => return error.ReadFailed,
                    error.StreamTooLong => return .{
                        .malformed_event = .fromMalformed(error.StreamTooLong, line_writer.buffered()),
                    },
                    error.WriteFailed => return .{
                        .decode_error = .fromMalformed(error.WriteFailed, line_writer.buffered()),
                    },
                };

                var ended = false;
                const next = reader.peekByte() catch |err| switch (err) {
                    error.EndOfStream => blk: {
                        ended = true;
                        break :blk null;
                    },
                    error.ReadFailed => return error.ReadFailed,
                };
                if (next) |byte| {
                    if (byte != '\n') {
                        return .{ .decode_error = .fromMalformed(
                            error.WatchDelimiterMissing,
                            line_writer.buffered(),
                        ) };
                    }
                    reader.toss(1);
                }

                if (line_len > max_watch_event_bytes) {
                    return .{ .malformed_event = .fromMalformed(
                        error.StreamTooLong,
                        line_writer.buffered(),
                    ) };
                }
                if (line_len == 0) {
                    if (ended) return .eof;
                    continue;
                }

                const line = line_writer.buffered();
                const event_type = self.peekEventType(line) catch |err| {
                    if (err == error.OutOfMemory) return err;
                    return .{ .malformed_event = .fromMalformed(err, line) };
                };
                switch (event_type) {
                    .BOOKMARK => {
                        self.applyBookmark(line) catch |err| {
                            if (err == error.OutOfMemory) return err;
                            return .{ .decode_error = .fromMalformed(err, line) };
                        };
                    },
                    .ERROR => {
                        const detail = self.parseStatusEvent(line) catch |err| {
                            if (err == error.OutOfMemory) return err;
                            return .{ .decode_error = .fromMalformed(err, line) };
                        };
                        if (detail.code == 410 or std.mem.eql(u8, detail.reasonSlice(), "Expired"))
                            return .{ .status_expired = detail };
                        return .{ .status_error = detail };
                    },
                    .ADDED, .MODIFIED, .DELETED => {
                        var event = self.parseWatchEvent(line) catch |err| {
                            if (err == error.OutOfMemory) return err;
                            return .{ .malformed_event = .fromMalformed(err, line) };
                        };
                        callback(context, &event) catch |err| {
                            callback_error.* = err;
                            return error.WatchCallbackFailed;
                        };
                    },
                }

                if (ended) return .eof;
            }
        }

        /// Build watch path with query parameters.
        ///
        /// Values go through QueryWriter, which percent-encodes them. This previously
        /// hand-built the query with raw `&key={s}` prints, so it never received the
        /// encoding fix that ListOptions did: a set-based selector from
        /// `LabelSelector.addIn` ("app in (a,b)") carries spaces and parentheses and
        /// produced a malformed request line -- 400 on every such watch.
        fn buildWatchPath(self: *Self) ![]const u8 {
            const allocator = self.client.allocator;

            var query = try QueryWriter.init(allocator);
            defer query.deinit();

            try query.addFlag("watch");
            try query.addOptionalString("resourceVersion", self.resource_version);
            try query.addOptionalInt("timeoutSeconds", self.options.timeout_seconds);
            try query.addOptionalString("labelSelector", self.options.label_selector);
            try query.addOptionalString("fieldSelector", self.options.field_selector);
            try query.addBoolFlag("allowWatchBookmarks", self.options.allow_watch_bookmarks);

            const query_string = try query.toOwnedSlice();
            defer allocator.free(query_string);

            if (self.namespace) |ns| {
                return std.fmt.allocPrint(allocator, "{s}/namespaces/{s}/{s}?{s}", .{
                    self.api_path,
                    ns,
                    self.resource,
                    query_string,
                });
            }
            return std.fmt.allocPrint(allocator, "{s}/{s}?{s}", .{
                self.api_path,
                self.resource,
                query_string,
            });
        }

        /// Parse a watch event from a JSON line.
        /// Returns an event that owns its parsed JSON memory.
        fn parseWatchEvent(self: *Self, json_line: []const u8) !WatchEvent(T) {
            const parsed = try std.json.parseFromSlice(
                WatchEnvelope,
                self.client.allocator,
                json_line,
                .{ .ignore_unknown_fields = true, .allocate = .alloc_always },
            );
            errdefer parsed.deinit();

            const event_type = EventType.fromString(parsed.value.type) orelse .ERROR;
            const object = parsed.value.object orelse return error.WatchEventMissingObject;

            return WatchEvent(T){
                .type_ = event_type,
                .object = object,
                ._parsed = parsed,
            };
        }

        /// Read just the `type` field of a watch line.
        fn peekEventType(self: *Self, json_line: []const u8) !EventType {
            const parsed = try std.json.parseFromSlice(
                TypeEnvelope,
                self.client.allocator,
                json_line,
                .{ .ignore_unknown_fields = true },
            );
            defer parsed.deinit();
            return EventType.fromString(parsed.value.type) orelse error.UnknownWatchEventType;
        }

        fn parseStatusEvent(self: *Self, json_line: []const u8) !WatchErrorDetail {
            const parsed = try std.json.parseFromSlice(
                StatusEnvelope,
                self.client.allocator,
                json_line,
                .{ .ignore_unknown_fields = true },
            );
            defer parsed.deinit();
            const status = parsed.value.object orelse return error.WatchStatusMissingObject;
            return .fromStatus(status.code, status.reason, status.message);
        }

        /// Advance `resource_version` from a BOOKMARK line.
        fn applyBookmark(self: *Self, json_line: []const u8) !void {
            const parsed = try std.json.parseFromSlice(
                BookmarkEnvelope,
                self.client.allocator,
                json_line,
                .{ .ignore_unknown_fields = true, .allocate = .alloc_always },
            );
            defer parsed.deinit();

            const resource_version = parsed.value.object.metadata.resourceVersion orelse
                return error.BookmarkMissingResourceVersion;
            try self.setResourceVersion(resource_version);
        }
    };
}

/// Informer maintains a local cache of resources and watches for changes.
/// Thread-safe: cache access is protected by a mutex.
///
/// Uses the list-then-watch pattern: on start(), performs an initial list to
/// populate the cache, then watches for incremental updates.
pub fn Informer(comptime T: type) type {
    return struct {
        client: *K8sClient,
        api_path: []const u8,
        resource: []const u8,
        namespace: ?[]const u8,
        /// Cache owns each entry's memory via its own parsed arena, independent of
        /// the transient list/watch parse buffers (which are freed after each event).
        cache: std.StringHashMap(std.json.Parsed(T)),
        /// Owned (duped) copy — the source slice lives in a parse arena that gets freed.
        resource_version: ?[]const u8,
        running: std.atomic.Value(bool),
        mutex: std.atomic.Mutex,

        const Self = @This();

        pub fn init(
            allocator: std.mem.Allocator,
            client: *K8sClient,
            api_path: []const u8,
            resource: []const u8,
            namespace: ?[]const u8,
        ) Self {
            return .{
                .client = client,
                .api_path = api_path,
                .resource = resource,
                .namespace = namespace,
                .cache = std.StringHashMap(std.json.Parsed(T)).init(allocator),
                .resource_version = null,
                .running = std.atomic.Value(bool).init(false),
                .mutex = .unlocked,
            };
        }

        pub fn deinit(self: *Self) void {
            lockMutex(&self.mutex);
            defer self.mutex.unlock();
            const allocator = self.cache.allocator;
            var it = self.cache.valueIterator();
            while (it.next()) |parsed| parsed.deinit();
            self.cache.deinit();
            if (self.resource_version) |rv| allocator.free(rv);
        }

        /// Deep-own `object` in its own parsed arena and insert/replace it in the cache.
        /// Caller MUST hold the mutex. Re-serializes then re-parses so cached memory is
        /// independent of the transient list/watch parse arena that gets freed per event.
        fn cachePut(self: *Self, object: T) !void {
            const allocator = self.cache.allocator;
            const json_bytes = try std.json.Stringify.valueAlloc(allocator, object, .{ .emit_null_optional_fields = false });
            defer allocator.free(json_bytes);
            const parsed = try std.json.parseFromSlice(T, allocator, json_bytes, .{
                .ignore_unknown_fields = true,
                .allocate = .alloc_always,
            });
            errdefer parsed.deinit();
            // Key slice lives in `parsed`'s arena, so it stays valid for the entry's
            // lifetime. Remove any prior entry first so its key+value are freed together.
            const key = parsed.value.metadata.name;
            if (self.cache.fetchRemove(key)) |old| old.value.deinit();
            try self.cache.put(key, parsed);
        }

        /// Remove and free a cache entry by name. Caller MUST hold the mutex.
        fn cacheRemove(self: *Self, name: []const u8) void {
            if (self.cache.fetchRemove(name)) |old| old.value.deinit();
        }

        /// Replace the stored resourceVersion with an owned copy (the source slice
        /// lives in a parse arena that is freed after the list/watch call returns).
        fn setResourceVersion(self: *Self, rv: ?[]const u8) !void {
            const allocator = self.cache.allocator;
            const owned: ?[]const u8 = if (rv) |v| try allocator.dupe(u8, v) else null;
            if (self.resource_version) |old| allocator.free(old);
            self.resource_version = owned;
        }

        /// Start the informer (list then watch).
        /// Blocks until stop() is called or an unrecoverable error occurs.
        pub fn start(self: *Self) !void {
            self.running.store(true, .release);

            try self.initialList();

            while (self.running.load(.acquire)) {
                self.watchLoop() catch |err| {
                    // On watch errors, retry if still running
                    if (!self.running.load(.acquire)) return;
                    switch (err) {
                        // resourceVersion expired (HTTP 410) — re-list from scratch and
                        // resume watching from the fresh version (client-go's relist).
                        error.ExpiredResourceVersion => {
                            try self.setResourceVersion(null);
                            try self.initialList();
                        },
                        else => return err,
                    }
                };
            }
        }

        /// Stop the informer
        pub fn stop(self: *Self) void {
            self.running.store(false, .release);
        }

        /// Get resource from cache by name (thread-safe).
        /// NOTE: the returned T borrows cache-owned memory; it is valid until the next
        /// mutation of that entry. Copy out any fields you need to retain.
        pub fn get(self: *Self, name: []const u8) ?T {
            lockMutex(&self.mutex);
            defer self.mutex.unlock();
            if (self.cache.get(name)) |parsed| return parsed.value;
            return null;
        }

        /// List all resources in cache (thread-safe)
        pub fn listCached(self: *Self) ![]T {
            lockMutex(&self.mutex);
            defer self.mutex.unlock();

            const allocator = self.cache.allocator;
            var result_list = try std.ArrayList(T).initCapacity(allocator, 0);
            errdefer result_list.deinit(allocator);

            var it = self.cache.valueIterator();
            while (it.next()) |parsed| {
                try result_list.append(allocator, parsed.value);
            }

            return try result_list.toOwnedSlice(allocator);
        }

        /// Initial list to populate cache
        fn initialList(self: *Self) !void {
            const rc = ResourceClient(T){
                .client = self.client,
                .api_path = self.api_path,
                .resource = self.resource,
            };

            const result = try rc.list(self.namespace);
            defer result.deinit();

            lockMutex(&self.mutex);
            defer self.mutex.unlock();

            // Replace the cache contents (this also runs on a relist after a 410, so
            // entries deleted while we were disconnected must not linger).
            var it = self.cache.valueIterator();
            while (it.next()) |parsed| parsed.deinit();
            self.cache.clearRetainingCapacity();

            // Populate cache from list result. In the current List(T) schema
            // `items` is non-optional, so iterate it directly.
            for (result.value.items) |item| {
                if (@hasField(T, "metadata")) {
                    if (item.metadata.name.len > 0) {
                        try self.cachePut(item);
                    }
                }
            }

            // Store resource version for subsequent watch (duped — the source slice
            // is freed when `result` is deinit'd above).
            try self.setResourceVersion(result.value.metadata.resourceVersion);
        }

        /// Watch loop to keep cache updated.
        /// Uses watchWithContext to pass the informer as context to the callback,
        /// enabling cache updates from within the event handler.
        fn watchLoop(self: *Self) !void {
            var watcher = Watcher(T).init(
                self.client,
                self.api_path,
                self.resource,
                self.namespace,
                .{
                    .resource_version = self.resource_version,
                    .allow_watch_bookmarks = true,
                },
            );

            defer watcher.deinit();

            try watcher.watchWithContext(*Self, self, handleWatchEvent);

            // After watch stream ends, update resource version for reconnection
            // (duped — watcher's slice may live in a buffer freed when it goes out of scope).
            try self.setResourceVersion(watcher.resource_version);
        }

        /// Callback for watch events — updates the informer cache.
        fn handleWatchEvent(self: *Self, event: *WatchEvent(T)) anyerror!void {
            defer event.deinit();

            lockMutex(&self.mutex);
            defer self.mutex.unlock();

            if (@hasField(T, "metadata")) {
                const name = event.object.metadata.name;
                switch (event.type_) {
                    .ADDED, .MODIFIED => try self.cachePut(event.object),
                    .DELETED => self.cacheRemove(name),
                    else => {},
                }
            }
        }
    };
}
