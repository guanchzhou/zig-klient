const std = @import("std");
const klient = @import("klient");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== Test: Nodes Client (Cluster-Scoped) ===\n\n", .{});

    var client = try klient.K8sClient.init(allocator, .{
        .server = "http://127.0.0.1:8080",
        .token = null,
        .namespace = "default",
    });
    defer client.deinit();

    var nodes_client = klient.Nodes.init(&client);

    const nodes = try nodes_client.list();
    defer nodes.deinit();
    std.debug.print("✓ Nodes.list() - Found {d} nodes\n", .{nodes.value.items.len});
    
    for (nodes.value.items) |node| {
        std.debug.print("  - {s}\n", .{node.metadata.name});
    }

    std.debug.print("\n✓ All Nodes tests passed!\n\n", .{});
}
