const std = @import("std");
const yaml = @import("yaml");

/// Cluster configuration from kubeconfig
pub const Cluster = struct {
    name: []const u8,
    server: []const u8,
    certificate_authority: ?[]const u8 = null,
    certificate_authority_data: ?[]const u8 = null,
    insecure_skip_tls_verify: ?bool = null,
};

/// Context configuration from kubeconfig
pub const Context = struct {
    name: []const u8,
    cluster: []const u8,
    user: []const u8,
    namespace: ?[]const u8 = null,
};

/// User configuration from kubeconfig
pub const ExecConfig = struct {
    command: ?[]const u8 = null,
    args: ?[][]const u8 = null,
    api_version: ?[]const u8 = null,

    pub fn deinit(self: *ExecConfig, allocator: std.mem.Allocator) void {
        if (self.command) |cmd| allocator.free(cmd);
        if (self.args) |args| {
            for (args) |arg| allocator.free(arg);
            allocator.free(args);
        }
        if (self.api_version) |v| allocator.free(v);
    }
};

pub const User = struct {
    name: []const u8,
    token: ?[]const u8 = null,
    client_certificate: ?[]const u8 = null,
    client_certificate_data: ?[]const u8 = null,
    client_key: ?[]const u8 = null,
    client_key_data: ?[]const u8 = null,
    username: ?[]const u8 = null,
    password: ?[]const u8 = null,
    exec: ?ExecConfig = null,
};

/// Parsed kubeconfig structure
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
            if (cluster.certificate_authority) |ca| allocator.free(ca);
            if (cluster.certificate_authority_data) |ca_data| allocator.free(ca_data);
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
            if (user.token) |token| allocator.free(token);
            if (user.client_certificate) |cert| allocator.free(cert);
            if (user.client_certificate_data) |cert_data| allocator.free(cert_data);
            if (user.client_key) |key| allocator.free(key);
            if (user.client_key_data) |key_data| allocator.free(key_data);
            if (user.username) |username| allocator.free(username);
            if (user.password) |password| allocator.free(password);
            if (user.exec) |*exec| {
                var e = exec.*;
                e.deinit(allocator);
            }
        }
        allocator.free(self.users);
    }

    pub fn getCurrentContext(self: *const Kubeconfig) ?Context {
        for (self.contexts) |context| {
            if (std.mem.eql(u8, context.name, self.current_context)) {
                return context;
            }
        }
        return null;
    }

    pub fn getContextByName(self: *const Kubeconfig, name: []const u8) ?Context {
        for (self.contexts) |context| {
            if (std.mem.eql(u8, context.name, name)) {
                return context;
            }
        }
        return null;
    }

    pub fn getClusterByName(self: *const Kubeconfig, name: []const u8) ?Cluster {
        for (self.clusters) |cluster| {
            if (std.mem.eql(u8, cluster.name, name)) {
                return cluster;
            }
        }
        return null;
    }

    pub fn getUserByName(self: *const Kubeconfig, name: []const u8) ?User {
        for (self.users) |user| {
            if (std.mem.eql(u8, user.name, name)) {
                return user;
            }
        }
        return null;
    }
};

