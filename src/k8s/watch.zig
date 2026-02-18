const std = @import("std");
const K8sClient = @import("client.zig").K8sClient;
const types = @import("types.zig");
const ResourceClient = @import("resources.zig").ResourceClient;

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

        const Self = @This();

        /// Watch event envelope for JSON parsing
        pub const WatchEnvelope = struct {
            type: []const u8 = "",
            object: T = undefined,
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
            };
        }

        /// Start watching for resource changes (stateless callback).
        /// Callback receives a WatchEvent that owns its memory — caller must
        /// call event.deinit() inside the callback when done.
        pub fn watch(
            self: *Self,
            callback: *const fn (*WatchEvent(T)) anyerror!void,
        ) !void {
            return self.watchImpl(void, {}, struct {
                fn cb(_: void, event: *WatchEvent(T)) anyerror!void {
                    return callback(event);
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

            if (response.head.status != .ok) {
                return error.WatchFailed;
            }

            var transfer_buffer: [4096]u8 = undefined;
            const reader = response.reader(&transfer_buffer);

            var line_buffer: [256 * 1024]u8 = undefined;
            while (true) {
                const line = reader.readUntilDelimiterOrEof(&line_buffer, '\n') catch |err| {
                    if (err == error.ReadFailed) {
                        if (response.bodyErr()) |body_err| {
                            return body_err;
                        }
                    }
                    return err;
                } orelse break;

                if (line.len == 0) continue;

                var event = try self.parseWatchEvent(line);

                if (event.type_ == .BOOKMARK) {
                    if (@hasField(T, "metadata")) {
                        if (event.object.metadata.resourceVersion) |rv| {
                            self.resource_version = rv;
                        }
                    }
                    event.deinit();
                    continue;
                }

                try callback(context, &event);
            }
        }

        /// Build watch path with query parameters
        fn buildWatchPath(self: *Self) ![]const u8 {
            const allocator = self.client.allocator;
            var path_list = try std.ArrayList(u8).initCapacity(allocator, 0);
            errdefer path_list.deinit(allocator);

            const writer = path_list.writer(allocator);

            if (self.namespace) |ns| {
                try writer.print("{s}/namespaces/{s}/{s}?watch=true", .{
                    self.api_path,
                    ns,
                    self.resource,
                });
            } else {
                try writer.print("{s}/{s}?watch=true", .{
                    self.api_path,
                    self.resource,
                });
            }

            if (self.resource_version) |rv| {
                try writer.print("&resourceVersion={s}", .{rv});
            }

            if (self.options.timeout_seconds) |timeout| {
                try writer.print("&timeoutSeconds={d}", .{timeout});
            }

            if (self.options.label_selector) |selector| {
                try writer.print("&labelSelector={s}", .{selector});
            }

            if (self.options.field_selector) |selector| {
                try writer.print("&fieldSelector={s}", .{selector});
            }

            if (self.options.allow_watch_bookmarks) {
                try writer.writeAll("&allowWatchBookmarks=true");
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

            const event_type = EventType.fromString(parsed.value.type) orelse .ERROR;

            return WatchEvent(T){
                .type_ = event_type,
                .object = parsed.value.object,
                ._parsed = parsed,
            };
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
        cache: std.StringHashMap(T),
        resource_version: ?[]const u8,
        running: std.atomic.Value(bool),
        mutex: std.Thread.Mutex,

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
                .cache = std.StringHashMap(T).init(allocator),
                .resource_version = null,
                .running = std.atomic.Value(bool).init(false),
                .mutex = .{},
            };
        }

        pub fn deinit(self: *Self) void {
            self.mutex.lock();
            defer self.mutex.unlock();
            self.cache.deinit();
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
                    return err;
                };
            }
        }

        /// Stop the informer
        pub fn stop(self: *Self) void {
            self.running.store(false, .release);
        }

        /// Get resource from cache by name (thread-safe)
        pub fn get(self: *Self, name: []const u8) ?T {
            self.mutex.lock();
            defer self.mutex.unlock();
            return self.cache.get(name);
        }

        /// List all resources in cache (thread-safe)
        pub fn listCached(self: *Self) ![]T {
            self.mutex.lock();
            defer self.mutex.unlock();

            var result_list = std.ArrayList(T).init(self.cache.allocator);
            errdefer result_list.deinit();

            var it = self.cache.valueIterator();
            while (it.next()) |value| {
                try result_list.append(value.*);
            }

            return try result_list.toOwnedSlice();
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

            self.mutex.lock();
            defer self.mutex.unlock();

            // Populate cache from list result
            if (result.value.items) |items| {
                for (items) |item| {
                    if (@hasField(T, "metadata")) {
                        if (item.metadata.name.len > 0) {
                            try self.cache.put(item.metadata.name, item);
                        }
                    }
                }
            }

            // Store resource version for subsequent watch
            if (result.value.metadata) |meta| {
                self.resource_version = meta.resourceVersion;
            }
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

            try watcher.watchWithContext(*Self, self, handleWatchEvent);

            // After watch stream ends, update resource version for reconnection
            self.resource_version = watcher.resource_version;
        }

        /// Callback for watch events — updates the informer cache.
        fn handleWatchEvent(self: *Self, event: *WatchEvent(T)) anyerror!void {
            defer event.deinit();

            self.mutex.lock();
            defer self.mutex.unlock();

            if (@hasField(T, "metadata")) {
                const name = event.object.metadata.name;
                switch (event.type_) {
                    .ADDED, .MODIFIED => {
                        try self.cache.put(name, event.object);
                    },
                    .DELETED => {
                        _ = self.cache.remove(name);
                    },
                    else => {},
                }
            }
        }
    };
}
