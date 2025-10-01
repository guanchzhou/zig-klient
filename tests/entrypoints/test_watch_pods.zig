const std = @import("std");
const klient = @import("klient");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  Test: Watch Pods (zig-klient)\n", .{});
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

    std.debug.print("👀 Starting watch on namespace '{s}'...\n", .{test_namespace});
    std.debug.print("   (Press Ctrl+C to stop, will auto-stop after 30 seconds)\n\n", .{});

    const pods_client = klient.Pods.init(&client);

    // Create watcher with label selector
    const label_selector = try klient.LabelSelector.init(allocator);
    defer label_selector.deinit();

    try label_selector.addEquals("app", "zig-test");

    const watch_options = klient.WatchOptions{
        .label_selector = try label_selector.toString(),
        .timeout_seconds = 30,
    };
    defer if (watch_options.label_selector) |ls| allocator.free(ls);

    var watcher = try klient.Watcher(klient.types.Pod).init(
        allocator,
        &client,
        "/api/v1",
        "pods",
        test_namespace,
        watch_options,
    );
    defer watcher.deinit();

    std.debug.print("📡 Watching for pod events...\n\n", .{});

    var event_count: usize = 0;
    const max_events = 20;

    while (try watcher.next()) |event| {
        defer allocator.free(event);
        event_count += 1;

        const event_type_str = switch (event.event_type) {
            .added => "ADDED",
            .modified => "MODIFIED",
            .deleted => "DELETED",
            .error_event => "ERROR",
        };

        std.debug.print("  Event #{d}: {s}\n", .{ event_count, event_type_str });
        std.debug.print("    Pod: {s}\n", .{event.object.metadata.name});

        if (event.object.status) |status| {
            if (status.phase) |phase| {
                std.debug.print("    Phase: {s}\n", .{phase});
            }
        }

        std.debug.print("\n", .{});

        if (event_count >= max_events) {
            std.debug.print("  (Stopping after {d} events)\n\n", .{max_events});
            break;
        }
    }

    if (event_count == 0) {
        std.debug.print("  (No events received - pod may not exist or no changes occurred)\n", .{});
        std.debug.print("  💡 Tip: Run test_create_pod.zig in another terminal to generate events\n\n", .{});
    }

    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  ✅ Watch completed - received {d} event(s)\n", .{event_count});
    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
}
