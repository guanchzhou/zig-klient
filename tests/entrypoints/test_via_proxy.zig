const std = @import("std");
const klient = @import("klient");

/// Test zig-klient against a running kubectl proxy (http://localhost:8080)
/// Start proxy first: kubectl proxy --port=8080
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  Integration Test via kubectl proxy (zig-klient)\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n\n", .{});

    // Connect directly to kubectl proxy (no TLS needed)
    var client = try klient.K8sClient.init(allocator, .{
        .server = "http://127.0.0.1:8080",
        .namespace = "default",
    });
    defer client.deinit();
    std.debug.print("✅ Client initialized: {s}\n\n", .{client.api_server});

    var passed: usize = 0;
    var failed: usize = 0;

    // Test 1: List pods
    std.debug.print("🧪 Test 1: List Pods\n", .{});
    if (runListPods(&client)) {
        passed += 1;
    } else |err| {
        std.debug.print("  ❌ FAILED: {}\n", .{err});
        failed += 1;
    }

    // Test 2: List namespaces
    std.debug.print("🧪 Test 2: List Namespaces\n", .{});
    if (runListNamespaces(&client)) {
        passed += 1;
    } else |err| {
        std.debug.print("  ❌ FAILED: {}\n", .{err});
        failed += 1;
    }

    // Test 3: List nodes
    std.debug.print("🧪 Test 3: List Nodes\n", .{});
    if (runListNodes(&client)) {
        passed += 1;
    } else |err| {
        std.debug.print("  ❌ FAILED: {}\n", .{err});
        failed += 1;
    }

    // Test 4: CRUD - Create pod via raw request
    std.debug.print("🧪 Test 4: Create Pod\n", .{});
    if (runCreatePod(&client)) {
        passed += 1;
    } else |err| {
        std.debug.print("  ❌ FAILED: {}\n", .{err});
        if (client.last_api_error) |api_err| {
            if (api_err.message) |msg| std.debug.print("     K8s: {s}\n", .{msg});
        }
        failed += 1;
    }

    // Test 5: CRUD - Get pod
    std.debug.print("🧪 Test 5: Get Pod\n", .{});
    if (runGetPod(&client)) {
        passed += 1;
    } else |err| {
        std.debug.print("  ❌ FAILED: {}\n", .{err});
        failed += 1;
    }

    // Test 6: CRUD - Delete pod
    std.debug.print("🧪 Test 6: Delete Pod\n", .{});
    if (runDeletePod(&client)) {
        passed += 1;
    } else |err| {
        std.debug.print("  ❌ FAILED: {}\n", .{err});
        failed += 1;
    }

    // Summary
    const total = passed + failed;
    std.debug.print("\n═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  RESULTS: {} passed, {} failed out of {} tests\n", .{ passed, failed, total });
    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});

    if (failed > 0) return error.TestsFailed;
}

fn runListPods(client: *klient.K8sClient) !void {
    const pods_client = klient.Pods.init(client);
    const parsed = try pods_client.client.list("default");
    defer parsed.deinit();
    std.debug.print("  ✅ PASSED - Found {} pod(s)\n", .{parsed.value.items.len});
}

fn runListNamespaces(client: *klient.K8sClient) !void {
    const ns_client = klient.Namespaces.init(client);
    const parsed = try ns_client.client.listAll();
    defer parsed.deinit();
    std.debug.print("  ✅ PASSED - Found {} namespace(s)\n", .{parsed.value.items.len});
    for (parsed.value.items) |ns| {
        std.debug.print("     - {s}\n", .{ns.metadata.name});
    }
}

fn runListNodes(client: *klient.K8sClient) !void {
    const nodes_client = klient.Nodes.init(client);
    const parsed = try nodes_client.client.listAll();
    defer parsed.deinit();
    std.debug.print("  ✅ PASSED - Found {} node(s)\n", .{parsed.value.items.len});
    for (parsed.value.items) |node| {
        std.debug.print("     - {s}\n", .{node.metadata.name});
    }
}

fn runCreatePod(client: *klient.K8sClient) !void {
    const manifest =
        \\{"apiVersion":"v1","kind":"Pod","metadata":{"name":"zig-klient-test","labels":{"app":"zig-klient-test"}},"spec":{"containers":[{"name":"busybox","image":"busybox:latest","command":["sleep","30"]}]}}
    ;
    const result = try client.request(.POST, "/api/v1/namespaces/default/pods", manifest);
    defer client.allocator.free(result);
    std.debug.print("  ✅ PASSED - Pod created\n", .{});
}

fn runGetPod(client: *klient.K8sClient) !void {
    const pods_client = klient.Pods.init(client);
    const parsed = try pods_client.client.get("zig-klient-test", "default");
    defer parsed.deinit();
    std.debug.print("  ✅ PASSED - Got pod: {s}\n", .{parsed.value.metadata.name});
}

fn runDeletePod(client: *klient.K8sClient) !void {
    const pods_client = klient.Pods.init(client);
    try pods_client.client.delete("zig-klient-test", "default");
    std.debug.print("  ✅ PASSED - Deleted\n", .{});
}
