const std = @import("std");
const Io = std.Io;

/// Standard paths for service account files in Kubernetes pods
pub const ServiceAccountPaths = struct {
    /// Service account token file
    pub const token = "/var/run/secrets/kubernetes.io/serviceaccount/token";

    /// CA certificate file
    pub const ca_cert = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt";

    /// Namespace file
    pub const namespace = "/var/run/secrets/kubernetes.io/serviceaccount/namespace";
};

/// Environment variables used for in-cluster configuration
pub const EnvVars = struct {
    /// Kubernetes service host
    pub const host = "KUBERNETES_SERVICE_HOST";

    /// Kubernetes service port
    pub const port = "KUBERNETES_SERVICE_PORT";
};

/// In-cluster configuration loaded from service account files
pub const InClusterConfig = struct {
    /// API server URL
    server: []const u8,

    /// Service account token for authentication
    token: []const u8,

    /// CA certificate data for TLS verification
    ca_cert_data: []const u8,

    /// Namespace the pod is running in
    namespace: []const u8,

    allocator: std.mem.Allocator,

    pub fn deinit(self: *InClusterConfig) void {
        self.allocator.free(self.server);
        self.allocator.free(self.token);
        self.allocator.free(self.ca_cert_data);
        self.allocator.free(self.namespace);
    }
};

/// Read the entire contents of a file opened via Io.Dir.openFileAbsolute into a
/// newly-allocated slice.  `max_bytes` caps the allocation to guard against
/// unexpectedly large files.
fn readFileAlloc(
    io: Io,
    file: Io.File,
    allocator: std.mem.Allocator,
    max_bytes: usize,
) ![]u8 {
    var buf: [4096]u8 = undefined;
    var file_reader = file.reader(io, &buf);
    const size = try file_reader.getSize();
    const read_len = @min(@as(usize, @intCast(size)), max_bytes);
    return file_reader.interface.readAlloc(allocator, read_len);
}

/// Load in-cluster configuration from service account files
/// This function reads the standard Kubernetes service account files
/// and environment variables to construct client configuration
pub fn loadInClusterConfig(io: Io, allocator: std.mem.Allocator) !InClusterConfig {
    // Read service account token
    const token_file = Io.Dir.openFileAbsolute(io, ServiceAccountPaths.token, .{}) catch {
        return error.ServiceAccountTokenNotFound;
    };
    defer token_file.close(io);

    const token = readFileAlloc(io, token_file, allocator, 64 * 1024) catch { // 64KB max
        return error.ServiceAccountTokenNotFound;
    };
    errdefer allocator.free(token);

    // Trim whitespace from token
    const trimmed_token = std.mem.trim(u8, token, &std.ascii.whitespace);
    const final_token = try allocator.dupe(u8, trimmed_token);
    allocator.free(token);
    errdefer allocator.free(final_token);

    // Read CA certificate
    const ca_file = Io.Dir.openFileAbsolute(io, ServiceAccountPaths.ca_cert, .{}) catch {
        return error.ServiceAccountCANotFound;
    };
    defer ca_file.close(io);

    const ca_cert_data = readFileAlloc(io, ca_file, allocator, 10 * 1024 * 1024) catch { // 10MB max
        return error.ServiceAccountCANotFound;
    };
    errdefer allocator.free(ca_cert_data);

    // Read namespace
    const ns_file = Io.Dir.openFileAbsolute(io, ServiceAccountPaths.namespace, .{}) catch {
        return error.ServiceAccountNamespaceNotFound;
    };
    defer ns_file.close(io);

    const ns_data = readFileAlloc(io, ns_file, allocator, 1024) catch { // 1KB max
        return error.ServiceAccountNamespaceNotFound;
    };
    defer allocator.free(ns_data);

    const trimmed_ns = std.mem.trim(u8, ns_data, &std.ascii.whitespace);
    const namespace = try allocator.dupe(u8, trimmed_ns);
    errdefer allocator.free(namespace);

    // Get Kubernetes service host and port from environment
    const host = if (std.c.getenv(EnvVars.host)) |p| std.mem.span(p) else {
        return error.KubernetesServiceHostNotSet;
    };

    const port = if (std.c.getenv(EnvVars.port)) |p| std.mem.span(p) else {
        return error.KubernetesServicePortNotSet;
    };

    // Construct API server URL
    const server = try std.fmt.allocPrint(
        allocator,
        "https://{s}:{s}",
        .{ host, port },
    );
    errdefer allocator.free(server);

    return InClusterConfig{
        .server = server,
        .token = final_token,
        .ca_cert_data = ca_cert_data,
        .namespace = namespace,
        .allocator = allocator,
    };
}

/// Check if running inside a Kubernetes cluster
/// Returns true if service account files are present
pub fn isInCluster(io: Io) bool {
    // Check if token file exists
    const token_file = Io.Dir.openFileAbsolute(io, ServiceAccountPaths.token, .{}) catch {
        return false;
    };
    token_file.close(io);

    // Check if environment variables are set
    return std.c.getenv(EnvVars.host) != null and
        std.c.getenv(EnvVars.port) != null;
}

/// Get default Kubernetes API server URL when running in-cluster
pub fn getDefaultServer(allocator: std.mem.Allocator) ![]const u8 {
    const host = if (std.c.getenv(EnvVars.host)) |p| std.mem.span(p) else {
        return error.KubernetesServiceHostNotSet;
    };

    const port = if (std.c.getenv(EnvVars.port)) |p| std.mem.span(p) else {
        return error.KubernetesServicePortNotSet;
    };

    return try std.fmt.allocPrint(
        allocator,
        "https://{s}:{s}",
        .{ host, port },
    );
}

/// Get service account token
pub fn getServiceAccountToken(io: Io, allocator: std.mem.Allocator) ![]const u8 {
    const token_file = Io.Dir.openFileAbsolute(io, ServiceAccountPaths.token, .{}) catch {
        return error.ServiceAccountTokenNotFound;
    };
    defer token_file.close(io);

    const token = readFileAlloc(io, token_file, allocator, 64 * 1024) catch { // 64KB max
        return error.ServiceAccountTokenNotFound;
    };
    defer allocator.free(token);

    const trimmed = std.mem.trim(u8, token, &std.ascii.whitespace);
    return try allocator.dupe(u8, trimmed);
}

/// Get service account CA certificate
pub fn getServiceAccountCA(io: Io, allocator: std.mem.Allocator) ![]const u8 {
    const ca_file = Io.Dir.openFileAbsolute(io, ServiceAccountPaths.ca_cert, .{}) catch {
        return error.ServiceAccountCANotFound;
    };
    defer ca_file.close(io);

    return readFileAlloc(io, ca_file, allocator, 10 * 1024 * 1024); // 10MB max
}

/// Get service account namespace
pub fn getServiceAccountNamespace(io: Io, allocator: std.mem.Allocator) ![]const u8 {
    const ns_file = Io.Dir.openFileAbsolute(io, ServiceAccountPaths.namespace, .{}) catch {
        return error.ServiceAccountNamespaceNotFound;
    };
    defer ns_file.close(io);

    const ns_data = readFileAlloc(io, ns_file, allocator, 1024) catch { // 1KB max
        return error.ServiceAccountNamespaceNotFound;
    };
    defer allocator.free(ns_data);

    const trimmed = std.mem.trim(u8, ns_data, &std.ascii.whitespace);
    return try allocator.dupe(u8, trimmed);
}
