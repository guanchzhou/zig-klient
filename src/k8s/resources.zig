const std = @import("std");
const K8sClient = @import("client.zig").K8sClient;
const types = @import("types.zig");
const list_opts = @import("list_options.zig");
const apply_mod = @import("apply.zig");
const delete_opts = @import("delete_options.zig");
const registry = @import("resource_registry.zig");
const QueryWriter = @import("query.zig").QueryWriter;

/// Scope-aware generic resource operations for any Kubernetes resource.
///
/// Path building respects cluster-scoped vs namespaced resources automatically
/// via the `is_cluster_scoped` field. For registered types, use
/// `SimpleResource(T)` or the `initFromRegistry` constructor which sets this
/// automatically from the resource registry.
pub fn ResourceClient(comptime T: type) type {
    return struct {
        client: *K8sClient,
        api_path: []const u8, // e.g., "/api/v1" or "/apis/apps/v1"
        resource: []const u8, // e.g., "pods", "deployments"
        is_cluster_scoped: bool = false,

        const Self = @This();

        /// Initialize from the resource registry (auto-configures api_path, resource, scope).
        pub fn initFromRegistry(k8s_client: *K8sClient) Self {
            const meta = comptime registry.metaFor(T);
            return .{
                .client = k8s_client,
                .api_path = meta.api_path,
                .resource = meta.resource_name,
                .is_cluster_scoped = meta.scope == .cluster,
            };
        }

        // --- Internal helpers ---

        /// Parse a K8s API JSON response into a typed Parsed(R).
        /// Uses .ignore_unknown_fields for forward compatibility with
        /// newer K8s API versions that may add fields.
        fn parseResponse(comptime R: type, allocator: std.mem.Allocator, body: []const u8) !std.json.Parsed(R) {
            return std.json.parseFromSlice(R, allocator, body, .{
                .ignore_unknown_fields = true,
                .allocate = .alloc_always,
            });
        }

        /// Serialize a Zig value to a JSON byte slice. Caller must free the result.
        fn serializeJson(allocator: std.mem.Allocator, value: anytype) ![]const u8 {
            var buf = try std.ArrayList(u8).initCapacity(allocator, 0);
            errdefer buf.deinit(allocator);
            try std.json.stringify(value, .{}, buf.writer(allocator));
            return try buf.toOwnedSlice(allocator);
        }

        fn buildCollectionPath(self: Self, namespace: ?[]const u8) ![]const u8 {
            const allocator = self.client.allocator;
            if (self.is_cluster_scoped) {
                return std.fmt.allocPrint(allocator, "{s}/{s}", .{
                    self.api_path,
                    self.resource,
                });
            }
            return std.fmt.allocPrint(allocator, "{s}/namespaces/{s}/{s}", .{
                self.api_path,
                namespace orelse self.client.namespace,
                self.resource,
            });
        }

        fn buildResourcePath(self: Self, name: []const u8, namespace: ?[]const u8) ![]const u8 {
            const allocator = self.client.allocator;
            if (self.is_cluster_scoped) {
                return std.fmt.allocPrint(allocator, "{s}/{s}/{s}", .{
                    self.api_path,
                    self.resource,
                    name,
                });
            }
            return std.fmt.allocPrint(allocator, "{s}/namespaces/{s}/{s}/{s}", .{
                self.api_path,
                namespace orelse self.client.namespace,
                self.resource,
                name,
            });
        }

        fn appendQueryString(allocator: std.mem.Allocator, base_path: []const u8, query_string: []const u8) ![]const u8 {
            if (query_string.len > 0) {
                return std.fmt.allocPrint(allocator, "{s}?{s}", .{ base_path, query_string });
            }
            return allocator.dupe(u8, base_path);
        }

        // --- List operations ---

        /// List resources in a namespace (or cluster-wide for cluster-scoped resources).
        /// NOTE: Caller must call deinit() on the returned Parsed object
        pub fn list(self: Self, namespace: ?[]const u8) !std.json.Parsed(types.List(T)) {
            const allocator = self.client.allocator;
            const path = try self.buildCollectionPath(namespace);
            defer allocator.free(path);

            const body = try self.client.request(.GET, path, null);
            defer allocator.free(body);

            return parseResponse(types.List(T), allocator, body);
        }

        /// List all resources across all namespaces
        /// NOTE: Caller must call deinit() on the returned Parsed object
        pub fn listAll(self: Self) !std.json.Parsed(types.List(T)) {
            const allocator = self.client.allocator;
            const path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{
                self.api_path,
                self.resource,
            });
            defer allocator.free(path);

            const body = try self.client.request(.GET, path, null);
            defer allocator.free(body);

            return parseResponse(types.List(T), allocator, body);
        }

        /// List resources with options (field/label selectors, pagination, etc.)
        /// NOTE: Caller must call deinit() on the returned Parsed object
        pub fn listWithOptions(self: Self, namespace: ?[]const u8, options: list_opts.ListOptions) !std.json.Parsed(types.List(T)) {
            const allocator = self.client.allocator;
            const base_path = try self.buildCollectionPath(namespace);
            defer allocator.free(base_path);

            const qs = try options.buildQueryString(allocator);
            defer allocator.free(qs);

            const path = try appendQueryString(allocator, base_path, qs);
            defer allocator.free(path);

            const body = try self.client.request(.GET, path, null);
            defer allocator.free(body);

            return parseResponse(types.List(T), allocator, body);
        }

        /// List all resources across all namespaces with options
        /// NOTE: Caller must call deinit() on the returned Parsed object
        pub fn listAllWithOptions(self: Self, options: list_opts.ListOptions) !std.json.Parsed(types.List(T)) {
            const allocator = self.client.allocator;

            const base_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{
                self.api_path,
                self.resource,
            });
            defer allocator.free(base_path);

            const qs = try options.buildQueryString(allocator);
            defer allocator.free(qs);

            const path = try appendQueryString(allocator, base_path, qs);
            defer allocator.free(path);

            const body = try self.client.request(.GET, path, null);
            defer allocator.free(body);

            return parseResponse(types.List(T), allocator, body);
        }

        // --- Single-resource operations ---

        /// Get a specific resource by name
        /// NOTE: Caller must call deinit() on the returned Parsed object
        pub fn get(self: Self, name: []const u8, namespace: ?[]const u8) !std.json.Parsed(T) {
            const allocator = self.client.allocator;
            const path = try self.buildResourcePath(name, namespace);
            defer allocator.free(path);

            const body = try self.client.request(.GET, path, null);
            defer allocator.free(body);

            return parseResponse(T, allocator, body);
        }

        /// Create a new resource
        /// NOTE: Caller must call deinit() on the returned Parsed object
        pub fn create(self: Self, resource: T, namespace: ?[]const u8) !std.json.Parsed(T) {
            const allocator = self.client.allocator;
            const path = try self.buildCollectionPath(namespace);
            defer allocator.free(path);

            const json_body = try serializeJson(allocator, resource);
            defer allocator.free(json_body);

            const body = try self.client.request(.POST, path, json_body);
            defer allocator.free(body);

            return parseResponse(T, allocator, body);
        }

        /// Create a new resource with options (field manager, field validation, dry-run)
        /// NOTE: Caller must call deinit() on the returned Parsed object
        pub fn createWithOptions(
            self: Self,
            resource: T,
            namespace: ?[]const u8,
            options: delete_opts.CreateOptions,
        ) !std.json.Parsed(T) {
            const allocator = self.client.allocator;

            const base_path = try self.buildCollectionPath(namespace);
            defer allocator.free(base_path);

            const qs = try options.buildQueryString(allocator);
            defer allocator.free(qs);

            const path = try appendQueryString(allocator, base_path, qs);
            defer allocator.free(path);

            const json_body = try serializeJson(allocator, resource);
            defer allocator.free(json_body);

            const body = try self.client.request(.POST, path, json_body);
            defer allocator.free(body);

            return parseResponse(T, allocator, body);
        }

        /// Update an existing resource (replace)
        /// NOTE: Caller must call deinit() on the returned Parsed object
        pub fn update(self: Self, resource: T, namespace: ?[]const u8) !std.json.Parsed(T) {
            const allocator = self.client.allocator;
            const path = try self.buildResourcePath(resource.metadata.name, namespace);
            defer allocator.free(path);

            const json_body = try serializeJson(allocator, resource);
            defer allocator.free(json_body);

            const body = try self.client.request(.PUT, path, json_body);
            defer allocator.free(body);

            return parseResponse(T, allocator, body);
        }

        /// Update an existing resource with options (field manager, field validation, dry-run)
        /// NOTE: Caller must call deinit() on the returned Parsed object
        pub fn updateWithOptions(
            self: Self,
            resource: T,
            namespace: ?[]const u8,
            options: delete_opts.UpdateOptions,
        ) !std.json.Parsed(T) {
            const allocator = self.client.allocator;

            const base_path = try self.buildResourcePath(resource.metadata.name, namespace);
            defer allocator.free(base_path);

            const qs = try options.buildQueryString(allocator);
            defer allocator.free(qs);

            const path = try appendQueryString(allocator, base_path, qs);
            defer allocator.free(path);

            const json_body = try serializeJson(allocator, resource);
            defer allocator.free(json_body);

            const body = try self.client.request(.PUT, path, json_body);
            defer allocator.free(body);

            return parseResponse(T, allocator, body);
        }

        /// Delete a resource
        pub fn delete(self: Self, name: []const u8, namespace: ?[]const u8) !void {
            const allocator = self.client.allocator;
            const path = try self.buildResourcePath(name, namespace);
            defer allocator.free(path);

            const body = try self.client.request(.DELETE, path, null);
            defer allocator.free(body);
        }

        /// Delete a resource with options (grace period, propagation policy, etc.)
        pub fn deleteWithOptions(
            self: Self,
            name: []const u8,
            namespace: ?[]const u8,
            options: delete_opts.DeleteOptions,
        ) !void {
            const allocator = self.client.allocator;

            const base_path = try self.buildResourcePath(name, namespace);
            defer allocator.free(base_path);

            const qs = try options.buildQueryString(allocator);
            defer allocator.free(qs);

            const path = try appendQueryString(allocator, base_path, qs);
            defer allocator.free(path);

            const delete_body = if (options.preconditions != null)
                try options.buildBody(allocator)
            else
                null;
            defer if (delete_body) |b| allocator.free(b);

            const response = try self.client.request(.DELETE, path, delete_body);
            defer allocator.free(response);
        }

        /// Delete collection of resources matching label/field selectors
        pub fn deleteCollection(
            self: Self,
            namespace: ?[]const u8,
            list_options: list_opts.ListOptions,
            delete_options: delete_opts.DeleteOptions,
        ) !void {
            const allocator = self.client.allocator;

            const list_query = try list_options.buildQueryString(allocator);
            defer allocator.free(list_query);

            const delete_query = try delete_options.buildQueryString(allocator);
            defer allocator.free(delete_query);

            // Combine query strings
            var combined = try std.ArrayList(u8).initCapacity(allocator, 0);
            defer combined.deinit(allocator);

            if (list_query.len > 0) {
                try combined.appendSlice(allocator, list_query);
            }
            if (delete_query.len > 0) {
                if (combined.items.len > 0) {
                    try combined.append(allocator, '&');
                }
                try combined.appendSlice(allocator, delete_query);
            }

            const qs = try combined.toOwnedSlice(allocator);
            defer allocator.free(qs);

            const base_path = try self.buildCollectionPath(namespace);
            defer allocator.free(base_path);

            const path = try appendQueryString(allocator, base_path, qs);
            defer allocator.free(path);

            const response = try self.client.request(.DELETE, path, null);
            defer allocator.free(response);
        }

        // --- Patch operations ---

        /// Patch a resource (strategic merge patch)
        /// NOTE: Caller must call deinit() on the returned Parsed object
        pub fn patch(self: Self, name: []const u8, patch_data: []const u8, namespace: ?[]const u8) !std.json.Parsed(T) {
            const allocator = self.client.allocator;
            const path = try self.buildResourcePath(name, namespace);
            defer allocator.free(path);

            const body = try self.client.requestWithContentType(
                .PATCH,
                path,
                patch_data,
                "application/strategic-merge-patch+json",
            );
            defer allocator.free(body);

            return parseResponse(T, allocator, body);
        }

        /// Patch a resource with custom content type
        /// NOTE: Caller must call deinit() on the returned Parsed object
        pub fn patchWithType(
            self: Self,
            name: []const u8,
            patch_data: []const u8,
            namespace: ?[]const u8,
            patch_type: apply_mod.PatchType,
        ) !std.json.Parsed(T) {
            const allocator = self.client.allocator;
            const path = try self.buildResourcePath(name, namespace);
            defer allocator.free(path);

            const body = try self.client.requestWithContentType(
                .PATCH,
                path,
                patch_data,
                patch_type.contentType(),
            );
            defer allocator.free(body);

            return parseResponse(T, allocator, body);
        }

        /// Server-side apply a resource
        /// NOTE: Caller must call deinit() on the returned Parsed object
        pub fn apply(
            self: Self,
            name: []const u8,
            resource_json: []const u8,
            namespace: ?[]const u8,
            options: apply_mod.ApplyOptions,
        ) !std.json.Parsed(T) {
            const allocator = self.client.allocator;

            const base_path = try self.buildResourcePath(name, namespace);
            defer allocator.free(base_path);

            const qs = try options.buildQueryString(allocator);
            defer allocator.free(qs);

            const path = try std.fmt.allocPrint(allocator, "{s}?{s}", .{ base_path, qs });
            defer allocator.free(path);

            const body = try self.client.requestWithContentType(
                .PATCH,
                path,
                resource_json,
                apply_mod.PatchType.apply.contentType(),
            );
            defer allocator.free(body);

            return parseResponse(T, allocator, body);
        }
    };
}

