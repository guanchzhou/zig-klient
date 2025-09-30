const std = @import("std");
const klient = @import("klient");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== Test: CronJobs Client ===\n\n", .{});

    var client = try klient.K8sClient.init(allocator, .{
        .server = "http://127.0.0.1:8080",
        .token = null,
        .namespace = "default",
    });
    defer client.deinit();

    var cronjobs_client = klient.CronJobs.init(&client);

    const all_cj = try cronjobs_client.client.listAll();
    defer all_cj.deinit();
    std.debug.print("✓ CronJobs.listAll() - Found {d} cronjobs\n", .{all_cj.value.items.len});

    std.debug.print("\n✓ All CronJobs tests passed!\n\n", .{});
}
