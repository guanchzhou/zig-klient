const std = @import("std");
const K8sClient = @import("client.zig").K8sClient;
const discovery = @import("discovery.zig");

/// Default pin. metrics-server through 0.9.x and `master` as of 2026-08-30
/// still registers only v1beta1 (`pkg/api/install.go`; kubernetes-sigs/metrics-server#1786
/// open, #1855 still a draft). A client that hits `/apis/metrics.k8s.io/v1` 404s
/// on real clusters. The apiserver defining v1 in 1.37 does not change that:
/// metrics.k8s.io is an aggregated API.
pub const default_group_version = "metrics.k8s.io/v1beta1";

/// Stable group/version defined by Kubernetes 1.37. Use only when THIS cluster's
/// `/apis` prefers it — `groupVersionFromDiscovery` / `initFromDiscovery`.
pub const stable_group_version = "metrics.k8s.io/v1";

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

/// Client for the Kubernetes Metrics Server API.
///
/// Default pin is v1beta1. `initFromDiscovery` switches to v1 only when the
/// server's `/apis` list prefers it.
pub const MetricsClient = struct {
    client: *K8sClient,
    group_version: []const u8 = default_group_version,

    pub fn init(k8s_client: *K8sClient) MetricsClient {
        return .{ .client = k8s_client };
    }

    /// Pick v1 when `/apis` prefers `metrics.k8s.io/v1`; otherwise stay on v1beta1.
    /// Discovery failure (no metrics-server, forbidden `/apis`) keeps v1beta1.
    pub fn initFromDiscovery(k8s_client: *K8sClient) MetricsClient {
        const d = discovery.Discovery.init(k8s_client);
        const parsed = d.groups() catch return init(k8s_client);
        defer parsed.deinit();
        return .{
            .client = k8s_client,
            .group_version = groupVersionFromDiscovery(parsed.value),
        };
    }

    fn path(self: MetricsClient, allocator: std.mem.Allocator, comptime fmt: []const u8, args: anytype) ![]u8 {
        return std.fmt.allocPrint(allocator, "/apis/{s}/" ++ fmt, .{self.group_version} ++ args);
    }

    /// Get metrics for all nodes
    pub fn getNodeMetrics(self: MetricsClient) !std.json.Parsed(MetricsList(NodeMetrics)) {
        const p = try self.path(self.client.allocator, "nodes", .{});
        defer self.client.allocator.free(p);
        const body = try self.client.request(.GET, p, null);
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
        const p = try self.path(self.client.allocator, "nodes/{s}", .{name});
        defer self.client.allocator.free(p);

        const body = try self.client.request(.GET, p, null);
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
        const p = try self.path(self.client.allocator, "pods", .{});
        defer self.client.allocator.free(p);
        const body = try self.client.request(.GET, p, null);
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
        const p = try self.path(self.client.allocator, "namespaces/{s}/pods", .{namespace});
        defer self.client.allocator.free(p);

        const body = try self.client.request(.GET, p, null);
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
        const p = try self.path(self.client.allocator, "namespaces/{s}/pods/{s}", .{ namespace, name });
        defer self.client.allocator.free(p);

        const body = try self.client.request(.GET, p, null);
        defer self.client.allocator.free(body);

        return try std.json.parseFromSlice(
            PodMetrics,
            self.client.allocator,
            body,
            .{ .ignore_unknown_fields = true, .allocate = .alloc_always },
        );
    }

    /// Parse CPU string to millicores.
    /// Handles: "100m" (millicores), "250000n" (nanocores), "1" (whole cores)
    pub fn parseCpuMillicores(cpu_str: []const u8) ?u64 {
        if (cpu_str.len == 0) return null;

        // Nanocores: "250000000n" → 250 millicores
        if (cpu_str[cpu_str.len - 1] == 'n') {
            const nanos = std.fmt.parseInt(u64, cpu_str[0 .. cpu_str.len - 1], 10) catch return null;
            return nanos / 1_000_000;
        }

        // Millicores: "100m" → 100
        if (cpu_str[cpu_str.len - 1] == 'm') {
            return std.fmt.parseInt(u64, cpu_str[0 .. cpu_str.len - 1], 10) catch null;
        }

        // Whole cores: "2" → 2000
        const cores = std.fmt.parseInt(u64, cpu_str, 10) catch return null;
        return cores * 1000;
    }

    /// Parse memory string to bytes.
    /// Handles binary suffixes (Ki, Mi, Gi, Ti), decimal suffixes (K, M, G, T),
    /// exponent notation (e/E), and plain bytes.
    pub fn parseMemoryBytes(mem_str: []const u8) ?u64 {
        if (mem_str.len == 0) return null;

        // Try binary suffixes first (2-char: Ki, Mi, Gi, Ti)
        if (mem_str.len >= 3) {
            const suffix2 = mem_str[mem_str.len - 2 ..];
            const num2 = mem_str[0 .. mem_str.len - 2];

            const binary_mult: ?u64 = if (std.mem.eql(u8, suffix2, "Ki"))
                1024
            else if (std.mem.eql(u8, suffix2, "Mi"))
                1024 * 1024
            else if (std.mem.eql(u8, suffix2, "Gi"))
                1024 * 1024 * 1024
            else if (std.mem.eql(u8, suffix2, "Ti"))
                1024 * 1024 * 1024 * 1024
            else
                null;

            if (binary_mult) |mult| {
                const value = std.fmt.parseInt(u64, num2, 10) catch return null;
                return value * mult;
            }
        }

        // Try decimal suffixes (1-char: K, M, G, T)
        if (mem_str.len >= 2) {
            const last = mem_str[mem_str.len - 1];
            const num1 = mem_str[0 .. mem_str.len - 1];

            const decimal_mult: ?u64 = switch (last) {
                'K' => 1_000,
                'M' => 1_000_000,
                'G' => 1_000_000_000,
                'T' => 1_000_000_000_000,
                else => null,
            };

            if (decimal_mult) |mult| {
                const value = std.fmt.parseInt(u64, num1, 10) catch return null;
                return value * mult;
            }
        }

        // Plain bytes (no suffix)
        return std.fmt.parseInt(u64, mem_str, 10) catch null;
    }
};

