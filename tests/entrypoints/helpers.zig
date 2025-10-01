const std = @import("std");
const klient = @import("klient");

/// Initialize K8sClient from default kubeconfig (~/.kube/config)
pub fn initClientFromKubeconfig(allocator: std.mem.Allocator) !klient.K8sClient {
    // Parse kubeconfig
    var parser = klient.KubeconfigParser.init(allocator);
    var config = try parser.load();
    defer config.deinit(allocator);

    // Get current context
    const context = config.getCurrentContext() orelse return error.NoCurrentContext;
    const cluster = config.getClusterByName(context.cluster) orelse return error.ClusterNotFound;
    const user = config.getUserByName(context.user) orelse return error.UserNotFound;

    // Create client config
    const client_config = klient.K8sClient.Config{
        .server = cluster.server,
        .token = user.token,
        .namespace = context.namespace orelse "default",
        // TLS config would be added here if needed
        // For rancher-desktop with http:// this is not required
    };

    return try klient.K8sClient.init(allocator, client_config);
}
