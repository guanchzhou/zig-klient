const std = @import("std");
const klient = @import("klient");

/// Test configuration and utilities
pub const TestConfig = struct {
    /// Kubernetes context to use (must be rancher-desktop)
    context: []const u8 = "rancher-desktop",

    /// Test namespace (isolated from other resources)
    namespace: []const u8 = "zig-klient-test",

    /// API server URL (from kubeconfig)
    api_server: []const u8 = "",

    /// Bearer token (from kubeconfig)
    token: ?[]const u8 = null,

    /// Enable verbose logging
    verbose: bool = false,
};

/// Test metrics for performance tracking
pub const TestMetrics = struct {
    start_time: i64,
    end_time: i64,
    operations: usize,
    errors: usize,
    retries: usize,

    pub fn init() TestMetrics {
        return .{
            .start_time = std.time.milliTimestamp(),
            .end_time = 0,
            .operations = 0,
            .errors = 0,
            .retries = 0,
        };
    }

    pub fn finish(self: *TestMetrics) void {
        self.end_time = std.time.milliTimestamp();
    }

    pub fn duration_ms(self: TestMetrics) i64 {
        return self.end_time - self.start_time;
    }

    pub fn ops_per_second(self: TestMetrics) f64 {
        const duration = @as(f64, @floatFromInt(self.duration_ms())) / 1000.0;
        if (duration == 0) return 0;
        return @as(f64, @floatFromInt(self.operations)) / duration;
    }

    pub fn success_rate(self: TestMetrics) f64 {
        if (self.operations == 0) return 0;
        const successes = self.operations - self.errors;
        return @as(f64, @floatFromInt(successes)) / @as(f64, @floatFromInt(self.operations)) * 100.0;
    }

    pub fn print(self: TestMetrics, name: []const u8) void {
        std.debug.print("\n📊 Metrics for {s}:\n", .{name});
        std.debug.print("  Duration: {d}ms\n", .{self.duration_ms()});
        std.debug.print("  Operations: {d}\n", .{self.operations});
        std.debug.print("  Errors: {d}\n", .{self.errors});
        std.debug.print("  Retries: {d}\n", .{self.retries});
        std.debug.print("  Throughput: {d:.2} ops/sec\n", .{self.ops_per_second()});
        std.debug.print("  Success Rate: {d:.2}%\n", .{self.success_rate()});
    }
};

/// Verify we're using the correct Kubernetes context
pub fn verifyContext(allocator: std.mem.Allocator) !void {
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "kubectl", "config", "current-context" },
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    const context = std.mem.trim(u8, result.stdout, &std.ascii.whitespace);

    if (!std.mem.eql(u8, context, "rancher-desktop")) {
        std.debug.print("❌ ERROR: Must use 'rancher-desktop' context, but current context is: {s}\n", .{context});
        std.debug.print("   Run: kubectl config use-context rancher-desktop\n", .{});
        return error.WrongKubernetesContext;
    }

    std.debug.print("✅ Using correct context: {s}\n", .{context});
}

/// Create test namespace (idempotent)
pub fn createTestNamespace(client: *klient.K8sClient, namespace: []const u8) !void {
    const allocator = client.allocator;

    // Create namespace manifest
    const manifest = try std.fmt.allocPrint(allocator,
        \\{{
        \\  "apiVersion": "v1",
        \\  "kind": "Namespace",
        \\  "metadata": {{
        \\    "name": "{s}",
        \\    "labels": {{
        \\      "test": "zig-klient",
        \\      "auto-delete": "true"
        \\    }}
        \\  }}
        \\}}
    , .{namespace});
    defer allocator.free(manifest);

    // Try to create namespace
    const path = "/api/v1/namespaces";
    const response = client.request(.POST, path, manifest) catch |err| {
        // Namespace might already exist, which is fine
        if (err == error.HttpConflict) {
            std.debug.print("✅ Namespace '{s}' already exists\n", .{namespace});
            return;
        }
        return err;
    };
    defer allocator.free(response);

    std.debug.print("✅ Created test namespace: {s}\n", .{namespace});
}

/// Delete test namespace and all resources (cleanup)
pub fn deleteTestNamespace(client: *klient.K8sClient, namespace: []const u8) !void {
    const path = try std.fmt.allocPrint(client.allocator, "/api/v1/namespaces/{s}", .{namespace});
    defer client.allocator.free(path);

    const response = client.request(.DELETE, path, null) catch |err| {
        // Namespace might not exist, which is fine
        std.debug.print("⚠️  Could not delete namespace (might not exist): {s}\n", .{@errorName(err)});
        return;
    };
    defer client.allocator.free(response);

    std.debug.print("✅ Deleted test namespace: {s}\n", .{namespace});

    // Wait for namespace to be fully deleted
    std.time.sleep(2 * std.time.ns_per_s);
}

