const std = @import("std");
const klient = @import("klient");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== Test: Deployments Client ===\n\n", .{});

    var client = try klient.K8sClient.init(allocator, .{
        .server = "http://127.0.0.1:8080",
        .token = null,
        .namespace = "default",
    });
    defer client.deinit();

    var deployments_client = klient.Deployments.init(&client);

    const all_deps = try deployments_client.client.listAll();
    defer all_deps.deinit();
    std.debug.print("✓ Deployments.listAll() - Found {d} deployments\n", .{all_deps.value.items.len});

    const ns_deps = try deployments_client.client.list("kube-system");
    defer ns_deps.deinit();
    std.debug.print("✓ Deployments.list(namespace) - Found {d} deployments in kube-system\n", .{ns_deps.value.items.len});

    std.debug.print("\n✓ All Deployments tests passed!\n\n", .{});
}
