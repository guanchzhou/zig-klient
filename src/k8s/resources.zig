const std = @import("std");
const K8sClient = @import("client.zig").K8sClient;
const types = @import("types.zig");

/// Generic resource operations for any Kubernetes resource
pub fn ResourceClient(comptime T: type) type {
    return struct {
        client: *K8sClient,
        api_path: []const u8, // e.g., "/api/v1" or "/apis/apps/v1"
        resource: []const u8, // e.g., "pods", "deployments"
        
        const Self = @This();
        
        /// List resources in a namespace
        pub fn list(self: Self, namespace: ?[]const u8) !types.List(T) {
            const ns = namespace orelse self.client.namespace;
            const path = try std.fmt.allocPrint(
                self.client.allocator,
                "{s}/namespaces/{s}/{s}",
                .{ self.api_path, ns, self.resource },
            );
            defer self.client.allocator.free(path);
            
            const body = try self.client.request(.GET, path, null);
            defer self.client.allocator.free(body);
            
            const parsed = try std.json.parseFromSlice(
                types.List(T),
                self.client.allocator,
                body,
                .{ .ignore_unknown_fields = true },
            );
            return parsed.value;
        }
        
        /// List all resources across all namespaces
        pub fn listAll(self: Self) !types.List(T) {
            const path = try std.fmt.allocPrint(
                self.client.allocator,
                "{s}/{s}",
                .{ self.api_path, self.resource },
            );
            defer self.client.allocator.free(path);
            
            const body = try self.client.request(.GET, path, null);
            defer self.client.allocator.free(body);
            
            const parsed = try std.json.parseFromSlice(
                types.List(T),
                self.client.allocator,
                body,
                .{ .ignore_unknown_fields = true },
            );
            return parsed.value;
        }
        
        /// Get a specific resource by name
        pub fn get(self: Self, name: []const u8, namespace: ?[]const u8) !T {
            const ns = namespace orelse self.client.namespace;
            const path = try std.fmt.allocPrint(
                self.client.allocator,
                "{s}/namespaces/{s}/{s}/{s}",
                .{ self.api_path, ns, self.resource, name },
            );
            defer self.client.allocator.free(path);
            
            const body = try self.client.request(.GET, path, null);
            defer self.client.allocator.free(body);
            
            const parsed = try std.json.parseFromSlice(
                T,
                self.client.allocator,
                body,
                .{ .ignore_unknown_fields = true },
            );
            return parsed.value;
        }
        
        /// Create a new resource
        pub fn create(self: Self, resource: T, namespace: ?[]const u8) !T {
            const ns = namespace orelse self.client.namespace;
            const path = try std.fmt.allocPrint(
                self.client.allocator,
                "{s}/namespaces/{s}/{s}",
                .{ self.api_path, ns, self.resource },
            );
            defer self.client.allocator.free(path);
            
            // Serialize resource to JSON
            var json_buffer = std.ArrayList(u8).init(self.client.allocator);
            defer json_buffer.deinit();
            
            try std.json.stringify(resource, .{}, json_buffer.writer());
            
            const body = try self.client.request(.POST, path, json_buffer.items);
            defer self.client.allocator.free(body);
            
            const parsed = try std.json.parseFromSlice(
                T,
                self.client.allocator,
                body,
                .{ .ignore_unknown_fields = true },
            );
            return parsed.value;
        }
        
        /// Update an existing resource (replace)
        pub fn update(self: Self, resource: T, namespace: ?[]const u8) !T {
            const ns = namespace orelse self.client.namespace;
            const path = try std.fmt.allocPrint(
                self.client.allocator,
                "{s}/namespaces/{s}/{s}/{s}",
                .{ self.api_path, ns, self.resource, resource.metadata.name },
            );
            defer self.client.allocator.free(path);
            
            // Serialize resource to JSON
            var json_buffer = std.ArrayList(u8).init(self.client.allocator);
            defer json_buffer.deinit();
            
            try std.json.stringify(resource, .{}, json_buffer.writer());
            
            const body = try self.client.request(.PUT, path, json_buffer.items);
            defer self.client.allocator.free(body);
            
            const parsed = try std.json.parseFromSlice(
                T,
                self.client.allocator,
                body,
                .{ .ignore_unknown_fields = true },
            );
            return parsed.value;
        }
        
        /// Delete a resource
        pub fn delete(self: Self, name: []const u8, namespace: ?[]const u8) !void {
            const ns = namespace orelse self.client.namespace;
            const path = try std.fmt.allocPrint(
                self.client.allocator,
                "{s}/namespaces/{s}/{s}/{s}",
                .{ self.api_path, ns, self.resource, name },
            );
            defer self.client.allocator.free(path);
            
            const body = try self.client.request(.DELETE, path, null);
            defer self.client.allocator.free(body);
        }
        
        /// Patch a resource (strategic merge patch)
        pub fn patch(self: Self, name: []const u8, patch_data: []const u8, namespace: ?[]const u8) !T {
            const ns = namespace orelse self.client.namespace;
            const path = try std.fmt.allocPrint(
                self.client.allocator,
                "{s}/namespaces/{s}/{s}/{s}",
                .{ self.api_path, ns, self.resource, name },
            );
            defer self.client.allocator.free(path);
            
            const body = try self.client.requestWithContentType(
                .PATCH,
                path,
                patch_data,
                "application/strategic-merge-patch+json",
            );
            defer self.client.allocator.free(body);
            
            const parsed = try std.json.parseFromSlice(
                T,
                self.client.allocator,
                body,
                .{ .ignore_unknown_fields = true },
            );
            return parsed.value;
        }
    };
}