// =============================================================================
// Comptime wrapper generator
// =============================================================================

/// Generates a simple wrapper struct for a registered K8s resource type.
/// The generated struct has a `.client` field (preserving the existing API)
/// and an `init()` constructor that auto-configures from the resource registry.
pub fn SimpleResource(comptime T: type) type {
    return struct {
        client: ResourceClient(T),

        pub fn init(k8s_client: *K8sClient) @This() {
            return .{ .client = ResourceClient(T).initFromRegistry(k8s_client) };
        }
    };
}

// =============================================================================
// Simple resource wrappers (no custom methods — generated from registry)
// =============================================================================

pub const Services = SimpleResource(types.Service);
pub const ConfigMaps = SimpleResource(types.ConfigMap);
pub const Secrets = SimpleResource(types.Secret);
pub const Namespaces = SimpleResource(types.Namespace);
pub const PersistentVolumes = SimpleResource(types.PersistentVolume);
pub const PersistentVolumeClaims = SimpleResource(types.PersistentVolumeClaim);
pub const Ingresses = SimpleResource(types.Ingress);
pub const ServiceAccounts = SimpleResource(types.ServiceAccount);
pub const Roles = SimpleResource(types.Role);
pub const RoleBindings = SimpleResource(types.RoleBinding);
pub const ClusterRoles = SimpleResource(types.ClusterRole);
pub const ClusterRoleBindings = SimpleResource(types.ClusterRoleBinding);
pub const NetworkPolicies = SimpleResource(types.NetworkPolicy);
pub const IPAddresses = SimpleResource(types.IPAddress);
pub const ServiceCIDRs = SimpleResource(types.ServiceCIDR);
pub const HorizontalPodAutoscalers = SimpleResource(types.HorizontalPodAutoscaler);
pub const StorageClasses = SimpleResource(types.StorageClass);
pub const ResourceQuotas = SimpleResource(types.ResourceQuota);
pub const LimitRanges = SimpleResource(types.LimitRange);
pub const PodDisruptionBudgets = SimpleResource(types.PodDisruptionBudget);
pub const IngressClasses = SimpleResource(types.IngressClass);
pub const EndpointsClient = SimpleResource(types.Endpoints);
pub const EndpointSlices = SimpleResource(types.EndpointSlice);
pub const Events = SimpleResource(types.Event);
pub const ReplicationControllers = SimpleResource(types.ReplicationController);
pub const PodTemplates = SimpleResource(types.PodTemplate);
pub const ControllerRevisions = SimpleResource(types.ControllerRevision);
pub const Leases = SimpleResource(types.Lease);
pub const PriorityClasses = SimpleResource(types.PriorityClass);
pub const Bindings = SimpleResource(types.Binding);
pub const ComponentStatuses = SimpleResource(types.ComponentStatus);
pub const VolumeAttachments = SimpleResource(types.VolumeAttachment);
pub const CSIDrivers = SimpleResource(types.CSIDriver);
pub const CSINodes = SimpleResource(types.CSINode);
pub const CSIStorageCapacities = SimpleResource(types.CSIStorageCapacity);
pub const Jobs = SimpleResource(types.Job);

