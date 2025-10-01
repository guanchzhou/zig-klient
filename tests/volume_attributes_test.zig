const std = @import("std");
const klient = @import("klient");

test "VolumeAttributesClass - create structure" {
    const vac = klient.VolumeAttributesClass{
        .apiVersion = "storage.k8s.io/v1",
        .kind = "VolumeAttributesClass",
        .metadata = .{
            .name = "test-volume-attributes",
        },
        .driverName = "ebs.csi.aws.com",
        .parameters = null,
    };
    
    try std.testing.expectEqualStrings("storage.k8s.io/v1", vac.apiVersion.?);
    try std.testing.expectEqualStrings("VolumeAttributesClass", vac.kind.?);
    try std.testing.expectEqualStrings("test-volume-attributes", vac.metadata.name);
    try std.testing.expectEqualStrings("ebs.csi.aws.com", vac.driverName);
    
    std.debug.print("✅ VolumeAttributesClass create structure test passed\n", .{});
}

test "VolumeAttributesClass - JSON deserialization" {
    const json_data =
        \\{
        \\  "apiVersion": "storage.k8s.io/v1",
        \\  "kind": "VolumeAttributesClass",
        \\  "metadata": {
        \\    "name": "bronze"
        \\  },
        \\  "driverName": "pd.csi.storage.gke.io",
        \\  "parameters": {
        \\    "iops": "1000",
        \\    "throughput": "125"
        \\  }
        \\}
    ;
    
    const parsed = try std.json.parseFromSlice(
        klient.VolumeAttributesClass,
        std.testing.allocator,
        json_data,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();
    
    try std.testing.expectEqualStrings("storage.k8s.io/v1", parsed.value.apiVersion.?);
    try std.testing.expectEqualStrings("VolumeAttributesClass", parsed.value.kind.?);
    try std.testing.expectEqualStrings("bronze", parsed.value.metadata.name);
    try std.testing.expectEqualStrings("pd.csi.storage.gke.io", parsed.value.driverName);
    
    std.debug.print("✅ VolumeAttributesClass JSON deserialization test passed\n", .{});
}

test "VolumeAttributesClass - minimal structure" {
    const vac = klient.VolumeAttributesClass{
        .apiVersion = "storage.k8s.io/v1",
        .kind = "VolumeAttributesClass",
        .metadata = .{
            .name = "default-attributes",
        },
        .driverName = "default.csi.driver",
        .parameters = null,
    };
    
    try std.testing.expectEqualStrings("default-attributes", vac.metadata.name);
    try std.testing.expectEqualStrings("default.csi.driver", vac.driverName);
    try std.testing.expect(vac.parameters == null);
    
    std.debug.print("✅ VolumeAttributesClass minimal structure test passed\n", .{});
}

