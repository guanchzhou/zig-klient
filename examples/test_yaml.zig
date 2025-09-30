const std = @import("std");
const klient = @import("klient");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var parser = klient.KubeconfigParser.init(allocator);
    var config = try parser.load();
    defer config.deinit(allocator);

    std.debug.print("\n✅ Successfully parsed kubeconfig WITHOUT kubectl!\n", .{});
    std.debug.print("   Current context: {s}\n", .{config.current_context});
    std.debug.print("   Clusters: {d}\n", .{config.clusters.len});
    std.debug.print("   Contexts: {d}\n", .{config.contexts.len});
    std.debug.print("   Users: {d}\n\n", .{config.users.len});

    if (config.getCurrentContext()) |ctx| {
        std.debug.print("   Context details:\n", .{});
        std.debug.print("   - Name: {s}\n", .{ctx.name});
        std.debug.print("   - Cluster: {s}\n", .{ctx.cluster});
        std.debug.print("   - User: {s}\n", .{ctx.user});
        if (ctx.namespace) |ns| {
            std.debug.print("   - Namespace: {s}\n", .{ns});
        }
    }
}
