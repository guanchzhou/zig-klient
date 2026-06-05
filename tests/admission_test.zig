const std = @import("std");
const klient = @import("klient");

test "ValidatingWebhookConfiguration - create structure" {
    const vwc = klient.ValidatingWebhookConfiguration{
        .apiVersion = "admissionregistration.k8s.io/v1",
        .kind = "ValidatingWebhookConfiguration",
        .metadata = .{
            .name = "test-webhook",
            .namespace = null,
        },
        .webhooks = null,
    };

    try std.testing.expectEqualStrings("admissionregistration.k8s.io/v1", vwc.apiVersion.?);
    try std.testing.expectEqualStrings("ValidatingWebhookConfiguration", vwc.kind.?);
    try std.testing.expectEqualStrings("test-webhook", vwc.metadata.name);
    std.debug.print("✅ ValidatingWebhookConfiguration create structure test passed\n", .{});
}

test "ValidatingWebhookConfiguration - deserialize from JSON" {
    const allocator = std.testing.allocator;
    const json_str =
        \\{
        \\  "apiVersion": "admissionregistration.k8s.io/v1",
        \\  "kind": "ValidatingWebhookConfiguration",
        \\  "metadata": {
        \\    "name": "my-webhook"
        \\  },
        \\  "webhooks": [
        \\    {
        \\      "name": "validate.example.com",
        \\      "clientConfig": {
        \\        "service": {
        \\          "name": "webhook-service",
        \\          "namespace": "default"
        \\        }
        \\      }
        \\    }
        \\  ]
        \\}
    ;

    var parsed = try std.json.parseFromSlice(klient.ValidatingWebhookConfiguration, allocator, json_str, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    const vwc = parsed.value;

    try std.testing.expectEqualStrings("my-webhook", vwc.metadata.name);
    try std.testing.expect(vwc.webhooks.?.len == 1);
    std.debug.print("✅ ValidatingWebhookConfiguration deserialize test passed\n", .{});
}

test "MutatingWebhookConfiguration - create structure" {
    const mwc = klient.MutatingWebhookConfiguration{
        .apiVersion = "admissionregistration.k8s.io/v1",
        .kind = "MutatingWebhookConfiguration",
        .metadata = .{
            .name = "test-mutating-webhook",
            .namespace = null,
        },
        .webhooks = null,
    };

    try std.testing.expectEqualStrings("admissionregistration.k8s.io/v1", mwc.apiVersion.?);
    try std.testing.expectEqualStrings("MutatingWebhookConfiguration", mwc.kind.?);
    try std.testing.expectEqualStrings("test-mutating-webhook", mwc.metadata.name);
    std.debug.print("✅ MutatingWebhookConfiguration create structure test passed\n", .{});
}

test "ValidatingAdmissionPolicy - create structure" {
    const policy = klient.ValidatingAdmissionPolicy{
        .apiVersion = "admissionregistration.k8s.io/v1",
        .kind = "ValidatingAdmissionPolicy",
        .metadata = .{
            .name = "test-policy",
            .namespace = "default",
        },
        .spec = .{
            .failurePolicy = "Fail",
            .matchConstraints = .null,
            .validations = null,
            .paramKind = null,
            .matchConditions = null,
            .auditAnnotations = null,
            .variables = null,
        },
    };

    try std.testing.expectEqualStrings("admissionregistration.k8s.io/v1", policy.apiVersion.?);
    try std.testing.expectEqualStrings("ValidatingAdmissionPolicy", policy.kind.?);
    try std.testing.expectEqualStrings("test-policy", policy.metadata.name);
    std.debug.print("✅ ValidatingAdmissionPolicy create structure test passed\n", .{});
}

test "ValidatingAdmissionPolicyBinding - create structure" {
    const binding = klient.ValidatingAdmissionPolicyBinding{
        .apiVersion = "admissionregistration.k8s.io/v1",
        .kind = "ValidatingAdmissionPolicyBinding",
        .metadata = .{
            .name = "test-binding",
            .namespace = "default",
        },
        .spec = .{
            .policyName = "test-policy",
            .paramRef = .null,
            .matchResources = .null,
            .validationActions = null,
        },
    };

    try std.testing.expectEqualStrings("admissionregistration.k8s.io/v1", binding.apiVersion.?);
    try std.testing.expectEqualStrings("ValidatingAdmissionPolicyBinding", binding.kind.?);
    try std.testing.expectEqualStrings("test-binding", binding.metadata.name);
    try std.testing.expectEqualStrings("test-policy", binding.spec.?.policyName);
    std.debug.print("✅ ValidatingAdmissionPolicyBinding create structure test passed\n", .{});
}

test "MutatingAdmissionPolicy - create structure (K8s 1.36 GA)" {
    const policy = klient.MutatingAdmissionPolicy{
        .apiVersion = "admissionregistration.k8s.io/v1",
        .kind = "MutatingAdmissionPolicy",
        .metadata = .{
            .name = "test-mutating-policy",
        },
        .spec = .{
            .failurePolicy = "Fail",
            .reinvocationPolicy = "IfNeeded",
            .mutations = null,
        },
    };

    try std.testing.expectEqualStrings("admissionregistration.k8s.io/v1", policy.apiVersion.?);
    try std.testing.expectEqualStrings("MutatingAdmissionPolicy", policy.kind.?);
    try std.testing.expectEqualStrings("test-mutating-policy", policy.metadata.name);
    try std.testing.expectEqualStrings("IfNeeded", policy.spec.?.reinvocationPolicy.?);
}

test "MutatingAdmissionPolicy - deserialize from JSON" {
    const allocator = std.testing.allocator;
    const json_str =
        \\{
        \\  "apiVersion": "admissionregistration.k8s.io/v1",
        \\  "kind": "MutatingAdmissionPolicy",
        \\  "metadata": { "name": "add-sidecar" },
        \\  "spec": {
        \\    "failurePolicy": "Fail",
        \\    "reinvocationPolicy": "Never",
        \\    "matchConstraints": { "resourceRules": [] },
        \\    "mutations": [
        \\      { "patchType": "ApplyConfiguration", "applyConfiguration": { "expression": "Object{}" } }
        \\    ]
        \\  }
        \\}
    ;

    var parsed = try std.json.parseFromSlice(klient.MutatingAdmissionPolicy, allocator, json_str, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    const policy = parsed.value;

    try std.testing.expectEqualStrings("add-sidecar", policy.metadata.name);
    try std.testing.expectEqualStrings("Never", policy.spec.?.reinvocationPolicy.?);
    try std.testing.expect(policy.spec.?.mutations.?.len == 1);
}

test "MutatingAdmissionPolicyBinding - create structure (K8s 1.36 GA)" {
    const binding = klient.MutatingAdmissionPolicyBinding{
        .apiVersion = "admissionregistration.k8s.io/v1",
        .kind = "MutatingAdmissionPolicyBinding",
        .metadata = .{
            .name = "test-mutating-binding",
        },
        .spec = .{
            .policyName = "add-sidecar",
            .paramRef = .null,
            .matchResources = .null,
        },
    };

    try std.testing.expectEqualStrings("MutatingAdmissionPolicyBinding", binding.kind.?);
    try std.testing.expectEqualStrings("add-sidecar", binding.spec.?.policyName);
}

test "registry: Mutating admission policies are cluster-scoped at admissionregistration.k8s.io/v1" {
    const policy_rc = klient.resources.ResourceClient(klient.MutatingAdmissionPolicy).initFromRegistry(undefined);
    try std.testing.expectEqualStrings("/apis/admissionregistration.k8s.io/v1", policy_rc.api_path);
    try std.testing.expectEqualStrings("mutatingadmissionpolicies", policy_rc.resource);
    try std.testing.expect(policy_rc.is_cluster_scoped);

    const binding_rc = klient.resources.ResourceClient(klient.MutatingAdmissionPolicyBinding).initFromRegistry(undefined);
    try std.testing.expectEqualStrings("mutatingadmissionpolicybindings", binding_rc.resource);
    try std.testing.expect(binding_rc.is_cluster_scoped);
}

test "CertificateSigningRequest - create structure" {
    const csr = klient.CertificateSigningRequest{
        .apiVersion = "certificates.k8s.io/v1",
        .kind = "CertificateSigningRequest",
        .metadata = .{
            .name = "test-csr",
            .namespace = "default",
        },
        .spec = .{
            .request = "LS0tLS1CRUdJTi...",
            .signerName = "kubernetes.io/kube-apiserver-client",
            .expirationSeconds = 86400,
            .usages = null,
            .username = null,
            .uid = null,
            .groups = null,
            .extra = null,
        },
    };

    try std.testing.expectEqualStrings("certificates.k8s.io/v1", csr.apiVersion.?);
    try std.testing.expectEqualStrings("CertificateSigningRequest", csr.kind.?);
    try std.testing.expectEqualStrings("test-csr", csr.metadata.name);
    try std.testing.expectEqualStrings("kubernetes.io/kube-apiserver-client", csr.spec.?.signerName);
    std.debug.print("✅ CertificateSigningRequest create structure test passed\n", .{});
}
