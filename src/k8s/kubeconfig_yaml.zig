const std = @import("std");
const yaml = @import("yaml");

/// Portable getenv wrapper (std.posix.getenv removed in 0.16)
fn getenv(name: [*:0]const u8) ?[]const u8 {
    return if (std.c.getenv(name)) |p| std.mem.span(p) else null;
}

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

/// Exec credential-plugin configuration attached to a user.
pub const ExecConfig = struct {
    command: ?[]const u8 = null,
    args: ?[][]const u8 = null,
    api_version: ?[]const u8 = null,
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

// --- YAML wire types --------------------------------------------------------
// These mirror the kubeconfig file layout exactly (`clusters[].cluster.server`),
// which is NOT the flat shape the public structs above expose. Decoding into
// these and then projecting keeps the public API unchanged.
//
// Unknown keys are IGNORED on purpose: real kubeconfigs carry plenty we do not
// model (apiVersion, kind, preferences, extensions, proxy-url, tls-server-name,
// exec.env, exec.interactiveMode...). This library rejects unknown fields by
// default, so without this every real config would fail to parse.
const decode_options = yaml.ParseOptions{ .ignore_unknown_fields = true };

const WireClusterBody = struct {
    server: []const u8,
    certificate_authority: ?[]const u8 = null,
    certificate_authority_data: ?[]const u8 = null,
    insecure_skip_tls_verify: ?bool = null,

    pub const yaml_rename = .{
        .certificate_authority = "certificate-authority",
        .certificate_authority_data = "certificate-authority-data",
        .insecure_skip_tls_verify = "insecure-skip-tls-verify",
    };
};

const WireExec = struct {
    command: ?[]const u8 = null,
    args: ?[][]const u8 = null,
    api_version: ?[]const u8 = null,

    // apiVersion is camelCase here while sibling kubeconfig keys are kebab-case.
    pub const yaml_rename = .{ .api_version = "apiVersion" };
};

const WireUserBody = struct {
    token: ?[]const u8 = null,
    client_certificate: ?[]const u8 = null,
    client_certificate_data: ?[]const u8 = null,
    client_key: ?[]const u8 = null,
    client_key_data: ?[]const u8 = null,
    username: ?[]const u8 = null,
    password: ?[]const u8 = null,
    exec: ?WireExec = null,

    pub const yaml_rename = .{
        .client_certificate = "client-certificate",
        .client_certificate_data = "client-certificate-data",
        .client_key = "client-key",
        .client_key_data = "client-key-data",
    };
};

const WireContextBody = struct {
    cluster: []const u8,
    user: []const u8,
    namespace: ?[]const u8 = null,
};

const WireRoot = struct {
    current_context: ?[]const u8 = null,
    clusters: []const struct { name: []const u8, cluster: WireClusterBody } = &.{},
    contexts: []const struct { name: []const u8, context: WireContextBody } = &.{},
    users: []const struct { name: []const u8, user: WireUserBody = .{} } = &.{},

    pub const yaml_rename = .{ .current_context = "current-context" };
};

/// Parsed kubeconfig structure.
///
/// Every string and slice reachable from here is owned by `arena`; `deinit`
/// frees the whole graph in one shot. The arena is heap-allocated so that
/// returning a Kubeconfig by value never moves it.
pub const Kubeconfig = struct {
    current_context: []const u8,
    clusters: []Cluster,
    contexts: []Context,
    users: []User,
    arena: *std.heap.ArenaAllocator,

    /// `allocator` is accepted for API compatibility and intentionally unused:
    /// the arena already knows the allocator it was created from, so passing a
    /// mismatched one cannot corrupt the free.
    pub fn deinit(self: *Kubeconfig, allocator: std.mem.Allocator) void {
        _ = allocator;
        const arena = self.arena;
        const child = arena.child_allocator;
        arena.deinit();
        child.destroy(arena);
    }

    pub fn getCurrentContext(self: *const Kubeconfig) ?Context {
        return self.getContextByName(self.current_context);
    }

    pub fn getContextByName(self: *const Kubeconfig, name: []const u8) ?Context {
        for (self.contexts) |context| {
            if (std.mem.eql(u8, context.name, name)) return context;
        }
        return null;
    }

    pub fn getClusterByName(self: *const Kubeconfig, name: []const u8) ?Cluster {
        for (self.clusters) |cluster| {
            if (std.mem.eql(u8, cluster.name, name)) return cluster;
        }
        return null;
    }

    pub fn getUserByName(self: *const Kubeconfig, name: []const u8) ?User {
        for (self.users) |user| {
            if (std.mem.eql(u8, user.name, name)) return user;
        }
        return null;
    }
};

/// Kubeconfig parser that reads directly from ~/.kube/config YAML file
pub const KubeconfigParser = struct {
    allocator: std.mem.Allocator,
    io: std.Io,

    pub fn init(allocator: std.mem.Allocator, io: std.Io) KubeconfigParser {
        return .{ .allocator = allocator, .io = io };
    }

    /// Load kubeconfig from KUBECONFIG env var or default location (~/.kube/config)
    pub fn load(self: *KubeconfigParser) !Kubeconfig {
        // Respect KUBECONFIG environment variable (used by kubectx, kubeswitch, etc.)
        if (getenv("KUBECONFIG")) |kc| {
            if (kc.len > 0) {
                // KUBECONFIG can be colon-separated; use the first path
                const first_path = if (std.mem.indexOf(u8, kc, ":")) |sep|
                    kc[0..sep]
                else
                    kc;
                return self.loadFromPath(first_path);
            }
        }

        const home = getenv("HOME") orelse return error.HomeNotFound;
        const config_path = try std.fmt.allocPrint(self.allocator, "{s}/.kube/config", .{home});
        defer self.allocator.free(config_path);

        return self.loadFromPath(config_path);
    }

    /// Load kubeconfig from specific path
    pub fn loadFromPath(self: *KubeconfigParser, path: []const u8) !Kubeconfig {
        const file = try std.Io.Dir.cwd().openFile(self.io, path, .{});
        defer file.close(self.io);

        var buf: [4096]u8 = undefined;
        var reader = file.reader(self.io, &buf);
        const size = try reader.getSize();
        const read_len = @min(@as(usize, @intCast(size)), 10 * 1024 * 1024);
        const content = try reader.interface.readAlloc(self.allocator, read_len);
        defer self.allocator.free(content);

        return self.parseYaml(content);
    }

    /// Parse YAML kubeconfig content
    pub fn parseYaml(self: *KubeconfigParser, content: []const u8) !Kubeconfig {
        const arena = try self.allocator.create(std.heap.ArenaAllocator);
        errdefer self.allocator.destroy(arena);
        arena.* = std.heap.ArenaAllocator.init(self.allocator);
        errdefer arena.deinit();

        const a = arena.allocator();

        // This parser is zero-copy: decoded scalars borrow from the source
        // buffer rather than being duplicated. `content` is owned by the caller
        // (loadFromPath frees it on return; the fuzz harness passes a stack
        // buffer), so it must be copied into the arena first or every string in
        // the returned Kubeconfig dangles.
        const owned_content = try a.dupe(u8, content);
        const root = try yaml.parseInto(WireRoot, a, owned_content, decode_options);

        const clusters = try a.alloc(Cluster, root.clusters.len);
        for (root.clusters, clusters) |src, *dst| dst.* = .{
            .name = src.name,
            .server = src.cluster.server,
            .certificate_authority = src.cluster.certificate_authority,
            .certificate_authority_data = src.cluster.certificate_authority_data,
            .insecure_skip_tls_verify = src.cluster.insecure_skip_tls_verify,
        };

        const contexts = try a.alloc(Context, root.contexts.len);
        for (root.contexts, contexts) |src, *dst| dst.* = .{
            .name = src.name,
            .cluster = src.context.cluster,
            .user = src.context.user,
            .namespace = src.context.namespace,
        };

        const users = try a.alloc(User, root.users.len);
        for (root.users, users) |src, *dst| dst.* = .{
            .name = src.name,
            .token = src.user.token,
            .client_certificate = src.user.client_certificate,
            .client_certificate_data = src.user.client_certificate_data,
            .client_key = src.user.client_key,
            .client_key_data = src.user.client_key_data,
            .username = src.user.username,
            .password = src.user.password,
            .exec = if (src.user.exec) |e| ExecConfig{
                .command = e.command,
                .args = e.args,
                .api_version = e.api_version,
            } else null,
        };

        return Kubeconfig{
            .current_context = root.current_context orelse return error.NoCurrentContext,
            .clusters = clusters,
            .contexts = contexts,
            .users = users,
            .arena = arena,
        };
    }
};
