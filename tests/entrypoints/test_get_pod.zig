const std = @import("std");
const klient = @import("klient");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  Test: Get Pod (zig-klient)\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n\n", .{});

    // Initialize client
    std.debug.print("🔌 Initializing Kubernetes client...\n", .{});
    var client = klient.K8sClient.initFromKubeconfig(allocator) catch |err| {
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
    const pod = pods_client.client.get(pod_name, test_namespace) catch |err| {
        std.debug.print("❌ Failed to get pod: {}\n", .{err});
        std.debug.print("\n💡 Tip: Run test_create_pod.zig first to create the pod\n", .{});
        return err;
    };
    defer allocator.free(pod);

    std.debug.print("✅ Pod found!\n\n", .{});

    // Display pod details
    std.debug.print("Pod Details:\n", .{});
    std.debug.print("  Name: {s}\n", .{pod.metadata.name});
    std.debug.print("  Namespace: {s}\n", .{pod.metadata.namespace orelse "default"});

    if (pod.metadata.uid) |uid| {
        std.debug.print("  UID: {s}\n", .{uid});
    }

    if (pod.metadata.labels) |labels| {
        std.debug.print("  Labels:\n", .{});
        var it = labels.iterator();
        while (it.next()) |entry| {
            std.debug.print("    {s}: {s}\n", .{ entry.key_ptr.*, entry.value_ptr.*.string });
        }
    }

    if (pod.status) |status| {
        std.debug.print("\n  Status:\n", .{});

        if (status.phase) |phase| {
            std.debug.print("    Phase: {s}\n", .{phase});
        }

        if (status.podIP) |ip| {
            std.debug.print("    Pod IP: {s}\n", .{ip});
        }

        if (status.hostIP) |ip| {
            std.debug.print("    Host IP: {s}\n", .{ip});
        }

        if (status.startTime) |start_time| {
            std.debug.print("    Start Time: {s}\n", .{start_time});
        }

        if (status.conditions) |conditions| {
            std.debug.print("    Conditions:\n", .{});
            for (conditions) |condition| {
                if (condition.type) |ctype| {
                    const status_str = if (condition.status) |s| s else "Unknown";
                    std.debug.print("      {s}: {s}\n", .{ ctype, status_str });
                }
            }
        }
    }

    if (pod.spec) |spec| {
        if (spec.containers) |containers| {
            std.debug.print("\n  Containers:\n", .{});
            for (containers, 0..) |container, i| {
                std.debug.print("    {}. Name: {s}\n", .{ i + 1, container.name });
                std.debug.print("       Image: {s}\n", .{container.image});
            }
        }
    }

    std.debug.print("\n═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  ✅ Test completed successfully\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
}
