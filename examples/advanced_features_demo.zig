const std = @import("std");
const klient = @import("klient");

/// Comprehensive demo of advanced zig-klient features
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n" ++ "=" ** 70 ++ "\n", .{});
    std.debug.print("  zig-klient Advanced Features Demo\n", .{});
    std.debug.print("=" ** 70 ++ "\n\n", .{});

    // === 1. In-Cluster Configuration ===
    std.debug.print("1. In-Cluster Configuration Detection\n", .{});
    if (klient.isInCluster()) {
        std.debug.print("   ✓ Running inside Kubernetes cluster\n", .{});

        var incluster_config = try klient.loadInClusterConfig(allocator);
        defer incluster_config.deinit();

        std.debug.print("   ✓ Server: {s}\n", .{incluster_config.server});
        std.debug.print("   ✓ Namespace: {s}\n", .{incluster_config.namespace});

        var client = try klient.K8sClient.init(allocator, .{
            .server = incluster_config.server,
            .token = incluster_config.token,
            .namespace = incluster_config.namespace,
        });
        defer client.deinit();
    } else {
        std.debug.print("   ℹ Running outside cluster, using kubectl proxy\n", .{});

        var client = try klient.K8sClient.init(allocator, .{
            .server = "http://127.0.0.1:8080",
            .token = null,
            .namespace = "default",
        });
        defer client.deinit();

        // === 2. Field and Label Selectors ===
        std.debug.print("\n2. Using Field and Label Selectors\n", .{});

        var pods = klient.Pods.init(&client);

        // Field selector example
        const field_options = klient.ListOptions{
            .field_selector = "status.phase=Running",
            .limit = 5,
        };

        const running_pods = try pods.client.listAllWithOptions(field_options);
        defer running_pods.deinit();

        std.debug.print("   ✓ Found {d} running pods (field selector)\n", .{running_pods.value.items.len});

        // Label selector builder example
        var label_selector = klient.LabelSelector.init(allocator);
        defer label_selector.deinit();

        try label_selector.addExists("app");
        try label_selector.addNotEquals("env", "test");

        const selector_str = try label_selector.build();
        defer allocator.free(selector_str);

        const label_options = klient.ListOptions{
            .label_selector = selector_str,
            .limit = 10,
        };

        const labeled_pods = try pods.client.listAllWithOptions(label_options);
        defer labeled_pods.deinit();

        std.debug.print("   ✓ Found {d} labeled pods (label selector: {s})\n", .{
            labeled_pods.value.items.len,
            selector_str,
        });

        // === 3. Pagination ===
        std.debug.print("\n3. Pagination Support\n", .{});

        const page_options = klient.ListOptions{
            .limit = 3,
        };

        const first_page = try pods.client.listAllWithOptions(page_options);
        defer first_page.deinit();

        std.debug.print("   ✓ Page 1: {d} pods\n", .{first_page.value.items.len});

        if (first_page.value.metadata.continue_) |continue_token| {
            const next_page_options = klient.ListOptions{
                .limit = 3,
                .continue_token = continue_token,
            };

            const second_page = try pods.client.listAllWithOptions(next_page_options);
            defer second_page.deinit();

            std.debug.print("   ✓ Page 2: {d} pods\n", .{second_page.value.items.len});
        } else {
            std.debug.print("   ℹ No more pages available\n", .{});
        }

        // === 4. JSON Patch Builder ===
        std.debug.print("\n4. JSON Patch Builder\n", .{});

        var json_patch = klient.JsonPatch.init(allocator);
        defer json_patch.deinit();

        try json_patch.add("/metadata/labels/demo", .{ .string = "true" });
        try json_patch.replace("/metadata/labels/version", .{ .string = "v2" });

        const patch_json = try json_patch.build();
        defer allocator.free(patch_json);

        std.debug.print("   ✓ Built JSON patch:\n", .{});
        std.debug.print("   {s}\n", .{patch_json});

        // === 5. Strategic Merge Patch ===
        std.debug.print("\n5. Patch Type Support\n", .{});
        std.debug.print("   ✓ Strategic Merge: {s}\n", .{klient.PatchType.strategic_merge.contentType()});
        std.debug.print("   ✓ JSON Merge: {s}\n", .{klient.PatchType.merge.contentType()});
        std.debug.print("   ✓ JSON Patch: {s}\n", .{klient.PatchType.json.contentType()});
        std.debug.print("   ✓ Server-Side Apply: {s}\n", .{klient.PatchType.apply.contentType()});

        // === 6. Apply Options ===
        std.debug.print("\n6. Server-Side Apply Options\n", .{});

        const apply_options = klient.ApplyOptions{
            .field_manager = "demo-controller",
            .force = false,
            .dry_run = "All",
        };

        const apply_query = try apply_options.buildQueryString(allocator);
        defer allocator.free(apply_query);

        std.debug.print("   ✓ Apply query string: {s}\n", .{apply_query});
    }

    // === Summary ===
    std.debug.print("\n" ++ "=" ** 70 ++ "\n", .{});
    std.debug.print("  Demo Complete!\n", .{});
    std.debug.print("\n  New Features Demonstrated:\n", .{});
    std.debug.print("  • In-cluster configuration detection\n", .{});
    std.debug.print("  • Field and label selectors with builder pattern\n", .{});
    std.debug.print("  • Pagination support with continue tokens\n", .{});
    std.debug.print("  • JSON Patch builder\n", .{});
    std.debug.print("  • Multiple patch content types\n", .{});
    std.debug.print("  • Server-side apply options\n", .{});
    std.debug.print("=" ** 70 ++ "\n\n", .{});
}