/// Choose the metrics group/version from an already-fetched `/apis` body.
/// v1 only when the server prefers it; otherwise v1beta1 (including "group absent").
pub fn groupVersionFromDiscovery(list: discovery.APIGroupList) []const u8 {
    const ver = discovery.preferredVersionIn(list, "metrics.k8s.io") orelse return default_group_version;
    if (std.mem.eql(u8, ver, "v1")) return stable_group_version;
    return default_group_version;
}

test "parse CPU millicores" {
    try std.testing.expectEqual(@as(?u64, 100), MetricsClient.parseCpuMillicores("100m"));
    try std.testing.expectEqual(@as(?u64, 1000), MetricsClient.parseCpuMillicores("1"));
    try std.testing.expectEqual(@as(?u64, 2500), MetricsClient.parseCpuMillicores("2500m"));
    try std.testing.expectEqual(@as(?u64, 250), MetricsClient.parseCpuMillicores("250000000n"));
    try std.testing.expectEqual(@as(?u64, 0), MetricsClient.parseCpuMillicores("500000n"));
    try std.testing.expectEqual(@as(?u64, null), MetricsClient.parseCpuMillicores(""));
}

test "parse memory bytes" {
    // Binary suffixes (base-1024)
    try std.testing.expectEqual(@as(?u64, 128 * 1024 * 1024), MetricsClient.parseMemoryBytes("128Mi"));
    try std.testing.expectEqual(@as(?u64, 1024 * 1024 * 1024), MetricsClient.parseMemoryBytes("1Gi"));
    try std.testing.expectEqual(@as(?u64, 1024 * 1024), MetricsClient.parseMemoryBytes("1024Ki"));
    // Decimal suffixes (base-1000)
    try std.testing.expectEqual(@as(?u64, 1_000), MetricsClient.parseMemoryBytes("1K"));
    try std.testing.expectEqual(@as(?u64, 500_000_000), MetricsClient.parseMemoryBytes("500M"));
    try std.testing.expectEqual(@as(?u64, 2_000_000_000), MetricsClient.parseMemoryBytes("2G"));
    // Plain bytes
    try std.testing.expectEqual(@as(?u64, 1048576), MetricsClient.parseMemoryBytes("1048576"));
    try std.testing.expectEqual(@as(?u64, null), MetricsClient.parseMemoryBytes(""));
}

test "metrics default pin is v1beta1, not v1" {
    try std.testing.expectEqualStrings("metrics.k8s.io/v1beta1", default_group_version);
    const client = MetricsClient{ .client = undefined };
    try std.testing.expectEqualStrings(default_group_version, client.group_version);
}

test "metrics stays on v1beta1 when that is all the server registers" {
    const parsed = try std.json.parseFromSlice(
        discovery.APIGroupList,
        std.testing.allocator,
        \\{"groups":[{"name":"metrics.k8s.io","versions":[{"groupVersion":"metrics.k8s.io/v1beta1","version":"v1beta1"}]}]}
    ,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();
    try std.testing.expectEqualStrings(default_group_version, groupVersionFromDiscovery(parsed.value));
}

test "metrics uses v1 only when discovery prefers it" {
    const parsed = try std.json.parseFromSlice(
        discovery.APIGroupList,
        std.testing.allocator,
        \\{"groups":[{"name":"metrics.k8s.io","preferredVersion":{"groupVersion":"metrics.k8s.io/v1","version":"v1"},"versions":[{"groupVersion":"metrics.k8s.io/v1","version":"v1"},{"groupVersion":"metrics.k8s.io/v1beta1","version":"v1beta1"}]}]}
    ,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();
    try std.testing.expectEqualStrings(stable_group_version, groupVersionFromDiscovery(parsed.value));
}

test "metrics stays on v1beta1 when the group is absent" {
    const parsed = try std.json.parseFromSlice(
        discovery.APIGroupList,
        std.testing.allocator,
        \\{"groups":[{"name":"apps","versions":[{"groupVersion":"apps/v1","version":"v1"}]}]}
    ,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();
    try std.testing.expectEqualStrings(default_group_version, groupVersionFromDiscovery(parsed.value));
}
