const std = @import("std");
const klient = @import("klient");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== Test: Services Client ===\n\n", .{});

    var client = try klient.K8sClient.init(allocator, .{
        .server = "http://127.0.0.1:8080",
        .token = null,
        .namespace = "default",
    });
    defer client.deinit();

    var services_client = klient.Services.init(&client);

    const all_svcs = try services_client.client.listAll();
    defer all_svcs.deinit();
    std.debug.print("✓ Services.listAll() - Found {d} services\n", .{all_svcs.value.items.len});

    const ns_svcs = try services_client.client.list("default");
    defer ns_svcs.deinit();
    std.debug.print("✓ Services.list(namespace) - Found {d} services in default\n", .{ns_svcs.value.items.len});

    std.debug.print("\n✓ All Services tests passed!\n\n", .{});
}
