const std = @import("std");
const klient = @import("klient");

/// Zig 0.16: executables need a concrete std.Io to pass into HTTP/TLS/file APIs.
/// Callers own the returned Threaded and must call deinit() before exiting.
pub fn initIo(allocator: std.mem.Allocator) std.Io.Threaded {
    return std.Io.Threaded.init(allocator, .{});
}

/// Initialize K8sClient from default kubeconfig (~/.kube/config)
pub fn initClientFromKubeconfig(allocator: std.mem.Allocator, io: std.Io) !klient.K8sClient {
    // Parse kubeconfig
    var parser = klient.KubeconfigParser.init(allocator, io);
    var config = try parser.load();
    defer config.deinit(allocator);

    // Get current context
    const context = config.getCurrentContext() orelse return error.NoCurrentContext;
    const cluster = config.getClusterByName(context.cluster) orelse return error.ClusterNotFound;
    const user = config.getUserByName(context.user) orelse return error.UserNotFound;

    // Build TLS config from the cluster CA and (for cert-auth clusters like
    // Rancher Desktop) the user's client certificate / key.
    var tls_config: ?klient.TlsConfig = null;
    {
        var cfg = klient.TlsConfig{};
        var configured = false;

        if (cluster.certificate_authority_data) |ca_b64| {
            cfg.ca_cert_data = try decodeBase64(allocator, ca_b64);
            configured = true;
        } else if (cluster.certificate_authority) |ca_path| {
            cfg.ca_cert_path = ca_path;
            configured = true;
        }

        if (user.client_certificate_data) |cert_b64| {
            cfg.client_cert_data = try decodeBase64(allocator, cert_b64);
            configured = true;
        } else if (user.client_certificate) |cert_path| {
            cfg.client_cert_path = cert_path;
            configured = true;
        }

        if (user.client_key_data) |key_b64| {
            cfg.client_key_data = try decodeBase64(allocator, key_b64);
            configured = true;
        } else if (user.client_key) |key_path| {
            cfg.client_key_path = key_path;
            configured = true;
        }

        if (configured) tls_config = cfg;
    }

    // Create client config
    const client_config = klient.K8sClient.Config{
        .server = cluster.server,
        .token = user.token,
        .namespace = context.namespace orelse "default",
        .tls_config = tls_config,
    };

    return try klient.K8sClient.init(allocator, io, client_config);
}

/// Decode base64-encoded data (e.g. certificate-authority-data from kubeconfig)
fn decodeBase64(allocator: std.mem.Allocator, b64: []const u8) ![]const u8 {
    const decoder = std.base64.standard.Decoder;
    const size = try decoder.calcSizeForSlice(b64);
    const buf = try allocator.alloc(u8, size);
    try decoder.decode(buf, b64);
    return buf;
}
