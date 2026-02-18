const std = @import("std");
const klient = @import("klient");
const helpers = @import("helpers.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  Test: Update Pod (zig-klient)\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n\n", .{});

    // Initialize client
    std.debug.print("🔌 Initializing Kubernetes client...\n", .{});
    var client = helpers.initClientFromKubeconfig(allocator) catch |err| {
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
    const current_parsed = pods_client.client.get(pod_name, test_namespace) catch |err| {
        std.debug.print("❌ Failed to get pod: {}\n", .{err});
        std.debug.print("\n💡 Tip: Run test_create_pod.zig first to create the pod\n", .{});
        return err;
    };
    defer current_parsed.deinit();
    const current_pod = current_parsed.value;

    std.debug.print("✅ Current pod retrieved\n", .{});
    std.debug.print("   Current labels:\n", .{});
    if (current_pod.metadata.labels) |labels| {
        if (labels == .object) {
            var it = labels.object.iterator();
            while (it.next()) |entry| {
                if (entry.value_ptr.* == .string) {
                    std.debug.print("     {s}: {s}\n", .{ entry.key_ptr.*, entry.value_ptr.*.string });
                }
            }
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

    // Parse the updated manifest into a Pod to pass to updateWithOptions
    const updated_resource = try std.json.parseFromSlice(
        klient.Pod,
        allocator,
        updated_manifest,
        .{ .ignore_unknown_fields = true, .allocate = .alloc_always },
    );
    defer updated_resource.deinit();

    const update_options = klient.UpdateOptions{
        .field_manager = "zig-klient-test",
    };

    const updated_parsed = pods_client.client.updateWithOptions(
        updated_resource.value,
        test_namespace,
        update_options,
    ) catch |err| {
        std.debug.print("❌ Failed to update pod: {}\n", .{err});
        return err;
    };
    defer updated_parsed.deinit();
    const updated_pod = updated_parsed.value;

    std.debug.print("✅ Pod updated successfully!\n", .{});
    std.debug.print("   Updated labels:\n", .{});
    if (updated_pod.metadata.labels) |labels| {
        if (labels == .object) {
            var it = labels.object.iterator();
            while (it.next()) |entry| {
                if (entry.value_ptr.* == .string) {
                    std.debug.print("     {s}: {s}\n", .{ entry.key_ptr.*, entry.value_ptr.*.string });
                }
            }
        }
    }

    std.debug.print("\n═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  ✅ Test completed successfully\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
}
