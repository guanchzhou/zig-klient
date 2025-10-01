const std = @import("std");
const klient = @import("klient");

test "StorageClass - create structure" {
    const sc = klient.StorageClass{
        .apiVersion = "storage.k8s.io/v1",
        .kind = "StorageClass",
        .metadata = .{
            .name = "fast-ssd",
            .namespace = null,
        },
        .provisioner = "kubernetes.io/aws-ebs",
        .parameters = .null,
        .reclaimPolicy = "Delete",
        .volumeBindingMode = "WaitForFirstConsumer",
        .allowVolumeExpansion = true,
        .mountOptions = null,
        .allowedTopologies = null,
    };

    try std.testing.expectEqualStrings("storage.k8s.io/v1", sc.apiVersion.?);
    try std.testing.expectEqualStrings("StorageClass", sc.kind.?);
    try std.testing.expectEqualStrings("fast-ssd", sc.metadata.name);
    try std.testing.expectEqualStrings("kubernetes.io/aws-ebs", sc.provisioner);
    try std.testing.expect(sc.allowVolumeExpansion.? == true);
    std.debug.print("✅ StorageClass create structure test passed\n", .{});
}

test "StorageClass - deserialize from JSON" {
    const allocator = std.testing.allocator;
    const json_str =
        \\{
        \\  "apiVersion": "storage.k8s.io/v1",
        \\  "kind": "StorageClass",
        \\  "metadata": {
        \\    "name": "gp2"
        \\  },
        \\  "provisioner": "kubernetes.io/aws-ebs",
        \\  "parameters": {
        \\    "type": "gp2"
        \\  },
        \\  "reclaimPolicy": "Delete",
        \\  "allowVolumeExpansion": true
        \\}
    ;

    var parsed = try std.json.parseFromSlice(klient.StorageClass, allocator, json_str, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    const sc = parsed.value;

    try std.testing.expectEqualStrings("gp2", sc.metadata.name);
    try std.testing.expectEqualStrings("kubernetes.io/aws-ebs", sc.provisioner);
    try std.testing.expect(sc.allowVolumeExpansion.? == true);
    std.debug.print("✅ StorageClass deserialize test passed\n", .{});
}

test "VolumeAttachment - create structure" {
    const va = klient.VolumeAttachment{
        .apiVersion = "storage.k8s.io/v1",
        .kind = "VolumeAttachment",
        .metadata = .{
            .name = "test-volume-attachment",
            .namespace = null,
        },
        .spec = .{
            .attacher = "ebs.csi.aws.com",
            .source = .null,
            .nodeName = "node-1",
        },
    };

    try std.testing.expectEqualStrings("storage.k8s.io/v1", va.apiVersion.?);
    try std.testing.expectEqualStrings("VolumeAttachment", va.kind.?);
    try std.testing.expectEqualStrings("test-volume-attachment", va.metadata.name);
    try std.testing.expectEqualStrings("ebs.csi.aws.com", va.spec.?.attacher);
    try std.testing.expectEqualStrings("node-1", va.spec.?.nodeName);
    std.debug.print("✅ VolumeAttachment create structure test passed\n", .{});
}

test "CSIDriver - create structure" {
    const driver = klient.CSIDriver{
        .apiVersion = "storage.k8s.io/v1",
        .kind = "CSIDriver",
        .metadata = .{
            .name = "ebs.csi.aws.com",
            .namespace = null,
        },
        .spec = .{
            .attachRequired = true,
            .podInfoOnMount = false,
            .volumeLifecycleModes = null,
            .storageCapacity = true,
            .fsGroupPolicy = "File",
            .tokenRequests = null,
            .requiresRepublish = false,
            .seLinuxMount = null,
        },
    };

    try std.testing.expectEqualStrings("storage.k8s.io/v1", driver.apiVersion.?);
    try std.testing.expectEqualStrings("CSIDriver", driver.kind.?);
    try std.testing.expectEqualStrings("ebs.csi.aws.com", driver.metadata.name);
    try std.testing.expect(driver.spec.attachRequired.? == true);
    try std.testing.expect(driver.spec.storageCapacity.? == true);
    std.debug.print("✅ CSIDriver create structure test passed\n", .{});
}

test "CSINode - create structure" {
    const node = klient.CSINode{
        .apiVersion = "storage.k8s.io/v1",
        .kind = "CSINode",
        .metadata = .{
            .name = "node-1",
            .namespace = null,
        },
        .spec = .{
            .drivers = &[_]std.json.Value{},
        },
    };

    try std.testing.expectEqualStrings("storage.k8s.io/v1", node.apiVersion.?);
    try std.testing.expectEqualStrings("CSINode", node.kind.?);
    try std.testing.expectEqualStrings("node-1", node.metadata.name);
    std.debug.print("✅ CSINode create structure test passed\n", .{});
}

test "CSIStorageCapacity - create structure" {
    const capacity = klient.CSIStorageCapacity{
        .apiVersion = "storage.k8s.io/v1",
        .kind = "CSIStorageCapacity",
        .metadata = .{
            .name = "test-capacity",
            .namespace = "default",
        },
        .spec = .{
            .storageClassName = "fast-ssd",
            .capacity = "100Gi",
            .maximumVolumeSize = "50Gi",
            .nodeTopology = .null,
        },
    };

    try std.testing.expectEqualStrings("storage.k8s.io/v1", capacity.apiVersion.?);
    try std.testing.expectEqualStrings("CSIStorageCapacity", capacity.kind.?);
    try std.testing.expectEqualStrings("test-capacity", capacity.metadata.name);
    try std.testing.expectEqualStrings("fast-ssd", capacity.spec.?.storageClassName);
    std.debug.print("✅ CSIStorageCapacity create structure test passed\n", .{});
}
