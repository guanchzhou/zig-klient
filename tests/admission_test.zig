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

