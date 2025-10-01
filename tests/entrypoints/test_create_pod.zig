const std = @import("std");
const klient = @import("klient");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  Test: Create Pod (zig-klient)\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n\n", .{});

    // Initialize client
    std.debug.print("🔌 Initializing Kubernetes client...\n", .{});
    var client = klient.K8sClient.initFromKubeconfig(allocator) catch |err| {
        std.debug.print("❌ Failed to initialize client: {}\n", .{err});
        return err;
    };
    defer client.deinit();
    std.debug.print("✅ Client initialized\n\n", .{});

    // Create test namespace
    const test_namespace = "zig-klient-test";
    std.debug.print("📦 Creating namespace '{s}'...\n", .{test_namespace});

    const namespaces_client = klient.Namespaces.init(&client);
    const ns_manifest =
        \\{
        \\  "apiVersion": "v1",
        \\  "kind": "Namespace",
        \\  "metadata": {
        \\    "name": "zig-klient-test",
        \\    "labels": {
        \\      "created-by": "zig-klient-test"
        \\    }
        \\  }
        \\}
    ;

    const namespace = namespaces_client.client.createFromJson(ns_manifest, null) catch |err| {
        if (err == error.AlreadyExists) {
            std.debug.print("⚠️  Namespace already exists (continuing...)\n", .{});
        } else {
            std.debug.print("❌ Failed to create namespace: {}\n", .{err});
            return err;
        }
    };
    if (namespace) |ns| {
        defer allocator.free(ns);
    }
    std.debug.print("✅ Namespace ready\n\n", .{});

    // Create test pod
    std.debug.print("🚀 Creating test pod...\n", .{});
    const pods_client = klient.Pods.init(&client);

    const pod_manifest =
        \\{
        \\  "apiVersion": "v1",
        \\  "kind": "Pod",
        \\  "metadata": {
        \\    "name": "zig-test-pod",
        \\    "namespace": "zig-klient-test",
        \\    "labels": {
        \\      "app": "zig-test",
        \\      "created-by": "zig-klient"
        \\    }
        \\  },
        \\  "spec": {
        \\    "containers": [
        \\      {
        \\        "name": "busybox",
        \\        "image": "busybox:latest",
        \\        "command": ["sh", "-c", "echo 'Hello from zig-klient!' && sleep 3600"],
        \\        "imagePullPolicy": "IfNotPresent"
        \\      }
        \\    ],
        \\    "restartPolicy": "Never"
        \\  }
        \\}
    ;

    const pod = pods_client.client.createFromJson(pod_manifest, test_namespace) catch |err| {
        std.debug.print("❌ Failed to create pod: {}\n", .{err});
        return err;
    };
    defer allocator.free(pod);

    std.debug.print("✅ Pod created successfully!\n", .{});
    std.debug.print("   Name: {s}\n", .{pod.metadata.name});
    std.debug.print("   Namespace: {s}\n", .{pod.metadata.namespace orelse "default"});

    if (pod.status) |status| {
        if (status.phase) |phase| {
            std.debug.print("   Phase: {s}\n", .{phase});
        }
    }

    std.debug.print("\n💡 Tip: Run test_get_pod.zig to check pod status\n", .{});
    std.debug.print("💡 Tip: Run test_delete_pod.zig to clean up\n", .{});

    std.debug.print("\n═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  ✅ Test completed successfully\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
}
