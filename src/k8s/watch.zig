const std = @import("std");
const K8sClient = @import("client.zig").K8sClient;
const types = @import("types.zig");
const ResourceClient = @import("resources.zig").ResourceClient;

const log = std.log.scoped(.klient_watch);

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
            const Cb = *const fn (*WatchEvent(T)) anyerror!void;
            return self.watchImpl(Cb, callback, struct {
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
            return self.watchImpl(Ctx, context, callback);
        }

        fn watchImpl(
            self: *Self,
            comptime Ctx: type,
            context: Ctx,
            callback: *const fn (Ctx, *WatchEvent(T)) anyerror!void,
        ) !void {
            const path = try self.buildWatchPath();
            defer self.client.allocator.free(path);

            var url_buf: [4096]u8 = undefined;
            const url = try std.fmt.bufPrint(
                &url_buf,
                "{s}{s}",
                .{ self.client.api_server, path },
            );

            const uri = try std.Uri.parse(url);

            var header_buffer: [4096]u8 = undefined;
            var headers = std.http.Client.Request.Headers{};

            if (self.client.token) |token| {
                const auth_value = try std.fmt.bufPrint(&header_buffer, "Bearer {s}", .{token});
                headers.authorization = .{ .override = auth_value };
            }

            var req = try self.client.http_client.request(.GET, uri, .{
                .redirect_behavior = @enumFromInt(3),
                .headers = headers,
            });
            defer req.deinit();

            try req.sendBodiless();

            var redirect_buffer: [2048]u8 = undefined;
            var response = try req.receiveHead(&redirect_buffer);

            // 410 Gone = the resourceVersion is too old / compacted away. Surface it
            // distinctly so an Informer can re-list from scratch (the canonical
            // list-then-watch recovery) instead of spinning on a doomed watch.
            if (response.head.status == .gone) {
                return error.ExpiredResourceVersion;
            }
            if (response.head.status != .ok) {
                return error.WatchFailed;
            }

            var transfer_buffer: [256 * 1024]u8 = undefined;
            var reader = response.reader(&transfer_buffer);

            while (true) {
                const line = reader.takeDelimiter('\n') catch |err| {
                    switch (err) {
                        error.ReadFailed => {
                            if (response.bodyErr()) |body_err| {
                                return body_err;
                            }
                            return error.WatchFailed;
                        },
                        error.StreamTooLong => return error.WatchFailed,
                    }
                } orelse break;

                if (line.len == 0) continue;

                // Dispatch on the event type before binding `object` to `T`.
                const event_type = self.peekEventType(line) orelse {
                    log.warn("watch: skipping line with unreadable event type", .{});
                    continue;
                };

                switch (event_type) {
                    .BOOKMARK => {
                        self.applyBookmark(line) catch |err| {
                            log.warn("watch: bookmark ignored: {t}", .{err});
                        };
                        continue;
                    },
                    // An ERROR carries a Status, not a T. Surfacing it properly needs a
                    // separate envelope; until then do not abort the stream over it.
                    .ERROR => {
                        log.warn("watch: server sent an ERROR event", .{});
                        continue;
                    },
                    .ADDED, .MODIFIED, .DELETED => {},
                }

                // A single malformed object must not tear down the whole watch.
                var event = self.parseWatchEvent(line) catch |err| {
                    log.warn("watch: skipping unparseable event: {t}", .{err});
                    continue;
                };

                try callback(context, &event);
            }
        }

        /// Build watch path with query parameters
        fn buildWatchPath(self: *Self) ![]const u8 {
            const allocator = self.client.allocator;
            var path_list = try std.ArrayList(u8).initCapacity(allocator, 0);
            errdefer path_list.deinit(allocator);

            // Zig 0.16: unmanaged ArrayList uses .print(gpa, fmt, args) directly;
            // the .writer() method was removed.
            if (self.namespace) |ns| {
                try path_list.print(allocator, "{s}/namespaces/{s}/{s}?watch=true", .{
                    self.api_path,
                    ns,
                    self.resource,
                });
            } else {
                try path_list.print(allocator, "{s}/{s}?watch=true", .{
                    self.api_path,
                    self.resource,
                });
            }

            if (self.resource_version) |rv| {
                try path_list.print(allocator, "&resourceVersion={s}", .{rv});
            }

            if (self.options.timeout_seconds) |timeout| {
                try path_list.print(allocator, "&timeoutSeconds={d}", .{timeout});
            }

            if (self.options.label_selector) |selector| {
                try path_list.print(allocator, "&labelSelector={s}", .{selector});
            }

            if (self.options.field_selector) |selector| {
                try path_list.print(allocator, "&fieldSelector={s}", .{selector});
            }

            if (self.options.allow_watch_bookmarks) {
                try path_list.appendSlice(allocator, "&allowWatchBookmarks=true");
            }

            return try path_list.toOwnedSlice(allocator);
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
        fn peekEventType(self: *Self, json_line: []const u8) ?EventType {
            const parsed = std.json.parseFromSlice(
                TypeEnvelope,
                self.client.allocator,
                json_line,
                .{ .ignore_unknown_fields = true },
            ) catch return null;
            defer parsed.deinit();
            return EventType.fromString(parsed.value.type) orelse .ERROR;
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

            if (parsed.value.object.metadata.resourceVersion) |rv| {
                try self.setResourceVersion(rv);
            }
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
            const json_bytes = try std.json.Stringify.valueAlloc(allocator, object, .{});
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
