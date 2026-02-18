const std = @import("std");

/// API error from Kubernetes
pub const ApiError = struct {
    kind: []const u8 = "Status",
    apiVersion: []const u8 = "v1",
    metadata: std.json.Value = .null,
    status: []const u8,
    message: ?[]const u8 = null,
    reason: ?[]const u8 = null,
    code: ?i32 = null,
    details: ?std.json.Value = null,
};

/// Watch event types
pub const WatchEvent = struct {
    type_: []const u8, // ADDED, MODIFIED, DELETED, ERROR
    object: std.json.Value,
};
