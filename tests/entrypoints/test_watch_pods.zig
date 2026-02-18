const std = @import("std");
const klient = @import("klient");
const helpers = @import("helpers.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  Test: Watch Pods (zig-klient)\n", .{});
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

    std.debug.print("👀 Starting watch on namespace '{s}'...\n", .{test_namespace});
    std.debug.print("   (Press Ctrl+C to stop, will auto-stop after 30 seconds)\n\n", .{});

    // Create watcher with label selector
    var label_selector = try klient.LabelSelector.init(allocator);
    defer label_selector.deinit();

    try label_selector.addEquals("app", "zig-test");

    const watch_options = klient.WatchOptions{
        .label_selector = try label_selector.build(),
        .timeout_seconds = 30,
    };
    defer if (watch_options.label_selector) |ls| allocator.free(ls);

    var watcher = klient.Watcher(klient.types.Pod).init(
        &client,
        "/api/v1",
        "pods",
        test_namespace,
        watch_options,
    );

    std.debug.print("📡 Watching for pod events...\n\n", .{});

    watcher.watch(&struct {
        fn callback(event: *klient.watch.WatchEvent(klient.types.Pod)) anyerror!void {
            const event_type_str = switch (event.type_) {
                .ADDED => "ADDED",
                .MODIFIED => "MODIFIED",
                .DELETED => "DELETED",
                .ERROR => "ERROR",
                .BOOKMARK => "BOOKMARK",
            };

            std.debug.print("  Event: {s}\n", .{event_type_str});
            std.debug.print("    Pod: {s}\n", .{event.object.metadata.name});

            if (event.object.status) |status| {
                if (status == .object) {
                    if (status.object.get("phase")) |phase| {
                        if (phase == .string) {
                            std.debug.print("    Phase: {s}\n", .{phase.string});
                        }
                    }
                }
            }

            std.debug.print("\n", .{});
            event.deinit();
        }
    }.callback) catch |err| {
        std.debug.print("  Watch ended: {}\n", .{err});
    };

    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  ✅ Watch completed\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
}
