const std = @import("std");
const klient = @import("klient");
const helpers = @import("helpers.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  Test: Get Pod (zig-klient)\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n\n", .{});

    // Initialize client
    std.debug.print("🔌 Initializing Kubernetes client...\n", .{});
    var client = helpers.initClientFromKubeconfig(allocator) catch |err| {
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
        if (status == .object) {
            std.debug.print("\n  Status:\n", .{});

            if (status.object.get("phase")) |phase| {
                if (phase == .string) {
                    std.debug.print("    Phase: {s}\n", .{phase.string});
                }
            }

            if (status.object.get("podIP")) |ip| {
                if (ip == .string) {
                    std.debug.print("    Pod IP: {s}\n", .{ip.string});
                }
            }

            if (status.object.get("hostIP")) |ip| {
                if (ip == .string) {
                    std.debug.print("    Host IP: {s}\n", .{ip.string});
                }
            }

            if (status.object.get("startTime")) |start_time| {
                if (start_time == .string) {
                    std.debug.print("    Start Time: {s}\n", .{start_time.string});
                }
            }

            if (status.object.get("conditions")) |conditions| {
                if (conditions == .array) {
                    std.debug.print("    Conditions:\n", .{});
                    for (conditions.array.items) |condition| {
                        if (condition == .object) {
                            const ctype = if (condition.object.get("type")) |t| (if (t == .string) t.string else "Unknown") else "Unknown";
                            const status_str = if (condition.object.get("status")) |s| (if (s == .string) s.string else "Unknown") else "Unknown";
                            std.debug.print("      {s}: {s}\n", .{ ctype, status_str });
                        }
                    }
                }
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
