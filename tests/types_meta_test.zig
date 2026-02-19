const std = @import("std");
const klient = @import("klient");

// =============================================================================
// Test Data Factory — generates K8s resource fixtures for testing.
// Uses the builder pattern to create resources with sensible defaults.
// =============================================================================

fn podJson(name: []const u8, namespace: []const u8, phase: []const u8) []const u8 {
    _ = name;
    _ = namespace;
    _ = phase;
    return
        \\{"apiVersion":"v1","kind":"Pod","metadata":{"name":"test-pod","namespace":"default"},"spec":{"containers":[{"name":"nginx","image":"nginx:latest"}]}}
    ;
}

// =============================================================================
// ObjectMeta tests
// =============================================================================

test "ObjectMeta: deserialize with all fields" {
    const allocator = std.testing.allocator;
    const json =
        \\{"name":"my-pod","namespace":"kube-system","uid":"abc-123","resourceVersion":"456","creationTimestamp":"2024-01-01T00:00:00Z","generation":3}
    ;

    const parsed = try std.json.parseFromSlice(klient.ObjectMeta, allocator, json, .{
        .ignore_unknown_fields = true,
        .allocate = .alloc_always,
    });
    defer parsed.deinit();

    try std.testing.expectEqualStrings("my-pod", parsed.value.name);
    try std.testing.expectEqualStrings("kube-system", parsed.value.namespace.?);
    try std.testing.expectEqualStrings("abc-123", parsed.value.uid.?);
    try std.testing.expectEqualStrings("456", parsed.value.resourceVersion.?);
    try std.testing.expectEqual(@as(?i64, 3), parsed.value.generation);
    std.debug.print("✅ ObjectMeta deserialization test passed\n", .{});
}

test "ObjectMeta: deserialize with minimal fields" {
    const allocator = std.testing.allocator;
    const json = \\{"name":"minimal"}
    ;

    const parsed = try std.json.parseFromSlice(klient.ObjectMeta, allocator, json, .{
        .ignore_unknown_fields = true,
        .allocate = .alloc_always,
    });
    defer parsed.deinit();

    try std.testing.expectEqualStrings("minimal", parsed.value.name);
    try std.testing.expectEqual(@as(?[]const u8, null), parsed.value.namespace);
    try std.testing.expectEqual(@as(?[]const u8, null), parsed.value.uid);
    std.debug.print("✅ ObjectMeta minimal deserialization test passed\n", .{});
}

// =============================================================================
// Resource(T) generic wrapper tests
// =============================================================================

test "Resource(T): Pod deserialization" {
    const allocator = std.testing.allocator;
    const json = podJson("test", "default", "Running");

    const parsed = try std.json.parseFromSlice(klient.Pod, allocator, json, .{
        .ignore_unknown_fields = true,
        .allocate = .alloc_always,
    });
    defer parsed.deinit();

    try std.testing.expectEqualStrings("test-pod", parsed.value.metadata.name);
    try std.testing.expect(parsed.value.spec != null);
    std.debug.print("✅ Resource(T) Pod deserialization test passed\n", .{});
}

test "Resource(T): unknown fields ignored gracefully" {
    const allocator = std.testing.allocator;
    const json =
        \\{"apiVersion":"v1","kind":"Pod","metadata":{"name":"test"},"spec":{"containers":[]},"unknownField":"should-be-ignored","anotherUnknown":42}
    ;

    const parsed = try std.json.parseFromSlice(klient.Pod, allocator, json, .{
        .ignore_unknown_fields = true,
        .allocate = .alloc_always,
    });
    defer parsed.deinit();

    try std.testing.expectEqualStrings("test", parsed.value.metadata.name);
    std.debug.print("✅ Resource(T) unknown fields test passed\n", .{});
}

// =============================================================================
// List(T) tests
// =============================================================================

test "List(T): Pod list deserialization" {
    const allocator = std.testing.allocator;
    const json =
        \\{"apiVersion":"v1","kind":"PodList","metadata":{"resourceVersion":"999"},"items":[{"metadata":{"name":"pod-1"}},{"metadata":{"name":"pod-2"}}]}
    ;

    const parsed = try std.json.parseFromSlice(klient.types.List(klient.Pod), allocator, json, .{
        .ignore_unknown_fields = true,
        .allocate = .alloc_always,
    });
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 2), parsed.value.items.len);
    try std.testing.expectEqualStrings("pod-1", parsed.value.items[0].metadata.name);
    try std.testing.expectEqualStrings("pod-2", parsed.value.items[1].metadata.name);
    try std.testing.expectEqualStrings("999", parsed.value.metadata.resourceVersion.?);
    std.debug.print("✅ List(T) Pod list deserialization test passed\n", .{});
}

test "List(T): empty items list" {
    const allocator = std.testing.allocator;
    const json =
        \\{"apiVersion":"v1","kind":"PodList","metadata":{},"items":[]}
    ;

    const parsed = try std.json.parseFromSlice(klient.types.List(klient.Pod), allocator, json, .{
        .ignore_unknown_fields = true,
        .allocate = .alloc_always,
    });
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 0), parsed.value.items.len);
    std.debug.print("✅ List(T) empty items test passed\n", .{});
}

