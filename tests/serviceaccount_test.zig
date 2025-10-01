const std = @import("std");
const klient = @import("klient");

test "ServiceAccount - create structure" {
    // Create a ServiceAccount
    const sa = klient.ServiceAccount{
        .apiVersion = "v1",
        .kind = "ServiceAccount",
        .metadata = .{
            .name = "test-sa",
            .namespace = "default",
        },
        .automountServiceAccountToken = true,
    };

    // Verify structure fields
    try std.testing.expectEqualStrings("v1", sa.apiVersion.?);
    try std.testing.expectEqualStrings("ServiceAccount", sa.kind.?);
    try std.testing.expectEqualStrings("test-sa", sa.metadata.name);
    try std.testing.expectEqualStrings("default", sa.metadata.namespace.?);
    try std.testing.expect(sa.automountServiceAccountToken.? == true);

    std.debug.print("✅ ServiceAccount create structure test passed\n", .{});
}

test "ServiceAccount - deserialize from JSON" {
    const allocator = std.testing.allocator;

    const json_str =
        \\{
        \\  "apiVersion": "v1",
        \\  "kind": "ServiceAccount",
        \\  "metadata": {
        \\    "name": "default",
        \\    "namespace": "default",
        \\    "uid": "12345",
        \\    "resourceVersion": "1000"
        \\  },
        \\  "automountServiceAccountToken": true
        \\}
    ;

    const parsed = try std.json.parseFromSlice(
        klient.ServiceAccount,
        allocator,
        json_str,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();

    const sa = parsed.value;
    try std.testing.expectEqualStrings("v1", sa.apiVersion.?);
    try std.testing.expectEqualStrings("ServiceAccount", sa.kind.?);
    try std.testing.expectEqualStrings("default", sa.metadata.name);
    try std.testing.expectEqualStrings("default", sa.metadata.namespace.?);
    try std.testing.expect(sa.automountServiceAccountToken.? == true);

    std.debug.print("✅ ServiceAccount deserialize test passed\n", .{});
}

test "ServiceAccount - with image pull secrets" {
    const allocator = std.testing.allocator;

    const json_str =
        \\{
        \\  "apiVersion": "v1",
        \\  "kind": "ServiceAccount",
        \\  "metadata": {
        \\    "name": "my-sa",
        \\    "namespace": "production"
        \\  },
        \\  "imagePullSecrets": [
        \\    {"name": "docker-registry-secret"},
        \\    {"name": "gcr-secret"}
        \\  ],
        \\  "automountServiceAccountToken": false
        \\}
    ;

    const parsed = try std.json.parseFromSlice(
        klient.ServiceAccount,
        allocator,
        json_str,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();

    const sa = parsed.value;
    try std.testing.expectEqualStrings("my-sa", sa.metadata.name);
    try std.testing.expectEqualStrings("production", sa.metadata.namespace.?);
    try std.testing.expect(sa.imagePullSecrets != null);
    try std.testing.expect(sa.automountServiceAccountToken.? == false);

    std.debug.print("✅ ServiceAccount with image pull secrets test passed\n", .{});
}

test "ServiceAccount - list response" {
    const allocator = std.testing.allocator;

    const json_str =
        \\{
        \\  "apiVersion": "v1",
        \\  "kind": "ServiceAccountList",
        \\  "items": [
        \\    {
        \\      "apiVersion": "v1",
        \\      "kind": "ServiceAccount",
        \\      "metadata": {
        \\        "name": "default",
        \\        "namespace": "default"
        \\      }
        \\    },
        \\    {
        \\      "apiVersion": "v1",
        \\      "kind": "ServiceAccount",
        \\      "metadata": {
        \\        "name": "admin",
        \\        "namespace": "kube-system"
        \\      }
        \\    }
        \\  ],
        \\  "metadata": {
        \\    "resourceVersion": "12345"
        \\  }
        \\}
    ;

    const parsed = try std.json.parseFromSlice(
        klient.types.List(klient.ServiceAccount),
        allocator,
        json_str,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();

    const list = parsed.value;
    try std.testing.expectEqual(@as(usize, 2), list.items.len);
    try std.testing.expectEqualStrings("default", list.items[0].metadata.name);
    try std.testing.expectEqualStrings("admin", list.items[1].metadata.name);
    try std.testing.expectEqualStrings("kube-system", list.items[1].metadata.namespace.?);

    std.debug.print("✅ ServiceAccount list response test passed\n", .{});
}
