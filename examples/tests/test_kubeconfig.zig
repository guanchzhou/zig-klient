const std = @import("std");
const klient = @import("klient");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== Test: Kubeconfig Parser ===\n\n", .{});

    var parser = klient.KubeconfigParser.init(allocator);
    var kubeconfig = try parser.load();
    defer kubeconfig.deinit(allocator);

    std.debug.print("✓ KubeconfigParser.init()\n", .{});
    std.debug.print("✓ KubeconfigParser.load()\n", .{});
    std.debug.print("  Current context: {s}\n", .{kubeconfig.current_context});
    std.debug.print("  Clusters: {d}\n", .{kubeconfig.clusters.len});
    std.debug.print("  Contexts: {d}\n", .{kubeconfig.contexts.len});
    std.debug.print("  Users: {d}\n", .{kubeconfig.users.len});

    const context = kubeconfig.getContextByName(kubeconfig.current_context);
    if (context) |ctx| {
        std.debug.print("✓ Kubeconfig.getContextByName()\n", .{});
        std.debug.print("  Context name: {s}\n", .{ctx.name});
    }

    std.debug.print("\n✓ All Kubeconfig tests passed!\n\n", .{});
}
