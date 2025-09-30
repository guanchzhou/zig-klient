const std = @import("std");
const klient = @import("klient");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== Test: Namespaces Client (Cluster-Scoped) ===\n\n", .{});

    var client = try klient.K8sClient.init(allocator, .{
        .server = "http://127.0.0.1:8080",
        .token = null,
        .namespace = "default",
    });
    defer client.deinit();

    var namespaces_client = klient.Namespaces.init(&client);

    const ns_list = try namespaces_client.list();
    defer ns_list.deinit();
    std.debug.print("✓ Namespaces.list() - Found {d} namespaces\n", .{ns_list.value.items.len});
    
    for (ns_list.value.items) |ns| {
        std.debug.print("  - {s}\n", .{ns.metadata.name});
    }

    std.debug.print("\n✓ All Namespaces tests passed!\n\n", .{});
}
