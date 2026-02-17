const std = @import("std");
const K8sClient = @import("client.zig").K8sClient;
const types = @import("types.zig");

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

/// Watch event for a specific resource type
pub fn WatchEvent(comptime T: type) type {
    return struct {
        type_: EventType,
        object: T,
        
        pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
            _ = allocator;
            _ = self;
            // Resource cleanup depends on T's structure
            // This is a placeholder - actual cleanup would be type-specific
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
        
        /// Start watching for resource changes
        /// Callback is called for each event received
        pub fn watch(
            self: *Self,
            callback: *const fn (WatchEvent(T)) anyerror!void,
        ) !void {
            const path = try self.buildWatchPath();
            defer self.client.allocator.free(path);
            
            // Make watch request (streaming) - stack-allocated URL
            var url_buf: [4096]u8 = undefined;
            const url = try std.fmt.bufPrint(
                &url_buf,
                "{s}{s}",
                .{ self.client.api_server, path },
            );
            
            const uri = try std.Uri.parse(url);
            
            // Build headers
            var header_buffer: [4096]u8 = undefined;
            var headers = std.http.Client.Request.Headers{};
            
            if (self.client.token) |token| {
                const auth_value = try std.fmt.bufPrint(&header_buffer, "Bearer {s}", .{token});
                headers.authorization = .{ .override = auth_value };
            }
            
            // Make streaming request
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
            
            // Read streaming events line by line
            var transfer_buffer: [4096]u8 = undefined;
            const reader = response.reader(&transfer_buffer);
            
            var line_buffer: [256 * 1024]u8 = undefined;
            while (true) {
                // Read one line (one JSON event)
                const line = reader.readUntilDelimiterOrEof(&line_buffer, '\n') catch |err| {
                    if (err == error.ReadFailed) {
                        if (response.bodyErr()) |body_err| {
                            return body_err;
                        }
                    }
                    return err;
                } orelse break; // EOF
                
                if (line.len == 0) continue;
                
                // Parse watch event
                const event = try self.parseWatchEvent(line);
                
                // Update resource version from event
                if (event.type_ == .BOOKMARK) {
                    // Extract resource version from bookmark
                    // (stored in object.metadata.resourceVersion)
                    continue;
                }
                
                // Call user callback
                try callback(event);
            }
        }
        
        /// Build watch path with query parameters
        fn buildWatchPath(self: *Self) ![]const u8 {
            var path_list = std.ArrayList(u8).init(self.client.allocator);
            errdefer path_list.deinit();
            
            const writer = path_list.writer();
            
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
            
            return try path_list.toOwnedSlice();
        }
        
        /// Watch event envelope for single-pass JSON parsing
        const WatchEnvelope = struct {
            type: []const u8 = "",
            object: T = undefined,
        };

        /// Parse a watch event from JSON line (single-pass)
        fn parseWatchEvent(self: *Self, json_line: []const u8) !WatchEvent(T) {
            const parsed = try std.json.parseFromSlice(
                WatchEnvelope,
                self.client.allocator,
                json_line,
                .{ .ignore_unknown_fields = true, .allocate = .alloc_always },
            );
            // Note: parsed memory is owned by caller via the returned object
            // For watch events in a streaming context, this is acceptable as
            // events are processed and discarded one at a time

            const event_type = EventType.fromString(parsed.value.type) orelse .ERROR;

            return WatchEvent(T){
                .type_ = event_type,
                .object = parsed.value.object,
            };
        }
    };
}

/// Informer maintains a local cache of resources and watches for changes.
/// Thread-safe: cache access is protected by a mutex.
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

        /// Start the informer (list then watch)
        pub fn start(self: *Self) !void {
            self.running.store(true, .release);

            // Initial list to populate cache
            try self.list();

            // Start watch loop
            while (self.running.load(.acquire)) {
                try self.watchLoop();
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

            var it = self.cache.valueIterator();
            while (it.next()) |value| {
                try result_list.append(value.*);
            }

            return try result_list.toOwnedSlice();
        }

        /// Initial list to populate cache
        fn list(self: *Self) !void {
            // This would use the list API to get all resources
            // For now, placeholder
            _ = self;
        }

        /// Watch loop to keep cache updated
        fn watchLoop(self: *Self) !void {
            const watcher = Watcher(T).init(
                self.client,
                self.api_path,
                self.resource,
                self.namespace,
                .{
                    .resource_version = self.resource_version,
                    .allow_watch_bookmarks = true,
                },
            );

            // Watch for events and update cache
            _ = watcher;
            // Implementation would call watcher.watch() with callback
        }
    };
}
