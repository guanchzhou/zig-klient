const std = @import("std");
const klient = @import("klient");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== Test: Jobs Client ===\n\n", .{});

    var client = try klient.K8sClient.init(allocator, .{
        .server = "http://127.0.0.1:8080",
        .token = null,
        .namespace = "default",
    });
    defer client.deinit();

    var jobs_client = klient.Jobs.init(&client);

    const all_jobs = try jobs_client.client.listAll();
    defer all_jobs.deinit();
    std.debug.print("✓ Jobs.listAll() - Found {d} jobs\n", .{all_jobs.value.items.len});

    std.debug.print("\n✓ All Jobs tests passed!\n\n", .{});
}
