const std = @import("std");
const klient = @import("klient");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== Test: Secrets Client ===\n\n", .{});

    var client = try klient.K8sClient.init(allocator, .{
        .server = "http://127.0.0.1:8080",
        .token = null,
        .namespace = "default",
    });
    defer client.deinit();

    var secrets_client = klient.Secrets.init(&client);

    // Test only klient-test namespace which has our simple test secret
    const ns_secrets = try secrets_client.client.list("klient-test");
    defer ns_secrets.deinit();
    std.debug.print("✓ Secrets.list(namespace) - Found {d} secrets in klient-test\n", .{ns_secrets.value.items.len});

    if (ns_secrets.value.items.len > 0) {
        std.debug.print("  First secret: {s}\n", .{ns_secrets.value.items[0].metadata.name});
    }

    std.debug.print("\n✓ All Secrets tests passed!\n\n", .{});
}
