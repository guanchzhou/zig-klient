const std = @import("std");
const K8sClient = @import("client.zig").K8sClient;
const types = @import("types.zig");

/// Custom Resource Definition (CRD) metadata
pub const CRDInfo = struct {
    group: []const u8,
    version: []const u8,
    kind: []const u8,
    plural: []const u8,
    namespaced: bool = true,

    /// Get API path for this CRD
    pub fn apiPath(self: CRDInfo, allocator: std.mem.Allocator) ![]const u8 {
        if (std.mem.eql(u8, self.group, "")) {
            return try std.fmt.allocPrint(allocator, "/api/{s}", .{self.version});
        }
        return try std.fmt.allocPrint(allocator, "/apis/{s}/{s}", .{ self.group, self.version });
    }

    /// Get resource path for this CRD
    pub fn resourcePath(self: CRDInfo, allocator: std.mem.Allocator, namespace: ?[]const u8, name: ?[]const u8) ![]const u8 {
        const api = try self.apiPath(allocator);
        defer allocator.free(api);

        if (self.namespaced) {
            const ns = namespace orelse "default";
            if (name) |n| {
                return try std.fmt.allocPrint(allocator, "{s}/namespaces/{s}/{s}/{s}", .{ api, ns, self.plural, n });
            }
            return try std.fmt.allocPrint(allocator, "{s}/namespaces/{s}/{s}", .{ api, ns, self.plural });
        } else {
            if (name) |n| {
                return try std.fmt.allocPrint(allocator, "{s}/{s}/{s}", .{ api, self.plural, n });
            }
            return try std.fmt.allocPrint(allocator, "{s}/{s}", .{ api, self.plural });
        }
    }
};

/// Dynamic client for Custom Resources.
/// All methods returning parsed data return std.json.Parsed — caller must call .deinit().
pub const DynamicClient = struct {
    client: *K8sClient,
    crd_info: CRDInfo,

    const Self = @This();

    pub fn init(client: *K8sClient, crd_info: CRDInfo) Self {
        return .{
            .client = client,
            .crd_info = crd_info,
        };
    }

    fn parseJsonResponse(allocator: std.mem.Allocator, body: []const u8) !std.json.Parsed(std.json.Value) {
        return std.json.parseFromSlice(std.json.Value, allocator, body, .{
            .ignore_unknown_fields = true,
            .allocate = .alloc_always,
        });
    }

    fn serializeValue(allocator: std.mem.Allocator, resource: std.json.Value) ![]const u8 {
        var buf = try std.ArrayList(u8).initCapacity(allocator, 0);
        errdefer buf.deinit(allocator);
        try std.json.stringify(resource, .{}, buf.writer(allocator));
        return try buf.toOwnedSlice(allocator);
    }

    /// List custom resources
    pub fn list(self: Self, namespace: ?[]const u8) !std.json.Parsed(std.json.Value) {
        const allocator = self.client.allocator;
        const path = try self.crd_info.resourcePath(allocator, namespace, null);
        defer allocator.free(path);

        const body = try self.client.request(.GET, path, null);
        defer allocator.free(body);

        return parseJsonResponse(allocator, body);
    }

    /// Get a specific custom resource
    pub fn get(self: Self, name: []const u8, namespace: ?[]const u8) !std.json.Parsed(std.json.Value) {
        const allocator = self.client.allocator;
        const path = try self.crd_info.resourcePath(allocator, namespace, name);
        defer allocator.free(path);

        const body = try self.client.request(.GET, path, null);
        defer allocator.free(body);

        return parseJsonResponse(allocator, body);
    }

    /// Create a custom resource
    pub fn create(self: Self, resource: std.json.Value, namespace: ?[]const u8) !std.json.Parsed(std.json.Value) {
        const allocator = self.client.allocator;
        const path = try self.crd_info.resourcePath(allocator, namespace, null);
        defer allocator.free(path);

        const json_body = try serializeValue(allocator, resource);
        defer allocator.free(json_body);

        const body = try self.client.request(.POST, path, json_body);
        defer allocator.free(body);

        return parseJsonResponse(allocator, body);
    }

    /// Update a custom resource
    pub fn update(self: Self, name: []const u8, resource: std.json.Value, namespace: ?[]const u8) !std.json.Parsed(std.json.Value) {
        const allocator = self.client.allocator;
        const path = try self.crd_info.resourcePath(allocator, namespace, name);
        defer allocator.free(path);

        const json_body = try serializeValue(allocator, resource);
        defer allocator.free(json_body);

        const body = try self.client.request(.PUT, path, json_body);
        defer allocator.free(body);

        return parseJsonResponse(allocator, body);
    }

    /// Delete a custom resource
    pub fn delete(self: Self, name: []const u8, namespace: ?[]const u8) !void {
        const allocator = self.client.allocator;
        const path = try self.crd_info.resourcePath(allocator, namespace, name);
        defer allocator.free(path);

        const body = try self.client.request(.DELETE, path, null);
        defer allocator.free(body);
    }

    /// Patch a custom resource
    pub fn patch(self: Self, name: []const u8, patch_data: []const u8, namespace: ?[]const u8) !std.json.Parsed(std.json.Value) {
        const allocator = self.client.allocator;
        const path = try self.crd_info.resourcePath(allocator, namespace, name);
        defer allocator.free(path);

        const body = try self.client.requestWithContentType(
            .PATCH,
            path,
            patch_data,
            "application/strategic-merge-patch+json",
        );
        defer allocator.free(body);

        return parseJsonResponse(allocator, body);
    }
};

/// Common CRD examples

/// Cert-Manager Certificate CRD
pub const CertManagerCertificate = CRDInfo{
    .group = "cert-manager.io",
    .version = "v1",
    .kind = "Certificate",
    .plural = "certificates",
    .namespaced = true,
};

/// Istio VirtualService CRD
pub const IstioVirtualService = CRDInfo{
    .group = "networking.istio.io",
    .version = "v1beta1",
    .kind = "VirtualService",
    .plural = "virtualservices",
    .namespaced = true,
};

/// Prometheus ServiceMonitor CRD
pub const PrometheusServiceMonitor = CRDInfo{
    .group = "monitoring.coreos.com",
    .version = "v1",
    .kind = "ServiceMonitor",
    .plural = "servicemonitors",
    .namespaced = true,
};

/// Argo Rollout CRD
pub const ArgoRollout = CRDInfo{
    .group = "argoproj.io",
    .version = "v1alpha1",
    .kind = "Rollout",
    .plural = "rollouts",
    .namespaced = true,
};

/// Knative Service CRD
pub const KnativeService = CRDInfo{
    .group = "serving.knative.dev",
    .version = "v1",
    .kind = "Service",
    .plural = "services",
    .namespaced = true,
};
