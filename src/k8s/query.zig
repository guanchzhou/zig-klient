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

    /// Add a string parameter: key=value
    pub fn addString(self: *QueryWriter, key: []const u8, value: []const u8) !void {
        const writer = self.buf.writer(self.allocator);
        if (self.has_param) try writer.writeByte('&');
        try writer.print("{s}={s}", .{ key, value });
        self.has_param = true;
    }

    /// Add an integer parameter: key=123
    pub fn addInt(self: *QueryWriter, key: []const u8, value: anytype) !void {
        const writer = self.buf.writer(self.allocator);
        if (self.has_param) try writer.writeByte('&');
        try writer.print("{s}={d}", .{ key, value });
        self.has_param = true;
    }

    /// Add a boolean flag: key=true
    pub fn addFlag(self: *QueryWriter, key: []const u8) !void {
        const writer = self.buf.writer(self.allocator);
        if (self.has_param) try writer.writeByte('&');
        try writer.print("{s}=true", .{key});
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
