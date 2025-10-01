const std = @import("std");
const klient = @import("klient");

test "ResourceClaim - create structure" {
    const claim = klient.ResourceClaim{
        .apiVersion = "resource.k8s.io/v1",
        .kind = "ResourceClaim",
        .metadata = .{
            .name = "test-resource-claim",
            .namespace = "default",
        },
        .spec = .{
            .devices = null,
        },
    };

    try std.testing.expectEqualStrings("resource.k8s.io/v1", claim.apiVersion.?);
    try std.testing.expectEqualStrings("ResourceClaim", claim.kind.?);
    try std.testing.expectEqualStrings("test-resource-claim", claim.metadata.name);

    std.debug.print("✅ ResourceClaim create structure test passed\n", .{});
}

test "ResourceClaim - JSON deserialization" {
    const json_data =
        \\{
        \\  "apiVersion": "resource.k8s.io/v1",
        \\  "kind": "ResourceClaim",
        \\  "metadata": {
        \\    "name": "gpu-claim",
        \\    "namespace": "ml-workloads"
        \\  },
        \\  "spec": {}
        \\}
    ;

    const parsed = try std.json.parseFromSlice(
        klient.ResourceClaim,
        std.testing.allocator,
        json_data,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();

    try std.testing.expectEqualStrings("resource.k8s.io/v1", parsed.value.apiVersion.?);
    try std.testing.expectEqualStrings("ResourceClaim", parsed.value.kind.?);
    try std.testing.expectEqualStrings("gpu-claim", parsed.value.metadata.name);
    try std.testing.expectEqualStrings("ml-workloads", parsed.value.metadata.namespace.?);

    std.debug.print("✅ ResourceClaim JSON deserialization test passed\n", .{});
}

test "ResourceClaimTemplate - create structure" {
    const template = klient.ResourceClaimTemplate{
        .apiVersion = "resource.k8s.io/v1",
        .kind = "ResourceClaimTemplate",
        .metadata = .{
            .name = "test-claim-template",
            .namespace = "default",
        },
        .spec = .{
            .spec = .null,
        },
    };

    try std.testing.expectEqualStrings("resource.k8s.io/v1", template.apiVersion.?);
    try std.testing.expectEqualStrings("ResourceClaimTemplate", template.kind.?);
    try std.testing.expectEqualStrings("test-claim-template", template.metadata.name);

    std.debug.print("✅ ResourceClaimTemplate create structure test passed\n", .{});
}

test "ResourceClaimTemplate - JSON deserialization" {
    const json_data =
        \\{
        \\  "apiVersion": "resource.k8s.io/v1",
        \\  "kind": "ResourceClaimTemplate",
        \\  "metadata": {
        \\    "name": "gpu-template",
        \\    "namespace": "default"
        \\  },
        \\  "spec": {
        \\    "spec": {}
        \\  }
        \\}
    ;

    const parsed = try std.json.parseFromSlice(
        klient.ResourceClaimTemplate,
        std.testing.allocator,
        json_data,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();

    try std.testing.expectEqualStrings("resource.k8s.io/v1", parsed.value.apiVersion.?);
    try std.testing.expectEqualStrings("ResourceClaimTemplate", parsed.value.kind.?);
    try std.testing.expectEqualStrings("gpu-template", parsed.value.metadata.name);

    std.debug.print("✅ ResourceClaimTemplate JSON deserialization test passed\n", .{});
}

test "ResourceSlice - create structure" {
    const slice = klient.ResourceSlice{
        .apiVersion = "resource.k8s.io/v1",
        .kind = "ResourceSlice",
        .metadata = .{
            .name = "test-resource-slice",
        },
        .spec = .{
            .driver = "gpu.resource.k8s.io",
            .nodeName = "node-1",
            .pool = null,
            .devices = null,
        },
    };

    try std.testing.expectEqualStrings("resource.k8s.io/v1", slice.apiVersion.?);
    try std.testing.expectEqualStrings("ResourceSlice", slice.kind.?);
    try std.testing.expectEqualStrings("test-resource-slice", slice.metadata.name);
    try std.testing.expectEqualStrings("gpu.resource.k8s.io", slice.spec.?.driver);
    try std.testing.expectEqualStrings("node-1", slice.spec.?.nodeName.?);

    std.debug.print("✅ ResourceSlice create structure test passed\n", .{});
}

test "ResourceSlice - JSON deserialization" {
    const json_data =
        \\{
        \\  "apiVersion": "resource.k8s.io/v1",
        \\  "kind": "ResourceSlice",
        \\  "metadata": {
        \\    "name": "node-1-gpu-slice"
        \\  },
        \\  "spec": {
        \\    "driver": "gpu.example.com",
        \\    "nodeName": "node-1"
        \\  }
        \\}
    ;

    const parsed = try std.json.parseFromSlice(
        klient.ResourceSlice,
        std.testing.allocator,
        json_data,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();

    try std.testing.expectEqualStrings("resource.k8s.io/v1", parsed.value.apiVersion.?);
    try std.testing.expectEqualStrings("ResourceSlice", parsed.value.kind.?);
    try std.testing.expectEqualStrings("node-1-gpu-slice", parsed.value.metadata.name);
    try std.testing.expectEqualStrings("gpu.example.com", parsed.value.spec.?.driver);

    std.debug.print("✅ ResourceSlice JSON deserialization test passed\n", .{});
}

test "DeviceClass - create structure" {
    const dc = klient.DeviceClass{
        .apiVersion = "resource.k8s.io/v1",
        .kind = "DeviceClass",
        .metadata = .{
            .name = "test-device-class",
        },
        .spec = .{
            .selectors = null,
            .config = null,
            .suitableNodes = null,
        },
    };

    try std.testing.expectEqualStrings("resource.k8s.io/v1", dc.apiVersion.?);
    try std.testing.expectEqualStrings("DeviceClass", dc.kind.?);
    try std.testing.expectEqualStrings("test-device-class", dc.metadata.name);

    std.debug.print("✅ DeviceClass create structure test passed\n", .{});
}

test "DeviceClass - JSON deserialization" {
    const json_data =
        \\{
        \\  "apiVersion": "resource.k8s.io/v1",
        \\  "kind": "DeviceClass",
        \\  "metadata": {
        \\    "name": "nvidia-gpu"
        \\  },
        \\  "spec": {}
        \\}
    ;

    const parsed = try std.json.parseFromSlice(
        klient.DeviceClass,
        std.testing.allocator,
        json_data,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();

    try std.testing.expectEqualStrings("resource.k8s.io/v1", parsed.value.apiVersion.?);
    try std.testing.expectEqualStrings("DeviceClass", parsed.value.kind.?);
    try std.testing.expectEqualStrings("nvidia-gpu", parsed.value.metadata.name);

    std.debug.print("✅ DeviceClass JSON deserialization test passed\n", .{});
}
