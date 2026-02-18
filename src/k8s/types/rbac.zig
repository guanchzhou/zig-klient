const std = @import("std");
const meta = @import("meta.zig");
const ObjectMeta = meta.ObjectMeta;

/// RBAC: PolicyRule for Role and ClusterRole
pub const PolicyRule = struct {
    apiGroups: ?[][]const u8 = null,
    resources: ?[][]const u8 = null,
    verbs: [][]const u8,
    resourceNames: ?[][]const u8 = null,
    nonResourceURLs: ?[][]const u8 = null,
};

/// RBAC: RoleRef for RoleBinding and ClusterRoleBinding
pub const RoleRef = struct {
    apiGroup: []const u8,
    kind: []const u8,
    name: []const u8,
};

/// RBAC: Subject for RoleBinding and ClusterRoleBinding
pub const Subject = struct {
    kind: []const u8,
    name: []const u8,
    namespace: ?[]const u8 = null,
    apiGroup: ?[]const u8 = null,
};

/// RBAC: Role (namespace-scoped)
pub const Role = struct {
    apiVersion: ?[]const u8 = null,
    kind: ?[]const u8 = null,
    metadata: ObjectMeta,
    rules: ?[]PolicyRule = null,
};

/// RBAC: RoleBinding (namespace-scoped)
pub const RoleBinding = struct {
    apiVersion: ?[]const u8 = null,
    kind: ?[]const u8 = null,
    metadata: ObjectMeta,
    subjects: ?[]Subject = null,
    roleRef: RoleRef,
};

/// RBAC: ClusterRole (cluster-scoped)
pub const ClusterRole = struct {
    apiVersion: ?[]const u8 = null,
    kind: ?[]const u8 = null,
    metadata: ObjectMeta,
    rules: ?[]PolicyRule = null,
    aggregationRule: ?std.json.Value = null,
};

/// RBAC: ClusterRoleBinding (cluster-scoped)
pub const ClusterRoleBinding = struct {
    apiVersion: ?[]const u8 = null,
    kind: ?[]const u8 = null,
    metadata: ObjectMeta,
    subjects: ?[]Subject = null,
    roleRef: RoleRef,
};
