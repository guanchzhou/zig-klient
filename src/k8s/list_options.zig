const std = @import("std");

/// Options for list operations with filtering and pagination
pub const ListOptions = struct {
    /// Field selector to filter results
    /// Example: "metadata.name=my-pod,status.phase=Running"
    field_selector: ?[]const u8 = null,

    /// Label selector to filter results
    /// Example: "app=nginx,tier=frontend"
    label_selector: ?[]const u8 = null,

    /// Maximum number of results to return
    limit: ?i64 = null,

    /// Continue token for pagination
    continue_token: ?[]const u8 = null,

    /// Resource version to list from
    resource_version: ?[]const u8 = null,

    /// Resource version match strategy
    /// Options: "NotOlderThan", "Exact"
    resource_version_match: ?[]const u8 = null,

    /// Timeout for the list call in seconds
    timeout_seconds: ?i64 = null,

    /// Pretty-print the output (for debugging)
    pretty: bool = false,

    /// Allow watch bookmarks
    allow_watch_bookmarks: bool = false,

    /// Send initial events in watch
    send_initial_events: bool = false,

    /// Build query string from options (single allocation)
    pub fn buildQueryString(self: ListOptions, allocator: std.mem.Allocator) ![]const u8 {
        var buf = try std.ArrayList(u8).initCapacity(allocator, 0);
        errdefer buf.deinit(allocator);
        const writer = buf.writer(allocator);

        var first = true;
        inline for (.{
            .{ "fieldSelector", self.field_selector },
            .{ "labelSelector", self.label_selector },
            .{ "continue", self.continue_token },
            .{ "resourceVersion", self.resource_version },
            .{ "resourceVersionMatch", self.resource_version_match },
        }) |entry| {
            if (entry[1]) |val| {
                if (!first) try writer.writeByte('&');
                try writer.print("{s}={s}", .{ entry[0], val });
                first = false;
            }
        }

        if (self.limit) |limit| {
            if (!first) try writer.writeByte('&');
            try writer.print("limit={d}", .{limit});
            first = false;
        }

        if (self.timeout_seconds) |timeout| {
            if (!first) try writer.writeByte('&');
            try writer.print("timeoutSeconds={d}", .{timeout});
            first = false;
        }

        if (self.pretty) {
            if (!first) try writer.writeByte('&');
            try writer.writeAll("pretty=true");
            first = false;
        }

        if (self.allow_watch_bookmarks) {
            if (!first) try writer.writeByte('&');
            try writer.writeAll("allowWatchBookmarks=true");
            first = false;
        }

        if (self.send_initial_events) {
            if (!first) try writer.writeByte('&');
            try writer.writeAll("sendInitialEvents=true");
            first = false;
        }

        return try buf.toOwnedSlice(allocator);
    }

    /// URL encode a string for query parameters
    fn urlEncode(allocator: std.mem.Allocator, input: []const u8) ![]const u8 {
        var result = std.ArrayList(u8).init(allocator);
        defer result.deinit();

        for (input) |c| {
            if (std.ascii.isAlphanumeric(c) or c == '-' or c == '_' or c == '.' or c == '~') {
                try result.append(c);
            } else if (c == ' ') {
                try result.append('+');
            } else {
                try result.writer().print("%{X:0>2}", .{c});
            }
        }

        return try result.toOwnedSlice();
    }
};

/// Pagination helper for listing resources in chunks
pub fn PaginatedList(comptime T: type) type {
    return struct {
        items: []T,
        continue_token: ?[]const u8,
        resource_version: ?[]const u8,
        remaining_item_count: ?i64,

        /// Check if there are more pages
        pub fn hasMore(self: @This()) bool {
            return self.continue_token != null;
        }
    };
}

