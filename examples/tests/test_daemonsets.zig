const std = @import("std");
const klient = @import("klient");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== Test: DaemonSets Client ===\n\n", .{});

    var client = try klient.K8sClient.init(allocator, .{
        .server = "http://127.0.0.1:8080",
        .token = null,
        .namespace = "default",
    });
    defer client.deinit();

    var daemonsets_client = klient.DaemonSets.init(&client);

    const all_ds = try daemonsets_client.client.listAll();
    defer all_ds.deinit();
    std.debug.print("✓ DaemonSets.listAll() - Found {d} daemonsets\n", .{all_ds.value.items.len});

    std.debug.print("\n✓ All DaemonSets tests passed!\n\n", .{});
}