/// Kubeconfig parser that reads directly from ~/.kube/config YAML file
pub const KubeconfigParser = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) KubeconfigParser {
        return .{ .allocator = allocator };
    }

    /// Load kubeconfig from default location (~/.kube/config)
    pub fn load(self: *KubeconfigParser) !Kubeconfig {
        const home = std.posix.getenv("HOME") orelse return error.HomeNotFound;
        const config_path = try std.fmt.allocPrint(self.allocator, "{s}/.kube/config", .{home});
        defer self.allocator.free(config_path);

        return self.loadFromPath(config_path);
    }

    /// Load kubeconfig from specific path
    pub fn loadFromPath(self: *KubeconfigParser, path: []const u8) !Kubeconfig {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const content = try file.readToEndAlloc(self.allocator, 10 * 1024 * 1024);
        defer self.allocator.free(content);

        return self.parseYaml(content);
    }

    /// Parse YAML kubeconfig content
    pub fn parseYaml(self: *KubeconfigParser, content: []const u8) !Kubeconfig {
        var parsed = yaml.Yaml{
            .source = content,
        };
        defer parsed.deinit(self.allocator);
        try parsed.load(self.allocator);

        if (parsed.docs.items.len == 0) return error.NoDocuments;
        const doc = parsed.docs.items[0];

        // doc is a Value, which can be .map
        const root_map = switch (doc) {
            .map => |m| m,
            else => return error.InvalidKubeconfigFormat,
        };

        var current_context: ?[]const u8 = null;
        var clusters = try std.ArrayList(Cluster).initCapacity(self.allocator, 0);
        var contexts = try std.ArrayList(Context).initCapacity(self.allocator, 0);
        var users = try std.ArrayList(User).initCapacity(self.allocator, 0);

        errdefer {
            if (current_context) |ctx| self.allocator.free(ctx);
            for (clusters.items) |cluster| {
                self.allocator.free(cluster.name);
                self.allocator.free(cluster.server);
                if (cluster.certificate_authority) |ca| self.allocator.free(ca);
                if (cluster.certificate_authority_data) |ca_data| self.allocator.free(ca_data);
            }
            clusters.deinit(self.allocator);
            for (contexts.items) |context| {
                self.allocator.free(context.name);
                self.allocator.free(context.cluster);
                self.allocator.free(context.user);
                if (context.namespace) |ns| self.allocator.free(ns);
            }
            contexts.deinit(self.allocator);
            for (users.items) |user| {
                self.allocator.free(user.name);
                if (user.token) |token| self.allocator.free(token);
                if (user.client_certificate) |cert| self.allocator.free(cert);
                if (user.client_certificate_data) |cert_data| self.allocator.free(cert_data);
                if (user.client_key) |key| self.allocator.free(key);
                if (user.client_key_data) |key_data| self.allocator.free(key_data);
                if (user.exec) |*exec| {
                    var e = exec.*;
                    e.deinit(self.allocator);
                }
            }
            users.deinit(self.allocator);
        }

        // Parse current-context
        if (root_map.get("current-context")) |value| {
            if (value.asScalar()) |scalar| {
                current_context = try self.allocator.dupe(u8, scalar);
            }
        }

        // Parse clusters
        if (root_map.get("clusters")) |value| {
            if (value.asList()) |list| {
                for (list) |cluster_item| {
                    const cluster = try self.parseCluster(cluster_item);
                    try clusters.append(self.allocator, cluster);
                }
            }
        }

        // Parse contexts
        if (root_map.get("contexts")) |value| {
            if (value.asList()) |list| {
                for (list) |context_item| {
                    const context = try self.parseContext(context_item);
                    try contexts.append(self.allocator, context);
                }
            }
        }

        // Parse users
        if (root_map.get("users")) |value| {
            if (value.asList()) |list| {
                for (list) |user_item| {
                    const user = try self.parseUser(user_item);
                    try users.append(self.allocator, user);
                }
            }
        }

        return Kubeconfig{
            .current_context = current_context orelse return error.NoCurrentContext,
            .clusters = try clusters.toOwnedSlice(self.allocator),
            .contexts = try contexts.toOwnedSlice(self.allocator),
            .users = try users.toOwnedSlice(self.allocator),
        };
    }

    fn parseCluster(self: *KubeconfigParser, value: yaml.Yaml.Value) !Cluster {
        const node_map = switch (value) {
            .map => |m| m,
            else => return error.InvalidClusterFormat,
        };

        var name: ?[]const u8 = null;
        var server: ?[]const u8 = null;
        var certificate_authority: ?[]const u8 = null;
        var certificate_authority_data: ?[]const u8 = null;
        var insecure_skip_tls_verify: ?bool = null;

        if (node_map.get("name")) |v| {
            if (v.asScalar()) |scalar| {
                name = try self.allocator.dupe(u8, scalar);
            }
        }

        if (node_map.get("cluster")) |cluster_value| {
            const cluster_map = switch (cluster_value) {
                .map => |m| m,
                else => return error.InvalidClusterFormat,
            };

            if (cluster_map.get("server")) |v| {
                if (v.asScalar()) |scalar| {
                    server = try self.allocator.dupe(u8, scalar);
                }
            }

            if (cluster_map.get("certificate-authority")) |v| {
                if (v.asScalar()) |scalar| {
                    certificate_authority = try self.allocator.dupe(u8, scalar);
                }
            }

            if (cluster_map.get("certificate-authority-data")) |v| {
                if (v.asScalar()) |scalar| {
                    certificate_authority_data = try self.allocator.dupe(u8, scalar);
                }
            }

            if (cluster_map.get("insecure-skip-tls-verify")) |v| {
                switch (v) {
                    .boolean => |b| insecure_skip_tls_verify = b,
                    else => {},
                }
            }
        }

        return Cluster{
            .name = name orelse return error.ClusterMissingName,
            .server = server orelse return error.ClusterMissingServer,
            .certificate_authority = certificate_authority,
            .certificate_authority_data = certificate_authority_data,
            .insecure_skip_tls_verify = insecure_skip_tls_verify,
        };
    }

    fn parseContext(self: *KubeconfigParser, value: yaml.Yaml.Value) !Context {
        const node_map = switch (value) {
            .map => |m| m,
            else => return error.InvalidContextFormat,
        };

        var name: ?[]const u8 = null;
        var cluster: ?[]const u8 = null;
        var user: ?[]const u8 = null;
        var namespace: ?[]const u8 = null;

        if (node_map.get("name")) |v| {
            if (v.asScalar()) |scalar| {
                name = try self.allocator.dupe(u8, scalar);
            }
        }

        if (node_map.get("context")) |context_value| {
            const context_map = switch (context_value) {
                .map => |m| m,
                else => return error.InvalidContextFormat,
            };

            if (context_map.get("cluster")) |v| {
                if (v.asScalar()) |scalar| {
                    cluster = try self.allocator.dupe(u8, scalar);
                }
            }

            if (context_map.get("user")) |v| {
                if (v.asScalar()) |scalar| {
                    user = try self.allocator.dupe(u8, scalar);
                }
            }

            if (context_map.get("namespace")) |v| {
                if (v.asScalar()) |scalar| {
                    namespace = try self.allocator.dupe(u8, scalar);
                }
            }
        }

        return Context{
            .name = name orelse return error.ContextMissingName,
            .cluster = cluster orelse return error.ContextMissingCluster,
            .user = user orelse return error.ContextMissingUser,
            .namespace = namespace,
        };
    }

    fn parseUser(self: *KubeconfigParser, value: yaml.Yaml.Value) !User {
        const node_map = switch (value) {
            .map => |m| m,
            else => return error.InvalidUserFormat,
        };

        var name: ?[]const u8 = null;
        var token: ?[]const u8 = null;
        var client_certificate: ?[]const u8 = null;
        var client_certificate_data: ?[]const u8 = null;
        var client_key: ?[]const u8 = null;
        var client_key_data: ?[]const u8 = null;
        var username: ?[]const u8 = null;
        var password: ?[]const u8 = null;

        if (node_map.get("name")) |v| {
            if (v.asScalar()) |scalar| {
                name = try self.allocator.dupe(u8, scalar);
            }
        }

        if (node_map.get("user")) |user_value| {
            const user_map = switch (user_value) {
                .map => |m| m,
                else => return error.InvalidUserFormat,
            };

            if (user_map.get("token")) |v| {
                if (v.asScalar()) |scalar| {
                    token = try self.allocator.dupe(u8, scalar);
                }
            }

            if (user_map.get("client-certificate")) |v| {
                if (v.asScalar()) |scalar| {
                    client_certificate = try self.allocator.dupe(u8, scalar);
                }
            }

            if (user_map.get("client-certificate-data")) |v| {
                if (v.asScalar()) |scalar| {
                    client_certificate_data = try self.allocator.dupe(u8, scalar);
                }
            }

            if (user_map.get("client-key")) |v| {
                if (v.asScalar()) |scalar| {
                    client_key = try self.allocator.dupe(u8, scalar);
                }
            }

            if (user_map.get("client-key-data")) |v| {
                if (v.asScalar()) |scalar| {
                    client_key_data = try self.allocator.dupe(u8, scalar);
                }
            }

            if (user_map.get("username")) |v| {
                if (v.asScalar()) |scalar| {
                    username = try self.allocator.dupe(u8, scalar);
                }
            }

            if (user_map.get("password")) |v| {
                if (v.asScalar()) |scalar| {
                    password = try self.allocator.dupe(u8, scalar);
                }
            }
        }

        // Parse exec config if present
        var exec_config: ?ExecConfig = null;
        if (node_map.get("user")) |user_value| {
            const user_map2 = switch (user_value) {
                .map => |m| m,
                else => null,
            };
            if (user_map2) |um| {
                if (um.get("exec")) |exec_value| {
                    const exec_map = switch (exec_value) {
                        .map => |m| m,
                        else => null,
                    };
                    if (exec_map) |em| {
                        var exec_cmd: ?[]const u8 = null;
                        var exec_api_version: ?[]const u8 = null;
                        var exec_args: ?[][]const u8 = null;

                        if (em.get("command")) |v| {
                            if (v.asScalar()) |scalar| {
                                exec_cmd = try self.allocator.dupe(u8, scalar);
                            }
                        }
                        if (em.get("apiVersion")) |v| {
                            if (v.asScalar()) |scalar| {
                                exec_api_version = try self.allocator.dupe(u8, scalar);
                            }
                        }
                        if (em.get("args")) |args_value| {
                            switch (args_value) {
                                .list => |list| {
                                    var args_list = std.ArrayListUnmanaged([]const u8){};
                                    for (list) |item| {
                                        if (item.asScalar()) |scalar| {
                                            try args_list.append(self.allocator, try self.allocator.dupe(u8, scalar));
                                        }
                                    }
                                    exec_args = try args_list.toOwnedSlice(self.allocator);
                                },
                                else => {},
                            }
                        }

                        exec_config = ExecConfig{
                            .command = exec_cmd,
                            .args = exec_args,
                            .api_version = exec_api_version,
                        };
                    }
                }
            }
        }

        return User{
            .name = name orelse return error.UserMissingName,
            .token = token,
            .client_certificate = client_certificate,
            .client_certificate_data = client_certificate_data,
            .client_key = client_key,
            .client_key_data = client_key_data,
            .username = username,
            .password = password,
            .exec = exec_config,
        };
    }
};
