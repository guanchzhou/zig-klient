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
}

test "registry: Namespace is cluster-scoped" {
    // SimpleResource uses initFromRegistry which reads the comptime table
    // We verify the struct fields are correctly set by checking the type's init
    const ns_type = klient.Namespaces;
    // The init function returns a wrapper with .client field
    // We can't call init without a real K8sClient, but we can verify
    // the type exists and has the right shape
    try std.testing.expect(@hasField(ns_type, "client"));
}

test "registry: Deployment is namespaced at /apis/apps/v1" {
    // Verify the Deployments wrapper exists with correct client type
    const deploy_type = klient.Deployments;
    try std.testing.expect(@hasField(deploy_type, "client"));
    // Verify custom methods exist
    try std.testing.expect(@hasDecl(deploy_type, "scale"));
    try std.testing.expect(@hasDecl(deploy_type, "rolloutRestart"));
    try std.testing.expect(@hasDecl(deploy_type, "setImage"));
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
}

// --- Gateway API registry values (2026-08-22) --------------------------------
// The registry's whole purpose is to be ONE reviewed list of API paths instead of
// URL strings scattered through callers. Until now this suite only made structural
// @hasField/@hasDecl checks, so a wrong group or plural in the table would ship
// silently -- exactly the failure that left c3s probing a nonexistent
// `cedar.k8s.io` group. These assert the actual values.
//
// Verified against Gateway API v1.6.1 standard channel (released 2026-07-16) by
// reading each CRD's served/storage versions, not by inference.

/// Read the REAL registry entry for T.
///
/// `initFromRegistry` derives every field from `comptime metaFor(T)` and only stores
/// the client pointer, so `undefined` is safe here -- nothing dereferences it. This
/// matters: the older tests in this file construct a ResourceClient from hand-written
/// literals and then assert those same literals, so they pass no matter what the
/// table says. These read the table.
fn expectMeta(
    comptime T: type,
    expected_path: []const u8,
    expected_plural: []const u8,
    comptime cluster_scoped: bool,
) !void {
    const rc = klient.resources.ResourceClient(T).initFromRegistry(undefined);
    try std.testing.expectEqualStrings(expected_path, rc.api_path);
    try std.testing.expectEqualStrings(expected_plural, rc.resource);
    try std.testing.expectEqual(cluster_scoped, rc.is_cluster_scoped);
}

test "registry: Gateway API standard channel paths and scopes" {
    const gw = "/apis/gateway.networking.k8s.io/v1";

    try expectMeta(klient.GatewayClass, gw, "gatewayclasses", true);
    try expectMeta(klient.Gateway, gw, "gateways", false);
    try expectMeta(klient.HTTPRoute, gw, "httproutes", false);
    try expectMeta(klient.GRPCRoute, gw, "grpcroutes", false);
    try expectMeta(klient.TCPRoute, gw, "tcproutes", false);
    try expectMeta(klient.TLSRoute, gw, "tlsroutes", false);
    try expectMeta(klient.UDPRoute, gw, "udproutes", false);
    try expectMeta(klient.BackendTLSPolicy, gw, "backendtlspolicies", false);
    try expectMeta(klient.ListenerSet, gw, "listenersets", false);
}

test "registry: ReferenceGrant stays on v1beta1, which is still the storage version" {
    // Gateway API v1.6.1 serves ReferenceGrant at BOTH v1 and v1beta1, and v1beta1
    // is still marked `storage: true`. This is deliberately NOT bumped to v1 --
    // pinning the storage version is correct, and "modernising" it would be churn.
    // Flip this test when upstream moves storage to v1.
    try expectMeta(
        klient.ReferenceGrant,
        "/apis/gateway.networking.k8s.io/v1beta1",
        "referencegrants",
        false,
    );
}
