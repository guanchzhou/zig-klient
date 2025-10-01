const std = @import("std");

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

/// Load in-cluster configuration from service account files
/// This function reads the standard Kubernetes service account files
/// and environment variables to construct client configuration
pub fn loadInClusterConfig(allocator: std.mem.Allocator) !InClusterConfig {
    // Read service account token
    const token_file = std.fs.openFileAbsolute(ServiceAccountPaths.token, .{}) catch {
        return error.ServiceAccountTokenNotFound;
    };
    defer token_file.close();

    const token = try token_file.readToEndAlloc(allocator, 64 * 1024); // 64KB max
    errdefer allocator.free(token);

    // Trim whitespace from token
    const trimmed_token = std.mem.trim(u8, token, &std.ascii.whitespace);
    const final_token = try allocator.dupe(u8, trimmed_token);
    allocator.free(token);
    errdefer allocator.free(final_token);

    // Read CA certificate
    const ca_file = std.fs.openFileAbsolute(ServiceAccountPaths.ca_cert, .{}) catch {
        return error.ServiceAccountCANotFound;
    };
    defer ca_file.close();

    const ca_cert_data = try ca_file.readToEndAlloc(allocator, 10 * 1024 * 1024); // 10MB max
    errdefer allocator.free(ca_cert_data);

    // Read namespace
    const ns_file = std.fs.openFileAbsolute(ServiceAccountPaths.namespace, .{}) catch {
        return error.ServiceAccountNamespaceNotFound;
    };
    defer ns_file.close();

    const ns_data = try ns_file.readToEndAlloc(allocator, 1024); // 1KB max
    defer allocator.free(ns_data);

    const trimmed_ns = std.mem.trim(u8, ns_data, &std.ascii.whitespace);
    const namespace = try allocator.dupe(u8, trimmed_ns);
    errdefer allocator.free(namespace);

    // Get Kubernetes service host and port from environment
    const host = std.posix.getenv(EnvVars.host) orelse {
        return error.KubernetesServiceHostNotSet;
    };

    const port = std.posix.getenv(EnvVars.port) orelse {
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
pub fn isInCluster() bool {
    // Check if token file exists
    const token_file = std.fs.openFileAbsolute(ServiceAccountPaths.token, .{}) catch {
        return false;
    };
    token_file.close();

    // Check if environment variables are set
    const host = std.posix.getenv(EnvVars.host);
    const port = std.posix.getenv(EnvVars.port);

    return host != null and port != null;
}

/// Get default Kubernetes API server URL when running in-cluster
pub fn getDefaultServer(allocator: std.mem.Allocator) ![]const u8 {
    const host = std.posix.getenv(EnvVars.host) orelse {
        return error.KubernetesServiceHostNotSet;
    };

    const port = std.posix.getenv(EnvVars.port) orelse {
        return error.KubernetesServicePortNotSet;
    };

    return try std.fmt.allocPrint(
        allocator,
        "https://{s}:{s}",
        .{ host, port },
    );
}

/// Get service account token
pub fn getServiceAccountToken(allocator: std.mem.Allocator) ![]const u8 {
    const token_file = std.fs.openFileAbsolute(ServiceAccountPaths.token, .{}) catch {
        return error.ServiceAccountTokenNotFound;
    };
    defer token_file.close();

    const token = try token_file.readToEndAlloc(allocator, 64 * 1024); // 64KB max
    defer allocator.free(token);

    const trimmed = std.mem.trim(u8, token, &std.ascii.whitespace);
    return try allocator.dupe(u8, trimmed);
}

/// Get service account CA certificate
pub fn getServiceAccountCA(allocator: std.mem.Allocator) ![]const u8 {
    const ca_file = std.fs.openFileAbsolute(ServiceAccountPaths.ca_cert, .{}) catch {
        return error.ServiceAccountCANotFound;
    };
    defer ca_file.close();

    return try ca_file.readToEndAlloc(allocator, 10 * 1024 * 1024); // 10MB max
}

/// Get service account namespace
pub fn getServiceAccountNamespace(allocator: std.mem.Allocator) ![]const u8 {
    const ns_file = std.fs.openFileAbsolute(ServiceAccountPaths.namespace, .{}) catch {
        return error.ServiceAccountNamespaceNotFound;
    };
    defer ns_file.close();

    const ns_data = try ns_file.readToEndAlloc(allocator, 1024); // 1KB max
    defer allocator.free(ns_data);

    const trimmed = std.mem.trim(u8, ns_data, &std.ascii.whitespace);
    return try allocator.dupe(u8, trimmed);
}
