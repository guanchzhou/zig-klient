const std = @import("std");
const klient = @import("klient");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== Test: ConfigMaps Client ===\n\n", .{});

    var client = try klient.K8sClient.init(allocator, .{
        .server = "http://127.0.0.1:8080",
        .token = null,
        .namespace = "default",
    });
    defer client.deinit();

    var configmaps_client = klient.ConfigMaps.init(&client);

    const all_cms = try configmaps_client.client.listAll();
    defer all_cms.deinit();
    std.debug.print("✓ ConfigMaps.listAll() - Found {d} configmaps\n", .{all_cms.value.items.len});

    const ns_cms = try configmaps_client.client.list("kube-system");
    defer ns_cms.deinit();
    std.debug.print("✓ ConfigMaps.list(namespace) - Found {d} configmaps in kube-system\n", .{ns_cms.value.items.len});

    std.debug.print("\n✓ All ConfigMaps tests passed!\n\n", .{});
}
