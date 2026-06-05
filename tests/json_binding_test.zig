// Regression tests for JSON field binding of reserved-ish names. Zig's std.json
// matches field names with a plain compare (no trailing-underscore stripping), so
// fields that mirror wire names like "type"/"continue" must be declared as such.
const std = @import("std");
const klient = @import("klient");

test "ServiceSpec.type binds the wire \"type\" field" {
    const allocator = std.testing.allocator;
    const json =
        \\{"apiVersion":"v1","kind":"Service","metadata":{"name":"svc"},
        \\ "spec":{"type":"ClusterIP","clusterIP":"10.0.0.1"}}
    ;
    var parsed = try std.json.parseFromSlice(klient.Service, allocator, json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    try std.testing.expectEqualStrings("ClusterIP", parsed.value.spec.?.type.?);
}

test "List(T).metadata.continue binds the wire \"continue\" token (pagination)" {
    const allocator = std.testing.allocator;
    const json =
        \\{"apiVersion":"v1","kind":"PodList",
        \\ "metadata":{"resourceVersion":"123","continue":"next-page-token"},
        \\ "items":[]}
    ;
    var parsed = try std.json.parseFromSlice(klient.types.List(klient.Pod), allocator, json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    try std.testing.expectEqualStrings("next-page-token", parsed.value.metadata.@"continue".?);
}

test "WatchEvent.type binds the wire \"type\" field" {
    const allocator = std.testing.allocator;
    const json =
        \\{"type":"ADDED","object":{"kind":"Pod"}}
    ;
    var parsed = try std.json.parseFromSlice(klient.types.WatchEvent, allocator, json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    try std.testing.expectEqualStrings("ADDED", parsed.value.type);
}

test "StrategicMergePatch.build emits a JSON object" {
    const allocator = std.testing.allocator;
    var patch = klient.apply.StrategicMergePatch.init(allocator);
    defer patch.deinit();
    try patch.addPatch("replicas", .{ .integer = 3 });
    const out = try patch.build();
    defer allocator.free(out);
    try std.testing.expect(std.mem.containsAtLeast(u8, out, 1, "\"replicas\":3"));
}

test "JsonPatch.build emits an array of operations" {
    const allocator = std.testing.allocator;
    var patch = klient.apply.JsonPatch.init(allocator);
    defer patch.deinit();
    try patch.replace("/spec/replicas", .{ .integer = 5 });
    const out = try patch.build();
    defer allocator.free(out);
    try std.testing.expect(out[0] == '[');
    try std.testing.expect(std.mem.containsAtLeast(u8, out, 1, "\"op\":\"replace\""));
    try std.testing.expect(std.mem.containsAtLeast(u8, out, 1, "\"path\":\"/spec/replicas\""));
}

test "ServiceSpec.type also serializes back as \"type\"" {
    const allocator = std.testing.allocator;
    const svc = klient.Service{
        .apiVersion = "v1",
        .kind = "Service",
        .metadata = .{ .name = "svc" },
        .spec = .{ .type = "NodePort" },
    };
    const out = try std.json.Stringify.valueAlloc(allocator, svc, .{});
    defer allocator.free(out);
    try std.testing.expect(std.mem.containsAtLeast(u8, out, 1, "\"type\":\"NodePort\""));
    try std.testing.expect(!std.mem.containsAtLeast(u8, out, 1, "type_"));
}
