const std = @import("std");
const klient = @import("klient");

test "HorizontalPodAutoscaler - create structure" {
    const hpa = klient.HorizontalPodAutoscaler{
        .apiVersion = "autoscaling/v2",
        .kind = "HorizontalPodAutoscaler",
        .metadata = .{
            .name = "test-hpa",
            .namespace = "default",
        },
        .spec = .{
            .maxReplicas = 10,
            .minReplicas = 2,
            .scaleTargetRef = .null,
            .metrics = null,
            .behavior = null,
        },
    };

    try std.testing.expectEqualStrings("autoscaling/v2", hpa.apiVersion.?);
    try std.testing.expectEqualStrings("HorizontalPodAutoscaler", hpa.kind.?);
    try std.testing.expectEqualStrings("test-hpa", hpa.metadata.name);
    try std.testing.expect(hpa.spec.?.maxReplicas == 10);
    try std.testing.expect(hpa.spec.?.minReplicas.? == 2);
    std.debug.print("✅ HorizontalPodAutoscaler create structure test passed\n", .{});
}

test "HorizontalPodAutoscaler - deserialize from JSON" {
    const allocator = std.testing.allocator;
    const json_str =
        \\{
        \\  "apiVersion": "autoscaling/v2",
        \\  "kind": "HorizontalPodAutoscaler",
        \\  "metadata": {
        \\    "name": "my-hpa",
        \\    "namespace": "production"
        \\  },
        \\  "spec": {
        \\    "maxReplicas": 20,
        \\    "minReplicas": 3,
        \\    "scaleTargetRef": {
        \\      "apiVersion": "apps/v1",
        \\      "kind": "Deployment",
        \\      "name": "my-app"
        \\    }
        \\  }
        \\}
    ;

    var parsed = try std.json.parseFromSlice(klient.HorizontalPodAutoscaler, allocator, json_str, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    const hpa = parsed.value;

    try std.testing.expectEqualStrings("my-hpa", hpa.metadata.name);
    try std.testing.expectEqualStrings("production", hpa.metadata.namespace.?);
    try std.testing.expect(hpa.spec.?.maxReplicas == 20);
    try std.testing.expect(hpa.spec.?.minReplicas.? == 3);
    std.debug.print("✅ HorizontalPodAutoscaler deserialize test passed\n", .{});
}

test "PodDisruptionBudget - create structure" {
    const pdb = klient.PodDisruptionBudget{
        .apiVersion = "policy/v1",
        .kind = "PodDisruptionBudget",
        .metadata = .{
            .name = "test-pdb",
            .namespace = "default",
        },
        .spec = .{
            .minAvailable = .null,
            .maxUnavailable = .null,
            .selector = .null,
            .unhealthyPodEvictionPolicy = null,
        },
    };

    try std.testing.expectEqualStrings("policy/v1", pdb.apiVersion.?);
    try std.testing.expectEqualStrings("PodDisruptionBudget", pdb.kind.?);
    try std.testing.expectEqualStrings("test-pdb", pdb.metadata.name);
    std.debug.print("✅ PodDisruptionBudget create structure test passed\n", .{});
}

test "PodDisruptionBudget - deserialize from JSON" {
    const allocator = std.testing.allocator;
    const json_str =
        \\{
        \\  "apiVersion": "policy/v1",
        \\  "kind": "PodDisruptionBudget",
        \\  "metadata": {
        \\    "name": "my-pdb",
        \\    "namespace": "production"
        \\  },
        \\  "spec": {
        \\    "minAvailable": 2,
        \\    "selector": {
        \\      "matchLabels": {
        \\        "app": "my-app"
        \\      }
        \\    }
        \\  }
        \\}
    ;

    var parsed = try std.json.parseFromSlice(klient.PodDisruptionBudget, allocator, json_str, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    const pdb = parsed.value;

    try std.testing.expectEqualStrings("my-pdb", pdb.metadata.name);
    try std.testing.expectEqualStrings("production", pdb.metadata.namespace.?);
    std.debug.print("✅ PodDisruptionBudget deserialize test passed\n", .{});
}

test "ResourceQuota - create structure" {
    const quota = klient.ResourceQuota{
        .apiVersion = "v1",
        .kind = "ResourceQuota",
        .metadata = .{
            .name = "test-quota",
            .namespace = "default",
        },
        .spec = .{
            .hard = .null,
            .scopes = null,
            .scopeSelector = null,
        },
    };

    try std.testing.expectEqualStrings("v1", quota.apiVersion.?);
    try std.testing.expectEqualStrings("ResourceQuota", quota.kind.?);
    try std.testing.expectEqualStrings("test-quota", quota.metadata.name);
    std.debug.print("✅ ResourceQuota create structure test passed\n", .{});
}

test "LimitRange - create structure" {
    const lr = klient.LimitRange{
        .apiVersion = "v1",
        .kind = "LimitRange",
        .metadata = .{
            .name = "test-limits",
            .namespace = "default",
        },
        .spec = .{
            .limits = &[_]std.json.Value{},
        },
    };

    try std.testing.expectEqualStrings("v1", lr.apiVersion.?);
    try std.testing.expectEqualStrings("LimitRange", lr.kind.?);
    try std.testing.expectEqualStrings("test-limits", lr.metadata.name);
    std.debug.print("✅ LimitRange create structure test passed\n", .{});
}
