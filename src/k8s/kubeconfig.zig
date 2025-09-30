const std = @import("std");
const xdg = @import("../core/xdg.zig");
const Logger = @import("../core/logger.zig");

/// Kubeconfig parser - reads and parses ~/.kube/config
pub const KubeconfigParser = struct {
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator) KubeconfigParser {
        return .{ .allocator = allocator };
    }
    
    /// Load kubeconfig from default location
    pub fn load(self: *KubeconfigParser) !Kubeconfig {
        const home = std.posix.getenv("HOME") orelse return error.HomeNotSet;
        const config_path = try std.fmt.allocPrint(
            self.allocator,
            "{s}/.kube/config",
            .{home}
        );
        defer self.allocator.free(config_path);
        
        Logger.debug("Loading kubeconfig from: {s}", .{config_path});
        
        return try self.loadFromPath(config_path);
    }
    
    /// Load kubeconfig from specific path
    pub fn loadFromPath(self: *KubeconfigParser, path: []const u8) !Kubeconfig {
        const file = std.fs.cwd().openFile(path, .{}) catch |err| {
            Logger.err("Failed to open kubeconfig: {}", .{err});
            return err;
        };
        defer file.close();
        
        const content = try file.readToEndAlloc(self.allocator, 1024 * 1024); // 1MB max
        defer self.allocator.free(content);
        
        return try self.parse(content);
    }
    
    /// Parse kubeconfig YAML content
    fn parse(self: *KubeconfigParser, content: []const u8) !Kubeconfig {
        // For initial implementation, we'll use a simple parser
        // TODO: Use proper YAML parser library
        
        var current_context: ?[]const u8 = null;
        var clusters = try std.ArrayList(Cluster).initCapacity(self.allocator, 0);
        var contexts = try std.ArrayList(Context).initCapacity(self.allocator, 0);
        var users = try std.ArrayList(User).initCapacity(self.allocator, 0);
        
        var lines = std.mem.tokenizeScalar(u8, content, '\n');
        var in_clusters = false;
        var in_contexts = false;
        var in_users = false;
        var current_cluster: ?Cluster = null;
        var current_ctxt: ?Context = null;
        var current_user: ?User = null;
        
        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \t\r");
            
            if (trimmed.len == 0 or trimmed[0] == '#') continue;
            
            // Parse current-context
            if (std.mem.startsWith(u8, trimmed, "current-context:")) {
                const value = std.mem.trim(u8, trimmed[16..], " ");
                current_context = try self.allocator.dupe(u8, value);
                continue;
            }
            
            // Section headers
            if (std.mem.eql(u8, trimmed, "clusters:")) {
                in_clusters = true;
                in_contexts = false;
                in_users = false;
                continue;
            }
            if (std.mem.eql(u8, trimmed, "contexts:")) {
                in_clusters = false;
                in_contexts = true;
                in_users = false;
                continue;
            }
            if (std.mem.eql(u8, trimmed, "users:")) {
                in_clusters = false;
                in_contexts = false;
                in_users = true;
                continue;
            }
            
            // Parse clusters
            if (in_clusters) {
                if (std.mem.startsWith(u8, trimmed, "- cluster:")) {
                    if (current_cluster) |cluster| {
                        try clusters.append(self.allocator, cluster);
                    }
                    current_cluster = Cluster{
                        .name = "",
                        .server = "",
                    };
                } else if (std.mem.startsWith(u8, trimmed, "server:")) {
                    const server = std.mem.trim(u8, trimmed[7..], " ");
                    if (current_cluster) |*cluster| {
                        cluster.server = try self.allocator.dupe(u8, server);
                    }
                } else if (std.mem.startsWith(u8, trimmed, "name:")) {
                    const name = std.mem.trim(u8, trimmed[5..], " ");
                    if (current_cluster) |*cluster| {
                        cluster.name = try self.allocator.dupe(u8, name);
                    }
                }
            }
            
            // Parse contexts
            if (in_contexts) {
                if (std.mem.startsWith(u8, trimmed, "- context:")) {
                    if (current_ctxt) |ctxt| {
                        try contexts.append(self.allocator, ctxt);
                    }
                    current_ctxt = Context{
                        .name = "",
                        .cluster = "",
                        .user = "",
                        .namespace = null,
                    };
                } else if (std.mem.startsWith(u8, trimmed, "name:")) {
                    const name = std.mem.trim(u8, trimmed[5..], " ");
                    if (current_ctxt) |*ctxt| {
                        ctxt.name = try self.allocator.dupe(u8, name);
                    }
                } else if (std.mem.startsWith(u8, trimmed, "cluster:")) {
                    const cluster = std.mem.trim(u8, trimmed[8..], " ");
                    if (current_ctxt) |*ctxt| {
                        ctxt.cluster = try self.allocator.dupe(u8, cluster);
                    }
                } else if (std.mem.startsWith(u8, trimmed, "user:")) {
                    const user = std.mem.trim(u8, trimmed[5..], " ");
                    if (current_ctxt) |*ctxt| {
                        ctxt.user = try self.allocator.dupe(u8, user);
                    }
                } else if (std.mem.startsWith(u8, trimmed, "namespace:")) {
                    const ns = std.mem.trim(u8, trimmed[10..], " ");
                    if (current_ctxt) |*ctxt| {
                        ctxt.namespace = try self.allocator.dupe(u8, ns);
                    }
                }
            }
            
            // Parse users
            if (in_users) {
                if (std.mem.startsWith(u8, trimmed, "- name:")) {
                    if (current_user) |user| {
                        try users.append(self.allocator, user);
                    }
                    const name = std.mem.trim(u8, trimmed[7..], " ");
                    current_user = User{
                        .name = try self.allocator.dupe(u8, name),
                        .token = null,
                        .cert_path = null,
                        .key_path = null,
                    };
                } else if (std.mem.startsWith(u8, trimmed, "token:")) {
                    const token = std.mem.trim(u8, trimmed[6..], " ");
                    if (current_user) |*user| {
                        user.token = try self.allocator.dupe(u8, token);
                    }
                } else if (std.mem.startsWith(u8, trimmed, "client-certificate:")) {
                    const cert = std.mem.trim(u8, trimmed[19..], " ");
                    if (current_user) |*user| {
                        user.cert_path = try self.allocator.dupe(u8, cert);
                    }
                } else if (std.mem.startsWith(u8, trimmed, "client-key:")) {
                    const key = std.mem.trim(u8, trimmed[11..], " ");
                    if (current_user) |*user| {
                        user.key_path = try self.allocator.dupe(u8, key);
                    }
                }
            }
        }
        
        // Append last items
        if (current_cluster) |cluster| {
            try clusters.append(self.allocator, cluster);
        }
        if (current_ctxt) |ctxt| {
            try contexts.append(self.allocator, ctxt);
        }
        if (current_user) |user| {
            try users.append(self.allocator, user);
        }
        
        return Kubeconfig{
            .current_context = current_context orelse return error.NoCurrentContext,
            .clusters = try clusters.toOwnedSlice(self.allocator),
            .contexts = try contexts.toOwnedSlice(self.allocator),
            .users = try users.toOwnedSlice(self.allocator),
        };
    }
};

