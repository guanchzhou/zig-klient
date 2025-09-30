const std = @import("std");

/// JSON structures matching kubectl config view -o json output
const KubeconfigJson = struct {
    @"current-context": []const u8,
    clusters: []ClusterItem,
    contexts: []ContextItem,
    users: []UserItem,
    
    const ClusterItem = struct {
        name: []const u8,
        cluster: struct {
            server: []const u8,
            @"certificate-authority-data": ?[]const u8 = null,
        },
    };
    
    const ContextItem = struct {
        name: []const u8,
        context: struct {
            cluster: []const u8,
            user: []const u8,
            namespace: ?[]const u8 = null,
        },
    };
    
    const UserItem = struct {
        name: []const u8,
        user: ?struct {
            token: ?[]const u8 = null,
            @"client-certificate-data": ?[]const u8 = null,
            @"client-key-data": ?[]const u8 = null,
        } = null,
    };
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
    
    pub fn getCurrentContext(self: *const Kubeconfig) ?Context {
        return self.getContextByName(self.current_context);
    }
    
    pub fn getContextByName(self: *const Kubeconfig, name: []const u8) ?Context {
        for (self.contexts) |context| {
            if (std.mem.eql(u8, context.name, name)) {
                return context;
            }
        }
        return null;
    }
    
    pub fn getCluster(self: *const Kubeconfig, name: []const u8) ?Cluster {
        for (self.clusters) |cluster| {
            if (std.mem.eql(u8, cluster.name, name)) {
                return cluster;
            }
        }
        return null;
    }
    
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
    exec_config: ?std.json.Value = null, // Exec credential config
};

pub const KubeconfigParser = struct {
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator) KubeconfigParser {
        return .{ .allocator = allocator };
    }
    
    pub fn load(self: *KubeconfigParser) !Kubeconfig {
        // Logging: User can wrap this call if needed
        
        // Run kubectl to get JSON output
        var child = std.process.Child.init(&[_][]const u8{
            "kubectl", "config", "view", "-o", "json",
        }, self.allocator);
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Ignore;
        
        try child.spawn();
        
        const stdout = try child.stdout.?.readToEndAlloc(self.allocator, 10 * 1024 * 1024);
        defer self.allocator.free(stdout);
        
        const term = try child.wait();
        if (term != .Exited or term.Exited != 0) {
            return error.KubectlFailed;
        }
        
        // Parse JSON (ignore unknown fields like apiVersion, kind, etc.)
        const parsed = try std.json.parseFromSlice(
            KubeconfigJson,
            self.allocator,
            stdout,
            .{ 
                .allocate = .alloc_always,
                .ignore_unknown_fields = true,
            },
        );
        defer parsed.deinit();
        
        const json = parsed.value;
        
        // Convert to our Kubeconfig format
        var clusters = try self.allocator.alloc(Cluster, json.clusters.len);
        for (json.clusters, 0..) |cluster, i| {
            clusters[i] = Cluster{
                .name = try self.allocator.dupe(u8, cluster.name),
                .server = try self.allocator.dupe(u8, cluster.cluster.server),
            };
        }
        
        var contexts = try self.allocator.alloc(Context, json.contexts.len);
        for (json.contexts, 0..) |context, i| {
            contexts[i] = Context{
                .name = try self.allocator.dupe(u8, context.name),
                .cluster = try self.allocator.dupe(u8, context.context.cluster),
                .user = try self.allocator.dupe(u8, context.context.user),
                .namespace = if (context.context.namespace) |ns| 
                    try self.allocator.dupe(u8, ns) 
                else 
                    null,
            };
        }
        
        var users = try self.allocator.alloc(User, json.users.len);
        for (json.users, 0..) |user, i| {
            users[i] = User{
                .name = try self.allocator.dupe(u8, user.name),
                .token = if (user.user) |u|
                    if (u.token) |t| try self.allocator.dupe(u8, t) else null
                else
                    null,
                .cert_path = null, // kubectl doesn't expose this in JSON view
                .key_path = null,  // kubectl doesn't expose this in JSON view
            };
        }
        
        return Kubeconfig{
            .current_context = try self.allocator.dupe(u8, json.@"current-context"),
            .clusters = clusters,
            .contexts = contexts,
            .users = users,
        };
    }
};
