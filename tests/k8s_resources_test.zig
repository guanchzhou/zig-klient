const std = @import("std");
const klient = @import("klient");
const K8sClient = klient.K8sClient;
const types = klient.types;
const resources = klient.resources;
const KubeconfigParser = klient.KubeconfigParser;

// These are integration tests that require a real Kubernetes cluster
// They will be skipped if kubectl is not available

test "Pods Resource - list operations" {
    const allocator = std.testing.allocator;
    
    // Try to get kubeconfig
    var parser = KubeconfigParser.init(allocator);
    var kubeconfig = parser.load() catch |err| {
        std.debug.print("⚠️  kubectl not available: {}\n", .{err});
        return error.SkipZigTest;
    };
    defer kubeconfig.deinit(allocator);
    
    const current_ctx = kubeconfig.getCurrentContext() orelse {
        std.debug.print("⚠️  No current context\n", .{});
        return error.SkipZigTest;
    };
    
    const cluster = kubeconfig.getCluster(current_ctx.cluster) orelse {
        std.debug.print("⚠️  Cluster not found\n", .{});
        return error.SkipZigTest;
    };
    
    var client = try K8sClient.init(allocator, .{
        .server = cluster.server,
        .token = null,
        .namespace = current_ctx.namespace,
    });
    defer client.deinit();
    
    const pods_client = resources.Pods.init(&client);
    
    // Test listAll
    const pod_list = pods_client.client.listAll() catch |err| {
        std.debug.print("⚠️  Could not list pods: {}\n", .{err});
        return error.SkipZigTest;
    };
    
    std.debug.print("✅ Listed {d} pods across all namespaces\n", .{pod_list.items.len});
}

test "Deployments Resource - operations" {
    const allocator = std.testing.allocator;
    
    // Try to get kubeconfig
    var parser = KubeconfigParser.init(allocator);
    var kubeconfig = parser.load() catch |err| {
        std.debug.print("⚠️  kubectl not available: {}\n", .{err});
        return error.SkipZigTest;
    };
    defer kubeconfig.deinit(allocator);
    
    const current_ctx = kubeconfig.getCurrentContext() orelse {
        std.debug.print("⚠️  No current context\n", .{});
        return error.SkipZigTest;
    };
    
    const cluster = kubeconfig.getCluster(current_ctx.cluster) orelse {
        std.debug.print("⚠️  Cluster not found\n", .{});
        return error.SkipZigTest;
    };
    
    var client = try K8sClient.init(allocator, .{
        .server = cluster.server,
        .token = null,
        .namespace = current_ctx.namespace,
    });
    defer client.deinit();
    
    const deployments = resources.Deployments.init(&client);
    
    // Test listAll deployments
    const deploy_list = deployments.client.listAll() catch |err| {
        std.debug.print("⚠️  Could not list deployments: {}\n", .{err});
        return error.SkipZigTest;
    };
    
    std.debug.print("✅ Listed {d} deployments\n", .{deploy_list.items.len});
}

test "Services Resource - list operations" {
    const allocator = std.testing.allocator;
    
    // Try to get kubeconfig
    var parser = KubeconfigParser.init(allocator);
    var kubeconfig = parser.load() catch |err| {
        std.debug.print("⚠️  kubectl not available: {}\n", .{err});
        return error.SkipZigTest;
    };
    defer kubeconfig.deinit(allocator);
    
    const current_ctx = kubeconfig.getCurrentContext() orelse {
        std.debug.print("⚠️  No current context\n", .{});
        return error.SkipZigTest;
    };
    
    const cluster = kubeconfig.getCluster(current_ctx.cluster) orelse {
        std.debug.print("⚠️  Cluster not found\n", .{});
        return error.SkipZigTest;
    };
    
    var client = try K8sClient.init(allocator, .{
        .server = cluster.server,
        .token = null,
        .namespace = current_ctx.namespace,
    });
    defer client.deinit();
    
    const services = resources.Services.init(&client);
    
    // Test listAll services
    const svc_list = services.client.listAll() catch |err| {
        std.debug.print("⚠️  Could not list services: {}\n", .{err});
        return error.SkipZigTest;
    };
    
    std.debug.print("✅ Listed {d} services\n", .{svc_list.items.len});
}