// Gateway API
pub const GatewayClasses = SimpleResource(types.GatewayClass);
pub const Gateways = SimpleResource(types.Gateway);
pub const HTTPRoutes = SimpleResource(types.HTTPRoute);
pub const GRPCRoutes = SimpleResource(types.GRPCRoute);
pub const ReferenceGrants = SimpleResource(types.ReferenceGrant);

// Dynamic Resource Allocation
pub const ResourceClaims = SimpleResource(types.ResourceClaim);
pub const ResourceClaimTemplates = SimpleResource(types.ResourceClaimTemplate);
pub const ResourceSlices = SimpleResource(types.ResourceSlice);
pub const DeviceClasses = SimpleResource(types.DeviceClass);
pub const VolumeAttributesClasses = SimpleResource(types.VolumeAttributesClass);

// Previously in final_resources.zig — now unified here
pub const CertificateSigningRequests = SimpleResource(types.CertificateSigningRequest);
pub const ValidatingWebhookConfigurations = SimpleResource(types.ValidatingWebhookConfiguration);
pub const MutatingWebhookConfigurations = SimpleResource(types.MutatingWebhookConfiguration);
pub const ValidatingAdmissionPolicies = SimpleResource(types.ValidatingAdmissionPolicy);
pub const ValidatingAdmissionPolicyBindings = SimpleResource(types.ValidatingAdmissionPolicyBinding);
pub const APIServices = SimpleResource(types.APIService);
pub const FlowSchemas = SimpleResource(types.FlowSchema);
pub const PriorityLevelConfigurations = SimpleResource(types.PriorityLevelConfiguration);
pub const RuntimeClasses = SimpleResource(types.RuntimeClass);
pub const StorageVersionMigrations = SimpleResource(types.StorageVersionMigration);

