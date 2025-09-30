const std = @import("std");
const klient = @import("klient");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== Test: StatefulSets Client ===\n\n", .{});

    var client = try klient.K8sClient.init(allocator, .{
        .server = "http://127.0.0.1:8080",
        .token = null,
        .namespace = "default",
    });
    defer client.deinit();

    var statefulsets_client = klient.StatefulSets.init(&client);

    const all_sts = try statefulsets_client.client.listAll();
    defer all_sts.deinit();
    std.debug.print("✓ StatefulSets.listAll() - Found {d} statefulsets\n", .{all_sts.value.items.len});

    std.debug.print("\n✓ All StatefulSets tests passed!\n\n", .{});
}
