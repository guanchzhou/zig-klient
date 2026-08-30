// Kubernetes 1.37 GA kinds and the StorageVersionMigration v1 bump.
// Field-level 1.37 additions on json.Value specs need no new types.
const std = @import("std");
const klient = @import("klient");

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

test "registry: 1.37 GA kinds and StorageVersionMigration v1" {
    try expectMeta(klient.DeviceTaintRule, "/apis/resource.k8s.io/v1", "devicetaintrules", true);
    try expectMeta(klient.ClusterTrustBundle, "/apis/certificates.k8s.io/v1", "clustertrustbundles", true);
    try expectMeta(klient.PodCertificateRequest, "/apis/certificates.k8s.io/v1", "podcertificaterequests", false);
    try expectMeta(klient.StorageVersionMigration, "/apis/storagemigration.k8s.io/v1", "storageversionmigrations", true);
}

test "registry: 1.37 alpha/beta kinds stay untyped" {
    // Standing rule (CHANGELOG 0.6.0): only GA near-universal APIs in the registry.
    // Re-checked against kubernetes v1.37.0 staging API 2026-08-30:
    //   lifecycle.k8s.io/v1alpha1 Eviction + EvictionRequest (EvictionRequestAPI, default off)
    //   scheduling.k8s.io/v1beta1 Workload + PodGroup (GenericWorkload)
    //   scheduling.k8s.io/v1alpha3 CompositePodGroup
    // Reach them with Discovery + DynamicClient if a cluster has the feature gates on.
    try std.testing.expect(!@hasDecl(klient, "Eviction"));
    try std.testing.expect(!@hasDecl(klient, "EvictionRequest"));
    try std.testing.expect(!@hasDecl(klient, "Workload"));
    try std.testing.expect(!@hasDecl(klient, "PodGroup"));
    try std.testing.expect(!@hasDecl(klient, "CompositePodGroup"));
    try std.testing.expect(!@hasDecl(klient.types, "Eviction"));
    try std.testing.expect(!@hasDecl(klient.types, "EvictionRequest"));
    try std.testing.expect(!@hasDecl(klient.types, "Workload"));
    try std.testing.expect(!@hasDecl(klient.types, "PodGroup"));
    try std.testing.expect(!@hasDecl(klient.types, "CompositePodGroup"));
}

test "DeviceTaintRule - create structure (K8s 1.37 GA)" {
    const rule = klient.DeviceTaintRule{
        .apiVersion = "resource.k8s.io/v1",
        .kind = "DeviceTaintRule",
        .metadata = .{ .name = "gpu-unhealthy" },
        .spec = .{
            .deviceSelector = .{ .driver = "dra.example.com", .pool = null, .device = null },
            .taint = .{ .key = "dra.example.com/unhealthy", .value = "Broken", .effect = "NoExecute" },
        },
    };

    try std.testing.expectEqualStrings("resource.k8s.io/v1", rule.apiVersion.?);
    try std.testing.expectEqualStrings("DeviceTaintRule", rule.kind.?);
    try std.testing.expectEqualStrings("dra.example.com", rule.spec.?.deviceSelector.?.driver.?);
    try std.testing.expectEqualStrings("NoExecute", rule.spec.?.taint.effect);
}