/// Generate a unique resource name for testing
pub fn generateUniqueName(allocator: std.mem.Allocator, prefix: []const u8) ![]const u8 {
    const timestamp = std.time.milliTimestamp();
    const random = std.crypto.random.int(u32);
    return try std.fmt.allocPrint(allocator, "{s}-{d}-{x}", .{ prefix, timestamp, random });
}

/// Create a simple Pod manifest for testing
pub fn createTestPodManifest(allocator: std.mem.Allocator, name: []const u8, namespace: []const u8, labels: ?[]const u8) ![]const u8 {
    const label_str = labels orelse "\"app\": \"test\"";

    return try std.fmt.allocPrint(allocator,
        \\{{
        \\  "apiVersion": "v1",
        \\  "kind": "Pod",
        \\  "metadata": {{
        \\    "name": "{s}",
        \\    "namespace": "{s}",
        \\    "labels": {{ {s} }}
        \\  }},
        \\  "spec": {{
        \\    "containers": [{{
        \\      "name": "test",
        \\      "image": "nginx:alpine",
        \\      "imagePullPolicy": "IfNotPresent"
        \\    }}]
        \\  }}
        \\}}
    , .{ name, namespace, label_str });
}

/// Create a ConfigMap manifest for testing
pub fn createTestConfigMapManifest(allocator: std.mem.Allocator, name: []const u8, namespace: []const u8) ![]const u8 {
    return try std.fmt.allocPrint(allocator,
        \\{{
        \\  "apiVersion": "v1",
        \\  "kind": "ConfigMap",
        \\  "metadata": {{
        \\    "name": "{s}",
        \\    "namespace": "{s}"
        \\  }},
        \\  "data": {{
        \\    "key1": "value1",
        \\    "key2": "value2"
        \\  }}
        \\}}
    , .{ name, namespace });
}

/// Create a Deployment manifest for testing
pub fn createTestDeploymentManifest(allocator: std.mem.Allocator, name: []const u8, namespace: []const u8, replicas: i32) ![]const u8 {
    return try std.fmt.allocPrint(allocator,
        \\{{
        \\  "apiVersion": "apps/v1",
        \\  "kind": "Deployment",
        \\  "metadata": {{
        \\    "name": "{s}",
        \\    "namespace": "{s}"
        \\  }},
        \\  "spec": {{
        \\    "replicas": {d},
        \\    "selector": {{
        \\      "matchLabels": {{ "app": "{s}" }}
        \\    }},
        \\    "template": {{
        \\      "metadata": {{
        \\        "labels": {{ "app": "{s}" }}
        \\      }},
        \\      "spec": {{
        \\        "containers": [{{
        \\          "name": "nginx",
        \\          "image": "nginx:alpine",
        \\          "imagePullPolicy": "IfNotPresent"
        \\        }}]
        \\      }}
        \\    }}
        \\  }}
        \\}}
    , .{ name, namespace, replicas, name, name });
}

/// Wait for a Pod to be ready
pub fn waitForPodReady(client: *klient.K8sClient, name: []const u8, namespace: []const u8, timeout_seconds: u32) !void {
    const allocator = client.allocator;
    const start = std.time.milliTimestamp();
    const timeout_ms = timeout_seconds * 1000;

    while (true) {
        const elapsed = std.time.milliTimestamp() - start;
        if (elapsed > timeout_ms) {
            return error.WaitTimeout;
        }

        // Get pod status
        const path = try std.fmt.allocPrint(allocator, "/api/v1/namespaces/{s}/pods/{s}", .{ namespace, name });
        defer allocator.free(path);

        const response = client.request(.GET, path, null) catch |err| {
            std.time.sleep(1 * std.time.ns_per_s);
            continue;
        };
        defer allocator.free(response);

        // Parse response to check status
        const parsed = std.json.parseFromSlice(
            std.json.Value,
            allocator,
            response,
            .{ .ignore_unknown_fields = true },
        ) catch {
            std.time.sleep(1 * std.time.ns_per_s);
            continue;
        };
        defer parsed.deinit();

        // Check if pod is ready
        const status = parsed.value.object.get("status") orelse {
            std.time.sleep(1 * std.time.ns_per_s);
            continue;
        };

        const phase = status.object.get("phase") orelse {
            std.time.sleep(1 * std.time.ns_per_s);
            continue;
        };

        if (std.mem.eql(u8, phase.string, "Running")) {
            std.debug.print("✅ Pod {s} is ready\n", .{name});
            return;
        }

        std.time.sleep(1 * std.time.ns_per_s);
    }
}