// =============================================================================
// Resources with custom methods
// =============================================================================

// --- Shared operations (eliminates duplication across Deployment/StatefulSet/etc.) ---

fn scalePatch(allocator: std.mem.Allocator, rc: anytype, name: []const u8, replicas: i32, namespace: ?[]const u8) !void {
    const patch_json = try std.fmt.allocPrint(
        allocator,
        "{{\"spec\":{{\"replicas\":{d}}}}}",
        .{replicas},
    );
    defer allocator.free(patch_json);

    const result = try rc.patch(name, patch_json, namespace);
    result.deinit();
}

fn rolloutRestartPatch(allocator: std.mem.Allocator, rc: anytype, name: []const u8, namespace: ?[]const u8) !void {
    const now = std.time.timestamp();
    const patch_json = try std.fmt.allocPrint(
        allocator,
        "{{\"spec\":{{\"template\":{{\"metadata\":{{\"annotations\":{{\"kubectl.kubernetes.io/restartedAt\":\"{d}\"}}}}}}}}}}",
        .{now},
    );
    defer allocator.free(patch_json);

    const result = try rc.patch(name, patch_json, namespace);
    result.deinit();
}

// --- Pods ---

pub const Pods = struct {
    client: ResourceClient(types.Pod),

    pub fn init(k8s_client: *K8sClient) Pods {
        return .{ .client = ResourceClient(types.Pod).initFromRegistry(k8s_client) };
    }

    pub const LogOptions = struct {
        container: ?[]const u8 = null,
        previous: bool = false,
        tail_lines: ?i64 = null,
        since_seconds: ?i64 = null,
        timestamps: bool = false,
        limit_bytes: ?i64 = null,
    };

    pub fn logs(self: Pods, name: []const u8, namespace: ?[]const u8) ![]const u8 {
        return self.logsWithOptions(name, namespace, .{});
    }

    pub fn logsWithOptions(self: Pods, name: []const u8, namespace: ?[]const u8, options: LogOptions) ![]const u8 {
        const ns = namespace orelse self.client.client.namespace;
        const allocator = self.client.client.allocator;

        var qw = try QueryWriter.init(allocator);
        defer qw.deinit();

        try qw.addOptionalString("container", options.container);
        try qw.addBoolFlag("previous", options.previous);
        try qw.addOptionalInt("tailLines", options.tail_lines);
        try qw.addOptionalInt("sinceSeconds", options.since_seconds);
        try qw.addBoolFlag("timestamps", options.timestamps);
        try qw.addOptionalInt("limitBytes", options.limit_bytes);

        const qs = try qw.toOwnedSlice();
        defer allocator.free(qs);

        const base_path = try std.fmt.allocPrint(
            allocator,
            "{s}/namespaces/{s}/{s}/{s}/log",
            .{ self.client.api_path, ns, self.client.resource, name },
        );
        defer allocator.free(base_path);

        const path = if (qs.len > 0)
            try std.fmt.allocPrint(allocator, "{s}?{s}", .{ base_path, qs })
        else
            try allocator.dupe(u8, base_path);
        defer allocator.free(path);

        return try self.client.client.request(.GET, path, null);
    }

    pub fn evict(self: Pods, name: []const u8, namespace: ?[]const u8) !void {
        const ns = namespace orelse self.client.client.namespace;
        const allocator = self.client.client.allocator;

        const path = try std.fmt.allocPrint(
            allocator,
            "{s}/namespaces/{s}/{s}/{s}/eviction",
            .{ self.client.api_path, ns, self.client.resource, name },
        );
        defer allocator.free(path);

        const body = try std.fmt.allocPrint(
            allocator,
            "{{\"apiVersion\":\"policy/v1\",\"kind\":\"Eviction\",\"metadata\":{{\"name\":\"{s}\",\"namespace\":\"{s}\"}}}}",
            .{ name, ns },
        );
        defer allocator.free(body);

        const response = try self.client.client.request(.POST, path, body);
        allocator.free(response);
    }
};

