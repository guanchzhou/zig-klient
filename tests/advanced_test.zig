const std = @import("std");
const klient = @import("klient");

test "APIService - create structure" {
    const api = klient.APIService{
        .apiVersion = "apiregistration.k8s.io/v1",
        .kind = "APIService",
        .metadata = .{
            .name = "v1.custom.example.com",
            .namespace = null,
        },
        .spec = .{
            .service = .null,
            .group = "custom.example.com",
            .version = "v1",
            .insecureSkipTLSVerify = false,
            .caBundle = null,
            .groupPriorityMinimum = 100,
            .versionPriority = 100,
        },
    };

    try std.testing.expectEqualStrings("apiregistration.k8s.io/v1", api.apiVersion.?);
    try std.testing.expectEqualStrings("APIService", api.kind.?);
    try std.testing.expectEqualStrings("v1.custom.example.com", api.metadata.name);
    try std.testing.expectEqualStrings("custom.example.com", api.spec.group);
    try std.testing.expect(api.spec.groupPriorityMinimum == 100);
    std.debug.print("✅ APIService create structure test passed\n", .{});
}

test "FlowSchema - create structure" {
    const fs = klient.FlowSchema{
        .apiVersion = "flowcontrol.apiserver.k8s.io/v1",
        .kind = "FlowSchema",
        .metadata = .{
            .name = "test-flow",
            .namespace = "default",
        },
        .spec = .{
            .priorityLevelConfiguration = .null,
            .matchingPrecedence = 1000,
            .distinguisherMethod = .null,
            .rules = null,
        },
    };

    try std.testing.expectEqualStrings("flowcontrol.apiserver.k8s.io/v1", fs.apiVersion.?);
    try std.testing.expectEqualStrings("FlowSchema", fs.kind.?);
    try std.testing.expectEqualStrings("test-flow", fs.metadata.name);
    try std.testing.expect(fs.spec.?.matchingPrecedence.? == 1000);
    std.debug.print("✅ FlowSchema create structure test passed\n", .{});
}

test "PriorityLevelConfiguration - create structure" {
    const plc = klient.PriorityLevelConfiguration{
        .apiVersion = "flowcontrol.apiserver.k8s.io/v1",
        .kind = "PriorityLevelConfiguration",
        .metadata = .{
            .name = "test-priority",
            .namespace = "default",
        },
        .spec = .{
            .type = "Limited",
            .limited = .null,
            .exempt = .null,
        },
    };

    try std.testing.expectEqualStrings("flowcontrol.apiserver.k8s.io/v1", plc.apiVersion.?);
    try std.testing.expectEqualStrings("PriorityLevelConfiguration", plc.kind.?);
    try std.testing.expectEqualStrings("test-priority", plc.metadata.name);
    try std.testing.expectEqualStrings("Limited", plc.spec.?.type);
    std.debug.print("✅ PriorityLevelConfiguration create structure test passed\n", .{});
}

test "RuntimeClass - create structure" {
    const rc = klient.RuntimeClass{
        .apiVersion = "node.k8s.io/v1",
        .kind = "RuntimeClass",
        .metadata = .{
            .name = "kata",
            .namespace = null,
        },
        .handler = "kata",
        .overhead = .null,
        .scheduling = .null,
    };

    try std.testing.expectEqualStrings("node.k8s.io/v1", rc.apiVersion.?);
    try std.testing.expectEqualStrings("RuntimeClass", rc.kind.?);
    try std.testing.expectEqualStrings("kata", rc.metadata.name);
    try std.testing.expectEqualStrings("kata", rc.handler);
    std.debug.print("✅ RuntimeClass create structure test passed\n", .{});
}

test "RuntimeClass - deserialize from JSON" {
    const allocator = std.testing.allocator;
    const json_str =
        \\{
        \\  "apiVersion": "node.k8s.io/v1",
        \\  "kind": "RuntimeClass",
        \\  "metadata": {
        \\    "name": "gvisor"
        \\  },
        \\  "handler": "runsc"
        \\}
    ;

    var parsed = try std.json.parseFromSlice(klient.RuntimeClass, allocator, json_str, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    const rc = parsed.value;

    try std.testing.expectEqualStrings("gvisor", rc.metadata.name);
    try std.testing.expectEqualStrings("runsc", rc.handler);
    std.debug.print("✅ RuntimeClass deserialize test passed\n", .{});
}

test "PriorityClass - create structure" {
    const pc = klient.PriorityClass{
        .apiVersion = "scheduling.k8s.io/v1",
        .kind = "PriorityClass",
        .metadata = .{
            .name = "high-priority",
            .namespace = null,
        },
        .value = 1000,
        .globalDefault = false,
        .description = "High priority class",
        .preemptionPolicy = "PreemptLowerPriority",
    };

    try std.testing.expectEqualStrings("scheduling.k8s.io/v1", pc.apiVersion.?);
    try std.testing.expectEqualStrings("PriorityClass", pc.kind.?);
    try std.testing.expectEqualStrings("high-priority", pc.metadata.name);
    try std.testing.expect(pc.value == 1000);
    try std.testing.expect(pc.globalDefault.? == false);
    std.debug.print("✅ PriorityClass create structure test passed\n", .{});
}

test "Lease - create structure" {
    const lease = klient.Lease{
        .apiVersion = "coordination.k8s.io/v1",
        .kind = "Lease",
        .metadata = .{
            .name = "test-lease",
            .namespace = "kube-system",
        },
        .spec = .{
            .holderIdentity = "node-1",
            .leaseDurationSeconds = 15,
            .acquireTime = null,
            .renewTime = null,
            .leaseTransitions = 0,
        },
    };

    try std.testing.expectEqualStrings("coordination.k8s.io/v1", lease.apiVersion.?);
    try std.testing.expectEqualStrings("Lease", lease.kind.?);
    try std.testing.expectEqualStrings("test-lease", lease.metadata.name);
    try std.testing.expectEqualStrings("node-1", lease.spec.?.holderIdentity.?);
    std.debug.print("✅ Lease create structure test passed\n", .{});
}

test "ComponentStatus - create structure" {
    const cs = klient.ComponentStatus{
        .apiVersion = "v1",
        .kind = "ComponentStatus",
        .metadata = .{
            .name = "etcd-0",
            .namespace = null,
        },
        .conditions = null,
    };

    try std.testing.expectEqualStrings("v1", cs.apiVersion.?);
    try std.testing.expectEqualStrings("ComponentStatus", cs.kind.?);
    try std.testing.expectEqualStrings("etcd-0", cs.metadata.name);
    std.debug.print("✅ ComponentStatus create structure test passed\n", .{});
}

test "Binding - create structure" {
    const binding = klient.Binding{
        .apiVersion = "v1",
        .kind = "Binding",
        .metadata = .{
            .name = "test-binding",
            .namespace = "default",
        },
        .spec = .{
            .target = .null,
        },
    };

    try std.testing.expectEqualStrings("v1", binding.apiVersion.?);
    try std.testing.expectEqualStrings("Binding", binding.kind.?);
    try std.testing.expectEqualStrings("test-binding", binding.metadata.name);
    std.debug.print("✅ Binding create structure test passed\n", .{});
}

