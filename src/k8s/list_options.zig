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

    /// Build query string from options
    pub fn buildQueryString(self: ListOptions, allocator: std.mem.Allocator) ![]const u8 {
        var query_parts = try std.ArrayList([]const u8).initCapacity(allocator, 0);
        defer {
            for (query_parts.items) |part| {
                allocator.free(part);
            }
            query_parts.deinit(allocator);
        }

        // Field selector
        if (self.field_selector) |fs| {
            const part = try std.fmt.allocPrint(allocator, "fieldSelector={s}", .{fs});
            try query_parts.append(allocator, part);
        }

        // Label selector
        if (self.label_selector) |ls| {
            const part = try std.fmt.allocPrint(allocator, "labelSelector={s}", .{ls});
            try query_parts.append(allocator, part);
        }

        // Limit
        if (self.limit) |limit| {
            const part = try std.fmt.allocPrint(allocator, "limit={d}", .{limit});
            try query_parts.append(allocator, part);
        }

        // Continue token
        if (self.continue_token) |ct| {
            const part = try std.fmt.allocPrint(allocator, "continue={s}", .{ct});
            try query_parts.append(allocator, part);
        }

        // Resource version
        if (self.resource_version) |rv| {
            const part = try std.fmt.allocPrint(allocator, "resourceVersion={s}", .{rv});
            try query_parts.append(allocator, part);
        }

        // Resource version match
        if (self.resource_version_match) |rvm| {
            const part = try std.fmt.allocPrint(allocator, "resourceVersionMatch={s}", .{rvm});
            try query_parts.append(allocator, part);
        }

        // Timeout
        if (self.timeout_seconds) |timeout| {
            const part = try std.fmt.allocPrint(allocator, "timeoutSeconds={d}", .{timeout});
            try query_parts.append(allocator, part);
        }

        // Pretty
        if (self.pretty) {
            const part = try std.fmt.allocPrint(allocator, "pretty=true", .{});
            try query_parts.append(allocator, part);
        }

        // Allow watch bookmarks
        if (self.allow_watch_bookmarks) {
            const part = try std.fmt.allocPrint(allocator, "allowWatchBookmarks=true", .{});
            try query_parts.append(allocator, part);
        }

        // Send initial events
        if (self.send_initial_events) {
            const part = try std.fmt.allocPrint(allocator, "sendInitialEvents=true", .{});
            try query_parts.append(allocator, part);
        }

        if (query_parts.items.len == 0) {
            return try allocator.dupe(u8, "");
        }

        // Join with &
        return try std.mem.join(allocator, "&", query_parts.items);
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
