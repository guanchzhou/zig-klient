const std = @import("std");
const klient = @import("klient");

test "Role - create structure" {
    // Create a Role (simplified - no rules for structure test)
    const role = klient.Role{
        .apiVersion = "rbac.authorization.k8s.io/v1",
        .kind = "Role",
        .metadata = .{
            .name = "pod-reader",
            .namespace = "default",
        },
        .rules = null,
    };

    // Verify structure fields
    try std.testing.expectEqualStrings("rbac.authorization.k8s.io/v1", role.apiVersion.?);
    try std.testing.expectEqualStrings("Role", role.kind.?);
    try std.testing.expectEqualStrings("pod-reader", role.metadata.name);
    try std.testing.expectEqualStrings("default", role.metadata.namespace.?);

    std.debug.print("✅ Role create structure test passed\n", .{});
}

test "Role - deserialize from JSON" {
    const allocator = std.testing.allocator;

    const json_str =
        \\{
        \\  "apiVersion": "rbac.authorization.k8s.io/v1",
        \\  "kind": "Role",
        \\  "metadata": {
        \\    "name": "pod-reader",
        \\    "namespace": "default"
        \\  },
        \\  "rules": [
        \\    {
        \\      "apiGroups": [""],
        \\      "resources": ["pods"],
        \\      "verbs": ["get", "list", "watch"]
        \\    }
        \\  ]
        \\}
    ;

    const parsed = try std.json.parseFromSlice(
        klient.Role,
        allocator,
        json_str,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();

    const role = parsed.value;
    try std.testing.expectEqualStrings("rbac.authorization.k8s.io/v1", role.apiVersion.?);
    try std.testing.expectEqualStrings("Role", role.kind.?);
    try std.testing.expectEqualStrings("pod-reader", role.metadata.name);
    try std.testing.expect(role.rules != null);

    std.debug.print("✅ Role deserialize test passed\n", .{});
}

test "RoleBinding - create structure" {
    // Create a RoleBinding (simplified - no subjects for structure test)
    const role_binding = klient.RoleBinding{
        .apiVersion = "rbac.authorization.k8s.io/v1",
        .kind = "RoleBinding",
        .metadata = .{
            .name = "read-pods",
            .namespace = "default",
        },
        .subjects = null,
        .roleRef = .{
            .kind = "Role",
            .name = "pod-reader",
            .apiGroup = "rbac.authorization.k8s.io",
        },
    };

    // Verify structure fields
    try std.testing.expectEqualStrings("rbac.authorization.k8s.io/v1", role_binding.apiVersion.?);
    try std.testing.expectEqualStrings("RoleBinding", role_binding.kind.?);
    try std.testing.expectEqualStrings("read-pods", role_binding.metadata.name);
    try std.testing.expectEqualStrings("pod-reader", role_binding.roleRef.name);

    std.debug.print("✅ RoleBinding create structure test passed\n", .{});
}

test "RoleBinding - deserialize from JSON" {
    const allocator = std.testing.allocator;

    const json_str =
        \\{
        \\  "apiVersion": "rbac.authorization.k8s.io/v1",
        \\  "kind": "RoleBinding",
        \\  "metadata": {
        \\    "name": "read-pods",
        \\    "namespace": "default"
        \\  },
        \\  "subjects": [
        \\    {
        \\      "kind": "ServiceAccount",
        \\      "name": "default",
        \\      "namespace": "default"
        \\    }
        \\  ],
        \\  "roleRef": {
        \\    "kind": "Role",
        \\    "name": "pod-reader",
        \\    "apiGroup": "rbac.authorization.k8s.io"
        \\  }
        \\}
    ;

    const parsed = try std.json.parseFromSlice(
        klient.RoleBinding,
        allocator,
        json_str,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();

    const role_binding = parsed.value;
    try std.testing.expectEqualStrings("rbac.authorization.k8s.io/v1", role_binding.apiVersion.?);
    try std.testing.expectEqualStrings("read-pods", role_binding.metadata.name);
    try std.testing.expectEqualStrings("pod-reader", role_binding.roleRef.name);

    std.debug.print("✅ RoleBinding deserialize test passed\n", .{});
}

test "ClusterRole - create structure" {
    // Create a ClusterRole (simplified - no rules for structure test)
    const cluster_role = klient.ClusterRole{
        .apiVersion = "rbac.authorization.k8s.io/v1",
        .kind = "ClusterRole",
        .metadata = .{
            .name = "secret-reader",
        },
        .rules = null,
    };

    // Verify structure fields
    try std.testing.expectEqualStrings("rbac.authorization.k8s.io/v1", cluster_role.apiVersion.?);
    try std.testing.expectEqualStrings("ClusterRole", cluster_role.kind.?);
    try std.testing.expectEqualStrings("secret-reader", cluster_role.metadata.name);

    std.debug.print("✅ ClusterRole create structure test passed\n", .{});
}

test "ClusterRole - deserialize from JSON" {
    const allocator = std.testing.allocator;

    const json_str =
        \\{
        \\  "apiVersion": "rbac.authorization.k8s.io/v1",
        \\  "kind": "ClusterRole",
        \\  "metadata": {
        \\    "name": "cluster-admin"
        \\  },
        \\  "rules": [
        \\    {
        \\      "apiGroups": ["*"],
        \\      "resources": ["*"],
        \\      "verbs": ["*"]
        \\    }
        \\  ]
        \\}
    ;

    const parsed = try std.json.parseFromSlice(
        klient.ClusterRole,
        allocator,
        json_str,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();

    const cluster_role = parsed.value;
    try std.testing.expectEqualStrings("rbac.authorization.k8s.io/v1", cluster_role.apiVersion.?);
    try std.testing.expectEqualStrings("cluster-admin", cluster_role.metadata.name);
    try std.testing.expect(cluster_role.rules != null);

    std.debug.print("✅ ClusterRole deserialize test passed\n", .{});
}

test "ClusterRoleBinding - create structure" {
    // Create a ClusterRoleBinding (simplified - no subjects for structure test)
    const cluster_role_binding = klient.ClusterRoleBinding{
        .apiVersion = "rbac.authorization.k8s.io/v1",
        .kind = "ClusterRoleBinding",
        .metadata = .{
            .name = "read-secrets-global",
        },
        .subjects = null,
        .roleRef = .{
            .kind = "ClusterRole",
            .name = "secret-reader",
            .apiGroup = "rbac.authorization.k8s.io",
        },
    };

    // Verify structure fields
    try std.testing.expectEqualStrings("rbac.authorization.k8s.io/v1", cluster_role_binding.apiVersion.?);
    try std.testing.expectEqualStrings("ClusterRoleBinding", cluster_role_binding.kind.?);
    try std.testing.expectEqualStrings("read-secrets-global", cluster_role_binding.metadata.name);
    try std.testing.expectEqualStrings("secret-reader", cluster_role_binding.roleRef.name);

    std.debug.print("✅ ClusterRoleBinding create structure test passed\n", .{});
}

test "ClusterRoleBinding - deserialize from JSON" {
    const allocator = std.testing.allocator;

    const json_str =
        \\{
        \\  "apiVersion": "rbac.authorization.k8s.io/v1",
        \\  "kind": "ClusterRoleBinding",
        \\  "metadata": {
        \\    "name": "cluster-admin-binding"
        \\  },
        \\  "subjects": [
        \\    {
        \\      "kind": "ServiceAccount",
        \\      "name": "admin",
        \\      "namespace": "kube-system"
        \\    }
        \\  ],
        \\  "roleRef": {
        \\    "kind": "ClusterRole",
        \\    "name": "cluster-admin",
        \\    "apiGroup": "rbac.authorization.k8s.io"
        \\  }
        \\}
    ;

    const parsed = try std.json.parseFromSlice(
        klient.ClusterRoleBinding,
        allocator,
        json_str,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();

    const cluster_role_binding = parsed.value;
    try std.testing.expectEqualStrings("rbac.authorization.k8s.io/v1", cluster_role_binding.apiVersion.?);
    try std.testing.expectEqualStrings("cluster-admin-binding", cluster_role_binding.metadata.name);
    try std.testing.expectEqualStrings("cluster-admin", cluster_role_binding.roleRef.name);

    std.debug.print("✅ ClusterRoleBinding deserialize test passed\n", .{});
}

test "Role list - deserialize from JSON" {
    const allocator = std.testing.allocator;

    const json_str =
        \\{
        \\  "apiVersion": "rbac.authorization.k8s.io/v1",
        \\  "kind": "RoleList",
        \\  "items": [
        \\    {
        \\      "apiVersion": "rbac.authorization.k8s.io/v1",
        \\      "kind": "Role",
        \\      "metadata": {
        \\        "name": "pod-reader",
        \\        "namespace": "default"
        \\      },
        \\      "rules": [
        \\        {
        \\          "apiGroups": [""],
        \\          "resources": ["pods"],
        \\          "verbs": ["get", "list"]
        \\        }
        \\      ]
        \\    }
        \\  ],
        \\  "metadata": {
        \\    "resourceVersion": "12345"
        \\  }
        \\}
    ;

    const parsed = try std.json.parseFromSlice(
        klient.types.List(klient.Role),
        allocator,
        json_str,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();

    const list = parsed.value;
    try std.testing.expectEqual(@as(usize, 1), list.items.len);
    try std.testing.expectEqualStrings("pod-reader", list.items[0].metadata.name);

    std.debug.print("✅ Role list deserialize test passed\n", .{});
}
