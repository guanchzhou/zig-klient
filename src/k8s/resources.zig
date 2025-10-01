const std = @import("std");
const K8sClient = @import("client.zig").K8sClient;
const types = @import("types.zig");
const list_opts = @import("list_options.zig");
const apply_mod = @import("apply.zig");
const delete_opts = @import("delete_options.zig");

/// Generic resource operations for any Kubernetes resource
pub fn ResourceClient(comptime T: type) type {
    return struct {
        client: *K8sClient,
        api_path: []const u8, // e.g., "/api/v1" or "/apis/apps/v1"
        resource: []const u8, // e.g., "pods", "deployments"

        const Self = @This();

        /// List resources in a namespace
        /// NOTE: Caller must call deinit() on the returned Parsed object
        pub fn list(self: Self, namespace: ?[]const u8) !std.json.Parsed(types.List(T)) {
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
                .{
                    .ignore_unknown_fields = true,
                    .allocate = .alloc_always,
                },
            );
            return parsed;
        }

        /// List all resources across all namespaces
        /// NOTE: Caller must call deinit() on the returned Parsed object
        pub fn listAll(self: Self) !std.json.Parsed(types.List(T)) {
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
                .{
                    .ignore_unknown_fields = true,
                    .allocate = .alloc_always,
                },
            );
            return parsed;
        }

        /// List resources with options (field/label selectors, pagination, etc.)
        /// NOTE: Caller must call deinit() on the returned Parsed object
        pub fn listWithOptions(self: Self, namespace: ?[]const u8, options: list_opts.ListOptions) !std.json.Parsed(types.List(T)) {
            const ns = namespace orelse self.client.namespace;

            // Build query string from options
            const query_string = try options.buildQueryString(self.client.allocator);
            defer self.client.allocator.free(query_string);

            // Build path with or without query string
            const path = if (query_string.len > 0)
                try std.fmt.allocPrint(
                    self.client.allocator,
                    "{s}/namespaces/{s}/{s}?{s}",
                    .{ self.api_path, ns, self.resource, query_string },
                )
            else
                try std.fmt.allocPrint(
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
                .{
                    .ignore_unknown_fields = true,
                    .allocate = .alloc_always,
                },
            );
            return parsed;
        }

        /// List all resources across all namespaces with options
        /// NOTE: Caller must call deinit() on the returned Parsed object
        pub fn listAllWithOptions(self: Self, options: list_opts.ListOptions) !std.json.Parsed(types.List(T)) {
            // Build query string from options
            const query_string = try options.buildQueryString(self.client.allocator);
            defer self.client.allocator.free(query_string);

            // Build path with or without query string
            const path = if (query_string.len > 0)
                try std.fmt.allocPrint(
                    self.client.allocator,
                    "{s}/{s}?{s}",
                    .{ self.api_path, self.resource, query_string },
                )
            else
                try std.fmt.allocPrint(
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
                .{
                    .ignore_unknown_fields = true,
                    .allocate = .alloc_always,
                },
            );
            return parsed;
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

        /// Create a new resource with options (field manager, field validation, dry-run)
        pub fn createWithOptions(
            self: Self,
            resource: T,
            namespace: ?[]const u8,
            options: delete_opts.CreateOptions,
        ) !T {
            const ns = namespace orelse self.client.namespace;

            // Build query string
            const query_string = try options.buildQueryString(self.client.allocator);
            defer self.client.allocator.free(query_string);

            // Build path with query string
            const path = if (query_string.len > 0)
                try std.fmt.allocPrint(
                    self.client.allocator,
                    "{s}/namespaces/{s}/{s}?{s}",
                    .{ self.api_path, ns, self.resource, query_string },
                )
            else
                try std.fmt.allocPrint(
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

        /// Update an existing resource with options (field manager, field validation, dry-run)
        pub fn updateWithOptions(
            self: Self,
            resource: T,
            namespace: ?[]const u8,
            options: delete_opts.UpdateOptions,
        ) !T {
            const ns = namespace orelse self.client.namespace;

            // Build query string
            const query_string = try options.buildQueryString(self.client.allocator);
            defer self.client.allocator.free(query_string);

            // Build path with query string
            const path = if (query_string.len > 0)
                try std.fmt.allocPrint(
                    self.client.allocator,
                    "{s}/namespaces/{s}/{s}/{s}?{s}",
                    .{ self.api_path, ns, self.resource, resource.metadata.name, query_string },
                )
            else
                try std.fmt.allocPrint(
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

        /// Delete a resource with options (grace period, propagation policy, etc.)
        pub fn deleteWithOptions(
            self: Self,
            name: []const u8,
            namespace: ?[]const u8,
            options: delete_opts.DeleteOptions,
        ) !void {
            const ns = namespace orelse self.client.namespace;

            // Build query string
            const query_string = try options.buildQueryString(self.client.allocator);
            defer self.client.allocator.free(query_string);

            // Build path with query string
            const path = if (query_string.len > 0)
                try std.fmt.allocPrint(
                    self.client.allocator,
                    "{s}/namespaces/{s}/{s}/{s}?{s}",
                    .{ self.api_path, ns, self.resource, name, query_string },
                )
            else
                try std.fmt.allocPrint(
                    self.client.allocator,
                    "{s}/namespaces/{s}/{s}/{s}",
                    .{ self.api_path, ns, self.resource, name },
                );
            defer self.client.allocator.free(path);

            // Build delete options body if we have preconditions
            const delete_body = if (options.preconditions != null)
                try options.buildBody(self.client.allocator)
            else
                null;
            defer if (delete_body) |body| self.client.allocator.free(body);

            const response = try self.client.request(.DELETE, path, delete_body);
            defer self.client.allocator.free(response);
        }

        /// Delete collection of resources matching label/field selectors
        pub fn deleteCollection(
            self: Self,
            namespace: ?[]const u8,
            list_options: list_opts.ListOptions,
            delete_options: delete_opts.DeleteOptions,
        ) !void {
            const ns = namespace orelse self.client.namespace;

            // Build list options query string
            const list_query = try list_options.buildQueryString(self.client.allocator);
            defer self.client.allocator.free(list_query);

            // Build delete options query string
            const delete_query = try delete_options.buildQueryString(self.client.allocator);
            defer self.client.allocator.free(delete_query);

            // Combine query strings
            var combined_query = std.ArrayList(u8).init(self.client.allocator);
            defer combined_query.deinit();

            if (list_query.len > 0) {
                try combined_query.appendSlice(list_query);
            }
            if (delete_query.len > 0) {
                if (combined_query.items.len > 0) {
                    try combined_query.append('&');
                }
                try combined_query.appendSlice(delete_query);
            }

            const query_string = try combined_query.toOwnedSlice();
            defer self.client.allocator.free(query_string);

            // Build path
            const path = if (query_string.len > 0)
                try std.fmt.allocPrint(
                    self.client.allocator,
                    "{s}/namespaces/{s}/{s}?{s}",
                    .{ self.api_path, ns, self.resource, query_string },
                )
            else
                try std.fmt.allocPrint(
                    self.client.allocator,
                    "{s}/namespaces/{s}/{s}",
                    .{ self.api_path, ns, self.resource },
                );
            defer self.client.allocator.free(path);

            const response = try self.client.request(.DELETE, path, null);
            defer self.client.allocator.free(response);
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

        /// Patch a resource with custom content type
        pub fn patchWithType(
            self: Self,
            name: []const u8,
            patch_data: []const u8,
            namespace: ?[]const u8,
            patch_type: apply_mod.PatchType,
        ) !T {
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
                patch_type.contentType(),
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

        /// Server-side apply a resource
        pub fn apply(
            self: Self,
            name: []const u8,
            resource_json: []const u8,
            namespace: ?[]const u8,
            options: apply_mod.ApplyOptions,
        ) !T {
            const ns = namespace orelse self.client.namespace;

            // Build query string
            const query_string = try options.buildQueryString(self.client.allocator);
            defer self.client.allocator.free(query_string);

            // Build path with query string
            const path = try std.fmt.allocPrint(
                self.client.allocator,
                "{s}/namespaces/{s}/{s}/{s}?{s}",
                .{ self.api_path, ns, self.resource, name, query_string },
            );
            defer self.client.allocator.free(path);

            const body = try self.client.requestWithContentType(
                .PATCH,
                path,
                resource_json,
                apply_mod.PatchType.apply.contentType(),
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
    /// NOTE: Caller must call deinit() on the returned Parsed object
    pub fn list(self: Namespaces) !std.json.Parsed(types.List(types.Namespace)) {
        const path = "/api/v1/namespaces";
        const body = try self.client.client.request(.GET, path, null);
        defer self.client.client.allocator.free(body);

        const parsed = try std.json.parseFromSlice(
            types.List(types.Namespace),
            self.client.client.allocator,
            body,
            .{
                .ignore_unknown_fields = true,
                .allocate = .alloc_always,
            },
        );
        return parsed;
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
    /// NOTE: Caller must call deinit() on the returned Parsed object
    pub fn list(self: Nodes) !std.json.Parsed(types.List(types.Node)) {
        const path = "/api/v1/nodes";
        const body = try self.client.client.request(.GET, path, null);
        defer self.client.client.allocator.free(body);

        const parsed = try std.json.parseFromSlice(
            types.List(types.Node),
            self.client.client.allocator,
            body,
            .{
                .ignore_unknown_fields = true,
                .allocate = .alloc_always,
            },
        );
        return parsed;
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
    /// NOTE: Caller must call deinit() on the returned Parsed object
    pub fn list(self: PersistentVolumes) !std.json.Parsed(types.List(types.PersistentVolume)) {
        const path = "/api/v1/persistentvolumes";
        const body = try self.client.client.request(.GET, path, null);
        defer self.client.client.allocator.free(body);

        const parsed = try std.json.parseFromSlice(
            types.List(types.PersistentVolume),
            self.client.client.allocator,
            body,
            .{
                .ignore_unknown_fields = true,
                .allocate = .alloc_always,
            },
        );
        return parsed;
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

pub const Ingresses = struct {
    client: ResourceClient(types.Ingress),

    pub fn init(k8s_client: *K8sClient) Ingresses {
        return .{
            .client = ResourceClient(types.Ingress){
                .client = k8s_client,
                .api_path = "/apis/networking.k8s.io/v1",
                .resource = "ingresses",
            },
        };
    }
};

pub const ServiceAccounts = struct {
    client: ResourceClient(types.ServiceAccount),

    pub fn init(k8s_client: *K8sClient) ServiceAccounts {
        return .{
            .client = ResourceClient(types.ServiceAccount){
                .client = k8s_client,
                .api_path = "/api/v1",
                .resource = "serviceaccounts",
            },
        };
    }
};

pub const Roles = struct {
    client: ResourceClient(types.Role),

    pub fn init(k8s_client: *K8sClient) Roles {
        return .{
            .client = ResourceClient(types.Role){
                .client = k8s_client,
                .api_path = "/apis/rbac.authorization.k8s.io/v1",
                .resource = "roles",
            },
        };
    }
};

pub const RoleBindings = struct {
    client: ResourceClient(types.RoleBinding),

    pub fn init(k8s_client: *K8sClient) RoleBindings {
        return .{
            .client = ResourceClient(types.RoleBinding){
                .client = k8s_client,
                .api_path = "/apis/rbac.authorization.k8s.io/v1",
                .resource = "rolebindings",
            },
        };
    }
};

pub const ClusterRoles = struct {
    client: ResourceClient(types.ClusterRole),

    pub fn init(k8s_client: *K8sClient) ClusterRoles {
        return .{
            .client = ResourceClient(types.ClusterRole){
                .client = k8s_client,
                .api_path = "/apis/rbac.authorization.k8s.io/v1",
                .resource = "clusterroles",
            },
        };
    }

    /// List all ClusterRoles (cluster-scoped)
    /// NOTE: Caller must call deinit() on the returned Parsed object
    pub fn list(self: ClusterRoles) !std.json.Parsed(types.List(types.ClusterRole)) {
        const path = "/apis/rbac.authorization.k8s.io/v1/clusterroles";
        const body = try self.client.client.request(.GET, path, null);
        defer self.client.client.allocator.free(body);

        const parsed = try std.json.parseFromSlice(
            types.List(types.ClusterRole),
            self.client.client.allocator,
            body,
            .{
                .ignore_unknown_fields = true,
                .allocate = .alloc_always,
            },
        );
        return parsed;
    }
};

pub const ClusterRoleBindings = struct {
    client: ResourceClient(types.ClusterRoleBinding),

    pub fn init(k8s_client: *K8sClient) ClusterRoleBindings {
        return .{
            .client = ResourceClient(types.ClusterRoleBinding){
                .client = k8s_client,
                .api_path = "/apis/rbac.authorization.k8s.io/v1",
                .resource = "clusterrolebindings",
            },
        };
    }

    /// List all ClusterRoleBindings (cluster-scoped)
    /// NOTE: Caller must call deinit() on the returned Parsed object
    pub fn list(self: ClusterRoleBindings) !std.json.Parsed(types.List(types.ClusterRoleBinding)) {
        const path = "/apis/rbac.authorization.k8s.io/v1/clusterrolebindings";
        const body = try self.client.client.request(.GET, path, null);
        defer self.client.client.allocator.free(body);

        const parsed = try std.json.parseFromSlice(
            types.List(types.ClusterRoleBinding),
            self.client.client.allocator,
            body,
            .{
                .ignore_unknown_fields = true,
                .allocate = .alloc_always,
            },
        );
        return parsed;
    }
};

pub const NetworkPolicies = struct {
    client: ResourceClient(types.NetworkPolicy),

    pub fn init(k8s_client: *K8sClient) NetworkPolicies {
        return .{
            .client = ResourceClient(types.NetworkPolicy){
                .client = k8s_client,
                .api_path = "/apis/networking.k8s.io/v1",
                .resource = "networkpolicies",
            },
        };
    }
};

pub const HorizontalPodAutoscalers = struct {
    client: ResourceClient(types.HorizontalPodAutoscaler),

    pub fn init(k8s_client: *K8sClient) HorizontalPodAutoscalers {
        return .{
            .client = ResourceClient(types.HorizontalPodAutoscaler){
                .client = k8s_client,
                .api_path = "/apis/autoscaling/v2",
                .resource = "horizontalpodautoscalers",
            },
        };
    }
};

pub const StorageClasses = struct {
    client: ResourceClient(types.StorageClass),

    pub fn init(k8s_client: *K8sClient) StorageClasses {
        return .{
            .client = ResourceClient(types.StorageClass){
                .client = k8s_client,
                .api_path = "/apis/storage.k8s.io/v1",
                .resource = "storageclasses",
            },
        };
    }

    /// List all StorageClasses (cluster-scoped)
    /// NOTE: Caller must call deinit() on the returned Parsed object
    pub fn list(self: StorageClasses) !std.json.Parsed(types.List(types.StorageClass)) {
        const path = "/apis/storage.k8s.io/v1/storageclasses";
        const body = try self.client.client.request(.GET, path, null);
        defer self.client.client.allocator.free(body);

        const parsed = try std.json.parseFromSlice(
            types.List(types.StorageClass),
            self.client.client.allocator,
            body,
            .{
                .ignore_unknown_fields = true,
                .allocate = .alloc_always,
            },
        );
        return parsed;
    }
};

pub const ResourceQuotas = struct {
    client: ResourceClient(types.ResourceQuota),

    pub fn init(k8s_client: *K8sClient) ResourceQuotas {
        return .{
            .client = ResourceClient(types.ResourceQuota){
                .client = k8s_client,
                .api_path = "/api/v1",
                .resource = "resourcequotas",
            },
        };
    }
};

pub const LimitRanges = struct {
    client: ResourceClient(types.LimitRange),

    pub fn init(k8s_client: *K8sClient) LimitRanges {
        return .{
            .client = ResourceClient(types.LimitRange){
                .client = k8s_client,
                .api_path = "/api/v1",
                .resource = "limitranges",
            },
        };
    }
};

pub const PodDisruptionBudgets = struct {
    client: ResourceClient(types.PodDisruptionBudget),

    pub fn init(k8s_client: *K8sClient) PodDisruptionBudgets {
        return .{
            .client = ResourceClient(types.PodDisruptionBudget){
                .client = k8s_client,
                .api_path = "/apis/policy/v1",
                .resource = "poddisruptionbudgets",
            },
        };
    }
};

pub const IngressClasses = struct {
    client: ResourceClient(types.IngressClass),

    pub fn init(k8s_client: *K8sClient) IngressClasses {
        return .{
            .client = ResourceClient(types.IngressClass){
                .client = k8s_client,
                .api_path = "/apis/networking.k8s.io/v1",
                .resource = "ingressclasses",
            },
        };
    }

    /// List all IngressClasses (cluster-scoped)
    /// NOTE: Caller must call deinit() on the returned Parsed object
    pub fn list(self: IngressClasses) !std.json.Parsed(types.List(types.IngressClass)) {
        const path = "/apis/networking.k8s.io/v1/ingressclasses";
        const body = try self.client.client.request(.GET, path, null);
        defer self.client.client.allocator.free(body);

        const parsed = try std.json.parseFromSlice(
            types.List(types.IngressClass),
            self.client.client.allocator,
            body,
            .{
                .ignore_unknown_fields = true,
                .allocate = .alloc_always,
            },
        );
        return parsed;
    }
};

pub const EndpointsClient = struct {
    client: ResourceClient(types.Endpoints),

    pub fn init(k8s_client: *K8sClient) EndpointsClient {
        return .{
            .client = ResourceClient(types.Endpoints){
                .client = k8s_client,
                .api_path = "/api/v1",
                .resource = "endpoints",
            },
        };
    }
};

pub const EndpointSlices = struct {
    client: ResourceClient(types.EndpointSlice),

    pub fn init(k8s_client: *K8sClient) EndpointSlices {
        return .{
            .client = ResourceClient(types.EndpointSlice){
                .client = k8s_client,
                .api_path = "/apis/discovery.k8s.io/v1",
                .resource = "endpointslices",
            },
        };
    }
};

pub const Events = struct {
    client: ResourceClient(types.Event),

    pub fn init(k8s_client: *K8sClient) Events {
        return .{
            .client = ResourceClient(types.Event){
                .client = k8s_client,
                .api_path = "/api/v1",
                .resource = "events",
            },
        };
    }
};

pub const ReplicationControllers = struct {
    client: ResourceClient(types.ReplicationController),

    pub fn init(k8s_client: *K8sClient) ReplicationControllers {
        return .{
            .client = ResourceClient(types.ReplicationController){
                .client = k8s_client,
                .api_path = "/api/v1",
                .resource = "replicationcontrollers",
            },
        };
    }
};

pub const PodTemplates = struct {
    client: ResourceClient(types.PodTemplate),

    pub fn init(k8s_client: *K8sClient) PodTemplates {
        return .{
            .client = ResourceClient(types.PodTemplate){
                .client = k8s_client,
                .api_path = "/api/v1",
                .resource = "podtemplates",
            },
        };
    }
};

pub const ControllerRevisions = struct {
    client: ResourceClient(types.ControllerRevision),

    pub fn init(k8s_client: *K8sClient) ControllerRevisions {
        return .{
            .client = ResourceClient(types.ControllerRevision){
                .client = k8s_client,
                .api_path = "/apis/apps/v1",
                .resource = "controllerrevisions",
            },
        };
    }
};

pub const Leases = struct {
    client: ResourceClient(types.Lease),

    pub fn init(k8s_client: *K8sClient) Leases {
        return .{
            .client = ResourceClient(types.Lease){
                .client = k8s_client,
                .api_path = "/apis/coordination.k8s.io/v1",
                .resource = "leases",
            },
        };
    }
};

pub const PriorityClasses = struct {
    client: ResourceClient(types.PriorityClass),

    pub fn init(k8s_client: *K8sClient) PriorityClasses {
        return .{
            .client = ResourceClient(types.PriorityClass){
                .client = k8s_client,
                .api_path = "/apis/scheduling.k8s.io/v1",
                .resource = "priorityclasses",
            },
        };
    }

    /// List all PriorityClasses (cluster-scoped)
    /// NOTE: Caller must call deinit() on the returned Parsed object
    pub fn list(self: PriorityClasses) !std.json.Parsed(types.List(types.PriorityClass)) {
        const path = "/apis/scheduling.k8s.io/v1/priorityclasses";
        const body = try self.client.client.request(.GET, path, null);
        defer self.client.client.allocator.free(body);

        const parsed = try std.json.parseFromSlice(
            types.List(types.PriorityClass),
            self.client.client.allocator,
            body,
            .{
                .ignore_unknown_fields = true,
                .allocate = .alloc_always,
            },
        );
        return parsed;
    }
};

pub const Bindings = struct {
    client: ResourceClient(types.Binding),

    pub fn init(k8s_client: *K8sClient) Bindings {
        return .{
            .client = ResourceClient(types.Binding){
                .client = k8s_client,
                .api_path = "/api/v1",
                .resource = "bindings",
            },
        };
    }
};

pub const ComponentStatuses = struct {
    client: ResourceClient(types.ComponentStatus),

    pub fn init(k8s_client: *K8sClient) ComponentStatuses {
        return .{
            .client = ResourceClient(types.ComponentStatus){
                .client = k8s_client,
                .api_path = "/api/v1",
                .resource = "componentstatuses",
            },
        };
    }

    /// List all ComponentStatuses (cluster-scoped)
    /// NOTE: Caller must call deinit() on the returned Parsed object
    pub fn list(self: ComponentStatuses) !std.json.Parsed(types.List(types.ComponentStatus)) {
        const path = "/api/v1/componentstatuses";
        const body = try self.client.client.request(.GET, path, null);
        defer self.client.client.allocator.free(body);

        const parsed = try std.json.parseFromSlice(
            types.List(types.ComponentStatus),
            self.client.client.allocator,
            body,
            .{
                .ignore_unknown_fields = true,
                .allocate = .alloc_always,
            },
        );
        return parsed;
    }
};

pub const VolumeAttachments = struct {
    client: ResourceClient(types.VolumeAttachment),

    pub fn init(k8s_client: *K8sClient) VolumeAttachments {
        return .{
            .client = ResourceClient(types.VolumeAttachment){
                .client = k8s_client,
                .api_path = "/apis/storage.k8s.io/v1",
                .resource = "volumeattachments",
            },
        };
    }

    /// List all VolumeAttachments (cluster-scoped)
    /// NOTE: Caller must call deinit() on the returned Parsed object
    pub fn list(self: VolumeAttachments) !std.json.Parsed(types.List(types.VolumeAttachment)) {
        const path = "/apis/storage.k8s.io/v1/volumeattachments";
        const body = try self.client.client.request(.GET, path, null);
        defer self.client.client.allocator.free(body);

        const parsed = try std.json.parseFromSlice(
            types.List(types.VolumeAttachment),
            self.client.client.allocator,
            body,
            .{
                .ignore_unknown_fields = true,
                .allocate = .alloc_always,
            },
        );
        return parsed;
    }
};

pub const CSIDrivers = struct {
    client: ResourceClient(types.CSIDriver),

    pub fn init(k8s_client: *K8sClient) CSIDrivers {
        return .{
            .client = ResourceClient(types.CSIDriver){
                .client = k8s_client,
                .api_path = "/apis/storage.k8s.io/v1",
                .resource = "csidrivers",
            },
        };
    }

    /// List all CSIDrivers (cluster-scoped)
    /// NOTE: Caller must call deinit() on the returned Parsed object
    pub fn list(self: CSIDrivers) !std.json.Parsed(types.List(types.CSIDriver)) {
        const path = "/apis/storage.k8s.io/v1/csidrivers";
        const body = try self.client.client.request(.GET, path, null);
        defer self.client.client.allocator.free(body);

        const parsed = try std.json.parseFromSlice(
            types.List(types.CSIDriver),
            self.client.client.allocator,
            body,
            .{
                .ignore_unknown_fields = true,
                .allocate = .alloc_always,
            },
        );
        return parsed;
    }
};

pub const CSINodes = struct {
    client: ResourceClient(types.CSINode),

    pub fn init(k8s_client: *K8sClient) CSINodes {
        return .{
            .client = ResourceClient(types.CSINode){
                .client = k8s_client,
                .api_path = "/apis/storage.k8s.io/v1",
                .resource = "csinodes",
            },
        };
    }

    /// List all CSINodes (cluster-scoped)
    /// NOTE: Caller must call deinit() on the returned Parsed object
    pub fn list(self: CSINodes) !std.json.Parsed(types.List(types.CSINode)) {
        const path = "/apis/storage.k8s.io/v1/csinodes";
        const body = try self.client.client.request(.GET, path, null);
        defer self.client.client.allocator.free(body);

        const parsed = try std.json.parseFromSlice(
            types.List(types.CSINode),
            self.client.client.allocator,
            body,
            .{
                .ignore_unknown_fields = true,
                .allocate = .alloc_always,
            },
        );
        return parsed;
    }
};

pub const CSIStorageCapacities = struct {
    client: ResourceClient(types.CSIStorageCapacity),

    pub fn init(k8s_client: *K8sClient) CSIStorageCapacities {
        return .{
            .client = ResourceClient(types.CSIStorageCapacity){
                .client = k8s_client,
                .api_path = "/apis/storage.k8s.io/v1",
                .resource = "csistoragecapacities",
            },
        };
    }
};
