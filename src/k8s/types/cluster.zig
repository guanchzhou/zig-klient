const std = @import("std");
const meta = @import("meta.zig");
const ObjectMeta = meta.ObjectMeta;
const Resource = meta.Resource;

/// CertificateSigningRequest specification
pub const CertificateSigningRequestSpec = struct {
    request: []const u8,
    signerName: []const u8,
    expirationSeconds: ?i32 = null,
    usages: ?[][]const u8 = null,
    username: ?[]const u8 = null,
    uid: ?[]const u8 = null,
    groups: ?[][]const u8 = null,
    extra: ?std.json.Value = null,
};

/// CertificateSigningRequest (certificate signing) - cluster-scoped
pub const CertificateSigningRequest = Resource(CertificateSigningRequestSpec);

/// ClusterTrustBundle specification (certificates.k8s.io/v1) — K8s 1.37 GA
pub const ClusterTrustBundleSpec = struct {
    /// Optional signer this bundle attests. Empty means a signer-less bundle.
    signerName: ?[]const u8 = null,
    /// PEM bundle of X.509 trust anchors. Required.
    trustBundle: []const u8,
};

/// ClusterTrustBundle (cluster-scoped X.509 trust anchors) — K8s 1.37 GA
pub const ClusterTrustBundle = Resource(ClusterTrustBundleSpec);

/// PodCertificateRequest specification (certificates.k8s.io/v1) — K8s 1.37 GA.
///
/// v1 drops `PKIXPublicKey` and `ProofOfPossession` that existed on v1beta1.
/// The public key lives inside `stubPKCS10Request` (JSON: base64 PKCS#10 CSR).
pub const PodCertificateRequestSpec = struct {
    signerName: []const u8,
    podName: []const u8,
    podUID: []const u8,
    serviceAccountName: []const u8,
    serviceAccountUID: []const u8,
    nodeName: []const u8,
    nodeUID: []const u8,
    maxExpirationSeconds: ?i32 = null,
    stubPKCS10Request: []const u8,
    unverifiedUserAnnotations: ?std.json.Value = null,
};

/// PodCertificateRequest (namespaced; issued by kubelet for podCertificate volumes)
pub const PodCertificateRequest = Resource(PodCertificateRequestSpec);

/// ValidatingWebhookConfiguration specification
pub const ValidatingWebhookConfigurationSpec = struct {
    webhooks: ?[]std.json.Value = null,
};

/// ValidatingWebhookConfiguration (admission validation webhook) - cluster-scoped
pub const ValidatingWebhookConfiguration = struct {
    apiVersion: ?[]const u8 = null,
    kind: ?[]const u8 = null,
    metadata: ObjectMeta,
    webhooks: ?[]std.json.Value = null,
};

/// MutatingWebhookConfiguration specification
pub const MutatingWebhookConfigurationSpec = struct {
    webhooks: ?[]std.json.Value = null,
};

/// MutatingWebhookConfiguration (admission mutation webhook) - cluster-scoped
pub const MutatingWebhookConfiguration = struct {
    apiVersion: ?[]const u8 = null,
    kind: ?[]const u8 = null,
    metadata: ObjectMeta,
    webhooks: ?[]std.json.Value = null,
};

/// ValidatingAdmissionPolicy specification
pub const ValidatingAdmissionPolicySpec = struct {
    failurePolicy: ?[]const u8 = null,
    matchConstraints: ?std.json.Value = null,
    validations: ?[]std.json.Value = null,
    paramKind: ?std.json.Value = null,
    matchConditions: ?[]std.json.Value = null,
    auditAnnotations: ?[]std.json.Value = null,
    variables: ?[]std.json.Value = null,
};

/// ValidatingAdmissionPolicy (admission policy) - cluster-scoped
pub const ValidatingAdmissionPolicy = Resource(ValidatingAdmissionPolicySpec);

