const std = @import("std");
const K8sClient = @import("client.zig").K8sClient;

/// Attempt to connect to Kubernetes with automatic proxy fallback
/// Returns an initialized client - caller must call deinit()
pub fn connectWithFallback(
    allocator: std.mem.Allocator,
    server: []const u8,
    token: ?[]const u8,
    namespace: ?[]const u8,
) !K8sClient {
    // If server is already HTTP (proxy), use it directly
    if (std.mem.startsWith(u8, server, "http://")) {
        return K8sClient.init(allocator, .{
            .server = server,
            .token = null, // No token needed for HTTP proxy
            .namespace = namespace,
        });
    }

    // Try direct HTTPS connection first
    var direct_client = K8sClient.init(allocator, .{
        .server = server,
        .token = token,
        .namespace = namespace,
    }) catch |err| {
        // Direct connection failed, try proxy
        if (tryProxyConnection(allocator, namespace)) |proxy_client| {
            return proxy_client;
        } else |_| {
            return err; // Return original error
        }
    };

    // Test the connection
    _ = direct_client.getClusterInfo() catch |err| {
        direct_client.deinit();
        // Connection test failed, try proxy
        if (tryProxyConnection(allocator, namespace)) |proxy_client| {
            return proxy_client;
        } else |_| {
            return err;
        }
    };

    return direct_client;
}

/// Try to connect via kubectl proxy
fn tryProxyConnection(allocator: std.mem.Allocator, namespace: ?[]const u8) !K8sClient {
    const proxy_urls = [_][]const u8{
        "http://127.0.0.1:8080",
        "http://localhost:8080",
        "http://127.0.0.1:8001",
        "http://localhost:8001",
    };

    for (proxy_urls) |proxy_url| {
        var client = K8sClient.init(allocator, .{
            .server = proxy_url,
            .token = null,
            .namespace = namespace,
        }) catch continue;

        // Test connection
        const cluster_info = client.getClusterInfo() catch {
            client.deinit();
            continue;
        };

        // Free the cluster info (it allocates k8s_version string)
        allocator.free(cluster_info.k8s_version);

        // Success
        return client;
    }

    return error.NoProxyAvailable;
}

/// Check if kubectl proxy is running on standard ports
pub fn isProxyRunning(allocator: std.mem.Allocator) bool {
    const proxy_urls = [_][]const u8{
        "http://127.0.0.1:8080",
        "http://localhost:8080",
    };

    for (proxy_urls) |proxy_url| {
        var client = K8sClient.init(allocator, .{
            .server = proxy_url,
            .token = null,
            .namespace = "default",
        }) catch continue;
        defer client.deinit();

        _ = client.getClusterInfo() catch continue;
        return true;
    }

    return false;
}

/// Get kubectl proxy URL if running, null otherwise
pub fn getProxyUrl(allocator: std.mem.Allocator) ?[]const u8 {
    const proxy_urls = [_][]const u8{
        "http://127.0.0.1:8080",
        "http://localhost:8080",
        "http://127.0.0.1:8001",
        "http://localhost:8001",
    };

    for (proxy_urls) |proxy_url| {
        var client = K8sClient.init(allocator, .{
            .server = proxy_url,
            .token = null,
            .namespace = "default",
        }) catch continue;
        defer client.deinit();

        _ = client.getClusterInfo() catch continue;
        return proxy_url;
    }

    return null;
}