/// Convenience methods for common resources
pub const Pods = struct {
    client: ResourceClient(types.Pod),
    
    pub fn init(k8s_client: *K8sClient) Pods {
        return .{
            .client = ResourceClient(types.Pod){
                .client = k8s_client,
                .api_path = "/api/v1",
                .resource = "pods",
            },
        };
    }
    
    /// Get pod logs
    pub fn logs(self: Pods, name: []const u8, namespace: ?[]const u8) ![]const u8 {
        const ns = namespace orelse self.client.client.namespace;
        const path = try std.fmt.allocPrint(
            self.client.client.allocator,
            "/api/v1/namespaces/{s}/pods/{s}/log",
            .{ ns, name },
        );
        defer self.client.client.allocator.free(path);
        
        return try self.client.client.request(.GET, path, null);
    }
};

pub const Deployments = struct {
    client: ResourceClient(types.Deployment),
    
    pub fn init(k8s_client: *K8sClient) Deployments {
        return .{
            .client = ResourceClient(types.Deployment){
                .client = k8s_client,
                .api_path = "/apis/apps/v1",
                .resource = "deployments",
            },
        };
    }
    
    /// Scale a deployment
    pub fn scale(self: Deployments, name: []const u8, replicas: i32, namespace: ?[]const u8) !void {
        const patch_json = try std.fmt.allocPrint(
            self.client.client.allocator,
            "{{\"spec\":{{\"replicas\":{d}}}}}",
            .{replicas},
        );
        defer self.client.client.allocator.free(patch_json);
        
        _ = try self.client.patch(name, patch_json, namespace);
    }
};

pub const Services = struct {
    client: ResourceClient(types.Service),
    
    pub fn init(k8s_client: *K8sClient) Services {
        return .{
            .client = ResourceClient(types.Service){
                .client = k8s_client,
                .api_path = "/api/v1",
                .resource = "services",
            },
        };
    }
};

pub const ConfigMaps = struct {
    client: ResourceClient(types.ConfigMap),
    
    pub fn init(k8s_client: *K8sClient) ConfigMaps {
        return .{
            .client = ResourceClient(types.ConfigMap){
                .client = k8s_client,
                .api_path = "/api/v1",
                .resource = "configmaps",
            },
        };
    }
};

pub const Secrets = struct {
    client: ResourceClient(types.Secret),
    
    pub fn init(k8s_client: *K8sClient) Secrets {
        return .{
            .client = ResourceClient(types.Secret){
                .client = k8s_client,
                .api_path = "/api/v1",
                .resource = "secrets",
            },
        };
    }
};

pub const Namespaces = struct {
    client: ResourceClient(types.Namespace),
    
    pub fn init(k8s_client: *K8sClient) Namespaces {
        return .{
            .client = ResourceClient(types.Namespace){
                .client = k8s_client,
                .api_path = "/api/v1",
                .resource = "namespaces",
            },
        };
    }
    
    /// List all namespaces (cluster-scoped)
    pub fn list(self: Namespaces) !types.List(types.Namespace) {
        const path = "/api/v1/namespaces";
        const body = try self.client.client.request(.GET, path, null);
        defer self.client.client.allocator.free(body);
        
        const parsed = try std.json.parseFromSlice(
            types.List(types.Namespace),
            self.client.client.allocator,
            body,
            .{ .ignore_unknown_fields = true },
        );
        return parsed.value;
    }
};

pub const Nodes = struct {
    client: ResourceClient(types.Node),
    
    pub fn init(k8s_client: *K8sClient) Nodes {
        return .{
            .client = ResourceClient(types.Node){
                .client = k8s_client,
                .api_path = "/api/v1",
                .resource = "nodes",
            },
        };
    }
    
    /// List all nodes (cluster-scoped)
    pub fn list(self: Nodes) !types.List(types.Node) {
        const path = "/api/v1/nodes";
        const body = try self.client.client.request(.GET, path, null);
        defer self.client.client.allocator.free(body);
        
        const parsed = try std.json.parseFromSlice(
            types.List(types.Node),
            self.client.client.allocator,
            body,
            .{ .ignore_unknown_fields = true },
        );
        return parsed.value;
    }
};

