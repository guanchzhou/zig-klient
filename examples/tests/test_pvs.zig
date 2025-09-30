const std = @import("std");
const klient = @import("klient");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== Test: PersistentVolumes Client (Cluster-Scoped) ===\n\n", .{});

    var client = try klient.K8sClient.init(allocator, .{
        .server = "http://127.0.0.1:8080",
        .token = null,
        .namespace = "default",
    });
    defer client.deinit();

    var pvs_client = klient.PersistentVolumes.init(&client);

    const pvs = try pvs_client.list();
    defer pvs.deinit();
    std.debug.print("✓ PersistentVolumes.list() - Found {d} pvs\n", .{pvs.value.items.len});

    std.debug.print("\n✓ All PersistentVolumes tests passed!\n\n", .{});
}