pub const Kubeconfig = struct {
    current_context: []const u8,
    clusters: []Cluster,
    contexts: []Context,
    users: []User,
    
    pub fn deinit(self: *Kubeconfig, allocator: std.mem.Allocator) void {
        allocator.free(self.current_context);
        for (self.clusters) |cluster| {
            allocator.free(cluster.name);
            allocator.free(cluster.server);
        }
        allocator.free(self.clusters);
        
        for (self.contexts) |context| {
            allocator.free(context.name);
            allocator.free(context.cluster);
            allocator.free(context.user);
            if (context.namespace) |ns| allocator.free(ns);
        }
        allocator.free(self.contexts);
        
        for (self.users) |user| {
            allocator.free(user.name);
            if (user.token) |t| allocator.free(t);
            if (user.cert_path) |c| allocator.free(c);
            if (user.key_path) |k| allocator.free(k);
        }
        allocator.free(self.users);
    }
    
    /// Get the current context
    pub fn getCurrentContext(self: *const Kubeconfig) ?Context {
        return self.getContextByName(self.current_context);
    }
    
    /// Get context by name
    pub fn getContextByName(self: *const Kubeconfig, name: []const u8) ?Context {
        for (self.contexts) |context| {
            if (std.mem.eql(u8, context.name, name)) {
                return context;
            }
        }
        return null;
    }
    
    /// Get cluster by name
    pub fn getCluster(self: *const Kubeconfig, name: []const u8) ?Cluster {
        for (self.clusters) |cluster| {
            if (std.mem.eql(u8, cluster.name, name)) {
                return cluster;
            }
        }
        return null;
    }
    
    /// Get user by name
    pub fn getUser(self: *const Kubeconfig, name: []const u8) ?User {
        for (self.users) |user| {
            if (std.mem.eql(u8, user.name, name)) {
                return user;
            }
        }
        return null;
    }
};

pub const Cluster = struct {
    name: []const u8,
    server: []const u8,
};

pub const Context = struct {
    name: []const u8,
    cluster: []const u8,
    user: []const u8,
    namespace: ?[]const u8,
};

pub const User = struct {
    name: []const u8,
    token: ?[]const u8,
    cert_path: ?[]const u8,
    key_path: ?[]const u8,
};
