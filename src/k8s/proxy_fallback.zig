const std = @import("std");
const K8sClient = @import("client.zig").K8sClient;

const proxy_urls = [_][]const u8{
    "http://127.0.0.1:8080",
    "http://localhost:8080",
    "http://127.0.0.1:8001",
    "http://localhost:8001",
};

/// Try connecting to a single URL. Returns a live-tested client or null.
/// On success, caller owns the client (must call deinit).
fn tryConnect(allocator: std.mem.Allocator, io: std.Io, url: []const u8, namespace: ?[]const u8) ?K8sClient {
    var client = K8sClient.init(allocator, io, .{
        .server = url,
        .token = null,
        .namespace = namespace,
    }) catch return null;

    const info = client.getClusterInfo() catch {
        client.deinit();
        return null;
    };
    allocator.free(info.k8s_version);

    return client;
}

/// Attempt to connect to Kubernetes with automatic proxy fallback.
/// Returns an initialized client — caller must call deinit().
pub fn connectWithFallback(
    allocator: std.mem.Allocator,
    io: std.Io,
    server: []const u8,
    token: ?[]const u8,
    namespace: ?[]const u8,
) !K8sClient {
    // If server is already HTTP (proxy), use it directly
    if (std.mem.startsWith(u8, server, "http://")) {
        return K8sClient.init(allocator, io, .{
            .server = server,
            .token = null,
            .namespace = namespace,
        });
    }

    // Try direct HTTPS connection first
    var direct_client = K8sClient.init(allocator, io, .{
        .server = server,
        .token = token,
        .namespace = namespace,
    }) catch |err| {
        return tryProxyConnection(allocator, io, namespace) orelse return err;
    };

    // Test the connection
    _ = direct_client.getClusterInfo() catch |err| {
        direct_client.deinit();
        return tryProxyConnection(allocator, io, namespace) orelse return err;
    };

    return direct_client;
}

/// Try to connect via kubectl proxy on standard ports.
fn tryProxyConnection(allocator: std.mem.Allocator, io: std.Io, namespace: ?[]const u8) ?K8sClient {
    for (proxy_urls) |url| {
        if (tryConnect(allocator, io, url, namespace)) |client| return client;
    }
    return null;
}

/// Check if kubectl proxy is running on standard ports.
pub fn isProxyRunning(allocator: std.mem.Allocator, io: std.Io) bool {
    // Only check the two most common proxy ports
    for (proxy_urls[0..2]) |url| {
        if (tryConnect(allocator, io, url, "default")) |*client| {
            var c = client.*;
            c.deinit();
            return true;
        }
    }
    return false;
}

/// Get kubectl proxy URL if running, null otherwise.
pub fn getProxyUrl(allocator: std.mem.Allocator, io: std.Io) ?[]const u8 {
    for (proxy_urls) |url| {
        if (tryConnect(allocator, io, url, "default")) |*client| {
            var c = client.*;
            c.deinit();
            return url;
        }
    }
    return null;
}