/// Assert that a value equals expected
pub fn assertEqual(comptime T: type, actual: T, expected: T, message: []const u8) !void {
    if (actual != expected) {
        std.debug.print("❌ Assertion failed: {s}\n", .{message});
        std.debug.print("   Expected: {any}\n", .{expected});
        std.debug.print("   Actual: {any}\n", .{actual});
        return error.AssertionFailed;
    }
}

/// Assert that a string equals expected
pub fn assertEqualStrings(actual: []const u8, expected: []const u8, message: []const u8) !void {
    if (!std.mem.eql(u8, actual, expected)) {
        std.debug.print("❌ Assertion failed: {s}\n", .{message});
        std.debug.print("   Expected: {s}\n", .{expected});
        std.debug.print("   Actual: {s}\n", .{actual});
        return error.AssertionFailed;
    }
}

/// Assert that an error occurred
pub fn assertError(comptime T: type, result: anytype, expected_error: anyerror, message: []const u8) !void {
    if (result) |_| {
        std.debug.print("❌ Assertion failed: {s}\n", .{message});
        std.debug.print("   Expected error: {s}\n", .{@errorName(expected_error)});
        std.debug.print("   But got success\n", .{});
        return error.AssertionFailed;
    } else |err| {
        if (err != expected_error) {
            std.debug.print("❌ Assertion failed: {s}\n", .{message});
            std.debug.print("   Expected error: {s}\n", .{@errorName(expected_error)});
            std.debug.print("   Actual error: {s}\n", .{@errorName(err)});
            return error.AssertionFailed;
        }
    }
}

/// Initialize test client with proper configuration
pub fn initTestClient(allocator: std.mem.Allocator) !*klient.K8sClient {
    // Load configuration from kubeconfig for rancher-desktop context
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{
            "kubectl",
            "config",
            "view",
            "--minify",
            "--context=rancher-desktop",
            "--output=json",
        },
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    if (result.term.Exited != 0) {
        std.debug.print("❌ Failed to get kubeconfig: {s}\n", .{result.stderr});
        return error.KubeconfigLoadFailed;
    }

    // Parse kubeconfig JSON
    const parsed = try std.json.parseFromSlice(
        std.json.Value,
        allocator,
        result.stdout,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();

    // Extract API server URL
    const clusters = parsed.value.object.get("clusters").?.array;
    const cluster = clusters.items[0].object.get("cluster").?;
    const server = cluster.object.get("server").?.string;

    // Extract token or certificate
    const users = parsed.value.object.get("users").?.array;
    const user = users.items[0].object.get("user").?;

    // Create client
    const client = try allocator.create(klient.K8sClient);
    errdefer allocator.destroy(client);

    // Initialize with token if available
    if (user.object.get("token")) |token_value| {
        client.* = try klient.K8sClient.init(allocator, server, .{
            .token = token_value.string,
            .namespace = "default",
        });
    } else {
        // Try certificate-based auth
        client.* = try klient.K8sClient.init(allocator, server, .{
            .namespace = "default",
        });
    }

    return client;
}

/// Cleanup and destroy test client
pub fn deinitTestClient(client: *klient.K8sClient, allocator: std.mem.Allocator) void {
    client.deinit();
    allocator.destroy(client);
}

/// Test summary for reporting
pub const TestSummary = struct {
    total: usize = 0,
    passed: usize = 0,
    failed: usize = 0,
    skipped: usize = 0,

    pub fn recordPass(self: *TestSummary) void {
        self.total += 1;
        self.passed += 1;
    }

    pub fn recordFail(self: *TestSummary) void {
        self.total += 1;
        self.failed += 1;
    }

    pub fn recordSkip(self: *TestSummary) void {
        self.total += 1;
        self.skipped += 1;
    }

    pub fn print(self: TestSummary, suite_name: []const u8) void {
        std.debug.print("\n{'═':<60}\n", .{});
        std.debug.print("  Test Suite: {s}\n", .{suite_name});
        std.debug.print("{'═':<60}\n", .{});
        std.debug.print("  Total:   {d}\n", .{self.total});
        std.debug.print("  ✅ Passed: {d}\n", .{self.passed});
        std.debug.print("  ❌ Failed: {d}\n", .{self.failed});
        std.debug.print("  ⏭️  Skipped: {d}\n", .{self.skipped});

        if (self.total > 0) {
            const pass_rate = @as(f64, @floatFromInt(self.passed)) / @as(f64, @floatFromInt(self.total)) * 100.0;
            std.debug.print("  Pass Rate: {d:.1}%\n", .{pass_rate});
        }
        std.debug.print("{'═':<60}\n\n", .{});
    }
};
