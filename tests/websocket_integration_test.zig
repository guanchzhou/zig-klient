const std = @import("std");
const klient = @import("klient");

/// Integration tests for WebSocket operations against rancher-desktop
/// These tests require a running Kubernetes cluster
///
/// Run with: zig test websocket_integration_test.zig --dep klient -Mklient=../src/klient.zig
///
/// Prerequisites:
/// 1. Rancher Desktop running
/// 2. kubectl context set to rancher-desktop
/// 3. Test pod deployed (see createTestPod below)
const TEST_NAMESPACE = "zig-klient-ws-test";
const TEST_POD_NAME = "ws-test-pod";

/// Helper to verify we're using rancher-desktop context
fn verifyContext(allocator: std.mem.Allocator) !void {
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "kubectl", "config", "current-context" },
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    const context = std.mem.trim(u8, result.stdout, &std.ascii.whitespace);

    if (!std.mem.eql(u8, context, "rancher-desktop")) {
        std.debug.print("❌ ERROR: Must use 'rancher-desktop' context, current: {s}\n", .{context});
        std.debug.print("   Run: kubectl config use-context rancher-desktop\n", .{});
        return error.WrongKubernetesContext;
    }

    std.debug.print("✅ Using correct context: {s}\n", .{context});
}

/// Create test namespace
fn createTestNamespace(allocator: std.mem.Allocator) !void {
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{
            "kubectl",
            "create",
            "namespace",
            TEST_NAMESPACE,
            "--dry-run=client",
            "-o",
            "yaml",
        },
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    const apply_result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "kubectl", "apply", "-f", "-" },
        .stdin_behavior = .{ .bytes = result.stdout },
    });
    defer allocator.free(apply_result.stdout);
    defer allocator.free(apply_result.stderr);

    std.debug.print("✅ Test namespace ready: {s}\n", .{TEST_NAMESPACE});
}

/// Create a test pod for exec/attach testing
fn createTestPod(allocator: std.mem.Allocator) !void {
    const pod_manifest =
        \\apiVersion: v1
        \\kind: Pod
        \\metadata:
        \\  name: ws-test-pod
        \\  namespace: zig-klient-ws-test
        \\  labels:
        \\    app: ws-test
        \\spec:
        \\  containers:
        \\  - name: busybox
        \\    image: busybox:latest
        \\    command: ["sh", "-c", "while true; do sleep 3600; done"]
        \\    imagePullPolicy: IfNotPresent
    ;

    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "kubectl", "apply", "-f", "-" },
        .stdin_behavior = .{ .bytes = pod_manifest },
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    if (result.term.Exited != 0) {
        std.debug.print("⚠️  Pod creation failed (may already exist): {s}\n", .{result.stderr});
        return;
    }

    std.debug.print("✅ Test pod created: {s}\n", .{TEST_POD_NAME});
}

/// Wait for pod to be ready
fn waitForPodReady(allocator: std.mem.Allocator, timeout_seconds: u32) !void {
    const start = std.time.milliTimestamp();
    const timeout_ms = timeout_seconds * 1000;

    std.debug.print("⏳ Waiting for pod to be ready (timeout: {d}s)...\n", .{timeout_seconds});

    while (true) {
        const elapsed = std.time.milliTimestamp() - start;
        if (elapsed > timeout_ms) {
            return error.WaitTimeout;
        }

        const result = try std.process.Child.run(.{
            .allocator = allocator,
            .argv = &[_][]const u8{
                "kubectl",
                "get",
                "pod",
                TEST_POD_NAME,
                "-n",
                TEST_NAMESPACE,
                "-o",
                "jsonpath={.status.phase}",
            },
        });
        defer allocator.free(result.stdout);
        defer allocator.free(result.stderr);

        if (std.mem.eql(u8, result.stdout, "Running")) {
            std.debug.print("✅ Pod is ready\n", .{});
            return;
        }

        std.time.sleep(2 * std.time.ns_per_s);
    }
}

/// Delete test resources
fn cleanup(allocator: std.mem.Allocator) !void {
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{
            "kubectl",
            "delete",
            "namespace",
            TEST_NAMESPACE,
            "--ignore-not-found=true",
        },
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    std.debug.print("✅ Cleanup complete\n", .{});
}