// --- Deployments ---

pub const Deployments = struct {
    client: ResourceClient(types.Deployment),

    pub fn init(k8s_client: *K8sClient) Deployments {
        return .{ .client = ResourceClient(types.Deployment).initFromRegistry(k8s_client) };
    }

    pub fn scale(self: Deployments, name: []const u8, replicas: i32, namespace: ?[]const u8) !void {
        return scalePatch(self.client.client.allocator, self.client, name, replicas, namespace);
    }

    pub fn rolloutRestart(self: Deployments, name: []const u8, namespace: ?[]const u8) !void {
        return rolloutRestartPatch(self.client.client.allocator, self.client, name, namespace);
    }

    pub fn setImage(self: Deployments, name: []const u8, container_name: []const u8, image: []const u8, namespace: ?[]const u8) !void {
        const allocator = self.client.client.allocator;
        const patch_json = try std.fmt.allocPrint(
            allocator,
            "{{\"spec\":{{\"template\":{{\"spec\":{{\"containers\":[{{\"name\":\"{s}\",\"image\":\"{s}\"}}]}}}}}}}}",
            .{ container_name, image },
        );
        defer allocator.free(patch_json);

        const result = try self.client.patch(name, patch_json, namespace);
        result.deinit();
    }
};

// --- ReplicaSets ---

