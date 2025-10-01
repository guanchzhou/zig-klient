const std = @import("std");
const klient = @import("klient");
const helpers = @import("helpers.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  Test: List Pods (zig-klient)\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n\n", .{});

    // Initialize client from kubeconfig
    std.debug.print("🔌 Initializing Kubernetes client from kubeconfig...\n", .{});
    var client = helpers.initClientFromKubeconfig(allocator) catch |err| {
        std.debug.print("❌ Failed to initialize client: {}\n", .{err});
        return err;
    };
    defer client.deinit();
    std.debug.print("✅ Client initialized\n", .{});
    std.debug.print("   API Server: {s}\n", .{client.api_server});
    std.debug.print("   Namespace: {s}\n\n", .{client.namespace});

    // Create Pods client
    const pods_client = klient.Pods.init(&client);

    // List pods in default namespace
    std.debug.print("📋 Listing pods in 'default' namespace...\n", .{});
    const pods_parsed = pods_client.client.list("default") catch |err| {
        std.debug.print("❌ Failed to list pods: {}\n", .{err});
        return err;
    };
    defer pods_parsed.deinit();
    const pods = pods_parsed.value.items;

    std.debug.print("✅ Found {} pod(s)\n\n", .{pods.len});

    if (pods.len > 0) {
        std.debug.print("Pods:\n", .{});
        for (pods, 0..) |pod, i| {
            std.debug.print("  {}. Name: {s}\n", .{ i + 1, pod.metadata.name });
            if (pod.status) |status| {
                if (status.phase) |phase| {
                    std.debug.print("     Phase: {s}\n", .{phase});
                }
            }
        }
    } else {
        std.debug.print("  (No pods in default namespace)\n", .{});
    }

    std.debug.print("\n═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  ✅ Test completed successfully\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
}
