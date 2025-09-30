const std = @import("std");
const klient = @import("klient");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== Test: Core Client Functions ===\n\n", .{});

    var client = try klient.K8sClient.init(allocator, .{
        .server = "http://127.0.0.1:8080",
        .token = null,
        .namespace = "default",
    });
    defer client.deinit();

    std.debug.print("✓ K8sClient.init()\n", .{});

    const info = try client.getClusterInfo();
    std.debug.print("✓ K8sClient.getClusterInfo()\n", .{});
    std.debug.print("  Version: {s}\n", .{info.k8s_version});

    std.debug.print("\n✓ All core client tests passed!\n\n", .{});
}