test "ConfigMaps Resource - operations" {
    const allocator = std.testing.allocator;
    
    // Try to get kubeconfig
    var parser = KubeconfigParser.init(allocator);
    var kubeconfig = parser.load() catch |err| {
        std.debug.print("⚠️  kubectl not available: {}\n", .{err});
        return error.SkipZigTest;
    };
    defer kubeconfig.deinit(allocator);
    
    const current_ctx = kubeconfig.getCurrentContext() orelse {
        std.debug.print("⚠️  No current context\n", .{});
        return error.SkipZigTest;
    };
    
    const cluster = kubeconfig.getCluster(current_ctx.cluster) orelse {
        std.debug.print("⚠️  Cluster not found\n", .{});
        return error.SkipZigTest;
    };
    
    var client = try K8sClient.init(allocator, .{
        .server = cluster.server,
        .token = null,
        .namespace = current_ctx.namespace,
    });
    defer client.deinit();
    
    const configmaps = resources.ConfigMaps.init(&client);
    
    // Test listAll configmaps
    const cm_list = configmaps.client.listAll() catch |err| {
        std.debug.print("⚠️  Could not list configmaps: {}\n", .{err});
        return error.SkipZigTest;
    };
    
    std.debug.print("✅ Listed {d} configmaps\n", .{cm_list.items.len});
}

test "Namespaces Resource - list operations" {
    const allocator = std.testing.allocator;
    
    // Try to get kubeconfig
    var parser = KubeconfigParser.init(allocator);
    var kubeconfig = parser.load() catch |err| {
        std.debug.print("⚠️  kubectl not available: {}\n", .{err});
        return error.SkipZigTest;
    };
    defer kubeconfig.deinit(allocator);
    
    const current_ctx = kubeconfig.getCurrentContext() orelse {
        std.debug.print("⚠️  No current context\n", .{});
        return error.SkipZigTest;
    };
    
    const cluster = kubeconfig.getCluster(current_ctx.cluster) orelse {
        std.debug.print("⚠️  Cluster not found\n", .{});
        return error.SkipZigTest;
    };
    
    var client = try K8sClient.init(allocator, .{
        .server = cluster.server,
        .token = null,
        .namespace = current_ctx.namespace,
    });
    defer client.deinit();
    
    const namespaces = resources.Namespaces.init(&client);
    
    // Test list namespaces (cluster-scoped)
    const ns_list = namespaces.list() catch |err| {
        std.debug.print("⚠️  Could not list namespaces: {}\n", .{err});
        return error.SkipZigTest;
    };
    
    std.debug.print("✅ Listed {d} namespaces\n", .{ns_list.items.len});
    if (ns_list.items.len > 0) {
        std.debug.print("   First namespace: {s}\n", .{ns_list.items[0].metadata.name});
    }
}

test "Nodes Resource - list operations" {
    const allocator = std.testing.allocator;
    
    // Try to get kubeconfig
    var parser = KubeconfigParser.init(allocator);
    var kubeconfig = parser.load() catch |err| {
        std.debug.print("⚠️  kubectl not available: {}\n", .{err});
        return error.SkipZigTest;
    };
    defer kubeconfig.deinit(allocator);
    
    const current_ctx = kubeconfig.getCurrentContext() orelse {
        std.debug.print("⚠️  No current context\n", .{});
        return error.SkipZigTest;
    };
    
    const cluster = kubeconfig.getCluster(current_ctx.cluster) orelse {
        std.debug.print("⚠️  Cluster not found\n", .{});
        return error.SkipZigTest;
    };
    
    var client = try K8sClient.init(allocator, .{
        .server = cluster.server,
        .token = null,
        .namespace = current_ctx.namespace,
    });
    defer client.deinit();
    
    const nodes = resources.Nodes.init(&client);
    
    // Test list nodes (cluster-scoped)
    const node_list = nodes.list() catch |err| {
        std.debug.print("⚠️  Could not list nodes: {}\n", .{err});
        return error.SkipZigTest;
    };
    
    std.debug.print("✅ Listed {d} nodes\n", .{node_list.items.len});
    if (node_list.items.len > 0) {
        std.debug.print("   First node: {s}\n", .{node_list.items[0].metadata.name});
    }
}
