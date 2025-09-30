const std = @import("std");
const klient = @import("klient");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== Debug Test ===\n\n", .{});

    var client = try klient.K8sClient.init(allocator, .{
        .server = "http://127.0.0.1:8080",
        .token = null,
        .namespace = "default",
    });
    defer client.deinit();

    var pods_client = klient.Pods.init(&client);
    const all_pods_parsed = try pods_client.client.listAll();
    defer all_pods_parsed.deinit();
    
    std.debug.print("Found {d} pods\n", .{all_pods_parsed.value.items.len});
    
    if (all_pods_parsed.value.items.len > 0) {
        const pod = all_pods_parsed.value.items[0];
        std.debug.print("First pod metadata.name type: {s}\n", .{@typeName(@TypeOf(pod.metadata.name))});
        std.debug.print("First pod metadata.name len: {d}\n", .{pod.metadata.name.len});
    }
}
