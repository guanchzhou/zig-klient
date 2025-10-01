const std = @import("std");
const klient = @import("klient");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  FULL INTEGRATION TEST (zig-klient)\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n\n", .{});

    var client = klient.K8sClient.initFromKubeconfig(allocator) catch |err| {
        std.debug.print("❌ Failed to initialize client: {}\n", .{err});
        return err;
    };
    defer client.deinit();

    std.debug.print("✅ Client initialized: {s}\n\n", .{client.api_server});

    const test_namespace = "zig-klient-integration";
    const pod_name = "integration-test-pod";

    var test_passed: usize = 0;
    var test_failed: usize = 0;

    // Test 1: Create Namespace
    std.debug.print("🧪 Test 1/7: Create Namespace\n", .{});
    {
        const namespaces_client = klient.Namespaces.init(&client);
        const ns_manifest =
            \\{
            \\  "apiVersion": "v1",
            \\  "kind": "Namespace",
            \\  "metadata": {
            \\    "name": "zig-klient-integration"
            \\  }
            \\}
        ;
        const ns = namespaces_client.client.createFromJson(ns_manifest, null) catch |err| {
            if (err == error.AlreadyExists) {
                std.debug.print("  ⚠️  Namespace exists (continuing)\n", .{});
                test_passed += 1;
            } else {
                std.debug.print("  ❌ FAILED: {}\n", .{err});
                test_failed += 1;
            }
            null;
        };
        if (ns) |n| {
            defer allocator.free(n);
            std.debug.print("  ✅ PASSED\n", .{});
            test_passed += 1;
        }
    }
    std.debug.print("\n", .{});

    // Test 2: Create Pod
    std.debug.print("🧪 Test 2/7: Create Pod\n", .{});
    {
        const pods_client = klient.Pods.init(&client);
        const pod_manifest =
            \\{
            \\  "apiVersion": "v1",
            \\  "kind": "Pod",
            \\  "metadata": {
            \\    "name": "integration-test-pod",
            \\    "namespace": "zig-klient-integration",
            \\    "labels": { "test": "integration", "version": "v1" }
            \\  },
            \\  "spec": {
            \\    "containers": [{
            \\      "name": "nginx",
            \\      "image": "nginx:alpine",
            \\      "ports": [{"containerPort": 80}]
            \\    }]
            \\  }
            \\}
        ;
        const pod = pods_client.client.createFromJson(pod_manifest, test_namespace) catch |err| {
            std.debug.print("  ❌ FAILED: {}\n", .{err});
            test_failed += 1;
            null;
        };
        if (pod) |p| {
            defer allocator.free(p);
            std.debug.print("  ✅ PASSED - Pod: {s}\n", .{p.metadata.name});
            test_passed += 1;
        }
    }
    std.debug.print("\n", .{});

    // Test 3: Get Pod
    std.debug.print("🧪 Test 3/7: Get Pod\n", .{});
    {
        const pods_client = klient.Pods.init(&client);
        const pod = pods_client.client.get(pod_name, test_namespace) catch |err| {
            std.debug.print("  ❌ FAILED: {}\n", .{err});
            test_failed += 1;
            null;
        };
        if (pod) |p| {
            defer allocator.free(p);
            std.debug.print("  ✅ PASSED - Found: {s}\n", .{p.metadata.name});
            if (p.status) |status| {
                if (status.phase) |phase| {
                    std.debug.print("     Phase: {s}\n", .{phase});
                }
            }
            test_passed += 1;
        }
    }
    std.debug.print("\n", .{});

    // Test 4: List Pods
    std.debug.print("🧪 Test 4/7: List Pods\n", .{});
    {
        const pods_client = klient.Pods.init(&client);
        const label_selector = try klient.LabelSelector.init(allocator);
        defer label_selector.deinit();
        try label_selector.addEquals("test", "integration");

        const list_options = klient.ListOptions{
            .label_selector = try label_selector.toString(),
        };
        defer if (list_options.label_selector) |ls| allocator.free(ls);

        const pods = pods_client.client.list(test_namespace, list_options) catch |err| {
            std.debug.print("  ❌ FAILED: {}\n", .{err});
            test_failed += 1;
            null;
        };
        if (pods) |p| {
            defer allocator.free(p);
            std.debug.print("  ✅ PASSED - Found {d} pod(s)\n", .{p.len});
            test_passed += 1;
        }
    }
    std.debug.print("\n", .{});

    // Test 5: Update Pod (patch label)
    std.debug.print("🧪 Test 5/7: Patch Pod\n", .{});
    {
        const pods_client = klient.Pods.init(&client);
        const patch_json =
            \\{
            \\  "metadata": {
            \\    "labels": {
            \\      "test": "integration",
            \\      "version": "v2",
            \\      "patched": "true"
            \\    }
            \\  }
            \\}
        ;
        const patch_options = klient.PatchOptions{
            .patch_type = .strategic_merge,
        };
        const patched = pods_client.client.patch(pod_name, test_namespace, patch_json, patch_options) catch |err| {
            std.debug.print("  ❌ FAILED: {}\n", .{err});
            test_failed += 1;
            null;
        };
        if (patched) |p| {
            defer allocator.free(p);
            std.debug.print("  ✅ PASSED - Patched successfully\n", .{});
            test_passed += 1;
        }
    }
    std.debug.print("\n", .{});

    // Test 6: Delete Pod with options
    std.debug.print("🧪 Test 6/7: Delete Pod\n", .{});
    {
        const pods_client = klient.Pods.init(&client);
        const delete_options = klient.DeleteOptions{
            .grace_period_seconds = 0,
            .propagation_policy = klient.PropagationPolicy.foreground.toString(),
        };
        pods_client.client.deleteWithOptions(pod_name, test_namespace, delete_options) catch |err| {
            std.debug.print("  ❌ FAILED: {}\n", .{err});
            test_failed += 1;
        };
        std.debug.print("  ✅ PASSED - Delete initiated\n", .{});
        test_passed += 1;
    }
    std.debug.print("\n", .{});

    // Test 7: Clean up namespace
    std.debug.print("🧪 Test 7/7: Delete Namespace\n", .{});
    {
        const namespaces_client = klient.Namespaces.init(&client);
        namespaces_client.client.delete(test_namespace, null) catch |err| {
            std.debug.print("  ❌ FAILED: {}\n", .{err});
            test_failed += 1;
        };
        std.debug.print("  ✅ PASSED - Namespace cleanup initiated\n", .{});
        test_passed += 1;
    }
    std.debug.print("\n", .{});

    // Summary
    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  TEST SUMMARY\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  ✅ Passed: {d}/7\n", .{test_passed});
    std.debug.print("  ❌ Failed: {d}/7\n", .{test_failed});
    std.debug.print("  📊 Success Rate: {d}%\n", .{(test_passed * 100) / 7});
    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});

    if (test_failed > 0) {
        return error.TestsFailed;
    }
}
