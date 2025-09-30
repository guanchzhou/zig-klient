const std = @import("std");
const klient = @import("klient");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n" ++ "=" ** 50 ++ "\n", .{});
    std.debug.print("✓ zig-klient Integration Test with Rancher Desktop\n", .{});
    std.debug.print("=" ** 50 ++ "\n\n", .{});

    // Initialize client
    var client = try klient.K8sClient.init(allocator, .{
        .server = "http://127.0.0.1:8080",
        .token = null,
        .namespace = "default",
    });
    defer client.deinit();

    // Test 1: Get cluster info
    std.debug.print("Test 1: Get Cluster Version\n", .{});
    const cluster_info = try client.getClusterInfo();
    std.debug.print("  → Kubernetes version: {s}\n\n", .{cluster_info.k8s_version});

    // Test 2: List all pods
    std.debug.print("Test 2: List All Pods\n", .{});
    var pods_client = klient.Pods.init(&client);
    const all_pods_parsed = try pods_client.client.listAll();
    defer all_pods_parsed.deinit();
    
    std.debug.print("  → Found {d} pods across all namespaces\n", .{all_pods_parsed.value.items.len});
    for (all_pods_parsed.value.items) |pod| {
        const ns = pod.metadata.namespace orelse "default";
        std.debug.print("    • {s}/{s}\n", .{ ns, pod.metadata.name });
    }

    // Test 3: List namespaces
    std.debug.print("\nTest 3: List Namespaces\n", .{});
    var namespaces_client = klient.Namespaces.init(&client);
    const namespaces_parsed = try namespaces_client.list();
    defer namespaces_parsed.deinit();
    
    std.debug.print("  → Found {d} namespaces\n", .{namespaces_parsed.value.items.len});
    for (namespaces_parsed.value.items) |ns| {
        std.debug.print("    • {s}\n", .{ns.metadata.name});
    }

    // Test 4: List nodes
    std.debug.print("\nTest 4: List Cluster Nodes\n", .{});
    var nodes_client = klient.Nodes.init(&client);
    const nodes_parsed = try nodes_client.list();
    defer nodes_parsed.deinit();
    
    std.debug.print("  → Found {d} nodes\n", .{nodes_parsed.value.items.len});
    for (nodes_parsed.value.items) |node| {
        std.debug.print("    • {s}\n", .{node.metadata.name});
    }

    std.debug.print("\n" ++ "=" ** 50 ++ "\n", .{});
    std.debug.print("✓ ALL TESTS PASSED!\n", .{});
    std.debug.print("✓ zig-klient successfully connected to your Rancher Desktop cluster\n", .{});
    std.debug.print("=" ** 50 ++ "\n\n", .{});
}
