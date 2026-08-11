/// Shared query string builder — eliminates duplication across
/// list_options.zig, delete_options.zig, and apply.zig.
const std = @import("std");

pub const QueryWriter = struct {
    buf: std.ArrayList(u8),
    allocator: std.mem.Allocator,
    has_param: bool = false,

    pub fn init(allocator: std.mem.Allocator) !QueryWriter {
        return .{
            .buf = try std.ArrayList(u8).initCapacity(allocator, 0),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *QueryWriter) void {
        self.buf.deinit(self.allocator);
    }

    /// RFC 3986 unreserved set. Everything else in a *value* is percent-encoded:
    /// anything structural (`&`, `=`) would corrupt the query, and a raw space
    /// terminates the HTTP request target outright.
    fn isUnreserved(c: u8) bool {
        return switch (c) {
            'A'...'Z', 'a'...'z', '0'...'9', '-', '.', '_', '~' => true,
            else => false,
        };
    }

    /// Add a string parameter: key=value.
    ///
    /// The value is percent-encoded. Set-based label selectors (`app in (a,b)`,
    /// produced by `LabelSelector.addIn`) contain spaces and parentheses; emitted
    /// raw they produced a malformed request line and the API server answered
    /// 400 Bad Request on every such query.
    pub fn addString(self: *QueryWriter, key: []const u8, value: []const u8) !void {
        if (self.has_param) try self.buf.append(self.allocator, '&');
        try self.buf.appendSlice(self.allocator, key);
        try self.buf.append(self.allocator, '=');
        try self.appendEncoded(value);
        self.has_param = true;
    }

    fn appendEncoded(self: *QueryWriter, value: []const u8) !void {
        const hex = "0123456789ABCDEF";
        for (value) |c| {
            if (isUnreserved(c)) {
                try self.buf.append(self.allocator, c);
            } else {
                try self.buf.appendSlice(self.allocator, &.{ '%', hex[c >> 4], hex[c & 0x0F] });
            }
        }
    }

    /// Add an integer parameter: key=123
    pub fn addInt(self: *QueryWriter, key: []const u8, value: anytype) !void {
        if (self.has_param) try self.buf.append(self.allocator, '&');
        try self.buf.appendSlice(self.allocator, key);
        try self.buf.append(self.allocator, '=');
        var tmp: [32]u8 = undefined;
        const s = std.fmt.bufPrint(&tmp, "{d}", .{value}) catch unreachable;
        try self.buf.appendSlice(self.allocator, s);
        self.has_param = true;
    }

    /// Add a boolean flag: key=true
    pub fn addFlag(self: *QueryWriter, key: []const u8) !void {
        if (self.has_param) try self.buf.append(self.allocator, '&');
        try self.buf.appendSlice(self.allocator, key);
        try self.buf.appendSlice(self.allocator, "=true");
        self.has_param = true;
    }

    /// Add an optional string parameter (no-op if null)
    pub fn addOptionalString(self: *QueryWriter, key: []const u8, value: ?[]const u8) !void {
        if (value) |v| try self.addString(key, v);
    }

    /// Add an optional integer parameter (no-op if null)
    pub fn addOptionalInt(self: *QueryWriter, key: []const u8, value: anytype) !void {
        if (value) |v| try self.addInt(key, v);
    }

    /// Add a boolean flag only if true
    pub fn addBoolFlag(self: *QueryWriter, key: []const u8, value: bool) !void {
        if (value) try self.addFlag(key);
    }

    /// Transfer ownership of the built query string to the caller.
    pub fn toOwnedSlice(self: *QueryWriter) ![]const u8 {
        return try self.buf.toOwnedSlice(self.allocator);
    }
};
