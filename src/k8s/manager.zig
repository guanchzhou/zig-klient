const std = @import("std");
const client_mod = @import("client.zig");
const kubeconfig_mod = @import("kubeconfig_json.zig");
const Logger = @import("../core/logger.zig");

const K8sClient = client_mod.K8sClient;
const KubeconfigParser = kubeconfig_mod.KubeconfigParser;
const Kubeconfig = kubeconfig_mod.Kubeconfig;

/// Kubernetes Manager - high-level interface for K8s operations  
/// Adapts standalone k8s library for app usage with logging
pub const K8sManager = struct {
    allocator: std.mem.Allocator,
    client: ?K8sClient,
    kubeconfig: ?Kubeconfig,
    connected: bool,
    
    pub fn init(allocator: std.mem.Allocator) K8sManager {
        return .{
            .allocator = allocator,
            .client = null,
            .kubeconfig = null,
            .connected = false,
        };
    }
    
    pub fn deinit(self: *K8sManager) void {
        if (self.client) |*c| c.deinit();
        if (self.kubeconfig) |*k| k.deinit(self.allocator);
    }
    
    /// Connect to Kubernetes cluster using kubeconfig
    /// If context_override is provided, use that instead of current-context
    pub fn connect(self: *K8sManager, context_override: ?[]const u8) !void {
        Logger.info("Connecting to Kubernetes cluster...", .{});
        
        // Try to parse kubeconfig
        Logger.debug("Loading kubeconfig via kubectl", .{});
        var parser = KubeconfigParser.init(self.allocator);
        self.kubeconfig = parser.load() catch |err| {
            Logger.err("Failed to load kubeconfig: {}. Using fixtures.", .{err});
            return;
        };
        
        Logger.info("Kubeconfig loaded successfully", .{});
        
        const kc = &self.kubeconfig.?;
        
        // Debug: log what we found
        Logger.info("Found {d} clusters, {d} contexts, {d} users", .{kc.clusters.len, kc.contexts.len, kc.users.len});
        for (kc.clusters) |cluster| {
            Logger.info("  Cluster: {s} -> {s}", .{cluster.name, cluster.server});
        }
        for (kc.contexts) |ctx| {
            Logger.info("  Context: {s} (cluster={s}, user={s})", .{ctx.name, ctx.cluster, ctx.user});
        }
        
        // Use context override if provided, otherwise use current-context
        const context_name = context_override orelse kc.current_context;
        
        if (context_override) |ctx| {
            Logger.info("Using context from --context flag: {s}", .{ctx});
        } else {
            Logger.info("Using current-context from kubeconfig: {s}", .{kc.current_context});
        }
        
        const current_context = kc.getContextByName(context_name) orelse {
            Logger.warn("Context '{s}' not found in kubeconfig. Using fixtures.", .{context_name});
            return;
        };
        const cluster = kc.getCluster(current_context.cluster) orelse {
            Logger.warn("Cluster not found in kubeconfig. Using fixtures.", .{});
            return;
        };
        const user = kc.getUser(current_context.user) orelse {
            Logger.warn("User not found in kubeconfig. Using fixtures.", .{});
            return;
        };
        
        Logger.info("Context: {s}, Cluster: {s}, Server: {s}", .{
            current_context.name,
            cluster.name,
            cluster.server,
        });
        
        // Create K8s client
        Logger.debug("K8s API Server: {s}", .{cluster.server});
        const client_config = K8sClient.Config{
            .server = cluster.server,
            .token = user.token,
            .namespace = current_context.namespace,
        };
        
        self.client = K8sClient.init(self.allocator, client_config) catch |err| {
            Logger.warn("Failed to create K8s client: {}. Using fixtures.", .{err});
            return;
        };
        self.connected = true;
        
        Logger.info("Successfully connected to Kubernetes cluster", .{});
    }
    
    /// Get pods (with fallback to fixtures if not connected)
    pub fn getPods(self: *K8sManager) ![]client_mod.Pod {
        if (self.connected and self.client != null) {
            return self.client.?.listAllPods() catch |err| {
                Logger.warn("Failed to get pods from K8s API: {}. Using fixtures.", .{err});
                self.connected = false; // Mark as disconnected since API calls are failing
                return try self.getFixturePods();
            };
        }
        
        // Fallback to fixtures
        Logger.warn("Not connected to K8s, using fixtures", .{});
        return try self.getFixturePods();
    }
    
    /// Get cluster info (with fallback to fixtures if not connected)
    pub fn getClusterInfo(self: *K8sManager) !ClusterData {
        if (self.connected and self.client != null) {
            const info = self.client.?.getClusterInfo() catch |err| {
                Logger.warn("Failed to get cluster info from K8s API: {}. Using fixtures.", .{err});
                self.connected = false; // Mark as disconnected since API calls are failing
                return try self.getFixtureClusterInfo();
            };
            
            const context_name = if (self.kubeconfig) |*kc|
                kc.current_context
            else
                "unknown";
            
            const cluster_name = if (self.kubeconfig) |*kc| blk: {
                const ctx = kc.getCurrentContext() orelse break :blk "unknown";
                break :blk ctx.cluster;
            } else "unknown";
            
            const user_name = if (self.kubeconfig) |*kc| blk: {
                const ctx = kc.getCurrentContext() orelse break :blk "unknown";
                break :blk ctx.user;
            } else "unknown";
            
            return ClusterData{
                .context = try self.allocator.dupe(u8, context_name),
                .cluster = try self.allocator.dupe(u8, cluster_name),
                .user = try self.allocator.dupe(u8, user_name),
                .k8s_version = info.k8s_version,
                .cpu_usage = info.cpu_usage,
                .mem_usage = info.mem_usage,
            };
        }
        
        // Fallback to fixtures
        Logger.warn("Not connected to K8s, using fixtures", .{});
        return try self.getFixtureClusterInfo();
    }
    
    /// Fallback: Get pods from fixtures
    fn getFixturePods(self: *K8sManager) ![]client_mod.Pod {
        const fixtures = @import("../fixtures/index.zig");
        const fixture_pods = fixtures.pods_data.default_pods;
        
        var pods = try self.allocator.alloc(client_mod.Pod, fixture_pods.len);
        
        for (fixture_pods, 0..) |fp, i| {
            pods[i] = client_mod.Pod{
                .name = try self.allocator.dupe(u8, fp.name),
                .namespace = try self.allocator.dupe(u8, fp.namespace),
                .ready = try self.allocator.dupe(u8, fp.ready),
                .status = try self.allocator.dupe(u8, fp.status),
                .restarts = fp.restarts,
                .age = try self.allocator.dupe(u8, fp.age),
                .node = try self.allocator.dupe(u8, "n/a"),
                .ip = try self.allocator.dupe(u8, "n/a"),
                .cpu_usage = try self.allocator.dupe(u8, "n/a"),
                .mem_usage = try self.allocator.dupe(u8, "n/a"),
            };
        }
        
        return pods;
    }
    
    /// Fallback: Get cluster info from fixtures
    fn getFixtureClusterInfo(self: *K8sManager) !ClusterData {
        const fixtures = @import("../fixtures/index.zig");
        const data = fixtures.k8s_data.default_data;
        
        return ClusterData{
            .context = try self.allocator.dupe(u8, data.context),
            .cluster = try self.allocator.dupe(u8, data.cluster),
            .user = try self.allocator.dupe(u8, data.user),
            .k8s_version = try self.allocator.dupe(u8, data.k8s_version),
            .cpu_usage = data.cpu_usage,
            .mem_usage = data.mem_usage,
        };
    }
    
    /// Check if connected to K8s cluster
    pub fn isConnected(self: *const K8sManager) bool {
        return self.connected;
    }
};

/// Cluster data for UI
pub const ClusterData = struct {
    context: []const u8,
    cluster: []const u8,
    user: []const u8,
    k8s_version: []const u8,
    cpu_usage: u8,
    mem_usage: u8,
    
    pub fn deinit(self: *ClusterData, allocator: std.mem.Allocator) void {
        allocator.free(self.context);
        allocator.free(self.cluster);
        allocator.free(self.user);
        allocator.free(self.k8s_version);
    }
};
