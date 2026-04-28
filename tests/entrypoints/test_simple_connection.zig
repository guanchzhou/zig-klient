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
    std.debug.print("  Simple Connection Test (zig-klient)\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n\n", .{});

    // Initialize client from kubeconfig
    std.debug.print("🔌 Initializing Kubernetes client from kubeconfig...\n", .{});
    var client = helpers.initClientFromKubeconfig(allocator, io) catch |err| {
        std.debug.print("❌ Failed to initialize client: {}\n", .{err});
        return err;
    };
    defer client.deinit();

    std.debug.print("✅ Client initialized successfully!\n", .{});
    std.debug.print("   API Server: {s}\n", .{client.api_server});
    std.debug.print("   Namespace: {s}\n", .{client.namespace});
    if (client.token) |token| {
        std.debug.print("   Token: {s}...\n", .{token[0..@min(20, token.len)]});
    } else {
        std.debug.print("   Token: (none)\n", .{});
    }

    std.debug.print("\n═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  ✅ Connection test passed!\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
}



