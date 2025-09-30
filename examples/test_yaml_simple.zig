const std = @import("std");
const klient = @import("klient");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var parser = klient.KubeconfigParser.init(allocator);
    var config = try parser.loadFromPath("/tmp/test_simple_config.yaml");
    defer config.deinit(allocator);

    std.debug.print("\n✅ Successfully parsed simple kubeconfig!\n", .{});
    std.debug.print("   Current context: {s}\n", .{config.current_context});
    std.debug.print("   Clusters: {d}\n", .{config.clusters.len});
    std.debug.print("   Contexts: {d}\n", .{config.contexts.len});
    std.debug.print("   Users: {d}\n\n", .{config.users.len});
}
