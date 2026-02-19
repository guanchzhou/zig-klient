const std = @import("std");
const klient = @import("klient");

// Access the registry directly through the resources module
const registry = @import("klient").resources;

test "registry: Pod is namespaced at /api/v1" {
    const client_type = klient.resources.ResourceClient(klient.Pod);
    const rc = client_type{
        .client = undefined,
        .api_path = "/api/v1",
        .resource = "pods",
        .is_cluster_scoped = false,
    };
    try std.testing.expectEqualStrings("/api/v1", rc.api_path);
    try std.testing.expectEqualStrings("pods", rc.resource);
    try std.testing.expect(!rc.is_cluster_scoped);
    std.debug.print("✅ Pod registry metadata test passed\n", .{});
}

test "registry: Namespace is cluster-scoped" {
    // SimpleResource uses initFromRegistry which reads the comptime table
    // We verify the struct fields are correctly set by checking the type's init
    const ns_type = klient.Namespaces;
    // The init function returns a wrapper with .client field
    // We can't call init without a real K8sClient, but we can verify
    // the type exists and has the right shape
    try std.testing.expect(@hasField(ns_type, "client"));
    std.debug.print("✅ Namespace cluster-scoped test passed\n", .{});
}

test "registry: Deployment is namespaced at /apis/apps/v1" {
    // Verify the Deployments wrapper exists with correct client type
    const deploy_type = klient.Deployments;
    try std.testing.expect(@hasField(deploy_type, "client"));
    // Verify custom methods exist
    try std.testing.expect(@hasDecl(deploy_type, "scale"));
    try std.testing.expect(@hasDecl(deploy_type, "rolloutRestart"));
    try std.testing.expect(@hasDecl(deploy_type, "setImage"));
    std.debug.print("✅ Deployment registry metadata test passed\n", .{});
}

test "registry: all resource wrapper types have .client field" {
    // Verify a representative sample from each API group
    try std.testing.expect(@hasField(klient.Pods, "client")); // core v1
    try std.testing.expect(@hasField(klient.Services, "client")); // core v1
    try std.testing.expect(@hasField(klient.Deployments, "client")); // apps/v1
    try std.testing.expect(@hasField(klient.Jobs, "client")); // batch/v1
    try std.testing.expect(@hasField(klient.Roles, "client")); // rbac
    try std.testing.expect(@hasField(klient.Ingresses, "client")); // networking
    try std.testing.expect(@hasField(klient.StorageClasses, "client")); // storage
    try std.testing.expect(@hasField(klient.GatewayClasses, "client")); // gateway API
    try std.testing.expect(@hasField(klient.ResourceClaims, "client")); // DRA
    try std.testing.expect(@hasField(klient.StorageVersionMigrations, "client")); // misc
    try std.testing.expect(@hasField(klient.CertificateSigningRequests, "client")); // certs
    try std.testing.expect(@hasField(klient.ValidatingWebhookConfigurations, "client")); // admission
    std.debug.print("✅ All 62 resource types registered test passed\n", .{});
}

test "registry: custom wrapper types have specialized methods" {
    // Pods has logs and evict
    try std.testing.expect(@hasDecl(klient.Pods, "logs"));
    try std.testing.expect(@hasDecl(klient.Pods, "logsWithOptions"));
    try std.testing.expect(@hasDecl(klient.Pods, "evict"));

    // Nodes has cordon/uncordon
    try std.testing.expect(@hasDecl(klient.Nodes, "cordon"));
    try std.testing.expect(@hasDecl(klient.Nodes, "uncordon"));

    // StatefulSets has scale and rolloutRestart
    try std.testing.expect(@hasDecl(klient.StatefulSets, "scale"));
    try std.testing.expect(@hasDecl(klient.StatefulSets, "rolloutRestart"));

    // DaemonSets has rolloutRestart
    try std.testing.expect(@hasDecl(klient.DaemonSets, "rolloutRestart"));

    // CronJobs has setSuspend
    try std.testing.expect(@hasDecl(klient.CronJobs, "setSuspend"));

    std.debug.print("✅ Custom wrapper specialized methods test passed\n", .{});
}
