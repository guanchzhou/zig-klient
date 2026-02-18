const std = @import("std");

/// Common metadata for all Kubernetes resources
pub const ObjectMeta = struct {
    name: []const u8,
    namespace: ?[]const u8 = null,
    labels: ?std.json.Value = null,
    annotations: ?std.json.Value = null,
    resourceVersion: ?[]const u8 = null,
    uid: ?[]const u8 = null,
    creationTimestamp: ?[]const u8 = null,
    deletionTimestamp: ?[]const u8 = null,
    generation: ?i64 = null,
};

/// Generic Kubernetes resource wrapper
pub fn Resource(comptime T: type) type {
    return struct {
        apiVersion: ?[]const u8 = null,
        kind: ?[]const u8 = null,
        metadata: ObjectMeta,
        spec: ?T = null,
        status: ?std.json.Value = null,
    };
}

/// List response wrapper for collections
pub fn List(comptime T: type) type {
    return struct {
        apiVersion: []const u8,
        kind: []const u8,
        items: []T,
        metadata: struct {
            resourceVersion: ?[]const u8 = null,
            continue_: ?[]const u8 = null,
        },
    };
}