/// ValidatingAdmissionPolicyBinding specification
pub const ValidatingAdmissionPolicyBindingSpec = struct {
    policyName: []const u8,
    paramRef: ?std.json.Value = null,
    matchResources: ?std.json.Value = null,
    validationActions: ?[][]const u8 = null,
};

/// ValidatingAdmissionPolicyBinding (admission policy binding) - cluster-scoped
pub const ValidatingAdmissionPolicyBinding = Resource(ValidatingAdmissionPolicyBindingSpec);

/// MutatingAdmissionPolicy specification (admissionregistration.k8s.io/v1) - K8s 1.36 GA
pub const MutatingAdmissionPolicySpec = struct {
    failurePolicy: ?[]const u8 = null,
    matchConstraints: ?std.json.Value = null,
    /// CEL-based mutations applied to matching objects (ApplyConfiguration or JSONPatch)
    mutations: ?[]std.json.Value = null,
    /// "Never" or "IfNeeded" — whether mutations may run again after other mutating admission
    reinvocationPolicy: ?[]const u8 = null,
    paramKind: ?std.json.Value = null,
    matchConditions: ?[]std.json.Value = null,
    variables: ?[]std.json.Value = null,
};

/// MutatingAdmissionPolicy (CEL admission mutation policy) - cluster-scoped
pub const MutatingAdmissionPolicy = Resource(MutatingAdmissionPolicySpec);

/// MutatingAdmissionPolicyBinding specification (admissionregistration.k8s.io/v1) - K8s 1.36 GA
pub const MutatingAdmissionPolicyBindingSpec = struct {
    policyName: []const u8,
    paramRef: ?std.json.Value = null,
    matchResources: ?std.json.Value = null,
};

/// MutatingAdmissionPolicyBinding (admission policy binding) - cluster-scoped
pub const MutatingAdmissionPolicyBinding = Resource(MutatingAdmissionPolicyBindingSpec);

/// APIService specification
pub const APIServiceSpec = struct {
    service: ?std.json.Value = null,
    group: []const u8,
    version: []const u8,
    insecureSkipTLSVerify: ?bool = null,
    caBundle: ?[]const u8 = null,
    groupPriorityMinimum: i32,
    versionPriority: i32,
};

/// APIService (API service registration) - cluster-scoped
pub const APIService = struct {
    apiVersion: ?[]const u8 = null,
    kind: ?[]const u8 = null,
    metadata: ObjectMeta,
    spec: APIServiceSpec,
};

/// FlowSchema specification
pub const FlowSchemaSpec = struct {
    priorityLevelConfiguration: std.json.Value,
    matchingPrecedence: ?i32 = null,
    distinguisherMethod: ?std.json.Value = null,
    rules: ?[]std.json.Value = null,
};

/// FlowSchema (API flow control) - cluster-scoped
pub const FlowSchema = Resource(FlowSchemaSpec);

/// PriorityLevelConfiguration specification
pub const PriorityLevelConfigurationSpec = struct {
    type: []const u8,
    limited: ?std.json.Value = null,
    exempt: ?std.json.Value = null,
};

/// PriorityLevelConfiguration (API priority level) - cluster-scoped
pub const PriorityLevelConfiguration = Resource(PriorityLevelConfigurationSpec);

/// RuntimeClass specification
pub const RuntimeClassSpec = struct {
    handler: []const u8,
    overhead: ?std.json.Value = null,
    scheduling: ?std.json.Value = null,
};

/// RuntimeClass (container runtime) - cluster-scoped
pub const RuntimeClass = struct {
    apiVersion: ?[]const u8 = null,
    kind: ?[]const u8 = null,
    metadata: ObjectMeta,
    handler: []const u8,
    overhead: ?std.json.Value = null,
    scheduling: ?std.json.Value = null,
};

/// StorageVersionMigration specification (storagemigration.k8s.io/v1) — K8s 1.37 GA
pub const StorageVersionMigrationSpec = struct {
    resource: std.json.Value,
};

/// StorageVersionMigration (cluster-scoped)
pub const StorageVersionMigration = Resource(StorageVersionMigrationSpec);