pub const ReplicaSets = struct {
    client: ResourceClient(types.ReplicaSet),

    pub fn init(k8s_client: *K8sClient) ReplicaSets {
        return .{ .client = ResourceClient(types.ReplicaSet).initFromRegistry(k8s_client) };
    }

    pub fn scale(self: ReplicaSets, name: []const u8, replicas: i32, namespace: ?[]const u8) !void {
        return scalePatch(self.client.client.allocator, self.client, name, replicas, namespace);
    }
};

// --- Nodes ---

pub const Nodes = struct {
    client: ResourceClient(types.Node),

    pub fn init(k8s_client: *K8sClient) Nodes {
        return .{ .client = ResourceClient(types.Node).initFromRegistry(k8s_client) };
    }

    pub fn cordon(self: Nodes, name: []const u8) !void {
        return self.setSchedulable(name, false);
    }

    pub fn uncordon(self: Nodes, name: []const u8) !void {
        return self.setSchedulable(name, true);
    }

    fn setSchedulable(self: Nodes, name: []const u8, schedulable: bool) !void {
        const allocator = self.client.client.allocator;
        const path = try std.fmt.allocPrint(allocator, "{s}/{s}/{s}", .{
            self.client.api_path, self.client.resource, name,
        });
        defer allocator.free(path);

        const patch_json = if (schedulable)
            "{\"spec\":{\"unschedulable\":false}}"
        else
            "{\"spec\":{\"unschedulable\":true}}";

        const response = try self.client.client.requestWithContentType(
            .PATCH,
            path,
            patch_json,
            "application/strategic-merge-patch+json",
        );
        allocator.free(response);
    }
};