test "WebSocket Integration - Setup test environment" {
    const allocator = std.testing.allocator;

    std.debug.print("\n{'═':<60}\n", .{});
    std.debug.print("  WebSocket Integration Tests\n", .{});
    std.debug.print("{'═':<60}\n", .{});

    // Verify context
    try verifyContext(allocator);

    // Create test namespace
    try createTestNamespace(allocator);

    // Create test pod
    try createTestPod(allocator);

    // Wait for pod to be ready
    try waitForPodReady(allocator, 60);

    std.debug.print("✅ Test environment setup complete\n", .{});
}

test "WebSocket Integration - Test kubectl exec as baseline" {
    const allocator = std.testing.allocator;

    std.debug.print("\n🧪 Testing kubectl exec (baseline)...\n", .{});

    // Use kubectl exec as a baseline to verify pod is working
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{
            "kubectl",
            "exec",
            TEST_POD_NAME,
            "-n",
            TEST_NAMESPACE,
            "--",
            "echo",
            "hello from pod",
        },
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    try std.testing.expect(std.mem.containsAtLeast(u8, result.stdout, 1, "hello from pod"));

    std.debug.print("  Output: {s}", .{result.stdout});
    std.debug.print("✅ kubectl exec works (pod is ready)\n", .{});
}

test "WebSocket Integration - Build exec path for test pod" {
    const allocator = std.testing.allocator;

    std.debug.print("\n🧪 Testing exec path building...\n", .{});

    const command = [_][]const u8{ "echo", "test" };
    const path = try klient.websocket.buildExecPath(
        allocator,
        TEST_NAMESPACE,
        TEST_POD_NAME,
        &command,
        .{ .stdout = true },
    );
    defer allocator.free(path);

    std.debug.print("  Exec path: {s}\n", .{path});

    // Verify path structure
    try std.testing.expect(std.mem.containsAtLeast(u8, path, 1, TEST_NAMESPACE));
    try std.testing.expect(std.mem.containsAtLeast(u8, path, 1, TEST_POD_NAME));
    try std.testing.expect(std.mem.containsAtLeast(u8, path, 1, "command=echo"));

    std.debug.print("✅ Exec path building works\n", .{});
}

test "WebSocket Integration - Cleanup" {
    const allocator = std.testing.allocator;

    std.debug.print("\n🧹 Cleaning up test resources...\n", .{});

    try cleanup(allocator);

    std.debug.print("\n{'═':<60}\n", .{});
    std.debug.print("  All WebSocket integration tests complete!\n", .{});
    std.debug.print("{'═':<60}\n\n", .{});
}

// NOTE: The following tests will work once websocket.zig is fully integrated

// test "WebSocket Integration - Pod exec simple command" {
//     const allocator = std.testing.allocator;
//
//     // Initialize K8s client (from kubeconfig)
//     var client = try initTestClient(allocator);
//     defer client.deinit();
//
//     // Initialize WebSocket client
//     var ws_client = try klient.WebSocketClient.init(
//         allocator,
//         client.api_server,
//         client.token,
//         client.ca_cert_data,
//     );
//     defer ws_client.deinit();
//
//     // Execute command in pod
//     var exec_client = klient.ExecClient.init(allocator, &ws_client);
//
//     const result = try exec_client.exec(TEST_POD_NAME, TEST_NAMESPACE, .{
//         .command = &[_][]const u8{ "echo", "hello from zig-klient" },
//         .stdout = true,
//     });
//     defer result.deinit();
//
//     try std.testing.expect(result.success());
//     try std.testing.expect(std.mem.containsAtLeast(u8, result.stdout(), 1, "hello from zig-klient"));
//
//     std.debug.print("✅ Pod exec test passed\n", .{});
// }

// test "WebSocket Integration - Pod exec with stderr" {
//     // Test error output
// }

// test "WebSocket Integration - Pod attach" {
//     // Test attach to running container
// }

// test "WebSocket Integration - Port forward" {
//     // Test port forwarding
// }