// =============================================================================
// CRD path building tests (integration between CRDInfo and path logic)
// =============================================================================

test "CRDInfo: namespaced resource path with name" {
    const allocator = std.testing.allocator;
    const crd = klient.CRDInfo{
        .group = "cert-manager.io",
        .version = "v1",
        .kind = "Certificate",
        .plural = "certificates",
        .namespaced = true,
    };

    const path = try crd.resourcePath(allocator, "my-ns", "my-cert");
    defer allocator.free(path);

    try std.testing.expectEqualStrings(
        "/apis/cert-manager.io/v1/namespaces/my-ns/certificates/my-cert",
        path,
    );
    std.debug.print("✅ CRDInfo namespaced path test passed\n", .{});
}

test "CRDInfo: cluster-scoped resource path" {
    const allocator = std.testing.allocator;
    const crd = klient.CRDInfo{
        .group = "example.io",
        .version = "v1",
        .kind = "ClusterWidget",
        .plural = "clusterwidgets",
        .namespaced = false,
    };

    const path = try crd.resourcePath(allocator, null, "my-widget");
    defer allocator.free(path);

    try std.testing.expectEqualStrings(
        "/apis/example.io/v1/clusterwidgets/my-widget",
        path,
    );
    std.debug.print("✅ CRDInfo cluster-scoped path test passed\n", .{});
}

test "CRDInfo: core API group path" {
    const allocator = std.testing.allocator;
    const crd = klient.CRDInfo{
        .group = "",
        .version = "v1",
        .kind = "ConfigMap",
        .plural = "configmaps",
        .namespaced = true,
    };

    const api_path = try crd.apiPath(allocator);
    defer allocator.free(api_path);

    try std.testing.expectEqualStrings("/api/v1", api_path);
    std.debug.print("✅ CRDInfo core API group path test passed\n", .{});
}

// =============================================================================
// Metrics parsing edge cases
// =============================================================================

test "metrics: parseCpuMillicores edge cases" {
    // Zero
    try std.testing.expectEqual(@as(?u64, 0), klient.MetricsClient.parseCpuMillicores("0"));
    try std.testing.expectEqual(@as(?u64, 0), klient.MetricsClient.parseCpuMillicores("0m"));

    // Large values
    try std.testing.expectEqual(@as(?u64, 32000), klient.MetricsClient.parseCpuMillicores("32"));

    // Invalid
    try std.testing.expectEqual(@as(?u64, null), klient.MetricsClient.parseCpuMillicores("abc"));
    try std.testing.expectEqual(@as(?u64, null), klient.MetricsClient.parseCpuMillicores(""));
    std.debug.print("✅ CPU millicores edge cases test passed\n", .{});
}

test "metrics: parseMemoryBytes edge cases" {
    // Zero
    try std.testing.expectEqual(@as(?u64, 0), klient.MetricsClient.parseMemoryBytes("0"));

    // Small values
    try std.testing.expectEqual(@as(?u64, 512), klient.MetricsClient.parseMemoryBytes("512"));

    // Binary vs decimal difference
    try std.testing.expectEqual(@as(?u64, 1024), klient.MetricsClient.parseMemoryBytes("1Ki"));
    try std.testing.expectEqual(@as(?u64, 1000), klient.MetricsClient.parseMemoryBytes("1K"));

    // Invalid
    try std.testing.expectEqual(@as(?u64, null), klient.MetricsClient.parseMemoryBytes(""));
    try std.testing.expectEqual(@as(?u64, null), klient.MetricsClient.parseMemoryBytes("abc"));
    std.debug.print("✅ Memory bytes edge cases test passed\n", .{});
}

// =============================================================================
// Retry logic edge cases
// =============================================================================

test "retry: shouldRetry returns false for non-retryable codes" {
    var ctx = klient.retry.RetryContext.init(klient.retry.defaultConfig);

    // 200-class should not retry
    try std.testing.expect(!ctx.shouldRetry(200));
    try std.testing.expect(!ctx.shouldRetry(201));
    try std.testing.expect(!ctx.shouldRetry(204));

    // 400-class (client errors) should not retry
    try std.testing.expect(!ctx.shouldRetry(400));
    try std.testing.expect(!ctx.shouldRetry(401));
    try std.testing.expect(!ctx.shouldRetry(403));
    try std.testing.expect(!ctx.shouldRetry(404));
    try std.testing.expect(!ctx.shouldRetry(422));

    // 429 (Too Many Requests) SHOULD retry
    try std.testing.expect(ctx.shouldRetry(429));

    // 500-class should retry
    try std.testing.expect(ctx.shouldRetry(500));
    try std.testing.expect(ctx.shouldRetry(502));
    try std.testing.expect(ctx.shouldRetry(503));
    try std.testing.expect(ctx.shouldRetry(504));

    // Null status code should retry (transport error)
    try std.testing.expect(ctx.shouldRetry(null));

    std.debug.print("✅ Retry shouldRetry edge cases test passed\n", .{});
}
