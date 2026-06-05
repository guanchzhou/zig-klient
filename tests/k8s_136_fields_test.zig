// K8s 1.36 field-level additions to existing resource types.
// Resource-kind additions (MutatingAdmissionPolicy etc.) live in admission_test.zig.
const std = @import("std");
const klient = @import("klient");

test "PodSpec.hostUsers round-trips (user namespaces GA in 1.36)" {
    const allocator = std.testing.allocator;
    const json_str =
        \\{
        \\  "apiVersion": "v1",
        \\  "kind": "Pod",
        \\  "metadata": { "name": "userns-pod" },
        \\  "spec": { "hostUsers": false, "containers": [] }
        \\}
    ;

    var parsed = try std.json.parseFromSlice(klient.Pod, allocator, json_str, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    try std.testing.expect(parsed.value.spec.?.hostUsers.? == false);

    // Serialize back and confirm the field is emitted.
    const out = try std.json.Stringify.valueAlloc(allocator, parsed.value.spec.?, .{});
    defer allocator.free(out);
    try std.testing.expect(std.mem.containsAtLeast(u8, out, 1, "\"hostUsers\":false"));
}

test "Volume.image OCI source round-trips (stable in 1.36)" {
    const allocator = std.testing.allocator;
    const json_str =
        \\{
        \\  "apiVersion": "v1",
        \\  "kind": "Pod",
        \\  "metadata": { "name": "image-volume-pod" },
        \\  "spec": {
        \\    "volumes": [
        \\      { "name": "artifact", "image": { "reference": "registry.example.com/app:v1", "pullPolicy": "IfNotPresent" } }
        \\    ]
        \\  }
        \\}
    ;

    var parsed = try std.json.parseFromSlice(klient.Pod, allocator, json_str, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const vol = parsed.value.spec.?.volumes.?[0];
    try std.testing.expectEqualStrings("artifact", vol.name);
    try std.testing.expectEqualStrings("registry.example.com/app:v1", vol.image.?.reference.?);
    try std.testing.expectEqualStrings("IfNotPresent", vol.image.?.pullPolicy.?);
}

test "ImageVolumeSource constructs directly" {
    const vol = klient.types.Volume{
        .name = "artifact",
        .image = .{ .reference = "ghcr.io/acme/data:latest", .pullPolicy = "Always" },
    };
    try std.testing.expectEqualStrings("ghcr.io/acme/data:latest", vol.image.?.reference.?);
}

test "DRA ResourceClaim adminAccess passes through devices json.Value (GA in 1.36)" {
    const allocator = std.testing.allocator;
    // adminAccess and prioritized lists graduated to GA in 1.36. ResourceClaimSpec.devices
    // is modeled as std.json.Value, so these nested fields are preserved without a typed schema.
    const json_str =
        \\{
        \\  "apiVersion": "resource.k8s.io/v1",
        \\  "kind": "ResourceClaim",
        \\  "metadata": { "name": "gpu-admin" },
        \\  "spec": {
        \\    "devices": {
        \\      "requests": [
        \\        { "name": "gpu", "deviceClassName": "example.com-gpu", "adminAccess": true }
        \\      ]
        \\    }
        \\  }
        \\}
    ;

    var parsed = try std.json.parseFromSlice(klient.ResourceClaim, allocator, json_str, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const devices = parsed.value.spec.?.devices.?;
    const requests = devices.object.get("requests").?.array;
    try std.testing.expect(requests.items.len == 1);
    try std.testing.expect(requests.items[0].object.get("adminAccess").?.bool == true);
}
