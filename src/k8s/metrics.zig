const std = @import("std");
const K8sClient = @import("client.zig").K8sClient;

/// Pod metrics from metrics.k8s.io/v1beta1
pub const PodMetrics = struct {
    metadata: struct {
        name: []const u8,
        namespace: ?[]const u8 = null,
        creationTimestamp: ?[]const u8 = null,
    },
    timestamp: ?[]const u8 = null,
    window: ?[]const u8 = null,
    containers: ?[]ContainerMetrics = null,
};

/// Container-level resource metrics
pub const ContainerMetrics = struct {
    name: []const u8,
    usage: ResourceUsage,
};

/// Resource usage values (CPU in cores/millicores, memory in bytes)
pub const ResourceUsage = struct {
    cpu: ?[]const u8 = null,
    memory: ?[]const u8 = null,
};

/// Node metrics from metrics.k8s.io/v1beta1
pub const NodeMetrics = struct {
    metadata: struct {
        name: []const u8,
        creationTimestamp: ?[]const u8 = null,
    },
    timestamp: ?[]const u8 = null,
    window: ?[]const u8 = null,
    usage: ResourceUsage,
};

/// Metrics list wrapper
pub fn MetricsList(comptime T: type) type {
    return struct {
        apiVersion: []const u8,
        kind: []const u8,
        items: []T,
        metadata: struct {
            resourceVersion: ?[]const u8 = null,
        },
    };
}

/// Client for Kubernetes Metrics Server API (metrics.k8s.io/v1beta1)
pub const MetricsClient = struct {
    client: *K8sClient,

    pub fn init(k8s_client: *K8sClient) MetricsClient {
        return .{ .client = k8s_client };
    }

    /// Get metrics for all nodes
    pub fn getNodeMetrics(self: MetricsClient) !std.json.Parsed(MetricsList(NodeMetrics)) {
        const body = try self.client.request(.GET, "/apis/metrics.k8s.io/v1beta1/nodes", null);
        defer self.client.allocator.free(body);

        return try std.json.parseFromSlice(
            MetricsList(NodeMetrics),
            self.client.allocator,
            body,
            .{ .ignore_unknown_fields = true, .allocate = .alloc_always },
        );
    }

    /// Get metrics for a specific node
    pub fn getNodeMetricsByName(self: MetricsClient, name: []const u8) !std.json.Parsed(NodeMetrics) {
        const path = try std.fmt.allocPrint(
            self.client.allocator,
            "/apis/metrics.k8s.io/v1beta1/nodes/{s}",
            .{name},
        );
        defer self.client.allocator.free(path);

        const body = try self.client.request(.GET, path, null);
        defer self.client.allocator.free(body);

        return try std.json.parseFromSlice(
            NodeMetrics,
            self.client.allocator,
            body,
            .{ .ignore_unknown_fields = true, .allocate = .alloc_always },
        );
    }

    /// Get metrics for all pods across all namespaces
    pub fn getAllPodMetrics(self: MetricsClient) !std.json.Parsed(MetricsList(PodMetrics)) {
        const body = try self.client.request(.GET, "/apis/metrics.k8s.io/v1beta1/pods", null);
        defer self.client.allocator.free(body);

        return try std.json.parseFromSlice(
            MetricsList(PodMetrics),
            self.client.allocator,
            body,
            .{ .ignore_unknown_fields = true, .allocate = .alloc_always },
        );
    }

    /// Get metrics for all pods in a namespace
    pub fn getPodMetrics(self: MetricsClient, namespace: []const u8) !std.json.Parsed(MetricsList(PodMetrics)) {
        const path = try std.fmt.allocPrint(
            self.client.allocator,
            "/apis/metrics.k8s.io/v1beta1/namespaces/{s}/pods",
            .{namespace},
        );
        defer self.client.allocator.free(path);

        const body = try self.client.request(.GET, path, null);
        defer self.client.allocator.free(body);

        return try std.json.parseFromSlice(
            MetricsList(PodMetrics),
            self.client.allocator,
            body,
            .{ .ignore_unknown_fields = true, .allocate = .alloc_always },
        );
    }

    /// Get metrics for a specific pod
    pub fn getPodMetricsByName(self: MetricsClient, name: []const u8, namespace: []const u8) !std.json.Parsed(PodMetrics) {
        const path = try std.fmt.allocPrint(
            self.client.allocator,
            "/apis/metrics.k8s.io/v1beta1/namespaces/{s}/pods/{s}",
            .{ namespace, name },
        );
        defer self.client.allocator.free(path);

        const body = try self.client.request(.GET, path, null);
        defer self.client.allocator.free(body);

        return try std.json.parseFromSlice(
            PodMetrics,
            self.client.allocator,
            body,
            .{ .ignore_unknown_fields = true, .allocate = .alloc_always },
        );
    }

    /// Parse CPU string (e.g., "100m", "1", "2500m") to millicores
    pub fn parseCpuMillicores(cpu_str: []const u8) ?u64 {
        if (cpu_str.len == 0) return null;
        if (cpu_str[cpu_str.len - 1] == 'm') {
            return std.fmt.parseInt(u64, cpu_str[0 .. cpu_str.len - 1], 10) catch null;
        }
        // Whole cores -> millicores
        const cores = std.fmt.parseInt(u64, cpu_str, 10) catch return null;
        return cores * 1000;
    }

    /// Parse memory string (e.g., "128Mi", "1Gi", "1048576Ki") to bytes
    pub fn parseMemoryBytes(mem_str: []const u8) ?u64 {
        if (mem_str.len < 2) return null;
        const suffix = mem_str[mem_str.len - 2 ..];
        const num_str = mem_str[0 .. mem_str.len - 2];

        const multiplier: u64 = if (std.mem.eql(u8, suffix, "Ki"))
            1024
        else if (std.mem.eql(u8, suffix, "Mi"))
            1024 * 1024
        else if (std.mem.eql(u8, suffix, "Gi"))
            1024 * 1024 * 1024
        else if (std.mem.eql(u8, suffix, "Ti"))
            1024 * 1024 * 1024 * 1024
        else
            return std.fmt.parseInt(u64, mem_str, 10) catch null;

        const value = std.fmt.parseInt(u64, num_str, 10) catch return null;
        return value * multiplier;
    }
};

test "parse CPU millicores" {
    try std.testing.expectEqual(@as(?u64, 100), MetricsClient.parseCpuMillicores("100m"));
    try std.testing.expectEqual(@as(?u64, 1000), MetricsClient.parseCpuMillicores("1"));
    try std.testing.expectEqual(@as(?u64, 2500), MetricsClient.parseCpuMillicores("2500m"));
    std.debug.print("✅ CPU millicores parsing test passed\n", .{});
}

test "parse memory bytes" {
    try std.testing.expectEqual(@as(?u64, 128 * 1024 * 1024), MetricsClient.parseMemoryBytes("128Mi"));
    try std.testing.expectEqual(@as(?u64, 1024 * 1024 * 1024), MetricsClient.parseMemoryBytes("1Gi"));
    try std.testing.expectEqual(@as(?u64, 1024 * 1024), MetricsClient.parseMemoryBytes("1024Ki"));
    std.debug.print("✅ Memory bytes parsing test passed\n", .{});
}
