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

/// Dynamic client for Custom Resources
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
    
    /// List custom resources
    pub fn list(self: Self, namespace: ?[]const u8) !std.json.Value {
        const path = try self.crd_info.resourcePath(self.client.allocator, namespace, null);
        defer self.client.allocator.free(path);
        
        const body = try self.client.request(.GET, path, null);
        defer self.client.allocator.free(body);
        
        const parsed = try std.json.parseFromSlice(
            std.json.Value,
            self.client.allocator,
            body,
            .{ .ignore_unknown_fields = true },
        );
        
        return parsed.value;
    }
    
    /// Get a specific custom resource
    pub fn get(self: Self, name: []const u8, namespace: ?[]const u8) !std.json.Value {
        const path = try self.crd_info.resourcePath(self.client.allocator, namespace, name);
        defer self.client.allocator.free(path);
        
        const body = try self.client.request(.GET, path, null);
        defer self.client.allocator.free(body);
        
        const parsed = try std.json.parseFromSlice(
            std.json.Value,
            self.client.allocator,
            body,
            .{ .ignore_unknown_fields = true },
        );
        
        return parsed.value;
    }
    
    /// Create a custom resource
    pub fn create(self: Self, resource: std.json.Value, namespace: ?[]const u8) !std.json.Value {
        const path = try self.crd_info.resourcePath(self.client.allocator, namespace, null);
        defer self.client.allocator.free(path);
        
        // Serialize resource to JSON
        var json_buffer = std.ArrayList(u8).init(self.client.allocator);
        defer json_buffer.deinit();
        
        try std.json.stringify(resource, .{}, json_buffer.writer());
        
        const body = try self.client.request(.POST, path, json_buffer.items);
        defer self.client.allocator.free(body);
        
        const parsed = try std.json.parseFromSlice(
            std.json.Value,
            self.client.allocator,
            body,
            .{ .ignore_unknown_fields = true },
        );
        
        return parsed.value;
    }
    
    /// Update a custom resource
    pub fn update(self: Self, name: []const u8, resource: std.json.Value, namespace: ?[]const u8) !std.json.Value {
        const path = try self.crd_info.resourcePath(self.client.allocator, namespace, name);
        defer self.client.allocator.free(path);
        
        // Serialize resource to JSON
        var json_buffer = std.ArrayList(u8).init(self.client.allocator);
        defer json_buffer.deinit();
        
        try std.json.stringify(resource, .{}, json_buffer.writer());
        
        const body = try self.client.request(.PUT, path, json_buffer.items);
        defer self.client.allocator.free(body);
        
        const parsed = try std.json.parseFromSlice(
            std.json.Value,
            self.client.allocator,
            body,
            .{ .ignore_unknown_fields = true },
        );
        
        return parsed.value;
    }
    
    /// Delete a custom resource
    pub fn delete(self: Self, name: []const u8, namespace: ?[]const u8) !void {
        const path = try self.crd_info.resourcePath(self.client.allocator, namespace, name);
        defer self.client.allocator.free(path);
        
        const body = try self.client.request(.DELETE, path, null);
        defer self.client.allocator.free(body);
    }
    
    /// Patch a custom resource
    pub fn patch(self: Self, name: []const u8, patch_data: []const u8, namespace: ?[]const u8) !std.json.Value {
        const path = try self.crd_info.resourcePath(self.client.allocator, namespace, name);
        defer self.client.allocator.free(path);
        
        const body = try self.client.requestWithContentType(
            .PATCH,
            path,
            patch_data,
            "application/strategic-merge-patch+json",
        );
        defer self.client.allocator.free(body);
        
        const parsed = try std.json.parseFromSlice(
            std.json.Value,
            self.client.allocator,
            body,
            .{ .ignore_unknown_fields = true },
        );
        
        return parsed.value;
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
