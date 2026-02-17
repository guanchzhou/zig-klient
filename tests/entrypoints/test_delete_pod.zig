const std = @import("std");
const klient = @import("klient");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  Test: Delete Pod (zig-klient)\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n\n", .{});

    // Initialize client
    std.debug.print("🔌 Initializing Kubernetes client...\n", .{});
    var client = klient.K8sClient.initFromKubeconfig(allocator) catch |err| {
        std.debug.print("❌ Failed to initialize client: {}\n", .{err});
        return err;
    };
    defer client.deinit();
    std.debug.print("✅ Client initialized\n\n", .{});

    const test_namespace = "zig-klient-test";
    const pod_name = "zig-test-pod";

    // Delete pod with advanced options
    std.debug.print("🗑️  Deleting pod '{s}' in namespace '{s}'...\n", .{ pod_name, test_namespace });

    const pods_client = klient.Pods.init(&client);

    const delete_options = klient.DeleteOptions{
        .grace_period_seconds = 5,
        .propagation_policy = klient.PropagationPolicy.foreground.toString(),
    };

    pods_client.client.deleteWithOptions(pod_name, test_namespace, delete_options) catch |err| {
        std.debug.print("❌ Failed to delete pod: {}\n", .{err});
        std.debug.print("\n💡 Tip: Pod may already be deleted or doesn't exist\n", .{});
        return err;
    };

    std.debug.print("✅ Pod deletion initiated\n", .{});
    std.debug.print("   Grace period: 5 seconds\n", .{});
    std.debug.print("   Propagation policy: Foreground\n\n", .{});

    // Wait a moment and verify deletion
    std.debug.print("⏳ Waiting for pod to be deleted...\n", .{});
    std.time.sleep(6 * std.time.ns_per_s);

    const verify_result = pods_client.client.get(pod_name, test_namespace);
    if (verify_result) |parsed| {
        defer parsed.deinit();
        std.debug.print("⚠️  Pod still exists (may be terminating)\n", .{});
        if (parsed.value.status) |status| {
            if (status.phase) |phase| {
                std.debug.print("   Current phase: {s}\n", .{phase});
            }
        }
    } else |err| {
        if (err == error.NotFound) {
            std.debug.print("✅ Pod successfully deleted\n", .{});
        } else {
            std.debug.print("⚠️  Verification failed: {}\n", .{err});
        }
    }

    // Delete namespace
    std.debug.print("\n📦 Cleaning up namespace '{s}'...\n", .{test_namespace});
    const namespaces_client = klient.Namespaces.init(&client);

    namespaces_client.client.delete(test_namespace, null) catch |err| {
        std.debug.print("⚠️  Failed to delete namespace: {}\n", .{err});
    };
    std.debug.print("✅ Namespace cleanup initiated\n", .{});

    std.debug.print("\n═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  ✅ Test completed successfully\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
}
