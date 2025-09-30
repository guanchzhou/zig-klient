const std = @import("std");
const klient = @import("klient");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== Test: Pods Client ===\n\n", .{});

    var client = try klient.K8sClient.init(allocator, .{
        .server = "http://127.0.0.1:8080",
        .token = null,
        .namespace = "default",
    });
    defer client.deinit();

    var pods_client = klient.Pods.init(&client);

    // Test listAll
    const all_pods = try pods_client.client.listAll();
    defer all_pods.deinit();
    std.debug.print("✓ Pods.listAll() - Found {d} pods\n", .{all_pods.value.items.len});

    // Test list (namespaced)
    const ns_pods = try pods_client.client.list("kube-system");
    defer ns_pods.deinit();
    std.debug.print("✓ Pods.list(namespace) - Found {d} pods in kube-system\n", .{ns_pods.value.items.len});

    // Test get (if pods exist)
    if (ns_pods.value.items.len > 0) {
        const pod_name = ns_pods.value.items[0].metadata.name;
        const pod = try pods_client.client.get(pod_name, "kube-system");
        std.debug.print("✓ Pods.get(name, namespace) - Retrieved: {s}\n", .{pod.metadata.name});
    }

    std.debug.print("\n✓ All Pods tests passed!\n\n", .{});
}
