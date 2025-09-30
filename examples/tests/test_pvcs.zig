const std = @import("std");
const klient = @import("klient");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== Test: PersistentVolumeClaims Client ===\n\n", .{});

    var client = try klient.K8sClient.init(allocator, .{
        .server = "http://127.0.0.1:8080",
        .token = null,
        .namespace = "default",
    });
    defer client.deinit();

    var pvcs_client = klient.PersistentVolumeClaims.init(&client);

    const all_pvcs = try pvcs_client.client.listAll();
    defer all_pvcs.deinit();
    std.debug.print("✓ PersistentVolumeClaims.listAll() - Found {d} pvcs\n", .{all_pvcs.value.items.len});

    std.debug.print("\n✓ All PersistentVolumeClaims tests passed!\n\n", .{});
}