/// Label selector builder for type-safe label selection
pub const LabelSelector = struct {
    allocator: std.mem.Allocator,
    selectors: std.ArrayList([]const u8),

    pub fn init(allocator: std.mem.Allocator) !LabelSelector {
        return .{
            .allocator = allocator,
            .selectors = try std.ArrayList([]const u8).initCapacity(allocator, 0),
        };
    }

    pub fn deinit(self: *LabelSelector) void {
        for (self.selectors.items) |selector| {
            self.allocator.free(selector);
        }
        self.selectors.deinit(self.allocator);
    }

    /// Add equality selector: key=value
    pub fn addEquals(self: *LabelSelector, key: []const u8, value: []const u8) !void {
        const selector = try std.fmt.allocPrint(self.allocator, "{s}={s}", .{ key, value });
        try self.selectors.append(self.allocator, selector);
    }

    /// Add inequality selector: key!=value
    pub fn addNotEquals(self: *LabelSelector, key: []const u8, value: []const u8) !void {
        const selector = try std.fmt.allocPrint(self.allocator, "{s}!={s}", .{ key, value });
        try self.selectors.append(self.allocator, selector);
    }

    /// Add set-based selector: key in (value1,value2)
    pub fn addIn(self: *LabelSelector, key: []const u8, values: []const []const u8) !void {
        const values_joined = try std.mem.join(self.allocator, ",", values);
        defer self.allocator.free(values_joined);

        const selector = try std.fmt.allocPrint(self.allocator, "{s} in ({s})", .{ key, values_joined });
        try self.selectors.append(self.allocator, selector);
    }

    /// Add set-based selector: key notin (value1,value2)
    pub fn addNotIn(self: *LabelSelector, key: []const u8, values: []const []const u8) !void {
        const values_joined = try std.mem.join(self.allocator, ",", values);
        defer self.allocator.free(values_joined);

        const selector = try std.fmt.allocPrint(self.allocator, "{s} notin ({s})", .{ key, values_joined });
        try self.selectors.append(self.allocator, selector);
    }

    /// Add existence selector: key
    pub fn addExists(self: *LabelSelector, key: []const u8) !void {
        const selector = try self.allocator.dupe(u8, key);
        try self.selectors.append(self.allocator, selector);
    }

    /// Add non-existence selector: !key
    pub fn addNotExists(self: *LabelSelector, key: []const u8) !void {
        const selector = try std.fmt.allocPrint(self.allocator, "!{s}", .{key});
        try self.selectors.append(self.allocator, selector);
    }

    /// Build the final label selector string
    pub fn build(self: *LabelSelector) ![]const u8 {
        if (self.selectors.items.len == 0) {
            return try self.allocator.dupe(u8, "");
        }
        return try std.mem.join(self.allocator, ",", self.selectors.items);
    }
};

/// Field selector builder for type-safe field selection
pub const FieldSelector = struct {
    allocator: std.mem.Allocator,
    selectors: std.ArrayList([]const u8),

    pub fn init(allocator: std.mem.Allocator) !FieldSelector {
        return .{
            .allocator = allocator,
            .selectors = try std.ArrayList([]const u8).initCapacity(allocator, 0),
        };
    }

    pub fn deinit(self: *FieldSelector) void {
        for (self.selectors.items) |selector| {
            self.allocator.free(selector);
        }
        self.selectors.deinit(self.allocator);
    }

    /// Add equality selector: key=value
    pub fn addEquals(self: *FieldSelector, field: []const u8, value: []const u8) !void {
        const selector = try std.fmt.allocPrint(self.allocator, "{s}={s}", .{ field, value });
        try self.selectors.append(self.allocator, selector);
    }

    /// Add inequality selector: key!=value
    pub fn addNotEquals(self: *FieldSelector, field: []const u8, value: []const u8) !void {
        const selector = try std.fmt.allocPrint(self.allocator, "{s}!={s}", .{ field, value });
        try self.selectors.append(self.allocator, selector);
    }

    /// Build the final field selector string
    pub fn build(self: *FieldSelector) ![]const u8 {
        if (self.selectors.items.len == 0) {
            return try self.allocator.dupe(u8, "");
        }
        return try std.mem.join(self.allocator, ",", self.selectors.items);
    }
};
