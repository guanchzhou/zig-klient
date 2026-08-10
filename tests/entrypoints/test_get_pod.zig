const std = @import("std");
const klient = @import("klient");
const helpers = @import("helpers.zig");

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var threaded = helpers.initIo(allocator);
    defer threaded.deinit();
    const io = threaded.io();

    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  Test: Get Pod (zig-klient)\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n\n", .{});

    // Initialize client
    std.debug.print("🔌 Initializing Kubernetes client...\n", .{});
    var client = helpers.initClientFromKubeconfig(allocator, io) catch |err| {
        std.debug.print("❌ Failed to initialize client: {}\n", .{err});
        return err;
    };
    defer client.deinit();
    std.debug.print("✅ Client initialized\n\n", .{});

    // Get pod
    const test_namespace = "zig-klient-test";
    const pod_name = "zig-test-pod";

    std.debug.print("🔍 Getting pod '{s}' in namespace '{s}'...\n", .{ pod_name, test_namespace });

    const pods_client = klient.Pods.init(&client);
    const parsed = pods_client.client.get(pod_name, test_namespace) catch |err| {
        std.debug.print("❌ Failed to get pod: {}\n", .{err});
        std.debug.print("\n💡 Tip: Run test_create_pod.zig first to create the pod\n", .{});
        return err;
    };
    defer parsed.deinit();
    const pod = parsed.value;

    std.debug.print("✅ Pod found!\n\n", .{});

    // Display pod details
    std.debug.print("Pod Details:\n", .{});
    std.debug.print("  Name: {s}\n", .{pod.metadata.name});
    std.debug.print("  Namespace: {s}\n", .{pod.metadata.namespace orelse "default"});

    if (pod.metadata.uid) |uid| {
        std.debug.print("  UID: {s}\n", .{uid});
    }

    if (pod.metadata.labels) |labels| {
        if (labels == .object) {
            std.debug.print("  Labels:\n", .{});
            var it = labels.object.iterator();
            while (it.next()) |entry| {
                if (entry.value_ptr.* == .string) {
                    std.debug.print("    {s}: {s}\n", .{ entry.key_ptr.*, entry.value_ptr.*.string });
                }
            }
        }
    }

    if (pod.status) |status| {
        std.debug.print("\n  Status:\n", .{});
        std.debug.print("    Phase: {s}\n", .{status.phase orelse "unknown"});
        std.debug.print("    Pod IP: {s}\n", .{status.podIP orelse "unknown"});
        std.debug.print("    Host IP: {s}\n", .{status.hostIP orelse "unknown"});
        std.debug.print("    Start Time: {s}\n", .{status.startTime orelse "unknown"});

        if (status.conditions) |conditions| {
            std.debug.print("    Conditions:\n", .{});
            for (conditions) |condition| {
                std.debug.print("      {s}: {s}\n", .{ condition.type, condition.status });
            }
        }
    }

    if (pod.spec) |spec| {
        if (spec.containers) |containers| {
            std.debug.print("\n  Containers:\n", .{});
            for (containers, 0..) |container, i| {
                std.debug.print("    {}. Name: {s}\n", .{ i + 1, container.name orelse "unknown" });
                std.debug.print("       Image: {s}\n", .{container.image orelse "unknown"});
            }
        }
    }

    std.debug.print("\n═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  ✅ Test completed successfully\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
}
