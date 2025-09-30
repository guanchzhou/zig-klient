const std = @import("std");
const klient = @import("klient");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== zig-klient Proxy Test ===\n", .{});
    std.debug.print("NOTE: This test requires 'kubectl proxy' running on port 8080\n", .{});
    std.debug.print("Run: kubectl proxy --port=8080\n\n", .{});

    // Initialize client pointing to kubectl proxy
    std.debug.print("1. Initializing K8s client (via kubectl proxy)...\n", .{});
    var client = try klient.K8sClient.init(allocator, .{
        .server = "http://127.0.0.1:8080",
        .token = null, // No auth needed for kubectl proxy
        .namespace = "default",
    });
    defer client.deinit();
    std.debug.print("   ✓ Client initialized\n", .{});

    // Test 1: Get cluster info
    std.debug.print("\n2. Getting cluster info...\n", .{});
    const cluster_info = try client.getClusterInfo();
    std.debug.print("   ✓ Kubernetes version: {s}\n", .{cluster_info.k8s_version});

    // Test 2: List all pods
    std.debug.print("\n3. Listing all pods (cluster-wide)...\n", .{});
    var pods_client = klient.Pods.init(&client);
    const all_pods_parsed = try pods_client.client.listAll();
    defer all_pods_parsed.deinit();
    
    std.debug.print("   ✓ Found {d} pods\n", .{all_pods_parsed.value.items.len});
    
    // Show first 5 pods
    const show_count = @min(5, all_pods_parsed.value.items.len);
    for (all_pods_parsed.value.items[0..show_count]) |pod| {
        const ns = pod.metadata.namespace orelse "default";
        std.debug.print("     - {s}/{s}\n", .{
            ns,
            pod.metadata.name,
        });
    }

    // Test 3: List deployments
    std.debug.print("\n4. Listing deployments in kube-system...\n", .{});
    var deployments_client = klient.Deployments.init(&client);
    const deployments_parsed = try deployments_client.client.list("kube-system");
    defer deployments_parsed.deinit();
    
    std.debug.print("   ✓ Found {d} deployments\n", .{deployments_parsed.value.items.len});
    
    for (deployments_parsed.value.items) |deployment| {
        const replicas = if (deployment.spec) |spec| spec.replicas orelse 0 else 0;
        std.debug.print("     - {s} (replicas: {d})\n", .{
            deployment.metadata.name,
            replicas,
        });
    }

    // Test 4: List namespaces
    std.debug.print("\n5. Listing all namespaces...\n", .{});
    var namespaces_client = klient.Namespaces.init(&client);
    const namespaces_parsed = try namespaces_client.list();
    defer namespaces_parsed.deinit();
    
    std.debug.print("   ✓ Found {d} namespaces\n", .{namespaces_parsed.value.items.len});
    
    for (namespaces_parsed.value.items) |ns| {
        std.debug.print("     - {s}\n", .{ns.metadata.name});
    }

    // Test 5: List nodes
    std.debug.print("\n6. Listing cluster nodes...\n", .{});
    var nodes_client = klient.Nodes.init(&client);
    const nodes_parsed = try nodes_client.list();
    defer nodes_parsed.deinit();
    
    std.debug.print("   ✓ Found {d} nodes\n", .{nodes_parsed.value.items.len});
    
    for (nodes_parsed.value.items) |node| {
        std.debug.print("     - {s}\n", .{node.metadata.name});
    }

    // Summary
    std.debug.print("\n=== Test Summary ===\n", .{});
    std.debug.print("✓ All tests passed!\n", .{});
    std.debug.print("✓ zig-klient successfully connected to Rancher Desktop cluster\n", .{});
    std.debug.print("✓ Features verified:\n", .{});
    std.debug.print("  - HTTP client (via kubectl proxy)\n", .{});
    std.debug.print("  - Resource listing (Pods, Deployments, Namespaces, Nodes)\n", .{});
    std.debug.print("  - JSON parsing and deserialization\n", .{});
    std.debug.print("\n", .{});
}
