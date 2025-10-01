const std = @import("std");
const klient = @import("klient");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  Test: Update Pod (zig-klient)\n", .{});
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

    // Get current pod
    std.debug.print("🔍 Getting current pod...\n", .{});
    const pods_client = klient.Pods.init(&client);
    const current_pod = pods_client.client.get(pod_name, test_namespace) catch |err| {
        std.debug.print("❌ Failed to get pod: {}\n", .{err});
        std.debug.print("\n💡 Tip: Run test_create_pod.zig first to create the pod\n", .{});
        return err;
    };
    defer allocator.free(current_pod);

    std.debug.print("✅ Current pod retrieved\n", .{});
    std.debug.print("   Current labels:\n", .{});
    if (current_pod.metadata.labels) |labels| {
        var it = labels.iterator();
        while (it.next()) |entry| {
            std.debug.print("     {s}: {s}\n", .{ entry.key_ptr.*, entry.value_ptr.*.string });
        }
    }

    // Update pod with new label
    std.debug.print("\n🔄 Updating pod with new label...\n", .{});

    const updated_manifest =
        \\{
        \\  "apiVersion": "v1",
        \\  "kind": "Pod",
        \\  "metadata": {
        \\    "name": "zig-test-pod",
        \\    "namespace": "zig-klient-test",
        \\    "labels": {
        \\      "app": "zig-test",
        \\      "created-by": "zig-klient",
        \\      "updated": "true",
        \\      "update-time": "2025-10-01"
        \\    }
        \\  },
        \\  "spec": {
        \\    "containers": [
        \\      {
        \\        "name": "busybox",
        \\        "image": "busybox:latest",
        \\        "command": ["sh", "-c", "echo 'Hello from zig-klient!' && sleep 3600"],
        \\        "imagePullPolicy": "IfNotPresent"
        \\      }
        \\    ],
        \\    "restartPolicy": "Never"
        \\  }
        \\}
    ;

    const update_options = klient.UpdateOptions{
        .field_manager = "zig-klient-test",
    };

    const updated_pod = pods_client.client.updateWithOptions(
        pod_name,
        test_namespace,
        updated_manifest,
        update_options,
    ) catch |err| {
        std.debug.print("❌ Failed to update pod: {}\n", .{err});
        return err;
    };
    defer allocator.free(updated_pod);

    std.debug.print("✅ Pod updated successfully!\n", .{});
    std.debug.print("   Updated labels:\n", .{});
    if (updated_pod.metadata.labels) |labels| {
        var it = labels.iterator();
        while (it.next()) |entry| {
            std.debug.print("     {s}: {s}\n", .{ entry.key_ptr.*, entry.value_ptr.*.string });
        }
    }

    std.debug.print("\n═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  ✅ Test completed successfully\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
}