test "DeviceTaintRule - deserialize from JSON" {
    const allocator = std.testing.allocator;
    const json_str =
        \\{
        \\  "apiVersion": "resource.k8s.io/v1",
        \\  "kind": "DeviceTaintRule",
        \\  "metadata": { "name": "example" },
        \\  "spec": {
        \\    "deviceSelector": { "driver": "dra.example.com" },
        \\    "taint": { "key": "dra.example.com/unhealthy", "value": "Broken", "effect": "NoExecute" }
        \\  }
        \\}
    ;

    var parsed = try std.json.parseFromSlice(klient.DeviceTaintRule, allocator, json_str, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    try std.testing.expectEqualStrings("example", parsed.value.metadata.name);
    try std.testing.expectEqualStrings("dra.example.com", parsed.value.spec.?.deviceSelector.?.driver.?);
    try std.testing.expectEqualStrings("Broken", parsed.value.spec.?.taint.value.?);
    try std.testing.expectEqualStrings("NoExecute", parsed.value.spec.?.taint.effect);
}

test "ClusterTrustBundle - create structure (K8s 1.37 GA)" {
    const bundle = klient.ClusterTrustBundle{
        .apiVersion = "certificates.k8s.io/v1",
        .kind = "ClusterTrustBundle",
        .metadata = .{ .name = "example.com:foo:v1" },
        .spec = .{
            .signerName = "example.com/foo",
            .trustBundle = "-----BEGIN CERTIFICATE-----\nMIIB\n-----END CERTIFICATE-----\n",
        },
    };

    try std.testing.expectEqualStrings("certificates.k8s.io/v1", bundle.apiVersion.?);
    try std.testing.expectEqualStrings("ClusterTrustBundle", bundle.kind.?);
    try std.testing.expectEqualStrings("example.com/foo", bundle.spec.?.signerName.?);
}

test "ClusterTrustBundle - deserialize from JSON" {
    const allocator = std.testing.allocator;
    const json_str =
        \\{
        \\  "apiVersion": "certificates.k8s.io/v1",
        \\  "kind": "ClusterTrustBundle",
        \\  "metadata": { "name": "example.com:foo:v1" },
        \\  "spec": {
        \\    "signerName": "example.com/foo",
        \\    "trustBundle": "-----BEGIN CERTIFICATE-----\nMIIB\n-----END CERTIFICATE-----\n"
        \\  }
        \\}
    ;

    var parsed = try std.json.parseFromSlice(klient.ClusterTrustBundle, allocator, json_str, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    try std.testing.expectEqualStrings("example.com:foo:v1", parsed.value.metadata.name);
    try std.testing.expectEqualStrings("example.com/foo", parsed.value.spec.?.signerName.?);
    try std.testing.expect(std.mem.startsWith(u8, parsed.value.spec.?.trustBundle, "-----BEGIN CERTIFICATE-----"));
}

test "PodCertificateRequest - create structure (K8s 1.37 GA, no v1beta1 fields)" {
    const req = klient.PodCertificateRequest{
        .apiVersion = "certificates.k8s.io/v1",
        .kind = "PodCertificateRequest",
        .metadata = .{ .name = "pcr-1", .namespace = "default" },
        .spec = .{
            .signerName = "kubernetes.io/kube-apiserver-client-pod",
            .podName = "app",
            .podUID = "11111111-1111-1111-1111-111111111111",
            .serviceAccountName = "default",
            .serviceAccountUID = "22222222-2222-2222-2222-222222222222",
            .nodeName = "node-1",
            .nodeUID = "33333333-3333-3333-3333-333333333333",
            .stubPKCS10Request = "MIIB",
        },
    };

    try std.testing.expectEqualStrings("PodCertificateRequest", req.kind.?);
    try std.testing.expectEqualStrings("app", req.spec.?.podName);
    try std.testing.expectEqualStrings("MIIB", req.spec.?.stubPKCS10Request);
}

test "PodCertificateRequest v1 drops PKIXPublicKey and ProofOfPossession" {
    const allocator = std.testing.allocator;
    // A v1beta1 body with the removed fields must still parse: ignore_unknown_fields
    // drops them, matching the v1 schema (those fields 404 on a 1.37 apiserver).
    const json_str =
        \\{
        \\  "apiVersion": "certificates.k8s.io/v1",
        \\  "kind": "PodCertificateRequest",
        \\  "metadata": { "name": "pcr-1", "namespace": "default" },
        \\  "spec": {
        \\    "signerName": "example.com/signer",
        \\    "podName": "app",
        \\    "podUID": "uid-pod",
        \\    "serviceAccountName": "default",
        \\    "serviceAccountUID": "uid-sa",
        \\    "nodeName": "node-1",
        \\    "nodeUID": "uid-node",
        \\    "stubPKCS10Request": "MIIB",
        \\    "pkixPublicKey": "SHOULD-BE-IGNORED",
        \\    "proofOfPossession": "SHOULD-BE-IGNORED"
        \\  }
        \\}
    ;

    var parsed = try std.json.parseFromSlice(klient.PodCertificateRequest, allocator, json_str, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    try std.testing.expectEqualStrings("MIIB", parsed.value.spec.?.stubPKCS10Request);
    try std.testing.expect(!@hasField(klient.types.PodCertificateRequestSpec, "pkixPublicKey"));
    try std.testing.expect(!@hasField(klient.types.PodCertificateRequestSpec, "proofOfPossession"));
}

test "StorageVersionMigration - deserialize at v1 (K8s 1.37 GA)" {
    const allocator = std.testing.allocator;
    const json_str =
        \\{
        \\  "apiVersion": "storagemigration.k8s.io/v1",
        \\  "kind": "StorageVersionMigration",
        \\  "metadata": { "name": "migrate-crds" },
        \\  "spec": { "resource": { "group": "example.com", "resource": "widgets" } }
        \\}
    ;

    var parsed = try std.json.parseFromSlice(klient.StorageVersionMigration, allocator, json_str, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    try std.testing.expectEqualStrings("storagemigration.k8s.io/v1", parsed.value.apiVersion.?);
    try std.testing.expectEqualStrings("widgets", parsed.value.spec.?.resource.object.get("resource").?.string);
}