pub const ReplicaSets = struct {
    client: ResourceClient(types.ReplicaSet),
    
    pub fn init(k8s_client: *K8sClient) ReplicaSets {
        return .{
            .client = ResourceClient(types.ReplicaSet){
                .client = k8s_client,
                .api_path = "/apis/apps/v1",
                .resource = "replicasets",
            },
        };
    }
    
    /// Scale a replicaset
    pub fn scale(self: ReplicaSets, name: []const u8, replicas: i32, namespace: ?[]const u8) !void {
        const patch_json = try std.fmt.allocPrint(
            self.client.client.allocator,
            "{{\"spec\":{{\"replicas\":{d}}}}}",
            .{replicas},
        );
        defer self.client.client.allocator.free(patch_json);
        
        _ = try self.client.patch(name, patch_json, namespace);
    }
};

pub const StatefulSets = struct {
    client: ResourceClient(types.StatefulSet),
    
    pub fn init(k8s_client: *K8sClient) StatefulSets {
        return .{
            .client = ResourceClient(types.StatefulSet){
                .client = k8s_client,
                .api_path = "/apis/apps/v1",
                .resource = "statefulsets",
            },
        };
    }
    
    /// Scale a statefulset
    pub fn scale(self: StatefulSets, name: []const u8, replicas: i32, namespace: ?[]const u8) !void {
        const patch_json = try std.fmt.allocPrint(
            self.client.client.allocator,
            "{{\"spec\":{{\"replicas\":{d}}}}}",
            .{replicas},
        );
        defer self.client.client.allocator.free(patch_json);
        
        _ = try self.client.patch(name, patch_json, namespace);
    }
};

pub const DaemonSets = struct {
    client: ResourceClient(types.DaemonSet),
    
    pub fn init(k8s_client: *K8sClient) DaemonSets {
        return .{
            .client = ResourceClient(types.DaemonSet){
                .client = k8s_client,
                .api_path = "/apis/apps/v1",
                .resource = "daemonsets",
            },
        };
    }
};

pub const Jobs = struct {
    client: ResourceClient(types.Job),
    
    pub fn init(k8s_client: *K8sClient) Jobs {
        return .{
            .client = ResourceClient(types.Job){
                .client = k8s_client,
                .api_path = "/apis/batch/v1",
                .resource = "jobs",
            },
        };
    }
};

pub const CronJobs = struct {
    client: ResourceClient(types.CronJob),
    
    pub fn init(k8s_client: *K8sClient) CronJobs {
        return .{
            .client = ResourceClient(types.CronJob){
                .client = k8s_client,
                .api_path = "/apis/batch/v1",
                .resource = "cronjobs",
            },
        };
    }
    
    /// Suspend/resume a cronjob
    pub fn setSuspend(self: CronJobs, name: []const u8, should_suspend: bool, namespace: ?[]const u8) !void {
        const patch_json = try std.fmt.allocPrint(
            self.client.client.allocator,
            "{{\"spec\":{{\"suspend\":{s}}}}}",
            .{if (should_suspend) "true" else "false"},
        );
        defer self.client.client.allocator.free(patch_json);
        
        _ = try self.client.patch(name, patch_json, namespace);
    }
};

pub const PersistentVolumes = struct {
    client: ResourceClient(types.PersistentVolume),
    
    pub fn init(k8s_client: *K8sClient) PersistentVolumes {
        return .{
            .client = ResourceClient(types.PersistentVolume){
                .client = k8s_client,
                .api_path = "/api/v1",
                .resource = "persistentvolumes",
            },
        };
    }
    
    /// List all PVs (cluster-scoped)
    pub fn list(self: PersistentVolumes) !types.List(types.PersistentVolume) {
        const path = "/api/v1/persistentvolumes";
        const body = try self.client.client.request(.GET, path, null);
        defer self.client.client.allocator.free(body);
        
        const parsed = try std.json.parseFromSlice(
            types.List(types.PersistentVolume),
            self.client.client.allocator,
            body,
            .{ .ignore_unknown_fields = true },
        );
        return parsed.value;
    }
};

pub const PersistentVolumeClaims = struct {
    client: ResourceClient(types.PersistentVolumeClaim),
    
    pub fn init(k8s_client: *K8sClient) PersistentVolumeClaims {
        return .{
            .client = ResourceClient(types.PersistentVolumeClaim){
                .client = k8s_client,
                .api_path = "/api/v1",
                .resource = "persistentvolumeclaims",
            },
        };
    }
};