// --- StatefulSets ---

pub const StatefulSets = struct {
    client: ResourceClient(types.StatefulSet),

    pub fn init(k8s_client: *K8sClient) StatefulSets {
        return .{ .client = ResourceClient(types.StatefulSet).initFromRegistry(k8s_client) };
    }

    pub fn scale(self: StatefulSets, name: []const u8, replicas: i32, namespace: ?[]const u8) !void {
        return scalePatch(self.client.client.allocator, self.client, name, replicas, namespace);
    }

    pub fn rolloutRestart(self: StatefulSets, name: []const u8, namespace: ?[]const u8) !void {
        return rolloutRestartPatch(self.client.client.allocator, self.client, name, namespace);
    }
};

// --- DaemonSets ---

pub const DaemonSets = struct {
    client: ResourceClient(types.DaemonSet),

    pub fn init(k8s_client: *K8sClient) DaemonSets {
        return .{ .client = ResourceClient(types.DaemonSet).initFromRegistry(k8s_client) };
    }

    pub fn rolloutRestart(self: DaemonSets, name: []const u8, namespace: ?[]const u8) !void {
        return rolloutRestartPatch(self.client.client.allocator, self.client, name, namespace);
    }
};

// --- CronJobs ---

pub const CronJobs = struct {
    client: ResourceClient(types.CronJob),

    pub fn init(k8s_client: *K8sClient) CronJobs {
        return .{ .client = ResourceClient(types.CronJob).initFromRegistry(k8s_client) };
    }

    pub fn setSuspend(self: CronJobs, name: []const u8, should_suspend: bool, namespace: ?[]const u8) !void {
        const allocator = self.client.client.allocator;
        const patch_json = try std.fmt.allocPrint(
            allocator,
            "{{\"spec\":{{\"suspend\":{s}}}}}",
            .{if (should_suspend) "true" else "false"},
        );
        defer allocator.free(patch_json);

        const result = try self.client.patch(name, patch_json, namespace);
        result.deinit();
    }
};
