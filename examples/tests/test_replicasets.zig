const std = @import("std");
const klient = @import("klient");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== Test: ReplicaSets Client ===\n\n", .{});

    var client = try klient.K8sClient.init(allocator, .{
        .server = "http://127.0.0.1:8080",
        .token = null,
        .namespace = "default",
    });
    defer client.deinit();

    var replicasets_client = klient.ReplicaSets.init(&client);

    const all_rs = try replicasets_client.client.listAll();
    defer all_rs.deinit();
    std.debug.print("✓ ReplicaSets.listAll() - Found {d} replicasets\n", .{all_rs.value.items.len});

    std.debug.print("\n✓ All ReplicaSets tests passed!\n\n", .{});
}
