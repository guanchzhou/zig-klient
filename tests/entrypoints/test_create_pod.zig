const std = @import("std");
const klient = @import("klient");
const helpers = @import("helpers.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  Test: Create Pod (zig-klient)\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n\n", .{});

    // Initialize client
    std.debug.print("🔌 Initializing Kubernetes client...\n", .{});
    var client = helpers.initClientFromKubeconfig(allocator) catch |err| {
        std.debug.print("❌ Failed to initialize client: {}\n", .{err});
        return err;
    };
    defer client.deinit();
    std.debug.print("✅ Client initialized\n\n", .{});

    // Create test namespace
    const test_namespace = "zig-klient-test";
    std.debug.print("📦 Creating namespace '{s}'...\n", .{test_namespace});

    const ns_manifest =
        \\{"apiVersion":"v1","kind":"Namespace","metadata":{"name":"zig-klient-test","labels":{"created-by":"zig-klient-test"}}}
    ;

    const ns_result = client.request(.POST, "/api/v1/namespaces", ns_manifest) catch |err| blk: {
        if (err == error.K8sApiError) {
            if (client.last_api_error) |api_err| {
                if (api_err.code != null and api_err.code.? == 409) {
                    std.debug.print("⚠️  Namespace already exists (continuing...)\n", .{});
                } else {
                    std.debug.print("❌ Failed to create namespace: {}\n", .{err});
                    return err;
                }
            }
        } else {
            std.debug.print("❌ Failed to create namespace: {}\n", .{err});
            return err;
        }
        break :blk null;
    };
    if (ns_result) |r| allocator.free(r);
    std.debug.print("✅ Namespace ready\n\n", .{});

    // Create test pod
    std.debug.print("🚀 Creating test pod...\n", .{});
    const pod_manifest =
        \\{"apiVersion":"v1","kind":"Pod","metadata":{"name":"zig-test-pod","namespace":"zig-klient-test","labels":{"app":"zig-test","created-by":"zig-klient"}},"spec":{"containers":[{"name":"busybox","image":"busybox:latest","command":["sh","-c","echo 'Hello from zig-klient!' && sleep 3600"],"imagePullPolicy":"IfNotPresent"}],"restartPolicy":"Never"}}
    ;

    const pod_path = try std.fmt.allocPrint(allocator, "/api/v1/namespaces/{s}/pods", .{test_namespace});
    defer allocator.free(pod_path);

    const pod_result = try client.request(.POST, pod_path, pod_manifest);
    defer allocator.free(pod_result);

    // Parse the response to display pod info
    const parsed = try std.json.parseFromSlice(
        klient.Pod,
        allocator,
        pod_result,
        .{ .ignore_unknown_fields = true, .allocate = .alloc_always },
    );
    defer parsed.deinit();
    const pod = parsed.value;

    std.debug.print("✅ Pod created successfully!\n", .{});
    std.debug.print("   Name: {s}\n", .{pod.metadata.name});
    std.debug.print("   Namespace: {s}\n", .{pod.metadata.namespace orelse "default"});

    if (pod.status) |status| {
        if (status == .object) {
            if (status.object.get("phase")) |phase| {
                if (phase == .string) {
                    std.debug.print("   Phase: {s}\n", .{phase.string});
                }
            }
        }
    }

    std.debug.print("\n💡 Tip: Run test_get_pod.zig to check pod status\n", .{});
    std.debug.print("💡 Tip: Run test_delete_pod.zig to clean up\n", .{});

    std.debug.print("\n═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  ✅ Test completed successfully\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
}
