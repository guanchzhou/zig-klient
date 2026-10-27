//! Protobuf message tables for the Kubernetes types zig-klient decodes,
//! generated from k8s.io/api v0.37.1 by tools/protobuf-gen. Do not edit;
//! run `zig build gen-protobuf` instead.

const Message = @import("protobuf.zig").Message;

/// zig-klient type name and the message of one list item.
pub const roots = .{
    .{ "Pod", &core_v1_Pod },
    .{ "Namespace", &core_v1_Namespace },
    .{ "Node", &core_v1_Node },
    .{ "Service", &core_v1_Service },
    .{ "ConfigMap", &core_v1_ConfigMap },
    .{ "Secret", &core_v1_Secret },
    .{ "PersistentVolume", &core_v1_PersistentVolume },
    .{ "PersistentVolumeClaim", &core_v1_PersistentVolumeClaim },
    .{ "ServiceAccount", &core_v1_ServiceAccount },
    .{ "Endpoints", &core_v1_Endpoints },
    .{ "Event", &core_v1_Event },
    .{ "ResourceQuota", &core_v1_ResourceQuota },
    .{ "LimitRange", &core_v1_LimitRange },
    .{ "Deployment", &apps_v1_Deployment },
    .{ "StatefulSet", &apps_v1_StatefulSet },
    .{ "DaemonSet", &apps_v1_DaemonSet },
    .{ "ReplicaSet", &apps_v1_ReplicaSet },
    .{ "Job", &batch_v1_Job },
    .{ "CronJob", &batch_v1_CronJob },
    .{ "Role", &rbac_v1_Role },
    .{ "RoleBinding", &rbac_v1_RoleBinding },
    .{ "ClusterRole", &rbac_v1_ClusterRole },
    .{ "ClusterRoleBinding", &rbac_v1_ClusterRoleBinding },
    .{ "Ingress", &networking_v1_Ingress },
    .{ "NetworkPolicy", &networking_v1_NetworkPolicy },
    .{ "IPAddress", &networking_v1_IPAddress },
    .{ "ServiceCIDR", &networking_v1_ServiceCIDR },
    .{ "IngressClass", &networking_v1_IngressClass },
    .{ "StorageClass", &storage_v1_StorageClass },
    .{ "CSIDriver", &storage_v1_CSIDriver },
    .{ "VolumeAttributesClass", &storage_v1_VolumeAttributesClass },
    .{ "HorizontalPodAutoscaler", &autoscaling_v2_HorizontalPodAutoscaler },
    .{ "PodDisruptionBudget", &policy_v1_PodDisruptionBudget },
    .{ "EndpointSlice", &discovery_v1_EndpointSlice },
    .{ "Lease", &coordination_v1_Lease },
    .{ "PriorityClass", &scheduling_v1_PriorityClass },
    .{ "CertificateSigningRequest", &certificates_v1_CertificateSigningRequest },
    .{ "ValidatingWebhookConfiguration", &admissionregistration_v1_ValidatingWebhookConfiguration },
    .{ "MutatingWebhookConfiguration", &admissionregistration_v1_MutatingWebhookConfiguration },
    .{ "ValidatingAdmissionPolicy", &admissionregistration_v1_ValidatingAdmissionPolicy },
    .{ "ValidatingAdmissionPolicyBinding", &admissionregistration_v1_ValidatingAdmissionPolicyBinding },
    .{ "MutatingAdmissionPolicy", &admissionregistration_v1_MutatingAdmissionPolicy },
    .{ "MutatingAdmissionPolicyBinding", &admissionregistration_v1_MutatingAdmissionPolicyBinding },
    .{ "RuntimeClass", &node_v1_RuntimeClass },
    .{ "ResourceClaim", &resource_v1_ResourceClaim },
    .{ "DeviceClass", &resource_v1_DeviceClass },
    .{ "StorageVersionMigration", &storagemigration_v1_StorageVersionMigration },
};

pub const admissionregistration_v1_ApplyConfiguration: Message = .{ .fields = &.{
    .{ .number = 1, .json = "expression", .type = .string },
} };

pub const admissionregistration_v1_AuditAnnotation: Message = .{ .fields = &.{
    .{ .number = 1, .json = "key", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "valueExpression", .type = .string, .omit_zero = false },
} };

pub const admissionregistration_v1_ExpressionWarning: Message = .{ .fields = &.{
    .{ .number = 2, .json = "fieldRef", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "warning", .type = .string, .omit_zero = false },
} };

pub const admissionregistration_v1_JSONPatch: Message = .{ .fields = &.{
    .{ .number = 1, .json = "expression", .type = .string },
} };

pub const admissionregistration_v1_MatchCondition: Message = .{ .fields = &.{
    .{ .number = 1, .json = "name", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "expression", .type = .string, .omit_zero = false },
} };

pub const admissionregistration_v1_MatchResources: Message = .{ .fields = &.{
    .{ .number = 1, .json = "namespaceSelector", .type = .message, .message = &meta_v1_LabelSelector, .omit_zero = false },
    .{ .number = 2, .json = "objectSelector", .type = .message, .message = &meta_v1_LabelSelector, .omit_zero = false },
    .{ .number = 3, .json = "resourceRules", .type = .message, .message = &admissionregistration_v1_NamedRuleWithOperations, .repeated = true },
    .{ .number = 4, .json = "excludeResourceRules", .type = .message, .message = &admissionregistration_v1_NamedRuleWithOperations, .repeated = true },
    .{ .number = 7, .json = "matchPolicy", .type = .string, .omit_zero = false },
} };

pub const admissionregistration_v1_MutatingAdmissionPolicy: Message = .{ .fields = &.{
    .{ .number = 1, .json = "metadata", .type = .message, .message = &meta_v1_ObjectMeta, .omit_zero = false },
    .{ .number = 2, .json = "spec", .type = .message, .message = &admissionregistration_v1_MutatingAdmissionPolicySpec, .omit_zero = false },
} };

pub const admissionregistration_v1_MutatingAdmissionPolicyBinding: Message = .{ .fields = &.{
    .{ .number = 1, .json = "metadata", .type = .message, .message = &meta_v1_ObjectMeta, .omit_zero = false },
    .{ .number = 2, .json = "spec", .type = .message, .message = &admissionregistration_v1_MutatingAdmissionPolicyBindingSpec, .omit_zero = false },
} };

pub const admissionregistration_v1_MutatingAdmissionPolicyBindingSpec: Message = .{ .fields = &.{
    .{ .number = 1, .json = "policyName", .type = .string },
    .{ .number = 2, .json = "paramRef", .type = .message, .message = &admissionregistration_v1_ParamRef, .omit_zero = false },
    .{ .number = 3, .json = "matchResources", .type = .message, .message = &admissionregistration_v1_MatchResources, .omit_zero = false },
} };

pub const admissionregistration_v1_MutatingAdmissionPolicySpec: Message = .{ .fields = &.{
    .{ .number = 1, .json = "paramKind", .type = .message, .message = &admissionregistration_v1_ParamKind, .omit_zero = false },
    .{ .number = 2, .json = "matchConstraints", .type = .message, .message = &admissionregistration_v1_MatchResources, .omit_zero = false },
    .{ .number = 3, .json = "variables", .type = .message, .message = &admissionregistration_v1_Variable, .repeated = true },
    .{ .number = 4, .json = "mutations", .type = .message, .message = &admissionregistration_v1_Mutation, .repeated = true },
    .{ .number = 5, .json = "failurePolicy", .type = .string, .omit_zero = false },
    .{ .number = 6, .json = "matchConditions", .type = .message, .message = &admissionregistration_v1_MatchCondition, .repeated = true },
    .{ .number = 7, .json = "reinvocationPolicy", .type = .string },
} };

pub const admissionregistration_v1_MutatingWebhook: Message = .{ .fields = &.{
    .{ .number = 1, .json = "name", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "clientConfig", .type = .message, .message = &admissionregistration_v1_WebhookClientConfig, .omit_zero = false },
    .{ .number = 3, .json = "rules", .type = .message, .message = &admissionregistration_v1_RuleWithOperations, .repeated = true },
    .{ .number = 4, .json = "failurePolicy", .type = .string, .omit_zero = false },
    .{ .number = 9, .json = "matchPolicy", .type = .string, .omit_zero = false },
    .{ .number = 5, .json = "namespaceSelector", .type = .message, .message = &meta_v1_LabelSelector, .omit_zero = false },
    .{ .number = 11, .json = "objectSelector", .type = .message, .message = &meta_v1_LabelSelector, .omit_zero = false },
    .{ .number = 6, .json = "sideEffects", .type = .string, .omit_zero = false },
    .{ .number = 7, .json = "timeoutSeconds", .type = .int32, .omit_zero = false },
    .{ .number = 8, .json = "admissionReviewVersions", .type = .string, .repeated = true },
    .{ .number = 10, .json = "reinvocationPolicy", .type = .string, .omit_zero = false },
    .{ .number = 12, .json = "matchConditions", .type = .message, .message = &admissionregistration_v1_MatchCondition, .repeated = true },
} };

pub const admissionregistration_v1_MutatingWebhookConfiguration: Message = .{ .fields = &.{
    .{ .number = 1, .json = "metadata", .type = .message, .message = &meta_v1_ObjectMeta, .omit_zero = false },
    .{ .number = 2, .json = "webhooks", .type = .message, .message = &admissionregistration_v1_MutatingWebhook, .repeated = true },
} };

pub const admissionregistration_v1_Mutation: Message = .{ .fields = &.{
    .{ .number = 2, .json = "patchType", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "applyConfiguration", .type = .message, .message = &admissionregistration_v1_ApplyConfiguration, .omit_zero = false },
    .{ .number = 4, .json = "jsonPatch", .type = .message, .message = &admissionregistration_v1_JSONPatch, .omit_zero = false },
} };

pub const admissionregistration_v1_NamedRuleWithOperations: Message = .{ .fields = &.{
    .{ .number = 1, .json = "resourceNames", .type = .string, .repeated = true },
    .{ .number = 2, .json = "", .type = .message, .message = &admissionregistration_v1_RuleWithOperations, .embedded = true },
} };

pub const admissionregistration_v1_ParamKind: Message = .{ .fields = &.{
    .{ .number = 1, .json = "apiVersion", .type = .string },
    .{ .number = 2, .json = "kind", .type = .string },
} };

pub const admissionregistration_v1_ParamRef: Message = .{ .fields = &.{
    .{ .number = 1, .json = "name", .type = .string },
    .{ .number = 2, .json = "namespace", .type = .string },
    .{ .number = 3, .json = "selector", .type = .message, .message = &meta_v1_LabelSelector, .omit_zero = false },
    .{ .number = 4, .json = "parameterNotFoundAction", .type = .string, .omit_zero = false },
} };

pub const admissionregistration_v1_Rule: Message = .{ .fields = &.{
    .{ .number = 1, .json = "apiGroups", .type = .string, .repeated = true },
    .{ .number = 2, .json = "apiVersions", .type = .string, .repeated = true },
    .{ .number = 3, .json = "resources", .type = .string, .repeated = true },
    .{ .number = 4, .json = "scope", .type = .string, .omit_zero = false },
} };

pub const admissionregistration_v1_RuleWithOperations: Message = .{ .fields = &.{
    .{ .number = 1, .json = "operations", .type = .string, .repeated = true },
    .{ .number = 2, .json = "", .type = .message, .message = &admissionregistration_v1_Rule, .embedded = true },
} };

pub const admissionregistration_v1_ServiceReference: Message = .{ .fields = &.{
    .{ .number = 1, .json = "namespace", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "name", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "path", .type = .string, .omit_zero = false },
    .{ .number = 4, .json = "port", .type = .int32, .omit_zero = false },
} };

pub const admissionregistration_v1_TypeChecking: Message = .{ .fields = &.{
    .{ .number = 1, .json = "expressionWarnings", .type = .message, .message = &admissionregistration_v1_ExpressionWarning, .repeated = true },
} };

pub const admissionregistration_v1_ValidatingAdmissionPolicy: Message = .{ .fields = &.{
    .{ .number = 1, .json = "metadata", .type = .message, .message = &meta_v1_ObjectMeta, .omit_zero = false },
    .{ .number = 2, .json = "spec", .type = .message, .message = &admissionregistration_v1_ValidatingAdmissionPolicySpec, .omit_zero = false },
    .{ .number = 3, .json = "status", .type = .message, .message = &admissionregistration_v1_ValidatingAdmissionPolicyStatus, .omit_zero = false },
} };

pub const admissionregistration_v1_ValidatingAdmissionPolicyBinding: Message = .{ .fields = &.{
    .{ .number = 1, .json = "metadata", .type = .message, .message = &meta_v1_ObjectMeta, .omit_zero = false },
    .{ .number = 2, .json = "spec", .type = .message, .message = &admissionregistration_v1_ValidatingAdmissionPolicyBindingSpec, .omit_zero = false },
} };

pub const admissionregistration_v1_ValidatingAdmissionPolicyBindingSpec: Message = .{ .fields = &.{
    .{ .number = 1, .json = "policyName", .type = .string },
    .{ .number = 2, .json = "paramRef", .type = .message, .message = &admissionregistration_v1_ParamRef, .omit_zero = false },
    .{ .number = 3, .json = "matchResources", .type = .message, .message = &admissionregistration_v1_MatchResources, .omit_zero = false },
    .{ .number = 4, .json = "validationActions", .type = .string, .repeated = true },
} };

pub const admissionregistration_v1_ValidatingAdmissionPolicySpec: Message = .{ .fields = &.{
    .{ .number = 1, .json = "paramKind", .type = .message, .message = &admissionregistration_v1_ParamKind, .omit_zero = false },
    .{ .number = 2, .json = "matchConstraints", .type = .message, .message = &admissionregistration_v1_MatchResources, .omit_zero = false },
    .{ .number = 3, .json = "validations", .type = .message, .message = &admissionregistration_v1_Validation, .repeated = true },
    .{ .number = 4, .json = "failurePolicy", .type = .string, .omit_zero = false },
    .{ .number = 5, .json = "auditAnnotations", .type = .message, .message = &admissionregistration_v1_AuditAnnotation, .repeated = true },
    .{ .number = 6, .json = "matchConditions", .type = .message, .message = &admissionregistration_v1_MatchCondition, .repeated = true },
    .{ .number = 7, .json = "variables", .type = .message, .message = &admissionregistration_v1_Variable, .repeated = true },
} };

pub const admissionregistration_v1_ValidatingAdmissionPolicyStatus: Message = .{ .fields = &.{
    .{ .number = 1, .json = "observedGeneration", .type = .int64 },
    .{ .number = 2, .json = "typeChecking", .type = .message, .message = &admissionregistration_v1_TypeChecking, .omit_zero = false },
    .{ .number = 3, .json = "conditions", .type = .message, .message = &meta_v1_Condition, .repeated = true },
} };

pub const admissionregistration_v1_ValidatingWebhook: Message = .{ .fields = &.{
    .{ .number = 1, .json = "name", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "clientConfig", .type = .message, .message = &admissionregistration_v1_WebhookClientConfig, .omit_zero = false },
    .{ .number = 3, .json = "rules", .type = .message, .message = &admissionregistration_v1_RuleWithOperations, .repeated = true },
    .{ .number = 4, .json = "failurePolicy", .type = .string, .omit_zero = false },
    .{ .number = 9, .json = "matchPolicy", .type = .string, .omit_zero = false },
    .{ .number = 5, .json = "namespaceSelector", .type = .message, .message = &meta_v1_LabelSelector, .omit_zero = false },
    .{ .number = 10, .json = "objectSelector", .type = .message, .message = &meta_v1_LabelSelector, .omit_zero = false },
    .{ .number = 6, .json = "sideEffects", .type = .string, .omit_zero = false },
    .{ .number = 7, .json = "timeoutSeconds", .type = .int32, .omit_zero = false },
    .{ .number = 8, .json = "admissionReviewVersions", .type = .string, .repeated = true },
    .{ .number = 11, .json = "matchConditions", .type = .message, .message = &admissionregistration_v1_MatchCondition, .repeated = true },
} };

pub const admissionregistration_v1_ValidatingWebhookConfiguration: Message = .{ .fields = &.{
    .{ .number = 1, .json = "metadata", .type = .message, .message = &meta_v1_ObjectMeta, .omit_zero = false },
    .{ .number = 2, .json = "webhooks", .type = .message, .message = &admissionregistration_v1_ValidatingWebhook, .repeated = true },
} };

pub const admissionregistration_v1_Validation: Message = .{ .fields = &.{
    .{ .number = 1, .json = "expression", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "message", .type = .string },
    .{ .number = 3, .json = "reason", .type = .string, .omit_zero = false },
    .{ .number = 4, .json = "messageExpression", .type = .string },
} };

pub const admissionregistration_v1_Variable: Message = .{ .fields = &.{
    .{ .number = 1, .json = "name", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "expression", .type = .string, .omit_zero = false },
} };

pub const admissionregistration_v1_WebhookClientConfig: Message = .{ .fields = &.{
    .{ .number = 3, .json = "url", .type = .string, .omit_zero = false },
    .{ .number = 1, .json = "service", .type = .message, .message = &admissionregistration_v1_ServiceReference, .omit_zero = false },
    .{ .number = 2, .json = "caBundle", .type = .bytes },
} };

pub const apps_v1_DaemonSet: Message = .{ .fields = &.{
    .{ .number = 1, .json = "metadata", .type = .message, .message = &meta_v1_ObjectMeta, .omit_zero = false },
    .{ .number = 2, .json = "spec", .type = .message, .message = &apps_v1_DaemonSetSpec, .omit_zero = false },
    .{ .number = 3, .json = "status", .type = .message, .message = &apps_v1_DaemonSetStatus, .omit_zero = false },
} };

pub const apps_v1_DaemonSetCondition: Message = .{ .fields = &.{
    .{ .number = 1, .json = "type", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "status", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "lastTransitionTime", .type = .time },
    .{ .number = 4, .json = "reason", .type = .string },
    .{ .number = 5, .json = "message", .type = .string },
} };

pub const apps_v1_DaemonSetSpec: Message = .{ .fields = &.{
    .{ .number = 1, .json = "selector", .type = .message, .message = &meta_v1_LabelSelector, .omit_zero = false },
    .{ .number = 2, .json = "template", .type = .message, .message = &core_v1_PodTemplateSpec, .omit_zero = false },
    .{ .number = 3, .json = "updateStrategy", .type = .message, .message = &apps_v1_DaemonSetUpdateStrategy, .omit_zero = false },
    .{ .number = 4, .json = "minReadySeconds", .type = .int32 },
    .{ .number = 6, .json = "revisionHistoryLimit", .type = .int32, .omit_zero = false },
} };

pub const apps_v1_DaemonSetStatus: Message = .{ .fields = &.{
    .{ .number = 1, .json = "currentNumberScheduled", .type = .int32, .omit_zero = false },
    .{ .number = 2, .json = "numberMisscheduled", .type = .int32, .omit_zero = false },
    .{ .number = 3, .json = "desiredNumberScheduled", .type = .int32, .omit_zero = false },
    .{ .number = 4, .json = "numberReady", .type = .int32, .omit_zero = false },
    .{ .number = 5, .json = "observedGeneration", .type = .int64 },
    .{ .number = 6, .json = "updatedNumberScheduled", .type = .int32 },
    .{ .number = 7, .json = "numberAvailable", .type = .int32 },
    .{ .number = 8, .json = "numberUnavailable", .type = .int32 },
    .{ .number = 9, .json = "collisionCount", .type = .int32, .omit_zero = false },
    .{ .number = 10, .json = "conditions", .type = .message, .message = &apps_v1_DaemonSetCondition, .repeated = true },
} };

pub const apps_v1_DaemonSetUpdateStrategy: Message = .{ .fields = &.{
    .{ .number = 1, .json = "type", .type = .string },
    .{ .number = 2, .json = "rollingUpdate", .type = .message, .message = &apps_v1_RollingUpdateDaemonSet, .omit_zero = false },
} };

pub const apps_v1_Deployment: Message = .{ .fields = &.{
    .{ .number = 1, .json = "metadata", .type = .message, .message = &meta_v1_ObjectMeta, .omit_zero = false },
    .{ .number = 2, .json = "spec", .type = .message, .message = &apps_v1_DeploymentSpec, .omit_zero = false },
    .{ .number = 3, .json = "status", .type = .message, .message = &apps_v1_DeploymentStatus, .omit_zero = false },
} };

pub const apps_v1_DeploymentCondition: Message = .{ .fields = &.{
    .{ .number = 1, .json = "type", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "status", .type = .string, .omit_zero = false },
    .{ .number = 6, .json = "lastUpdateTime", .type = .time },
    .{ .number = 7, .json = "lastTransitionTime", .type = .time },
    .{ .number = 4, .json = "reason", .type = .string },
    .{ .number = 5, .json = "message", .type = .string },
} };

pub const apps_v1_DeploymentSpec: Message = .{ .fields = &.{
    .{ .number = 1, .json = "replicas", .type = .int32, .omit_zero = false },
    .{ .number = 2, .json = "selector", .type = .message, .message = &meta_v1_LabelSelector, .omit_zero = false },
    .{ .number = 3, .json = "template", .type = .message, .message = &core_v1_PodTemplateSpec, .omit_zero = false },
    .{ .number = 4, .json = "strategy", .type = .message, .message = &apps_v1_DeploymentStrategy, .omit_zero = false },
    .{ .number = 5, .json = "minReadySeconds", .type = .int32 },
    .{ .number = 6, .json = "revisionHistoryLimit", .type = .int32, .omit_zero = false },
    .{ .number = 7, .json = "paused", .type = .bool },
    .{ .number = 9, .json = "progressDeadlineSeconds", .type = .int32, .omit_zero = false },
} };

pub const apps_v1_DeploymentStatus: Message = .{ .fields = &.{
    .{ .number = 1, .json = "observedGeneration", .type = .int64 },
    .{ .number = 2, .json = "replicas", .type = .int32 },
    .{ .number = 3, .json = "updatedReplicas", .type = .int32 },
    .{ .number = 7, .json = "readyReplicas", .type = .int32 },
    .{ .number = 4, .json = "availableReplicas", .type = .int32 },
    .{ .number = 5, .json = "unavailableReplicas", .type = .int32 },
    .{ .number = 9, .json = "terminatingReplicas", .type = .int32, .omit_zero = false },
    .{ .number = 6, .json = "conditions", .type = .message, .message = &apps_v1_DeploymentCondition, .repeated = true },
    .{ .number = 8, .json = "collisionCount", .type = .int32, .omit_zero = false },
} };

pub const apps_v1_DeploymentStrategy: Message = .{ .fields = &.{
    .{ .number = 1, .json = "type", .type = .string },
    .{ .number = 2, .json = "rollingUpdate", .type = .message, .message = &apps_v1_RollingUpdateDeployment, .omit_zero = false },
} };

pub const apps_v1_ReplicaSet: Message = .{ .fields = &.{
    .{ .number = 1, .json = "metadata", .type = .message, .message = &meta_v1_ObjectMeta, .omit_zero = false },
    .{ .number = 2, .json = "spec", .type = .message, .message = &apps_v1_ReplicaSetSpec, .omit_zero = false },
    .{ .number = 3, .json = "status", .type = .message, .message = &apps_v1_ReplicaSetStatus, .omit_zero = false },
} };

pub const apps_v1_ReplicaSetCondition: Message = .{ .fields = &.{
    .{ .number = 1, .json = "type", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "status", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "lastTransitionTime", .type = .time },
    .{ .number = 4, .json = "reason", .type = .string },
    .{ .number = 5, .json = "message", .type = .string },
} };

pub const apps_v1_ReplicaSetSpec: Message = .{ .fields = &.{
    .{ .number = 1, .json = "replicas", .type = .int32, .omit_zero = false },
    .{ .number = 4, .json = "minReadySeconds", .type = .int32 },
    .{ .number = 2, .json = "selector", .type = .message, .message = &meta_v1_LabelSelector, .omit_zero = false },
    .{ .number = 3, .json = "template", .type = .message, .message = &core_v1_PodTemplateSpec, .omit_zero = false },
} };

pub const apps_v1_ReplicaSetStatus: Message = .{ .fields = &.{
    .{ .number = 1, .json = "replicas", .type = .int32, .omit_zero = false },
    .{ .number = 2, .json = "fullyLabeledReplicas", .type = .int32 },
    .{ .number = 4, .json = "readyReplicas", .type = .int32 },
    .{ .number = 5, .json = "availableReplicas", .type = .int32 },
    .{ .number = 7, .json = "terminatingReplicas", .type = .int32, .omit_zero = false },
    .{ .number = 3, .json = "observedGeneration", .type = .int64 },
    .{ .number = 6, .json = "conditions", .type = .message, .message = &apps_v1_ReplicaSetCondition, .repeated = true },
} };

pub const apps_v1_RollingUpdateDaemonSet: Message = .{ .fields = &.{
    .{ .number = 1, .json = "maxUnavailable", .type = .int_or_string, .omit_zero = false },
    .{ .number = 2, .json = "maxSurge", .type = .int_or_string, .omit_zero = false },
} };

pub const apps_v1_RollingUpdateDeployment: Message = .{ .fields = &.{
    .{ .number = 1, .json = "maxUnavailable", .type = .int_or_string, .omit_zero = false },
    .{ .number = 2, .json = "maxSurge", .type = .int_or_string, .omit_zero = false },
} };

pub const apps_v1_RollingUpdateStatefulSetStrategy: Message = .{ .fields = &.{
    .{ .number = 1, .json = "partition", .type = .int32, .omit_zero = false },
    .{ .number = 2, .json = "maxUnavailable", .type = .int_or_string, .omit_zero = false },
} };

pub const apps_v1_StatefulSet: Message = .{ .fields = &.{
    .{ .number = 1, .json = "metadata", .type = .message, .message = &meta_v1_ObjectMeta, .omit_zero = false },
    .{ .number = 2, .json = "spec", .type = .message, .message = &apps_v1_StatefulSetSpec, .omit_zero = false },
    .{ .number = 3, .json = "status", .type = .message, .message = &apps_v1_StatefulSetStatus, .omit_zero = false },
} };

pub const apps_v1_StatefulSetCondition: Message = .{ .fields = &.{
    .{ .number = 1, .json = "type", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "status", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "lastTransitionTime", .type = .time },
    .{ .number = 4, .json = "reason", .type = .string },
    .{ .number = 5, .json = "message", .type = .string },
} };

pub const apps_v1_StatefulSetOrdinals: Message = .{ .fields = &.{
    .{ .number = 1, .json = "start", .type = .int32, .omit_zero = false },
} };

pub const apps_v1_StatefulSetPersistentVolumeClaimRetentionPolicy: Message = .{ .fields = &.{
    .{ .number = 1, .json = "whenDeleted", .type = .string },
    .{ .number = 2, .json = "whenScaled", .type = .string },
} };

pub const apps_v1_StatefulSetSpec: Message = .{ .fields = &.{
    .{ .number = 1, .json = "replicas", .type = .int32, .omit_zero = false },
    .{ .number = 2, .json = "selector", .type = .message, .message = &meta_v1_LabelSelector, .omit_zero = false },
    .{ .number = 3, .json = "template", .type = .message, .message = &core_v1_PodTemplateSpec, .omit_zero = false },
    .{ .number = 4, .json = "volumeClaimTemplates", .type = .message, .message = &core_v1_PersistentVolumeClaim, .repeated = true },
    .{ .number = 5, .json = "serviceName", .type = .string, .omit_zero = false },
    .{ .number = 6, .json = "podManagementPolicy", .type = .string },
    .{ .number = 7, .json = "updateStrategy", .type = .message, .message = &apps_v1_StatefulSetUpdateStrategy, .omit_zero = false },
    .{ .number = 8, .json = "revisionHistoryLimit", .type = .int32, .omit_zero = false },
    .{ .number = 9, .json = "minReadySeconds", .type = .int32 },
    .{ .number = 10, .json = "persistentVolumeClaimRetentionPolicy", .type = .message, .message = &apps_v1_StatefulSetPersistentVolumeClaimRetentionPolicy, .omit_zero = false },
    .{ .number = 11, .json = "ordinals", .type = .message, .message = &apps_v1_StatefulSetOrdinals, .omit_zero = false },
} };

pub const apps_v1_StatefulSetStatus: Message = .{ .fields = &.{
    .{ .number = 1, .json = "observedGeneration", .type = .int64 },
    .{ .number = 2, .json = "replicas", .type = .int32, .omit_zero = false },
    .{ .number = 3, .json = "readyReplicas", .type = .int32 },
    .{ .number = 4, .json = "currentReplicas", .type = .int32 },
    .{ .number = 5, .json = "updatedReplicas", .type = .int32 },
    .{ .number = 6, .json = "currentRevision", .type = .string },
    .{ .number = 7, .json = "updateRevision", .type = .string },
    .{ .number = 9, .json = "collisionCount", .type = .int32, .omit_zero = false },
    .{ .number = 10, .json = "conditions", .type = .message, .message = &apps_v1_StatefulSetCondition, .repeated = true },
    .{ .number = 11, .json = "availableReplicas", .type = .int32, .omit_zero = false },
} };

pub const apps_v1_StatefulSetUpdateStrategy: Message = .{ .fields = &.{
    .{ .number = 1, .json = "type", .type = .string },
    .{ .number = 2, .json = "rollingUpdate", .type = .message, .message = &apps_v1_RollingUpdateStatefulSetStrategy, .omit_zero = false },
} };

pub const autoscaling_v2_ContainerResourceMetricSource: Message = .{ .fields = &.{
    .{ .number = 1, .json = "name", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "target", .type = .message, .message = &autoscaling_v2_MetricTarget, .omit_zero = false },
    .{ .number = 3, .json = "container", .type = .string, .omit_zero = false },
} };

pub const autoscaling_v2_ContainerResourceMetricStatus: Message = .{ .fields = &.{
    .{ .number = 1, .json = "name", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "current", .type = .message, .message = &autoscaling_v2_MetricValueStatus, .omit_zero = false },
    .{ .number = 3, .json = "container", .type = .string, .omit_zero = false },
} };

pub const autoscaling_v2_CrossVersionObjectReference: Message = .{ .fields = &.{
    .{ .number = 1, .json = "kind", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "name", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "apiVersion", .type = .string },
} };

pub const autoscaling_v2_ExternalMetricSource: Message = .{ .fields = &.{
    .{ .number = 1, .json = "metric", .type = .message, .message = &autoscaling_v2_MetricIdentifier, .omit_zero = false },
    .{ .number = 2, .json = "target", .type = .message, .message = &autoscaling_v2_MetricTarget, .omit_zero = false },
} };

pub const autoscaling_v2_ExternalMetricStatus: Message = .{ .fields = &.{
    .{ .number = 1, .json = "metric", .type = .message, .message = &autoscaling_v2_MetricIdentifier, .omit_zero = false },
    .{ .number = 2, .json = "current", .type = .message, .message = &autoscaling_v2_MetricValueStatus, .omit_zero = false },
} };

pub const autoscaling_v2_HPAScalingPolicy: Message = .{ .fields = &.{
    .{ .number = 1, .json = "type", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "value", .type = .int32, .omit_zero = false },
    .{ .number = 3, .json = "periodSeconds", .type = .int32, .omit_zero = false },
} };

pub const autoscaling_v2_HPAScalingRules: Message = .{ .fields = &.{
    .{ .number = 3, .json = "stabilizationWindowSeconds", .type = .int32, .omit_zero = false },
    .{ .number = 1, .json = "selectPolicy", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "policies", .type = .message, .message = &autoscaling_v2_HPAScalingPolicy, .repeated = true },
    .{ .number = 4, .json = "tolerance", .type = .quantity, .omit_zero = false },
} };

pub const autoscaling_v2_HorizontalPodAutoscaler: Message = .{ .fields = &.{
    .{ .number = 1, .json = "metadata", .type = .message, .message = &meta_v1_ObjectMeta, .omit_zero = false },
    .{ .number = 2, .json = "spec", .type = .message, .message = &autoscaling_v2_HorizontalPodAutoscalerSpec, .omit_zero = false },
    .{ .number = 3, .json = "status", .type = .message, .message = &autoscaling_v2_HorizontalPodAutoscalerStatus, .omit_zero = false },
} };

pub const autoscaling_v2_HorizontalPodAutoscalerBehavior: Message = .{ .fields = &.{
    .{ .number = 1, .json = "scaleUp", .type = .message, .message = &autoscaling_v2_HPAScalingRules, .omit_zero = false },
    .{ .number = 2, .json = "scaleDown", .type = .message, .message = &autoscaling_v2_HPAScalingRules, .omit_zero = false },
} };

pub const autoscaling_v2_HorizontalPodAutoscalerCondition: Message = .{ .fields = &.{
    .{ .number = 1, .json = "type", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "status", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "lastTransitionTime", .type = .time },
    .{ .number = 4, .json = "reason", .type = .string },
    .{ .number = 5, .json = "message", .type = .string },
    .{ .number = 6, .json = "observedGeneration", .type = .int64, .omit_zero = false },
} };

pub const autoscaling_v2_HorizontalPodAutoscalerSpec: Message = .{ .fields = &.{
    .{ .number = 1, .json = "scaleTargetRef", .type = .message, .message = &autoscaling_v2_CrossVersionObjectReference, .omit_zero = false },
    .{ .number = 2, .json = "minReplicas", .type = .int32, .omit_zero = false },
    .{ .number = 3, .json = "maxReplicas", .type = .int32, .omit_zero = false },
    .{ .number = 4, .json = "metrics", .type = .message, .message = &autoscaling_v2_MetricSpec, .repeated = true },
    .{ .number = 5, .json = "behavior", .type = .message, .message = &autoscaling_v2_HorizontalPodAutoscalerBehavior, .omit_zero = false },
} };

pub const autoscaling_v2_HorizontalPodAutoscalerStatus: Message = .{ .fields = &.{
    .{ .number = 1, .json = "observedGeneration", .type = .int64, .omit_zero = false },
    .{ .number = 2, .json = "lastScaleTime", .type = .time, .omit_zero = false },
    .{ .number = 3, .json = "currentReplicas", .type = .int32 },
    .{ .number = 4, .json = "desiredReplicas", .type = .int32, .omit_zero = false },
    .{ .number = 5, .json = "currentMetrics", .type = .message, .message = &autoscaling_v2_MetricStatus, .repeated = true },
    .{ .number = 6, .json = "conditions", .type = .message, .message = &autoscaling_v2_HorizontalPodAutoscalerCondition, .repeated = true },
} };

pub const autoscaling_v2_MetricIdentifier: Message = .{ .fields = &.{
    .{ .number = 1, .json = "name", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "selector", .type = .message, .message = &meta_v1_LabelSelector, .omit_zero = false },
} };

pub const autoscaling_v2_MetricSpec: Message = .{ .fields = &.{
    .{ .number = 1, .json = "type", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "object", .type = .message, .message = &autoscaling_v2_ObjectMetricSource, .omit_zero = false },
    .{ .number = 3, .json = "pods", .type = .message, .message = &autoscaling_v2_PodsMetricSource, .omit_zero = false },
    .{ .number = 4, .json = "resource", .type = .message, .message = &autoscaling_v2_ResourceMetricSource, .omit_zero = false },
    .{ .number = 7, .json = "containerResource", .type = .message, .message = &autoscaling_v2_ContainerResourceMetricSource, .omit_zero = false },
    .{ .number = 5, .json = "external", .type = .message, .message = &autoscaling_v2_ExternalMetricSource, .omit_zero = false },
} };

pub const autoscaling_v2_MetricStatus: Message = .{ .fields = &.{
    .{ .number = 1, .json = "type", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "object", .type = .message, .message = &autoscaling_v2_ObjectMetricStatus, .omit_zero = false },
    .{ .number = 3, .json = "pods", .type = .message, .message = &autoscaling_v2_PodsMetricStatus, .omit_zero = false },
    .{ .number = 4, .json = "resource", .type = .message, .message = &autoscaling_v2_ResourceMetricStatus, .omit_zero = false },
    .{ .number = 7, .json = "containerResource", .type = .message, .message = &autoscaling_v2_ContainerResourceMetricStatus, .omit_zero = false },
    .{ .number = 5, .json = "external", .type = .message, .message = &autoscaling_v2_ExternalMetricStatus, .omit_zero = false },
} };

pub const autoscaling_v2_MetricTarget: Message = .{ .fields = &.{
    .{ .number = 1, .json = "type", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "value", .type = .quantity, .omit_zero = false },
    .{ .number = 3, .json = "averageValue", .type = .quantity, .omit_zero = false },
    .{ .number = 4, .json = "averageUtilization", .type = .int32, .omit_zero = false },
} };

pub const autoscaling_v2_MetricValueStatus: Message = .{ .fields = &.{
    .{ .number = 1, .json = "value", .type = .quantity, .omit_zero = false },
    .{ .number = 2, .json = "averageValue", .type = .quantity, .omit_zero = false },
    .{ .number = 3, .json = "averageUtilization", .type = .int32, .omit_zero = false },
} };

pub const autoscaling_v2_ObjectMetricSource: Message = .{ .fields = &.{
    .{ .number = 1, .json = "describedObject", .type = .message, .message = &autoscaling_v2_CrossVersionObjectReference, .omit_zero = false },
    .{ .number = 2, .json = "target", .type = .message, .message = &autoscaling_v2_MetricTarget, .omit_zero = false },
    .{ .number = 3, .json = "metric", .type = .message, .message = &autoscaling_v2_MetricIdentifier, .omit_zero = false },
} };

pub const autoscaling_v2_ObjectMetricStatus: Message = .{ .fields = &.{
    .{ .number = 1, .json = "metric", .type = .message, .message = &autoscaling_v2_MetricIdentifier, .omit_zero = false },
    .{ .number = 2, .json = "current", .type = .message, .message = &autoscaling_v2_MetricValueStatus, .omit_zero = false },
    .{ .number = 3, .json = "describedObject", .type = .message, .message = &autoscaling_v2_CrossVersionObjectReference, .omit_zero = false },
} };

pub const autoscaling_v2_PodsMetricSource: Message = .{ .fields = &.{
    .{ .number = 1, .json = "metric", .type = .message, .message = &autoscaling_v2_MetricIdentifier, .omit_zero = false },
    .{ .number = 2, .json = "target", .type = .message, .message = &autoscaling_v2_MetricTarget, .omit_zero = false },
} };

pub const autoscaling_v2_PodsMetricStatus: Message = .{ .fields = &.{
    .{ .number = 1, .json = "metric", .type = .message, .message = &autoscaling_v2_MetricIdentifier, .omit_zero = false },
    .{ .number = 2, .json = "current", .type = .message, .message = &autoscaling_v2_MetricValueStatus, .omit_zero = false },
} };

pub const autoscaling_v2_ResourceMetricSource: Message = .{ .fields = &.{
    .{ .number = 1, .json = "name", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "target", .type = .message, .message = &autoscaling_v2_MetricTarget, .omit_zero = false },
} };

pub const autoscaling_v2_ResourceMetricStatus: Message = .{ .fields = &.{
    .{ .number = 1, .json = "name", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "current", .type = .message, .message = &autoscaling_v2_MetricValueStatus, .omit_zero = false },
} };

pub const batch_v1_CronJob: Message = .{ .fields = &.{
    .{ .number = 1, .json = "metadata", .type = .message, .message = &meta_v1_ObjectMeta, .omit_zero = false },
    .{ .number = 2, .json = "spec", .type = .message, .message = &batch_v1_CronJobSpec, .omit_zero = false },
    .{ .number = 3, .json = "status", .type = .message, .message = &batch_v1_CronJobStatus, .omit_zero = false },
} };

pub const batch_v1_CronJobSpec: Message = .{ .fields = &.{
    .{ .number = 1, .json = "schedule", .type = .string, .omit_zero = false },
    .{ .number = 8, .json = "timeZone", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "startingDeadlineSeconds", .type = .int64, .omit_zero = false },
    .{ .number = 3, .json = "concurrencyPolicy", .type = .string },
    .{ .number = 4, .json = "suspend", .type = .bool, .omit_zero = false },
    .{ .number = 5, .json = "jobTemplate", .type = .message, .message = &batch_v1_JobTemplateSpec, .omit_zero = false },
    .{ .number = 6, .json = "successfulJobsHistoryLimit", .type = .int32, .omit_zero = false },
    .{ .number = 7, .json = "failedJobsHistoryLimit", .type = .int32, .omit_zero = false },
} };

pub const batch_v1_CronJobStatus: Message = .{ .fields = &.{
    .{ .number = 1, .json = "active", .type = .message, .message = &core_v1_ObjectReference, .repeated = true },
    .{ .number = 4, .json = "lastScheduleTime", .type = .time, .omit_zero = false },
    .{ .number = 5, .json = "lastSuccessfulTime", .type = .time, .omit_zero = false },
} };

pub const batch_v1_Job: Message = .{ .fields = &.{
    .{ .number = 1, .json = "metadata", .type = .message, .message = &meta_v1_ObjectMeta, .omit_zero = false },
    .{ .number = 2, .json = "spec", .type = .message, .message = &batch_v1_JobSpec, .omit_zero = false },
    .{ .number = 3, .json = "status", .type = .message, .message = &batch_v1_JobStatus, .omit_zero = false },
} };

pub const batch_v1_JobCondition: Message = .{ .fields = &.{
    .{ .number = 1, .json = "type", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "status", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "lastProbeTime", .type = .time },
    .{ .number = 4, .json = "lastTransitionTime", .type = .time },
    .{ .number = 5, .json = "reason", .type = .string },
    .{ .number = 6, .json = "message", .type = .string },
} };

pub const batch_v1_JobSchedulingConfiguration: Message = .{ .fields = &.{
    .{ .number = 1, .json = "schedulingPolicy", .type = .message, .message = &scheduling_v1alpha3_WorkloadPodGroupSchedulingPolicy, .omit_zero = false },
    .{ .number = 2, .json = "schedulingConstraints", .type = .message, .message = &scheduling_v1alpha3_WorkloadPodGroupSchedulingConstraints, .omit_zero = false },
    .{ .number = 3, .json = "disruptionMode", .type = .message, .message = &scheduling_v1alpha3_WorkloadPodGroupDisruptionMode, .omit_zero = false },
    .{ .number = 4, .json = "resourceClaims", .type = .message, .message = &scheduling_v1alpha3_WorkloadPodGroupResourceClaim, .repeated = true },
} };

pub const batch_v1_JobSpec: Message = .{ .fields = &.{
    .{ .number = 1, .json = "parallelism", .type = .int32, .omit_zero = false },
    .{ .number = 2, .json = "completions", .type = .int32, .omit_zero = false },
    .{ .number = 3, .json = "activeDeadlineSeconds", .type = .int64, .omit_zero = false },
    .{ .number = 11, .json = "podFailurePolicy", .type = .message, .message = &batch_v1_PodFailurePolicy, .omit_zero = false },
    .{ .number = 16, .json = "successPolicy", .type = .message, .message = &batch_v1_SuccessPolicy, .omit_zero = false },
    .{ .number = 7, .json = "backoffLimit", .type = .int32, .omit_zero = false },
    .{ .number = 12, .json = "backoffLimitPerIndex", .type = .int32, .omit_zero = false },
    .{ .number = 13, .json = "maxFailedIndexes", .type = .int32, .omit_zero = false },
    .{ .number = 4, .json = "selector", .type = .message, .message = &meta_v1_LabelSelector, .omit_zero = false },
    .{ .number = 5, .json = "manualSelector", .type = .bool, .omit_zero = false },
    .{ .number = 6, .json = "template", .type = .message, .message = &core_v1_PodTemplateSpec, .omit_zero = false },
    .{ .number = 8, .json = "ttlSecondsAfterFinished", .type = .int32, .omit_zero = false },
    .{ .number = 9, .json = "completionMode", .type = .string, .omit_zero = false },
    .{ .number = 10, .json = "suspend", .type = .bool, .omit_zero = false },
    .{ .number = 14, .json = "podReplacementPolicy", .type = .string, .omit_zero = false },
    .{ .number = 15, .json = "managedBy", .type = .string, .omit_zero = false },
    .{ .number = 17, .json = "scheduling", .type = .message, .message = &batch_v1_JobSchedulingConfiguration, .omit_zero = false },
} };

pub const batch_v1_JobStatus: Message = .{ .fields = &.{
    .{ .number = 1, .json = "conditions", .type = .message, .message = &batch_v1_JobCondition, .repeated = true },
    .{ .number = 2, .json = "startTime", .type = .time, .omit_zero = false },
    .{ .number = 3, .json = "completionTime", .type = .time, .omit_zero = false },
    .{ .number = 4, .json = "active", .type = .int32 },
    .{ .number = 5, .json = "succeeded", .type = .int32 },
    .{ .number = 6, .json = "failed", .type = .int32 },
    .{ .number = 11, .json = "terminating", .type = .int32, .omit_zero = false },
    .{ .number = 7, .json = "completedIndexes", .type = .string },
    .{ .number = 10, .json = "failedIndexes", .type = .string, .omit_zero = false },
    .{ .number = 8, .json = "uncountedTerminatedPods", .type = .message, .message = &batch_v1_UncountedTerminatedPods, .omit_zero = false },
    .{ .number = 9, .json = "ready", .type = .int32, .omit_zero = false },
} };

pub const batch_v1_JobTemplateSpec: Message = .{ .fields = &.{
    .{ .number = 1, .json = "metadata", .type = .message, .message = &meta_v1_ObjectMeta, .omit_zero = false },
    .{ .number = 2, .json = "spec", .type = .message, .message = &batch_v1_JobSpec, .omit_zero = false },
} };

pub const batch_v1_PodFailurePolicy: Message = .{ .fields = &.{
    .{ .number = 1, .json = "rules", .type = .message, .message = &batch_v1_PodFailurePolicyRule, .repeated = true },
} };

pub const batch_v1_PodFailurePolicyOnExitCodesRequirement: Message = .{ .fields = &.{
    .{ .number = 1, .json = "containerName", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "operator", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "values", .type = .int32, .repeated = true },
} };

pub const batch_v1_PodFailurePolicyOnPodConditionsPattern: Message = .{ .fields = &.{
    .{ .number = 1, .json = "type", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "status", .type = .string, .omit_zero = false },
} };

pub const batch_v1_PodFailurePolicyRule: Message = .{ .fields = &.{
    .{ .number = 1, .json = "action", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "onExitCodes", .type = .message, .message = &batch_v1_PodFailurePolicyOnExitCodesRequirement, .omit_zero = false },
    .{ .number = 3, .json = "onPodConditions", .type = .message, .message = &batch_v1_PodFailurePolicyOnPodConditionsPattern, .repeated = true },
} };

pub const batch_v1_SuccessPolicy: Message = .{ .fields = &.{
    .{ .number = 1, .json = "rules", .type = .message, .message = &batch_v1_SuccessPolicyRule, .repeated = true },
} };

pub const batch_v1_SuccessPolicyRule: Message = .{ .fields = &.{
    .{ .number = 1, .json = "succeededIndexes", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "succeededCount", .type = .int32, .omit_zero = false },
} };

pub const batch_v1_UncountedTerminatedPods: Message = .{ .fields = &.{
    .{ .number = 1, .json = "succeeded", .type = .string, .repeated = true },
    .{ .number = 2, .json = "failed", .type = .string, .repeated = true },
} };

pub const certificates_v1_CertificateSigningRequest: Message = .{ .fields = &.{
    .{ .number = 1, .json = "metadata", .type = .message, .message = &meta_v1_ObjectMeta, .omit_zero = false },
    .{ .number = 2, .json = "spec", .type = .message, .message = &certificates_v1_CertificateSigningRequestSpec, .omit_zero = false },
    .{ .number = 3, .json = "status", .type = .message, .message = &certificates_v1_CertificateSigningRequestStatus, .omit_zero = false },
} };

pub const certificates_v1_CertificateSigningRequestCondition: Message = .{ .fields = &.{
    .{ .number = 1, .json = "type", .type = .string, .omit_zero = false },
    .{ .number = 6, .json = "status", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "reason", .type = .string },
    .{ .number = 3, .json = "message", .type = .string },
    .{ .number = 4, .json = "lastUpdateTime", .type = .time },
    .{ .number = 5, .json = "lastTransitionTime", .type = .time },
} };

pub const certificates_v1_CertificateSigningRequestSpec: Message = .{ .fields = &.{
    .{ .number = 1, .json = "request", .type = .bytes, .omit_zero = false },
    .{ .number = 7, .json = "signerName", .type = .string, .omit_zero = false },
    .{ .number = 8, .json = "expirationSeconds", .type = .int32, .omit_zero = false },
    .{ .number = 5, .json = "usages", .type = .string, .repeated = true },
    .{ .number = 2, .json = "username", .type = .string },
    .{ .number = 3, .json = "uid", .type = .string },
    .{ .number = 4, .json = "groups", .type = .string, .repeated = true },
    .{ .number = 6, .json = "extra", .type = .string_list, .map = true },
} };

pub const certificates_v1_CertificateSigningRequestStatus: Message = .{ .fields = &.{
    .{ .number = 1, .json = "conditions", .type = .message, .message = &certificates_v1_CertificateSigningRequestCondition, .repeated = true },
    .{ .number = 2, .json = "certificate", .type = .bytes },
} };

pub const coordination_v1_Lease: Message = .{ .fields = &.{
    .{ .number = 1, .json = "metadata", .type = .message, .message = &meta_v1_ObjectMeta, .omit_zero = false },
    .{ .number = 2, .json = "spec", .type = .message, .message = &coordination_v1_LeaseSpec, .omit_zero = false },
} };

pub const coordination_v1_LeaseSpec: Message = .{ .fields = &.{
    .{ .number = 1, .json = "holderIdentity", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "leaseDurationSeconds", .type = .int32, .omit_zero = false },
    .{ .number = 3, .json = "acquireTime", .type = .micro_time, .omit_zero = false },
    .{ .number = 4, .json = "renewTime", .type = .micro_time, .omit_zero = false },
    .{ .number = 5, .json = "leaseTransitions", .type = .int32, .omit_zero = false },
    .{ .number = 6, .json = "strategy", .type = .string, .omit_zero = false },
    .{ .number = 7, .json = "preferredHolder", .type = .string, .omit_zero = false },
} };

pub const core_v1_AWSElasticBlockStoreVolumeSource: Message = .{ .fields = &.{
    .{ .number = 1, .json = "volumeID", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "fsType", .type = .string },
    .{ .number = 3, .json = "partition", .type = .int32 },
    .{ .number = 4, .json = "readOnly", .type = .bool },
} };

pub const core_v1_Affinity: Message = .{ .fields = &.{
    .{ .number = 1, .json = "nodeAffinity", .type = .message, .message = &core_v1_NodeAffinity, .omit_zero = false },
    .{ .number = 2, .json = "podAffinity", .type = .message, .message = &core_v1_PodAffinity, .omit_zero = false },
    .{ .number = 3, .json = "podAntiAffinity", .type = .message, .message = &core_v1_PodAntiAffinity, .omit_zero = false },
} };

pub const core_v1_AppArmorProfile: Message = .{ .fields = &.{
    .{ .number = 1, .json = "type", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "localhostProfile", .type = .string, .omit_zero = false },
} };

pub const core_v1_AttachedVolume: Message = .{ .fields = &.{
    .{ .number = 1, .json = "name", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "devicePath", .type = .string, .omit_zero = false },
} };

pub const core_v1_AzureDiskVolumeSource: Message = .{ .fields = &.{
    .{ .number = 1, .json = "diskName", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "diskURI", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "cachingMode", .type = .string, .omit_zero = false },
    .{ .number = 4, .json = "fsType", .type = .string, .omit_zero = false },
    .{ .number = 5, .json = "readOnly", .type = .bool, .omit_zero = false },
    .{ .number = 6, .json = "kind", .type = .string, .omit_zero = false },
} };

pub const core_v1_AzureFilePersistentVolumeSource: Message = .{ .fields = &.{
    .{ .number = 1, .json = "secretName", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "shareName", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "readOnly", .type = .bool },
    .{ .number = 4, .json = "secretNamespace", .type = .string, .omit_zero = false },
} };

pub const core_v1_AzureFileVolumeSource: Message = .{ .fields = &.{
    .{ .number = 1, .json = "secretName", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "shareName", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "readOnly", .type = .bool },
} };

pub const core_v1_CSIPersistentVolumeSource: Message = .{ .fields = &.{
    .{ .number = 1, .json = "driver", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "volumeHandle", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "readOnly", .type = .bool },
    .{ .number = 4, .json = "fsType", .type = .string },
    .{ .number = 5, .json = "volumeAttributes", .type = .string, .map = true },
    .{ .number = 6, .json = "controllerPublishSecretRef", .type = .message, .message = &core_v1_SecretReference, .omit_zero = false },
    .{ .number = 7, .json = "nodeStageSecretRef", .type = .message, .message = &core_v1_SecretReference, .omit_zero = false },
    .{ .number = 8, .json = "nodePublishSecretRef", .type = .message, .message = &core_v1_SecretReference, .omit_zero = false },
    .{ .number = 9, .json = "controllerExpandSecretRef", .type = .message, .message = &core_v1_SecretReference, .omit_zero = false },
    .{ .number = 10, .json = "nodeExpandSecretRef", .type = .message, .message = &core_v1_SecretReference, .omit_zero = false },
} };

pub const core_v1_CSIVolumeSource: Message = .{ .fields = &.{
    .{ .number = 1, .json = "driver", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "readOnly", .type = .bool, .omit_zero = false },
    .{ .number = 3, .json = "fsType", .type = .string, .omit_zero = false },
    .{ .number = 4, .json = "volumeAttributes", .type = .string, .map = true },
    .{ .number = 5, .json = "nodePublishSecretRef", .type = .message, .message = &core_v1_LocalObjectReference, .omit_zero = false },
} };

pub const core_v1_Capabilities: Message = .{ .fields = &.{
    .{ .number = 1, .json = "add", .type = .string, .repeated = true },
    .{ .number = 2, .json = "drop", .type = .string, .repeated = true },
} };

pub const core_v1_CephFSPersistentVolumeSource: Message = .{ .fields = &.{
    .{ .number = 1, .json = "monitors", .type = .string, .repeated = true },
    .{ .number = 2, .json = "path", .type = .string },
    .{ .number = 3, .json = "user", .type = .string },
    .{ .number = 4, .json = "secretFile", .type = .string },
    .{ .number = 5, .json = "secretRef", .type = .message, .message = &core_v1_SecretReference, .omit_zero = false },
    .{ .number = 6, .json = "readOnly", .type = .bool },
} };

pub const core_v1_CephFSVolumeSource: Message = .{ .fields = &.{
    .{ .number = 1, .json = "monitors", .type = .string, .repeated = true },
    .{ .number = 2, .json = "path", .type = .string },
    .{ .number = 3, .json = "user", .type = .string },
    .{ .number = 4, .json = "secretFile", .type = .string },
    .{ .number = 5, .json = "secretRef", .type = .message, .message = &core_v1_LocalObjectReference, .omit_zero = false },
    .{ .number = 6, .json = "readOnly", .type = .bool },
} };

pub const core_v1_CinderPersistentVolumeSource: Message = .{ .fields = &.{
    .{ .number = 1, .json = "volumeID", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "fsType", .type = .string },
    .{ .number = 3, .json = "readOnly", .type = .bool },
    .{ .number = 4, .json = "secretRef", .type = .message, .message = &core_v1_SecretReference, .omit_zero = false },
} };

pub const core_v1_CinderVolumeSource: Message = .{ .fields = &.{
    .{ .number = 1, .json = "volumeID", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "fsType", .type = .string },
    .{ .number = 3, .json = "readOnly", .type = .bool },
    .{ .number = 4, .json = "secretRef", .type = .message, .message = &core_v1_LocalObjectReference, .omit_zero = false },
} };

pub const core_v1_ClientIPConfig: Message = .{ .fields = &.{
    .{ .number = 1, .json = "timeoutSeconds", .type = .int32, .omit_zero = false },
} };

pub const core_v1_ClusterTrustBundleProjection: Message = .{ .fields = &.{
    .{ .number = 1, .json = "name", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "signerName", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "labelSelector", .type = .message, .message = &meta_v1_LabelSelector, .omit_zero = false },
    .{ .number = 5, .json = "optional", .type = .bool, .omit_zero = false },
    .{ .number = 4, .json = "path", .type = .string, .omit_zero = false },
    .{ .number = 6, .json = "user", .type = .int64, .omit_zero = false },
} };

pub const core_v1_ConfigMap: Message = .{ .fields = &.{
    .{ .number = 1, .json = "metadata", .type = .message, .message = &meta_v1_ObjectMeta, .omit_zero = false },
    .{ .number = 4, .json = "immutable", .type = .bool, .omit_zero = false },
    .{ .number = 2, .json = "data", .type = .string, .map = true },
    .{ .number = 3, .json = "binaryData", .type = .bytes, .map = true },
} };

pub const core_v1_ConfigMapEnvSource: Message = .{ .fields = &.{
    .{ .number = 1, .json = "", .type = .message, .message = &core_v1_LocalObjectReference, .embedded = true },
    .{ .number = 2, .json = "optional", .type = .bool, .omit_zero = false },
} };

pub const core_v1_ConfigMapKeySelector: Message = .{ .fields = &.{
    .{ .number = 1, .json = "", .type = .message, .message = &core_v1_LocalObjectReference, .embedded = true },
    .{ .number = 2, .json = "key", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "optional", .type = .bool, .omit_zero = false },
} };

pub const core_v1_ConfigMapNodeConfigSource: Message = .{ .fields = &.{
    .{ .number = 1, .json = "namespace", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "name", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "uid", .type = .string },
    .{ .number = 4, .json = "resourceVersion", .type = .string },
    .{ .number = 5, .json = "kubeletConfigKey", .type = .string, .omit_zero = false },
} };

pub const core_v1_ConfigMapProjection: Message = .{ .fields = &.{
    .{ .number = 1, .json = "", .type = .message, .message = &core_v1_LocalObjectReference, .embedded = true },
    .{ .number = 2, .json = "items", .type = .message, .message = &core_v1_KeyToPath, .repeated = true },
    .{ .number = 4, .json = "optional", .type = .bool, .omit_zero = false },
} };

pub const core_v1_ConfigMapVolumeSource: Message = .{ .fields = &.{
    .{ .number = 1, .json = "", .type = .message, .message = &core_v1_LocalObjectReference, .embedded = true },
    .{ .number = 2, .json = "items", .type = .message, .message = &core_v1_KeyToPath, .repeated = true },
    .{ .number = 3, .json = "defaultMode", .type = .int32, .omit_zero = false },
    .{ .number = 4, .json = "optional", .type = .bool, .omit_zero = false },
    .{ .number = 5, .json = "defaultUser", .type = .int64, .omit_zero = false },
} };

pub const core_v1_Container: Message = .{ .fields = &.{
    .{ .number = 1, .json = "name", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "image", .type = .string },
    .{ .number = 3, .json = "command", .type = .string, .repeated = true },
    .{ .number = 4, .json = "args", .type = .string, .repeated = true },
    .{ .number = 5, .json = "workingDir", .type = .string },
    .{ .number = 6, .json = "ports", .type = .message, .message = &core_v1_ContainerPort, .repeated = true },
    .{ .number = 19, .json = "envFrom", .type = .message, .message = &core_v1_EnvFromSource, .repeated = true },
    .{ .number = 7, .json = "env", .type = .message, .message = &core_v1_EnvVar, .repeated = true },
    .{ .number = 8, .json = "resources", .type = .message, .message = &core_v1_ResourceRequirements, .omit_zero = false },
    .{ .number = 23, .json = "resizePolicy", .type = .message, .message = &core_v1_ContainerResizePolicy, .repeated = true },
    .{ .number = 24, .json = "restartPolicy", .type = .string, .omit_zero = false },
    .{ .number = 25, .json = "restartPolicyRules", .type = .message, .message = &core_v1_ContainerRestartRule, .repeated = true },
    .{ .number = 9, .json = "volumeMounts", .type = .message, .message = &core_v1_VolumeMount, .repeated = true },
    .{ .number = 21, .json = "volumeDevices", .type = .message, .message = &core_v1_VolumeDevice, .repeated = true },
    .{ .number = 10, .json = "livenessProbe", .type = .message, .message = &core_v1_Probe, .omit_zero = false },
    .{ .number = 11, .json = "readinessProbe", .type = .message, .message = &core_v1_Probe, .omit_zero = false },
    .{ .number = 22, .json = "startupProbe", .type = .message, .message = &core_v1_Probe, .omit_zero = false },
    .{ .number = 12, .json = "lifecycle", .type = .message, .message = &core_v1_Lifecycle, .omit_zero = false },
    .{ .number = 13, .json = "terminationMessagePath", .type = .string },
    .{ .number = 20, .json = "terminationMessagePolicy", .type = .string },
    .{ .number = 14, .json = "imagePullPolicy", .type = .string },
    .{ .number = 15, .json = "securityContext", .type = .message, .message = &core_v1_SecurityContext, .omit_zero = false },
    .{ .number = 16, .json = "stdin", .type = .bool },
    .{ .number = 17, .json = "stdinOnce", .type = .bool },
    .{ .number = 18, .json = "tty", .type = .bool },
} };

pub const core_v1_ContainerExtendedResourceRequest: Message = .{ .fields = &.{
    .{ .number = 1, .json = "containerName", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "resourceName", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "requestName", .type = .string, .omit_zero = false },
} };

pub const core_v1_ContainerImage: Message = .{ .fields = &.{
    .{ .number = 1, .json = "names", .type = .string, .repeated = true },
    .{ .number = 2, .json = "sizeBytes", .type = .int64 },
} };

pub const core_v1_ContainerPort: Message = .{ .fields = &.{
    .{ .number = 1, .json = "name", .type = .string },
    .{ .number = 2, .json = "hostPort", .type = .int32 },
    .{ .number = 3, .json = "containerPort", .type = .int32, .omit_zero = false },
    .{ .number = 4, .json = "protocol", .type = .string },
    .{ .number = 5, .json = "hostIP", .type = .string },
} };

pub const core_v1_ContainerResizePolicy: Message = .{ .fields = &.{
    .{ .number = 1, .json = "resourceName", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "restartPolicy", .type = .string, .omit_zero = false },
} };

pub const core_v1_ContainerRestartRule: Message = .{ .fields = &.{
    .{ .number = 1, .json = "action", .type = .string },
    .{ .number = 2, .json = "exitCodes", .type = .message, .message = &core_v1_ContainerRestartRuleOnExitCodes, .omit_zero = false },
} };

pub const core_v1_ContainerRestartRuleOnExitCodes: Message = .{ .fields = &.{
    .{ .number = 1, .json = "operator", .type = .string },
    .{ .number = 2, .json = "values", .type = .int32, .repeated = true },
} };

pub const core_v1_ContainerState: Message = .{ .fields = &.{
    .{ .number = 1, .json = "waiting", .type = .message, .message = &core_v1_ContainerStateWaiting, .omit_zero = false },
    .{ .number = 2, .json = "running", .type = .message, .message = &core_v1_ContainerStateRunning, .omit_zero = false },
    .{ .number = 3, .json = "terminated", .type = .message, .message = &core_v1_ContainerStateTerminated, .omit_zero = false },
} };

pub const core_v1_ContainerStateRunning: Message = .{ .fields = &.{
    .{ .number = 1, .json = "startedAt", .type = .time },
} };

pub const core_v1_ContainerStateTerminated: Message = .{ .fields = &.{
    .{ .number = 1, .json = "exitCode", .type = .int32, .omit_zero = false },
    .{ .number = 2, .json = "signal", .type = .int32 },
    .{ .number = 3, .json = "reason", .type = .string },
    .{ .number = 4, .json = "message", .type = .string },
    .{ .number = 5, .json = "startedAt", .type = .time },
    .{ .number = 6, .json = "finishedAt", .type = .time },
    .{ .number = 7, .json = "containerID", .type = .string },
} };

pub const core_v1_ContainerStateWaiting: Message = .{ .fields = &.{
    .{ .number = 1, .json = "reason", .type = .string },
    .{ .number = 2, .json = "message", .type = .string },
} };

pub const core_v1_ContainerStatus: Message = .{ .fields = &.{
    .{ .number = 1, .json = "name", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "state", .type = .message, .message = &core_v1_ContainerState, .omit_zero = false },
    .{ .number = 3, .json = "lastState", .type = .message, .message = &core_v1_ContainerState, .omit_zero = false },
    .{ .number = 4, .json = "ready", .type = .bool, .omit_zero = false },
    .{ .number = 5, .json = "restartCount", .type = .int32, .omit_zero = false },
    .{ .number = 6, .json = "image", .type = .string, .omit_zero = false },
    .{ .number = 7, .json = "imageID", .type = .string, .omit_zero = false },
    .{ .number = 8, .json = "containerID", .type = .string },
    .{ .number = 9, .json = "started", .type = .bool, .omit_zero = false },
    .{ .number = 10, .json = "allocatedResources", .type = .quantity, .map = true },
    .{ .number = 11, .json = "resources", .type = .message, .message = &core_v1_ResourceRequirements, .omit_zero = false },
    .{ .number = 12, .json = "volumeMounts", .type = .message, .message = &core_v1_VolumeMountStatus, .repeated = true },
    .{ .number = 13, .json = "user", .type = .message, .message = &core_v1_ContainerUser, .omit_zero = false },
    .{ .number = 14, .json = "allocatedResourcesStatus", .type = .message, .message = &core_v1_ResourceStatus, .repeated = true },
    .{ .number = 15, .json = "stopSignal", .type = .string, .omit_zero = false },
} };

pub const core_v1_ContainerUser: Message = .{ .fields = &.{
    .{ .number = 1, .json = "linux", .type = .message, .message = &core_v1_LinuxContainerUser, .omit_zero = false },
} };

pub const core_v1_DaemonEndpoint: Message = .{ .fields = &.{
    .{ .number = 1, .json = "Port", .type = .int32, .omit_zero = false },
} };

pub const core_v1_DownwardAPIProjection: Message = .{ .fields = &.{
    .{ .number = 1, .json = "items", .type = .message, .message = &core_v1_DownwardAPIVolumeFile, .repeated = true },
} };

pub const core_v1_DownwardAPIVolumeFile: Message = .{ .fields = &.{
    .{ .number = 1, .json = "path", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "fieldRef", .type = .message, .message = &core_v1_ObjectFieldSelector, .omit_zero = false },
    .{ .number = 3, .json = "resourceFieldRef", .type = .message, .message = &core_v1_ResourceFieldSelector, .omit_zero = false },
    .{ .number = 4, .json = "mode", .type = .int32, .omit_zero = false },
    .{ .number = 5, .json = "user", .type = .int64, .omit_zero = false },
} };

pub const core_v1_DownwardAPIVolumeSource: Message = .{ .fields = &.{
    .{ .number = 1, .json = "items", .type = .message, .message = &core_v1_DownwardAPIVolumeFile, .repeated = true },
    .{ .number = 2, .json = "defaultMode", .type = .int32, .omit_zero = false },
    .{ .number = 3, .json = "defaultUser", .type = .int64, .omit_zero = false },
} };

pub const core_v1_EmptyDirVolumeSource: Message = .{ .fields = &.{
    .{ .number = 1, .json = "medium", .type = .string },
    .{ .number = 2, .json = "sizeLimit", .type = .quantity, .omit_zero = false },
    .{ .number = 3, .json = "mode", .type = .int32, .omit_zero = false },
} };

pub const core_v1_EndpointAddress: Message = .{ .fields = &.{
    .{ .number = 1, .json = "ip", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "hostname", .type = .string },
    .{ .number = 4, .json = "nodeName", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "targetRef", .type = .message, .message = &core_v1_ObjectReference, .omit_zero = false },
} };

pub const core_v1_EndpointPort: Message = .{ .fields = &.{
    .{ .number = 1, .json = "name", .type = .string },
    .{ .number = 2, .json = "port", .type = .int32, .omit_zero = false },
    .{ .number = 3, .json = "protocol", .type = .string },
    .{ .number = 4, .json = "appProtocol", .type = .string, .omit_zero = false },
} };

pub const core_v1_EndpointSubset: Message = .{ .fields = &.{
    .{ .number = 1, .json = "addresses", .type = .message, .message = &core_v1_EndpointAddress, .repeated = true },
    .{ .number = 2, .json = "notReadyAddresses", .type = .message, .message = &core_v1_EndpointAddress, .repeated = true },
    .{ .number = 3, .json = "ports", .type = .message, .message = &core_v1_EndpointPort, .repeated = true },
} };

pub const core_v1_Endpoints: Message = .{ .fields = &.{
    .{ .number = 1, .json = "metadata", .type = .message, .message = &meta_v1_ObjectMeta, .omit_zero = false },
    .{ .number = 2, .json = "subsets", .type = .message, .message = &core_v1_EndpointSubset, .repeated = true },
} };

pub const core_v1_EnvFromSource: Message = .{ .fields = &.{
    .{ .number = 1, .json = "prefix", .type = .string },
    .{ .number = 2, .json = "configMapRef", .type = .message, .message = &core_v1_ConfigMapEnvSource, .omit_zero = false },
    .{ .number = 3, .json = "secretRef", .type = .message, .message = &core_v1_SecretEnvSource, .omit_zero = false },
} };

pub const core_v1_EnvVar: Message = .{ .fields = &.{
    .{ .number = 1, .json = "name", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "value", .type = .string },
    .{ .number = 3, .json = "valueFrom", .type = .message, .message = &core_v1_EnvVarSource, .omit_zero = false },
} };

pub const core_v1_EnvVarSource: Message = .{ .fields = &.{
    .{ .number = 1, .json = "fieldRef", .type = .message, .message = &core_v1_ObjectFieldSelector, .omit_zero = false },
    .{ .number = 2, .json = "resourceFieldRef", .type = .message, .message = &core_v1_ResourceFieldSelector, .omit_zero = false },
    .{ .number = 3, .json = "configMapKeyRef", .type = .message, .message = &core_v1_ConfigMapKeySelector, .omit_zero = false },
    .{ .number = 4, .json = "secretKeyRef", .type = .message, .message = &core_v1_SecretKeySelector, .omit_zero = false },
    .{ .number = 5, .json = "fileKeyRef", .type = .message, .message = &core_v1_FileKeySelector, .omit_zero = false },
} };

pub const core_v1_EphemeralContainer: Message = .{ .fields = &.{
    .{ .number = 1, .json = "", .type = .message, .message = &core_v1_EphemeralContainerCommon, .embedded = true },
    .{ .number = 2, .json = "targetContainerName", .type = .string },
} };

pub const core_v1_EphemeralContainerCommon: Message = .{ .fields = &.{
    .{ .number = 1, .json = "name", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "image", .type = .string },
    .{ .number = 3, .json = "command", .type = .string, .repeated = true },
    .{ .number = 4, .json = "args", .type = .string, .repeated = true },
    .{ .number = 5, .json = "workingDir", .type = .string },
    .{ .number = 6, .json = "ports", .type = .message, .message = &core_v1_ContainerPort, .repeated = true },
    .{ .number = 19, .json = "envFrom", .type = .message, .message = &core_v1_EnvFromSource, .repeated = true },
    .{ .number = 7, .json = "env", .type = .message, .message = &core_v1_EnvVar, .repeated = true },
    .{ .number = 8, .json = "resources", .type = .message, .message = &core_v1_ResourceRequirements, .omit_zero = false },
    .{ .number = 23, .json = "resizePolicy", .type = .message, .message = &core_v1_ContainerResizePolicy, .repeated = true },
    .{ .number = 24, .json = "restartPolicy", .type = .string, .omit_zero = false },
    .{ .number = 25, .json = "restartPolicyRules", .type = .message, .message = &core_v1_ContainerRestartRule, .repeated = true },
    .{ .number = 9, .json = "volumeMounts", .type = .message, .message = &core_v1_VolumeMount, .repeated = true },
    .{ .number = 21, .json = "volumeDevices", .type = .message, .message = &core_v1_VolumeDevice, .repeated = true },
    .{ .number = 10, .json = "livenessProbe", .type = .message, .message = &core_v1_Probe, .omit_zero = false },
    .{ .number = 11, .json = "readinessProbe", .type = .message, .message = &core_v1_Probe, .omit_zero = false },
    .{ .number = 22, .json = "startupProbe", .type = .message, .message = &core_v1_Probe, .omit_zero = false },
    .{ .number = 12, .json = "lifecycle", .type = .message, .message = &core_v1_Lifecycle, .omit_zero = false },
    .{ .number = 13, .json = "terminationMessagePath", .type = .string },
    .{ .number = 20, .json = "terminationMessagePolicy", .type = .string },
    .{ .number = 14, .json = "imagePullPolicy", .type = .string },
    .{ .number = 15, .json = "securityContext", .type = .message, .message = &core_v1_SecurityContext, .omit_zero = false },
    .{ .number = 16, .json = "stdin", .type = .bool },
    .{ .number = 17, .json = "stdinOnce", .type = .bool },
    .{ .number = 18, .json = "tty", .type = .bool },
} };

pub const core_v1_EphemeralVolumeSource: Message = .{ .fields = &.{
    .{ .number = 1, .json = "volumeClaimTemplate", .type = .message, .message = &core_v1_PersistentVolumeClaimTemplate, .omit_zero = false },
} };

pub const core_v1_Event: Message = .{ .fields = &.{
    .{ .number = 1, .json = "metadata", .type = .message, .message = &meta_v1_ObjectMeta, .omit_zero = false },
    .{ .number = 2, .json = "involvedObject", .type = .message, .message = &core_v1_ObjectReference, .omit_zero = false },
    .{ .number = 3, .json = "reason", .type = .string },
    .{ .number = 4, .json = "message", .type = .string },
    .{ .number = 5, .json = "source", .type = .message, .message = &core_v1_EventSource, .omit_zero = false },
    .{ .number = 6, .json = "firstTimestamp", .type = .time },
    .{ .number = 7, .json = "lastTimestamp", .type = .time },
    .{ .number = 8, .json = "count", .type = .int32 },
    .{ .number = 9, .json = "type", .type = .string },
    .{ .number = 10, .json = "eventTime", .type = .micro_time },
    .{ .number = 11, .json = "series", .type = .message, .message = &core_v1_EventSeries, .omit_zero = false },
    .{ .number = 12, .json = "action", .type = .string },
    .{ .number = 13, .json = "related", .type = .message, .message = &core_v1_ObjectReference, .omit_zero = false },
    .{ .number = 14, .json = "reportingComponent", .type = .string, .omit_zero = false },
    .{ .number = 15, .json = "reportingInstance", .type = .string, .omit_zero = false },
} };

pub const core_v1_EventSeries: Message = .{ .fields = &.{
    .{ .number = 1, .json = "count", .type = .int32 },
    .{ .number = 2, .json = "lastObservedTime", .type = .micro_time },
} };

pub const core_v1_EventSource: Message = .{ .fields = &.{
    .{ .number = 1, .json = "component", .type = .string },
    .{ .number = 2, .json = "host", .type = .string },
} };

pub const core_v1_EvictionResponder: Message = .{ .fields = &.{
    .{ .number = 1, .json = "name", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "priority", .type = .int32, .omit_zero = false },
} };

pub const core_v1_ExecAction: Message = .{ .fields = &.{
    .{ .number = 1, .json = "command", .type = .string, .repeated = true },
} };

pub const core_v1_FCVolumeSource: Message = .{ .fields = &.{
    .{ .number = 1, .json = "targetWWNs", .type = .string, .repeated = true },
    .{ .number = 2, .json = "lun", .type = .int32, .omit_zero = false },
    .{ .number = 3, .json = "fsType", .type = .string },
    .{ .number = 4, .json = "readOnly", .type = .bool },
    .{ .number = 5, .json = "wwids", .type = .string, .repeated = true },
} };

pub const core_v1_FileKeySelector: Message = .{ .fields = &.{
    .{ .number = 1, .json = "volumeName", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "path", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "key", .type = .string, .omit_zero = false },
    .{ .number = 4, .json = "optional", .type = .bool, .omit_zero = false },
} };

pub const core_v1_FlexPersistentVolumeSource: Message = .{ .fields = &.{
    .{ .number = 1, .json = "driver", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "fsType", .type = .string },
    .{ .number = 3, .json = "secretRef", .type = .message, .message = &core_v1_SecretReference, .omit_zero = false },
    .{ .number = 4, .json = "readOnly", .type = .bool },
    .{ .number = 5, .json = "options", .type = .string, .map = true },
} };

pub const core_v1_FlexVolumeSource: Message = .{ .fields = &.{
    .{ .number = 1, .json = "driver", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "fsType", .type = .string },
    .{ .number = 3, .json = "secretRef", .type = .message, .message = &core_v1_LocalObjectReference, .omit_zero = false },
    .{ .number = 4, .json = "readOnly", .type = .bool },
    .{ .number = 5, .json = "options", .type = .string, .map = true },
} };

pub const core_v1_FlockerVolumeSource: Message = .{ .fields = &.{
    .{ .number = 1, .json = "datasetName", .type = .string },
    .{ .number = 2, .json = "datasetUUID", .type = .string },
} };

pub const core_v1_GCEPersistentDiskVolumeSource: Message = .{ .fields = &.{
    .{ .number = 1, .json = "pdName", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "fsType", .type = .string },
    .{ .number = 3, .json = "partition", .type = .int32 },
    .{ .number = 4, .json = "readOnly", .type = .bool },
} };

pub const core_v1_GRPCAction: Message = .{ .fields = &.{
    .{ .number = 1, .json = "port", .type = .int32, .omit_zero = false },
    .{ .number = 2, .json = "service", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "mode", .type = .string, .omit_zero = false },
} };

pub const core_v1_GitRepoVolumeSource: Message = .{ .fields = &.{
    .{ .number = 1, .json = "repository", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "revision", .type = .string },
    .{ .number = 3, .json = "directory", .type = .string },
} };

pub const core_v1_GlusterfsPersistentVolumeSource: Message = .{ .fields = &.{
    .{ .number = 1, .json = "endpoints", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "path", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "readOnly", .type = .bool },
    .{ .number = 4, .json = "endpointsNamespace", .type = .string, .omit_zero = false },
} };

pub const core_v1_GlusterfsVolumeSource: Message = .{ .fields = &.{
    .{ .number = 1, .json = "endpoints", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "path", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "readOnly", .type = .bool },
} };

pub const core_v1_HTTPGetAction: Message = .{ .fields = &.{
    .{ .number = 1, .json = "path", .type = .string },
    .{ .number = 2, .json = "port", .type = .int_or_string, .omit_zero = false },
    .{ .number = 3, .json = "host", .type = .string },
    .{ .number = 4, .json = "scheme", .type = .string },
    .{ .number = 5, .json = "httpHeaders", .type = .message, .message = &core_v1_HTTPHeader, .repeated = true },
    .{ .number = 6, .json = "protocol", .type = .string, .omit_zero = false },
} };

pub const core_v1_HTTPHeader: Message = .{ .fields = &.{
    .{ .number = 1, .json = "name", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "value", .type = .string, .omit_zero = false },
} };

pub const core_v1_HostAlias: Message = .{ .fields = &.{
    .{ .number = 1, .json = "ip", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "hostnames", .type = .string, .repeated = true },
} };

pub const core_v1_HostIP: Message = .{ .fields = &.{
    .{ .number = 1, .json = "ip", .type = .string, .omit_zero = false },
} };

pub const core_v1_HostPathVolumeSource: Message = .{ .fields = &.{
    .{ .number = 1, .json = "path", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "type", .type = .string, .omit_zero = false },
} };

pub const core_v1_ISCSIPersistentVolumeSource: Message = .{ .fields = &.{
    .{ .number = 1, .json = "targetPortal", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "iqn", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "lun", .type = .int32, .omit_zero = false },
    .{ .number = 4, .json = "iscsiInterface", .type = .string },
    .{ .number = 5, .json = "fsType", .type = .string },
    .{ .number = 6, .json = "readOnly", .type = .bool },
    .{ .number = 7, .json = "portals", .type = .string, .repeated = true },
    .{ .number = 8, .json = "chapAuthDiscovery", .type = .bool },
    .{ .number = 11, .json = "chapAuthSession", .type = .bool },
    .{ .number = 10, .json = "secretRef", .type = .message, .message = &core_v1_SecretReference, .omit_zero = false },
    .{ .number = 12, .json = "initiatorName", .type = .string, .omit_zero = false },
} };

pub const core_v1_ISCSIVolumeSource: Message = .{ .fields = &.{
    .{ .number = 1, .json = "targetPortal", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "iqn", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "lun", .type = .int32, .omit_zero = false },
    .{ .number = 4, .json = "iscsiInterface", .type = .string },
    .{ .number = 5, .json = "fsType", .type = .string },
    .{ .number = 6, .json = "readOnly", .type = .bool },
    .{ .number = 7, .json = "portals", .type = .string, .repeated = true },
    .{ .number = 8, .json = "chapAuthDiscovery", .type = .bool },
    .{ .number = 11, .json = "chapAuthSession", .type = .bool },
    .{ .number = 10, .json = "secretRef", .type = .message, .message = &core_v1_LocalObjectReference, .omit_zero = false },
    .{ .number = 12, .json = "initiatorName", .type = .string, .omit_zero = false },
} };

pub const core_v1_ImageVolumeSource: Message = .{ .fields = &.{
    .{ .number = 1, .json = "reference", .type = .string },
    .{ .number = 2, .json = "pullPolicy", .type = .string },
} };

pub const core_v1_ImageVolumeStatus: Message = .{ .fields = &.{
    .{ .number = 1, .json = "imageRef", .type = .string },
} };

pub const core_v1_KeyToPath: Message = .{ .fields = &.{
    .{ .number = 1, .json = "key", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "path", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "mode", .type = .int32, .omit_zero = false },
    .{ .number = 4, .json = "user", .type = .int64, .omit_zero = false },
} };

pub const core_v1_Lifecycle: Message = .{ .fields = &.{
    .{ .number = 1, .json = "postStart", .type = .message, .message = &core_v1_LifecycleHandler, .omit_zero = false },
    .{ .number = 2, .json = "preStop", .type = .message, .message = &core_v1_LifecycleHandler, .omit_zero = false },
    .{ .number = 3, .json = "stopSignal", .type = .string, .omit_zero = false },
} };

pub const core_v1_LifecycleHandler: Message = .{ .fields = &.{
    .{ .number = 1, .json = "exec", .type = .message, .message = &core_v1_ExecAction, .omit_zero = false },
    .{ .number = 2, .json = "httpGet", .type = .message, .message = &core_v1_HTTPGetAction, .omit_zero = false },
    .{ .number = 3, .json = "tcpSocket", .type = .message, .message = &core_v1_TCPSocketAction, .omit_zero = false },
    .{ .number = 4, .json = "sleep", .type = .message, .message = &core_v1_SleepAction, .omit_zero = false },
} };

pub const core_v1_LimitRange: Message = .{ .fields = &.{
    .{ .number = 1, .json = "metadata", .type = .message, .message = &meta_v1_ObjectMeta, .omit_zero = false },
    .{ .number = 2, .json = "spec", .type = .message, .message = &core_v1_LimitRangeSpec, .omit_zero = false },
} };

pub const core_v1_LimitRangeItem: Message = .{ .fields = &.{
    .{ .number = 1, .json = "type", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "max", .type = .quantity, .map = true },
    .{ .number = 3, .json = "min", .type = .quantity, .map = true },
    .{ .number = 4, .json = "default", .type = .quantity, .map = true },
    .{ .number = 5, .json = "defaultRequest", .type = .quantity, .map = true },
    .{ .number = 6, .json = "maxLimitRequestRatio", .type = .quantity, .map = true },
} };

pub const core_v1_LimitRangeSpec: Message = .{ .fields = &.{
    .{ .number = 1, .json = "limits", .type = .message, .message = &core_v1_LimitRangeItem, .repeated = true },
} };

pub const core_v1_LinuxContainerUser: Message = .{ .fields = &.{
    .{ .number = 1, .json = "uid", .type = .int64, .omit_zero = false },
    .{ .number = 2, .json = "gid", .type = .int64, .omit_zero = false },
    .{ .number = 3, .json = "supplementalGroups", .type = .int64, .repeated = true },
} };

pub const core_v1_LoadBalancerIngress: Message = .{ .fields = &.{
    .{ .number = 1, .json = "ip", .type = .string },
    .{ .number = 2, .json = "hostname", .type = .string },
    .{ .number = 3, .json = "ipMode", .type = .string, .omit_zero = false },
    .{ .number = 4, .json = "ports", .type = .message, .message = &core_v1_PortStatus, .repeated = true },
} };

pub const core_v1_LoadBalancerStatus: Message = .{ .fields = &.{
    .{ .number = 1, .json = "ingress", .type = .message, .message = &core_v1_LoadBalancerIngress, .repeated = true },
} };

pub const core_v1_LocalObjectReference: Message = .{ .fields = &.{
    .{ .number = 1, .json = "name", .type = .string },
} };

pub const core_v1_LocalVolumeSource: Message = .{ .fields = &.{
    .{ .number = 1, .json = "path", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "fsType", .type = .string, .omit_zero = false },
} };

pub const core_v1_ModifyVolumeStatus: Message = .{ .fields = &.{
    .{ .number = 1, .json = "targetVolumeAttributesClassName", .type = .string },
    .{ .number = 2, .json = "status", .type = .string, .omit_zero = false },
} };

pub const core_v1_NFSVolumeSource: Message = .{ .fields = &.{
    .{ .number = 1, .json = "server", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "path", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "readOnly", .type = .bool },
} };

pub const core_v1_Namespace: Message = .{ .fields = &.{
    .{ .number = 1, .json = "metadata", .type = .message, .message = &meta_v1_ObjectMeta, .omit_zero = false },
    .{ .number = 2, .json = "spec", .type = .message, .message = &core_v1_NamespaceSpec, .omit_zero = false },
    .{ .number = 3, .json = "status", .type = .message, .message = &core_v1_NamespaceStatus, .omit_zero = false },
} };

pub const core_v1_NamespaceCondition: Message = .{ .fields = &.{
    .{ .number = 1, .json = "type", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "status", .type = .string, .omit_zero = false },
    .{ .number = 4, .json = "lastTransitionTime", .type = .time },
    .{ .number = 5, .json = "reason", .type = .string },
    .{ .number = 6, .json = "message", .type = .string },
} };

pub const core_v1_NamespaceSpec: Message = .{ .fields = &.{
    .{ .number = 1, .json = "finalizers", .type = .string, .repeated = true },
} };

pub const core_v1_NamespaceStatus: Message = .{ .fields = &.{
    .{ .number = 1, .json = "phase", .type = .string },
    .{ .number = 2, .json = "conditions", .type = .message, .message = &core_v1_NamespaceCondition, .repeated = true },
} };

pub const core_v1_Node: Message = .{ .fields = &.{
    .{ .number = 1, .json = "metadata", .type = .message, .message = &meta_v1_ObjectMeta, .omit_zero = false },
    .{ .number = 2, .json = "spec", .type = .message, .message = &core_v1_NodeSpec, .omit_zero = false },
    .{ .number = 3, .json = "status", .type = .message, .message = &core_v1_NodeStatus, .omit_zero = false },
} };

pub const core_v1_NodeAddress: Message = .{ .fields = &.{
    .{ .number = 1, .json = "type", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "address", .type = .string, .omit_zero = false },
} };

pub const core_v1_NodeAffinity: Message = .{ .fields = &.{
    .{ .number = 1, .json = "requiredDuringSchedulingIgnoredDuringExecution", .type = .message, .message = &core_v1_NodeSelector, .omit_zero = false },
    .{ .number = 2, .json = "preferredDuringSchedulingIgnoredDuringExecution", .type = .message, .message = &core_v1_PreferredSchedulingTerm, .repeated = true },
} };

pub const core_v1_NodeAllocatableMappedResources: Message = .{ .fields = &.{
    .{ .number = 1, .json = "name", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "quantity", .type = .quantity, .omit_zero = false },
} };

pub const core_v1_NodeAllocatableOverheadResources: Message = .{ .fields = &.{
    .{ .number = 1, .json = "name", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "perPod", .type = .quantity, .omit_zero = false },
    .{ .number = 3, .json = "perContainer", .type = .quantity, .omit_zero = false },
} };

pub const core_v1_NodeAllocatableResourceClaimStatus: Message = .{ .fields = &.{
    .{ .number = 1, .json = "resourceClaimName", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "containers", .type = .string, .repeated = true },
    .{ .number = 4, .json = "mapping", .type = .message, .message = &core_v1_NodeAllocatableMappedResources, .repeated = true },
    .{ .number = 5, .json = "overhead", .type = .message, .message = &core_v1_NodeAllocatableOverheadResources, .repeated = true },
} };

pub const core_v1_NodeCondition: Message = .{ .fields = &.{
    .{ .number = 1, .json = "type", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "status", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "lastHeartbeatTime", .type = .time },
    .{ .number = 4, .json = "lastTransitionTime", .type = .time },
    .{ .number = 5, .json = "reason", .type = .string },
    .{ .number = 6, .json = "message", .type = .string },
} };

pub const core_v1_NodeConfigSource: Message = .{ .fields = &.{
    .{ .number = 2, .json = "configMap", .type = .message, .message = &core_v1_ConfigMapNodeConfigSource, .omit_zero = false },
} };

pub const core_v1_NodeConfigStatus: Message = .{ .fields = &.{
    .{ .number = 1, .json = "assigned", .type = .message, .message = &core_v1_NodeConfigSource, .omit_zero = false },
    .{ .number = 2, .json = "active", .type = .message, .message = &core_v1_NodeConfigSource, .omit_zero = false },
    .{ .number = 3, .json = "lastKnownGood", .type = .message, .message = &core_v1_NodeConfigSource, .omit_zero = false },
    .{ .number = 4, .json = "error", .type = .string },
} };

pub const core_v1_NodeDaemonEndpoints: Message = .{ .fields = &.{
    .{ .number = 1, .json = "kubeletEndpoint", .type = .message, .message = &core_v1_DaemonEndpoint, .omit_zero = false },
} };

pub const core_v1_NodeFeatures: Message = .{ .fields = &.{
    .{ .number = 1, .json = "supplementalGroupsPolicy", .type = .bool, .omit_zero = false },
} };

pub const core_v1_NodePodPreemptionPolicy: Message = .{ .fields = &.{
    .{ .number = 1, .json = "disableResizePreemption", .type = .string, .repeated = true },
} };

pub const core_v1_NodeRuntimeHandler: Message = .{ .fields = &.{
    .{ .number = 1, .json = "name", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "features", .type = .message, .message = &core_v1_NodeRuntimeHandlerFeatures, .omit_zero = false },
} };

pub const core_v1_NodeRuntimeHandlerFeatures: Message = .{ .fields = &.{
    .{ .number = 1, .json = "recursiveReadOnlyMounts", .type = .bool, .omit_zero = false },
    .{ .number = 2, .json = "userNamespaces", .type = .bool, .omit_zero = false },
} };

pub const core_v1_NodeSelector: Message = .{ .fields = &.{
    .{ .number = 1, .json = "nodeSelectorTerms", .type = .message, .message = &core_v1_NodeSelectorTerm, .repeated = true },
} };

pub const core_v1_NodeSelectorRequirement: Message = .{ .fields = &.{
    .{ .number = 1, .json = "key", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "operator", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "values", .type = .string, .repeated = true },
} };

pub const core_v1_NodeSelectorTerm: Message = .{ .fields = &.{
    .{ .number = 1, .json = "matchExpressions", .type = .message, .message = &core_v1_NodeSelectorRequirement, .repeated = true },
    .{ .number = 2, .json = "matchFields", .type = .message, .message = &core_v1_NodeSelectorRequirement, .repeated = true },
} };

pub const core_v1_NodeSpec: Message = .{ .fields = &.{
    .{ .number = 1, .json = "podCIDR", .type = .string },
    .{ .number = 7, .json = "podCIDRs", .type = .string, .repeated = true },
    .{ .number = 3, .json = "providerID", .type = .string },
    .{ .number = 4, .json = "unschedulable", .type = .bool },
    .{ .number = 5, .json = "taints", .type = .message, .message = &core_v1_Taint, .repeated = true },
    .{ .number = 6, .json = "configSource", .type = .message, .message = &core_v1_NodeConfigSource, .omit_zero = false },
    .{ .number = 2, .json = "externalID", .type = .string },
    .{ .number = 8, .json = "podPreemptionPolicy", .type = .message, .message = &core_v1_NodePodPreemptionPolicy, .omit_zero = false },
} };

pub const core_v1_NodeStatus: Message = .{ .fields = &.{
    .{ .number = 1, .json = "capacity", .type = .quantity, .map = true },
    .{ .number = 2, .json = "allocatable", .type = .quantity, .map = true },
    .{ .number = 3, .json = "phase", .type = .string },
    .{ .number = 4, .json = "conditions", .type = .message, .message = &core_v1_NodeCondition, .repeated = true },
    .{ .number = 5, .json = "addresses", .type = .message, .message = &core_v1_NodeAddress, .repeated = true },
    .{ .number = 6, .json = "daemonEndpoints", .type = .message, .message = &core_v1_NodeDaemonEndpoints, .omit_zero = false },
    .{ .number = 7, .json = "nodeInfo", .type = .message, .message = &core_v1_NodeSystemInfo, .omit_zero = false },
    .{ .number = 8, .json = "images", .type = .message, .message = &core_v1_ContainerImage, .repeated = true },
    .{ .number = 9, .json = "volumesInUse", .type = .string, .repeated = true },
    .{ .number = 10, .json = "volumesAttached", .type = .message, .message = &core_v1_AttachedVolume, .repeated = true },
    .{ .number = 11, .json = "config", .type = .message, .message = &core_v1_NodeConfigStatus, .omit_zero = false },
    .{ .number = 12, .json = "runtimeHandlers", .type = .message, .message = &core_v1_NodeRuntimeHandler, .repeated = true },
    .{ .number = 13, .json = "features", .type = .message, .message = &core_v1_NodeFeatures, .omit_zero = false },
    .{ .number = 14, .json = "declaredFeatures", .type = .string, .repeated = true },
} };

pub const core_v1_NodeSwapStatus: Message = .{ .fields = &.{
    .{ .number = 1, .json = "capacity", .type = .int64, .omit_zero = false },
} };

pub const core_v1_NodeSystemInfo: Message = .{ .fields = &.{
    .{ .number = 1, .json = "machineID", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "systemUUID", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "bootID", .type = .string, .omit_zero = false },
    .{ .number = 4, .json = "kernelVersion", .type = .string, .omit_zero = false },
    .{ .number = 5, .json = "osImage", .type = .string, .omit_zero = false },
    .{ .number = 6, .json = "containerRuntimeVersion", .type = .string, .omit_zero = false },
    .{ .number = 7, .json = "kubeletVersion", .type = .string, .omit_zero = false },
    .{ .number = 8, .json = "kubeProxyVersion", .type = .string, .omit_zero = false },
    .{ .number = 9, .json = "operatingSystem", .type = .string, .omit_zero = false },
    .{ .number = 10, .json = "architecture", .type = .string, .omit_zero = false },
    .{ .number = 11, .json = "swap", .type = .message, .message = &core_v1_NodeSwapStatus, .omit_zero = false },
    .{ .number = 12, .json = "runningInUserNamespace", .type = .bool, .omit_zero = false },
} };

pub const core_v1_ObjectFieldSelector: Message = .{ .fields = &.{
    .{ .number = 1, .json = "apiVersion", .type = .string },
    .{ .number = 2, .json = "fieldPath", .type = .string, .omit_zero = false },
} };

pub const core_v1_ObjectReference: Message = .{ .fields = &.{
    .{ .number = 1, .json = "kind", .type = .string },
    .{ .number = 2, .json = "namespace", .type = .string },
    .{ .number = 3, .json = "name", .type = .string },
    .{ .number = 4, .json = "uid", .type = .string },
    .{ .number = 5, .json = "apiVersion", .type = .string },
    .{ .number = 6, .json = "resourceVersion", .type = .string },
    .{ .number = 7, .json = "fieldPath", .type = .string },
} };

pub const core_v1_PersistentVolume: Message = .{ .fields = &.{
    .{ .number = 1, .json = "metadata", .type = .message, .message = &meta_v1_ObjectMeta, .omit_zero = false },
    .{ .number = 2, .json = "spec", .type = .message, .message = &core_v1_PersistentVolumeSpec, .omit_zero = false },
    .{ .number = 3, .json = "status", .type = .message, .message = &core_v1_PersistentVolumeStatus, .omit_zero = false },
} };

pub const core_v1_PersistentVolumeClaim: Message = .{ .fields = &.{
    .{ .number = 1, .json = "metadata", .type = .message, .message = &meta_v1_ObjectMeta, .omit_zero = false },
    .{ .number = 2, .json = "spec", .type = .message, .message = &core_v1_PersistentVolumeClaimSpec, .omit_zero = false },
    .{ .number = 3, .json = "status", .type = .message, .message = &core_v1_PersistentVolumeClaimStatus, .omit_zero = false },
} };

pub const core_v1_PersistentVolumeClaimCondition: Message = .{ .fields = &.{
    .{ .number = 1, .json = "type", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "status", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "lastProbeTime", .type = .time },
    .{ .number = 4, .json = "lastTransitionTime", .type = .time },
    .{ .number = 5, .json = "reason", .type = .string },
    .{ .number = 6, .json = "message", .type = .string },
} };

pub const core_v1_PersistentVolumeClaimSpec: Message = .{ .fields = &.{
    .{ .number = 1, .json = "accessModes", .type = .string, .repeated = true },
    .{ .number = 4, .json = "selector", .type = .message, .message = &meta_v1_LabelSelector, .omit_zero = false },
    .{ .number = 2, .json = "resources", .type = .message, .message = &core_v1_VolumeResourceRequirements, .omit_zero = false },
    .{ .number = 3, .json = "volumeName", .type = .string },
    .{ .number = 5, .json = "storageClassName", .type = .string, .omit_zero = false },
    .{ .number = 6, .json = "volumeMode", .type = .string, .omit_zero = false },
    .{ .number = 7, .json = "dataSource", .type = .message, .message = &core_v1_TypedLocalObjectReference, .omit_zero = false },
    .{ .number = 8, .json = "dataSourceRef", .type = .message, .message = &core_v1_TypedObjectReference, .omit_zero = false },
    .{ .number = 9, .json = "volumeAttributesClassName", .type = .string, .omit_zero = false },
} };

pub const core_v1_PersistentVolumeClaimStatus: Message = .{ .fields = &.{
    .{ .number = 1, .json = "phase", .type = .string },
    .{ .number = 2, .json = "accessModes", .type = .string, .repeated = true },
    .{ .number = 3, .json = "capacity", .type = .quantity, .map = true },
    .{ .number = 4, .json = "conditions", .type = .message, .message = &core_v1_PersistentVolumeClaimCondition, .repeated = true },
    .{ .number = 5, .json = "allocatedResources", .type = .quantity, .map = true },
    .{ .number = 7, .json = "allocatedResourceStatuses", .type = .string, .map = true },
    .{ .number = 8, .json = "currentVolumeAttributesClassName", .type = .string, .omit_zero = false },
    .{ .number = 9, .json = "modifyVolumeStatus", .type = .message, .message = &core_v1_ModifyVolumeStatus, .omit_zero = false },
    .{ .number = 10, .json = "healthStatus", .type = .message, .message = &core_v1_VolumeHealthStatus, .omit_zero = false },
} };

pub const core_v1_PersistentVolumeClaimTemplate: Message = .{ .fields = &.{
    .{ .number = 1, .json = "metadata", .type = .message, .message = &meta_v1_ObjectMeta, .omit_zero = false },
    .{ .number = 2, .json = "spec", .type = .message, .message = &core_v1_PersistentVolumeClaimSpec, .omit_zero = false },
} };

pub const core_v1_PersistentVolumeClaimVolumeSource: Message = .{ .fields = &.{
    .{ .number = 1, .json = "claimName", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "readOnly", .type = .bool },
} };

pub const core_v1_PersistentVolumeSource: Message = .{ .fields = &.{
    .{ .number = 1, .json = "gcePersistentDisk", .type = .message, .message = &core_v1_GCEPersistentDiskVolumeSource, .omit_zero = false },
    .{ .number = 2, .json = "awsElasticBlockStore", .type = .message, .message = &core_v1_AWSElasticBlockStoreVolumeSource, .omit_zero = false },
    .{ .number = 3, .json = "hostPath", .type = .message, .message = &core_v1_HostPathVolumeSource, .omit_zero = false },
    .{ .number = 4, .json = "glusterfs", .type = .message, .message = &core_v1_GlusterfsPersistentVolumeSource, .omit_zero = false },
    .{ .number = 5, .json = "nfs", .type = .message, .message = &core_v1_NFSVolumeSource, .omit_zero = false },
    .{ .number = 6, .json = "rbd", .type = .message, .message = &core_v1_RBDPersistentVolumeSource, .omit_zero = false },
    .{ .number = 7, .json = "iscsi", .type = .message, .message = &core_v1_ISCSIPersistentVolumeSource, .omit_zero = false },
    .{ .number = 8, .json = "cinder", .type = .message, .message = &core_v1_CinderPersistentVolumeSource, .omit_zero = false },
    .{ .number = 9, .json = "cephfs", .type = .message, .message = &core_v1_CephFSPersistentVolumeSource, .omit_zero = false },
    .{ .number = 10, .json = "fc", .type = .message, .message = &core_v1_FCVolumeSource, .omit_zero = false },
    .{ .number = 11, .json = "flocker", .type = .message, .message = &core_v1_FlockerVolumeSource, .omit_zero = false },
    .{ .number = 12, .json = "flexVolume", .type = .message, .message = &core_v1_FlexPersistentVolumeSource, .omit_zero = false },
    .{ .number = 13, .json = "azureFile", .type = .message, .message = &core_v1_AzureFilePersistentVolumeSource, .omit_zero = false },
    .{ .number = 14, .json = "vsphereVolume", .type = .message, .message = &core_v1_VsphereVirtualDiskVolumeSource, .omit_zero = false },
    .{ .number = 15, .json = "quobyte", .type = .message, .message = &core_v1_QuobyteVolumeSource, .omit_zero = false },
    .{ .number = 16, .json = "azureDisk", .type = .message, .message = &core_v1_AzureDiskVolumeSource, .omit_zero = false },
    .{ .number = 17, .json = "photonPersistentDisk", .type = .message, .message = &core_v1_PhotonPersistentDiskVolumeSource, .omit_zero = false },
    .{ .number = 18, .json = "portworxVolume", .type = .message, .message = &core_v1_PortworxVolumeSource, .omit_zero = false },
    .{ .number = 19, .json = "scaleIO", .type = .message, .message = &core_v1_ScaleIOPersistentVolumeSource, .omit_zero = false },
    .{ .number = 20, .json = "local", .type = .message, .message = &core_v1_LocalVolumeSource, .omit_zero = false },
    .{ .number = 21, .json = "storageos", .type = .message, .message = &core_v1_StorageOSPersistentVolumeSource, .omit_zero = false },
    .{ .number = 22, .json = "csi", .type = .message, .message = &core_v1_CSIPersistentVolumeSource, .omit_zero = false },
} };

pub const core_v1_PersistentVolumeSpec: Message = .{ .fields = &.{
    .{ .number = 1, .json = "capacity", .type = .quantity, .map = true },
    .{ .number = 2, .json = "", .type = .message, .message = &core_v1_PersistentVolumeSource, .embedded = true },
    .{ .number = 3, .json = "accessModes", .type = .string, .repeated = true },
    .{ .number = 4, .json = "claimRef", .type = .message, .message = &core_v1_ObjectReference, .omit_zero = false },
    .{ .number = 5, .json = "persistentVolumeReclaimPolicy", .type = .string },
    .{ .number = 6, .json = "storageClassName", .type = .string },
    .{ .number = 7, .json = "mountOptions", .type = .string, .repeated = true },
    .{ .number = 8, .json = "volumeMode", .type = .string, .omit_zero = false },
    .{ .number = 9, .json = "nodeAffinity", .type = .message, .message = &core_v1_VolumeNodeAffinity, .omit_zero = false },
    .{ .number = 10, .json = "volumeAttributesClassName", .type = .string, .omit_zero = false },
} };

pub const core_v1_PersistentVolumeStatus: Message = .{ .fields = &.{
    .{ .number = 1, .json = "phase", .type = .string },
    .{ .number = 2, .json = "message", .type = .string },
    .{ .number = 3, .json = "reason", .type = .string },
    .{ .number = 4, .json = "lastPhaseTransitionTime", .type = .time, .omit_zero = false },
} };

pub const core_v1_PhotonPersistentDiskVolumeSource: Message = .{ .fields = &.{
    .{ .number = 1, .json = "pdID", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "fsType", .type = .string },
} };

pub const core_v1_Pod: Message = .{ .fields = &.{
    .{ .number = 1, .json = "metadata", .type = .message, .message = &meta_v1_ObjectMeta, .omit_zero = false },
    .{ .number = 2, .json = "spec", .type = .message, .message = &core_v1_PodSpec, .omit_zero = false },
    .{ .number = 3, .json = "status", .type = .message, .message = &core_v1_PodStatus, .omit_zero = false },
} };

pub const core_v1_PodAffinity: Message = .{ .fields = &.{
    .{ .number = 1, .json = "requiredDuringSchedulingIgnoredDuringExecution", .type = .message, .message = &core_v1_PodAffinityTerm, .repeated = true },
    .{ .number = 2, .json = "preferredDuringSchedulingIgnoredDuringExecution", .type = .message, .message = &core_v1_WeightedPodAffinityTerm, .repeated = true },
} };

pub const core_v1_PodAffinityTerm: Message = .{ .fields = &.{
    .{ .number = 1, .json = "labelSelector", .type = .message, .message = &meta_v1_LabelSelector, .omit_zero = false },
    .{ .number = 2, .json = "namespaces", .type = .string, .repeated = true },
    .{ .number = 3, .json = "topologyKey", .type = .string, .omit_zero = false },
    .{ .number = 4, .json = "namespaceSelector", .type = .message, .message = &meta_v1_LabelSelector, .omit_zero = false },
    .{ .number = 5, .json = "matchLabelKeys", .type = .string, .repeated = true },
    .{ .number = 6, .json = "mismatchLabelKeys", .type = .string, .repeated = true },
} };

pub const core_v1_PodAntiAffinity: Message = .{ .fields = &.{
    .{ .number = 1, .json = "requiredDuringSchedulingIgnoredDuringExecution", .type = .message, .message = &core_v1_PodAffinityTerm, .repeated = true },
    .{ .number = 2, .json = "preferredDuringSchedulingIgnoredDuringExecution", .type = .message, .message = &core_v1_WeightedPodAffinityTerm, .repeated = true },
} };

pub const core_v1_PodCertificateProjection: Message = .{ .fields = &.{
    .{ .number = 1, .json = "signerName", .type = .string },
    .{ .number = 2, .json = "keyType", .type = .string },
    .{ .number = 3, .json = "maxExpirationSeconds", .type = .int32, .omit_zero = false },
    .{ .number = 4, .json = "credentialBundlePath", .type = .string },
    .{ .number = 5, .json = "keyPath", .type = .string },
    .{ .number = 6, .json = "certificateChainPath", .type = .string },
    .{ .number = 7, .json = "userAnnotations", .type = .string, .map = true },
    .{ .number = 8, .json = "user", .type = .int64, .omit_zero = false },
} };

pub const core_v1_PodCondition: Message = .{ .fields = &.{
    .{ .number = 1, .json = "type", .type = .string, .omit_zero = false },
    .{ .number = 7, .json = "observedGeneration", .type = .int64 },
    .{ .number = 2, .json = "status", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "lastProbeTime", .type = .time },
    .{ .number = 4, .json = "lastTransitionTime", .type = .time },
    .{ .number = 5, .json = "reason", .type = .string },
    .{ .number = 6, .json = "message", .type = .string },
} };

pub const core_v1_PodDNSConfig: Message = .{ .fields = &.{
    .{ .number = 1, .json = "nameservers", .type = .string, .repeated = true },
    .{ .number = 2, .json = "searches", .type = .string, .repeated = true },
    .{ .number = 3, .json = "options", .type = .message, .message = &core_v1_PodDNSConfigOption, .repeated = true },
} };

pub const core_v1_PodDNSConfigOption: Message = .{ .fields = &.{
    .{ .number = 1, .json = "name", .type = .string },
    .{ .number = 2, .json = "value", .type = .string, .omit_zero = false },
} };

pub const core_v1_PodExtendedResourceClaimStatus: Message = .{ .fields = &.{
    .{ .number = 1, .json = "requestMappings", .type = .message, .message = &core_v1_ContainerExtendedResourceRequest, .repeated = true },
    .{ .number = 2, .json = "resourceClaimName", .type = .string, .omit_zero = false },
} };

pub const core_v1_PodIP: Message = .{ .fields = &.{
    .{ .number = 1, .json = "ip", .type = .string, .omit_zero = false },
} };

pub const core_v1_PodOS: Message = .{ .fields = &.{
    .{ .number = 1, .json = "name", .type = .string, .omit_zero = false },
} };

pub const core_v1_PodReadinessGate: Message = .{ .fields = &.{
    .{ .number = 1, .json = "conditionType", .type = .string, .omit_zero = false },
} };

pub const core_v1_PodResourceClaim: Message = .{ .fields = &.{
    .{ .number = 1, .json = "name", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "resourceClaimName", .type = .string, .omit_zero = false },
    .{ .number = 4, .json = "resourceClaimTemplateName", .type = .string, .omit_zero = false },
} };

pub const core_v1_PodResourceClaimStatus: Message = .{ .fields = &.{
    .{ .number = 1, .json = "name", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "resourceClaimName", .type = .string, .omit_zero = false },
} };

pub const core_v1_PodSchedulingGate: Message = .{ .fields = &.{
    .{ .number = 1, .json = "name", .type = .string, .omit_zero = false },
} };

pub const core_v1_PodSchedulingGroup: Message = .{ .fields = &.{
    .{ .number = 1, .json = "podGroupName", .type = .string, .omit_zero = false },
} };

pub const core_v1_PodSecurityContext: Message = .{ .fields = &.{
    .{ .number = 1, .json = "seLinuxOptions", .type = .message, .message = &core_v1_SELinuxOptions, .omit_zero = false },
    .{ .number = 8, .json = "windowsOptions", .type = .message, .message = &core_v1_WindowsSecurityContextOptions, .omit_zero = false },
    .{ .number = 2, .json = "runAsUser", .type = .int64, .omit_zero = false },
    .{ .number = 6, .json = "runAsGroup", .type = .int64, .omit_zero = false },
    .{ .number = 3, .json = "runAsNonRoot", .type = .bool, .omit_zero = false },
    .{ .number = 4, .json = "supplementalGroups", .type = .int64, .repeated = true },
    .{ .number = 12, .json = "supplementalGroupsPolicy", .type = .string, .omit_zero = false },
    .{ .number = 5, .json = "fsGroup", .type = .int64, .omit_zero = false },
    .{ .number = 7, .json = "sysctls", .type = .message, .message = &core_v1_Sysctl, .repeated = true },
    .{ .number = 9, .json = "fsGroupChangePolicy", .type = .string, .omit_zero = false },
    .{ .number = 10, .json = "seccompProfile", .type = .message, .message = &core_v1_SeccompProfile, .omit_zero = false },
    .{ .number = 11, .json = "appArmorProfile", .type = .message, .message = &core_v1_AppArmorProfile, .omit_zero = false },
    .{ .number = 13, .json = "seLinuxChangePolicy", .type = .string, .omit_zero = false },
} };

pub const core_v1_PodSpec: Message = .{ .fields = &.{
    .{ .number = 1, .json = "volumes", .type = .message, .message = &core_v1_Volume, .repeated = true },
    .{ .number = 20, .json = "initContainers", .type = .message, .message = &core_v1_Container, .repeated = true },
    .{ .number = 2, .json = "containers", .type = .message, .message = &core_v1_Container, .repeated = true },
    .{ .number = 34, .json = "ephemeralContainers", .type = .message, .message = &core_v1_EphemeralContainer, .repeated = true },
    .{ .number = 3, .json = "restartPolicy", .type = .string },
    .{ .number = 4, .json = "terminationGracePeriodSeconds", .type = .int64, .omit_zero = false },
    .{ .number = 5, .json = "activeDeadlineSeconds", .type = .int64, .omit_zero = false },
    .{ .number = 6, .json = "dnsPolicy", .type = .string },
    .{ .number = 7, .json = "nodeSelector", .type = .string, .map = true },
    .{ .number = 8, .json = "serviceAccountName", .type = .string },
    .{ .number = 9, .json = "serviceAccount", .type = .string },
    .{ .number = 21, .json = "automountServiceAccountToken", .type = .bool, .omit_zero = false },
    .{ .number = 10, .json = "nodeName", .type = .string },
    .{ .number = 11, .json = "hostNetwork", .type = .bool },
    .{ .number = 12, .json = "hostPID", .type = .bool },
    .{ .number = 13, .json = "hostIPC", .type = .bool },
    .{ .number = 27, .json = "shareProcessNamespace", .type = .bool, .omit_zero = false },
    .{ .number = 14, .json = "securityContext", .type = .message, .message = &core_v1_PodSecurityContext, .omit_zero = false },
    .{ .number = 15, .json = "imagePullSecrets", .type = .message, .message = &core_v1_LocalObjectReference, .repeated = true },
    .{ .number = 16, .json = "hostname", .type = .string },
    .{ .number = 17, .json = "subdomain", .type = .string },
    .{ .number = 18, .json = "affinity", .type = .message, .message = &core_v1_Affinity, .omit_zero = false },
    .{ .number = 19, .json = "schedulerName", .type = .string },
    .{ .number = 22, .json = "tolerations", .type = .message, .message = &core_v1_Toleration, .repeated = true },
    .{ .number = 23, .json = "hostAliases", .type = .message, .message = &core_v1_HostAlias, .repeated = true },
    .{ .number = 24, .json = "priorityClassName", .type = .string },
    .{ .number = 25, .json = "priority", .type = .int32, .omit_zero = false },
    .{ .number = 26, .json = "dnsConfig", .type = .message, .message = &core_v1_PodDNSConfig, .omit_zero = false },
    .{ .number = 28, .json = "readinessGates", .type = .message, .message = &core_v1_PodReadinessGate, .repeated = true },
    .{ .number = 29, .json = "runtimeClassName", .type = .string, .omit_zero = false },
    .{ .number = 30, .json = "enableServiceLinks", .type = .bool, .omit_zero = false },
    .{ .number = 31, .json = "preemptionPolicy", .type = .string, .omit_zero = false },
    .{ .number = 32, .json = "overhead", .type = .quantity, .map = true },
    .{ .number = 33, .json = "topologySpreadConstraints", .type = .message, .message = &core_v1_TopologySpreadConstraint, .repeated = true },
    .{ .number = 35, .json = "setHostnameAsFQDN", .type = .bool, .omit_zero = false },
    .{ .number = 36, .json = "os", .type = .message, .message = &core_v1_PodOS, .omit_zero = false },
    .{ .number = 37, .json = "hostUsers", .type = .bool, .omit_zero = false },
    .{ .number = 38, .json = "schedulingGates", .type = .message, .message = &core_v1_PodSchedulingGate, .repeated = true },
    .{ .number = 39, .json = "resourceClaims", .type = .message, .message = &core_v1_PodResourceClaim, .repeated = true },
    .{ .number = 40, .json = "resources", .type = .message, .message = &core_v1_ResourceRequirements, .omit_zero = false },
    .{ .number = 41, .json = "hostnameOverride", .type = .string, .omit_zero = false },
    .{ .number = 43, .json = "schedulingGroup", .type = .message, .message = &core_v1_PodSchedulingGroup, .omit_zero = false },
    .{ .number = 44, .json = "evictionResponders", .type = .message, .message = &core_v1_EvictionResponder, .repeated = true },
} };

pub const core_v1_PodStatus: Message = .{ .fields = &.{
    .{ .number = 17, .json = "observedGeneration", .type = .int64 },
    .{ .number = 1, .json = "phase", .type = .string },
    .{ .number = 2, .json = "conditions", .type = .message, .message = &core_v1_PodCondition, .repeated = true },
    .{ .number = 3, .json = "message", .type = .string },
    .{ .number = 4, .json = "reason", .type = .string },
    .{ .number = 11, .json = "nominatedNodeName", .type = .string },
    .{ .number = 5, .json = "hostIP", .type = .string },
    .{ .number = 16, .json = "hostIPs", .type = .message, .message = &core_v1_HostIP, .repeated = true },
    .{ .number = 6, .json = "podIP", .type = .string },
    .{ .number = 12, .json = "podIPs", .type = .message, .message = &core_v1_PodIP, .repeated = true },
    .{ .number = 7, .json = "startTime", .type = .time, .omit_zero = false },
    .{ .number = 10, .json = "initContainerStatuses", .type = .message, .message = &core_v1_ContainerStatus, .repeated = true },
    .{ .number = 8, .json = "containerStatuses", .type = .message, .message = &core_v1_ContainerStatus, .repeated = true },
    .{ .number = 9, .json = "qosClass", .type = .string },
    .{ .number = 13, .json = "ephemeralContainerStatuses", .type = .message, .message = &core_v1_ContainerStatus, .repeated = true },
    .{ .number = 14, .json = "resize", .type = .string },
    .{ .number = 15, .json = "resourceClaimStatuses", .type = .message, .message = &core_v1_PodResourceClaimStatus, .repeated = true },
    .{ .number = 18, .json = "extendedResourceClaimStatus", .type = .message, .message = &core_v1_PodExtendedResourceClaimStatus, .omit_zero = false },
    .{ .number = 19, .json = "allocatedResources", .type = .quantity, .map = true },
    .{ .number = 20, .json = "resources", .type = .message, .message = &core_v1_ResourceRequirements, .omit_zero = false },
    .{ .number = 21, .json = "nodeAllocatableResourceClaimStatuses", .type = .message, .message = &core_v1_NodeAllocatableResourceClaimStatus, .repeated = true },
    .{ .number = 22, .json = "volumeHealth", .type = .message, .message = &core_v1_PodVolumeHealth, .repeated = true },
} };

pub const core_v1_PodTemplateSpec: Message = .{ .fields = &.{
    .{ .number = 1, .json = "metadata", .type = .message, .message = &meta_v1_ObjectMeta, .omit_zero = false },
    .{ .number = 2, .json = "spec", .type = .message, .message = &core_v1_PodSpec, .omit_zero = false },
} };

pub const core_v1_PodVolumeHealth: Message = .{ .fields = &.{
    .{ .number = 1, .json = "name", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "healthConditions", .type = .message, .message = &core_v1_VolumeHealthCondition, .repeated = true },
    .{ .number = 3, .json = "lastTransitionTime", .type = .time },
} };

pub const core_v1_PortStatus: Message = .{ .fields = &.{
    .{ .number = 1, .json = "port", .type = .int32, .omit_zero = false },
    .{ .number = 2, .json = "protocol", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "error", .type = .string, .omit_zero = false },
} };

pub const core_v1_PortworxVolumeSource: Message = .{ .fields = &.{
    .{ .number = 1, .json = "volumeID", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "fsType", .type = .string },
    .{ .number = 3, .json = "readOnly", .type = .bool },
} };

pub const core_v1_PreferredSchedulingTerm: Message = .{ .fields = &.{
    .{ .number = 1, .json = "weight", .type = .int32, .omit_zero = false },
    .{ .number = 2, .json = "preference", .type = .message, .message = &core_v1_NodeSelectorTerm, .omit_zero = false },
} };

pub const core_v1_Probe: Message = .{ .fields = &.{
    .{ .number = 1, .json = "", .type = .message, .message = &core_v1_ProbeHandler, .embedded = true },
    .{ .number = 2, .json = "initialDelaySeconds", .type = .int32 },
    .{ .number = 3, .json = "timeoutSeconds", .type = .int32 },
    .{ .number = 4, .json = "periodSeconds", .type = .int32 },
    .{ .number = 5, .json = "successThreshold", .type = .int32 },
    .{ .number = 6, .json = "failureThreshold", .type = .int32 },
    .{ .number = 7, .json = "terminationGracePeriodSeconds", .type = .int64, .omit_zero = false },
} };

pub const core_v1_ProbeHandler: Message = .{ .fields = &.{
    .{ .number = 1, .json = "exec", .type = .message, .message = &core_v1_ExecAction, .omit_zero = false },
    .{ .number = 2, .json = "httpGet", .type = .message, .message = &core_v1_HTTPGetAction, .omit_zero = false },
    .{ .number = 3, .json = "tcpSocket", .type = .message, .message = &core_v1_TCPSocketAction, .omit_zero = false },
    .{ .number = 4, .json = "grpc", .type = .message, .message = &core_v1_GRPCAction, .omit_zero = false },
} };

pub const core_v1_ProjectedVolumeSource: Message = .{ .fields = &.{
    .{ .number = 1, .json = "sources", .type = .message, .message = &core_v1_VolumeProjection, .repeated = true },
    .{ .number = 2, .json = "defaultMode", .type = .int32, .omit_zero = false },
    .{ .number = 3, .json = "defaultUser", .type = .int64, .omit_zero = false },
} };

pub const core_v1_QuobyteVolumeSource: Message = .{ .fields = &.{
    .{ .number = 1, .json = "registry", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "volume", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "readOnly", .type = .bool },
    .{ .number = 4, .json = "user", .type = .string },
    .{ .number = 5, .json = "group", .type = .string },
    .{ .number = 6, .json = "tenant", .type = .string },
} };

pub const core_v1_RBDPersistentVolumeSource: Message = .{ .fields = &.{
    .{ .number = 1, .json = "monitors", .type = .string, .repeated = true },
    .{ .number = 2, .json = "image", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "fsType", .type = .string },
    .{ .number = 4, .json = "pool", .type = .string },
    .{ .number = 5, .json = "user", .type = .string },
    .{ .number = 6, .json = "keyring", .type = .string },
    .{ .number = 7, .json = "secretRef", .type = .message, .message = &core_v1_SecretReference, .omit_zero = false },
    .{ .number = 8, .json = "readOnly", .type = .bool },
} };

pub const core_v1_RBDVolumeSource: Message = .{ .fields = &.{
    .{ .number = 1, .json = "monitors", .type = .string, .repeated = true },
    .{ .number = 2, .json = "image", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "fsType", .type = .string },
    .{ .number = 4, .json = "pool", .type = .string },
    .{ .number = 5, .json = "user", .type = .string },
    .{ .number = 6, .json = "keyring", .type = .string },
    .{ .number = 7, .json = "secretRef", .type = .message, .message = &core_v1_LocalObjectReference, .omit_zero = false },
    .{ .number = 8, .json = "readOnly", .type = .bool },
} };

pub const core_v1_ResourceClaim: Message = .{ .fields = &.{
    .{ .number = 1, .json = "name", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "request", .type = .string },
} };

pub const core_v1_ResourceFieldSelector: Message = .{ .fields = &.{
    .{ .number = 1, .json = "containerName", .type = .string },
    .{ .number = 2, .json = "resource", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "divisor", .type = .quantity },
} };

pub const core_v1_ResourceHealth: Message = .{ .fields = &.{
    .{ .number = 1, .json = "resourceID", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "health", .type = .string },
    .{ .number = 6, .json = "message", .type = .string, .omit_zero = false },
} };

pub const core_v1_ResourceQuota: Message = .{ .fields = &.{
    .{ .number = 1, .json = "metadata", .type = .message, .message = &meta_v1_ObjectMeta, .omit_zero = false },
    .{ .number = 2, .json = "spec", .type = .message, .message = &core_v1_ResourceQuotaSpec, .omit_zero = false },
    .{ .number = 3, .json = "status", .type = .message, .message = &core_v1_ResourceQuotaStatus, .omit_zero = false },
} };

pub const core_v1_ResourceQuotaSpec: Message = .{ .fields = &.{
    .{ .number = 1, .json = "hard", .type = .quantity, .map = true },
    .{ .number = 2, .json = "scopes", .type = .string, .repeated = true },
    .{ .number = 3, .json = "scopeSelector", .type = .message, .message = &core_v1_ScopeSelector, .omit_zero = false },
} };

pub const core_v1_ResourceQuotaStatus: Message = .{ .fields = &.{
    .{ .number = 1, .json = "hard", .type = .quantity, .map = true },
    .{ .number = 2, .json = "used", .type = .quantity, .map = true },
} };

pub const core_v1_ResourceRequirements: Message = .{ .fields = &.{
    .{ .number = 1, .json = "limits", .type = .quantity, .map = true },
    .{ .number = 2, .json = "requests", .type = .quantity, .map = true },
    .{ .number = 3, .json = "claims", .type = .message, .message = &core_v1_ResourceClaim, .repeated = true },
} };

pub const core_v1_ResourceStatus: Message = .{ .fields = &.{
    .{ .number = 1, .json = "name", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "resources", .type = .message, .message = &core_v1_ResourceHealth, .repeated = true },
} };

pub const core_v1_SELinuxOptions: Message = .{ .fields = &.{
    .{ .number = 1, .json = "user", .type = .string },
    .{ .number = 2, .json = "role", .type = .string },
    .{ .number = 3, .json = "type", .type = .string },
    .{ .number = 4, .json = "level", .type = .string },
} };

pub const core_v1_ScaleIOPersistentVolumeSource: Message = .{ .fields = &.{
    .{ .number = 1, .json = "gateway", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "system", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "secretRef", .type = .message, .message = &core_v1_SecretReference, .omit_zero = false },
    .{ .number = 4, .json = "sslEnabled", .type = .bool },
    .{ .number = 5, .json = "protectionDomain", .type = .string },
    .{ .number = 6, .json = "storagePool", .type = .string },
    .{ .number = 7, .json = "storageMode", .type = .string },
    .{ .number = 8, .json = "volumeName", .type = .string },
    .{ .number = 9, .json = "fsType", .type = .string },
    .{ .number = 10, .json = "readOnly", .type = .bool },
} };

pub const core_v1_ScaleIOVolumeSource: Message = .{ .fields = &.{
    .{ .number = 1, .json = "gateway", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "system", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "secretRef", .type = .message, .message = &core_v1_LocalObjectReference, .omit_zero = false },
    .{ .number = 4, .json = "sslEnabled", .type = .bool },
    .{ .number = 5, .json = "protectionDomain", .type = .string },
    .{ .number = 6, .json = "storagePool", .type = .string },
    .{ .number = 7, .json = "storageMode", .type = .string },
    .{ .number = 8, .json = "volumeName", .type = .string },
    .{ .number = 9, .json = "fsType", .type = .string },
    .{ .number = 10, .json = "readOnly", .type = .bool },
} };

pub const core_v1_ScopeSelector: Message = .{ .fields = &.{
    .{ .number = 1, .json = "matchExpressions", .type = .message, .message = &core_v1_ScopedResourceSelectorRequirement, .repeated = true },
} };

pub const core_v1_ScopedResourceSelectorRequirement: Message = .{ .fields = &.{
    .{ .number = 1, .json = "scopeName", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "operator", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "values", .type = .string, .repeated = true },
} };

pub const core_v1_SeccompProfile: Message = .{ .fields = &.{
    .{ .number = 1, .json = "type", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "localhostProfile", .type = .string, .omit_zero = false },
} };

pub const core_v1_Secret: Message = .{ .fields = &.{
    .{ .number = 1, .json = "metadata", .type = .message, .message = &meta_v1_ObjectMeta, .omit_zero = false },
    .{ .number = 5, .json = "immutable", .type = .bool, .omit_zero = false },
    .{ .number = 2, .json = "data", .type = .bytes, .map = true },
    .{ .number = 4, .json = "stringData", .type = .string, .map = true },
    .{ .number = 3, .json = "type", .type = .string },
} };

pub const core_v1_SecretEnvSource: Message = .{ .fields = &.{
    .{ .number = 1, .json = "", .type = .message, .message = &core_v1_LocalObjectReference, .embedded = true },
    .{ .number = 2, .json = "optional", .type = .bool, .omit_zero = false },
} };

pub const core_v1_SecretKeySelector: Message = .{ .fields = &.{
    .{ .number = 1, .json = "", .type = .message, .message = &core_v1_LocalObjectReference, .embedded = true },
    .{ .number = 2, .json = "key", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "optional", .type = .bool, .omit_zero = false },
} };

pub const core_v1_SecretProjection: Message = .{ .fields = &.{
    .{ .number = 1, .json = "", .type = .message, .message = &core_v1_LocalObjectReference, .embedded = true },
    .{ .number = 2, .json = "items", .type = .message, .message = &core_v1_KeyToPath, .repeated = true },
    .{ .number = 4, .json = "optional", .type = .bool, .omit_zero = false },
} };

pub const core_v1_SecretReference: Message = .{ .fields = &.{
    .{ .number = 1, .json = "name", .type = .string },
    .{ .number = 2, .json = "namespace", .type = .string },
} };

pub const core_v1_SecretVolumeSource: Message = .{ .fields = &.{
    .{ .number = 1, .json = "secretName", .type = .string },
    .{ .number = 2, .json = "items", .type = .message, .message = &core_v1_KeyToPath, .repeated = true },
    .{ .number = 3, .json = "defaultMode", .type = .int32, .omit_zero = false },
    .{ .number = 4, .json = "optional", .type = .bool, .omit_zero = false },
    .{ .number = 5, .json = "defaultUser", .type = .int64, .omit_zero = false },
} };

pub const core_v1_SecurityContext: Message = .{ .fields = &.{
    .{ .number = 1, .json = "capabilities", .type = .message, .message = &core_v1_Capabilities, .omit_zero = false },
    .{ .number = 2, .json = "privileged", .type = .bool, .omit_zero = false },
    .{ .number = 3, .json = "seLinuxOptions", .type = .message, .message = &core_v1_SELinuxOptions, .omit_zero = false },
    .{ .number = 10, .json = "windowsOptions", .type = .message, .message = &core_v1_WindowsSecurityContextOptions, .omit_zero = false },
    .{ .number = 4, .json = "runAsUser", .type = .int64, .omit_zero = false },
    .{ .number = 8, .json = "runAsGroup", .type = .int64, .omit_zero = false },
    .{ .number = 5, .json = "runAsNonRoot", .type = .bool, .omit_zero = false },
    .{ .number = 6, .json = "readOnlyRootFilesystem", .type = .bool, .omit_zero = false },
    .{ .number = 7, .json = "allowPrivilegeEscalation", .type = .bool, .omit_zero = false },
    .{ .number = 9, .json = "procMount", .type = .string, .omit_zero = false },
    .{ .number = 11, .json = "seccompProfile", .type = .message, .message = &core_v1_SeccompProfile, .omit_zero = false },
    .{ .number = 12, .json = "appArmorProfile", .type = .message, .message = &core_v1_AppArmorProfile, .omit_zero = false },
} };

pub const core_v1_Service: Message = .{ .fields = &.{
    .{ .number = 1, .json = "metadata", .type = .message, .message = &meta_v1_ObjectMeta, .omit_zero = false },
    .{ .number = 2, .json = "spec", .type = .message, .message = &core_v1_ServiceSpec, .omit_zero = false },
    .{ .number = 3, .json = "status", .type = .message, .message = &core_v1_ServiceStatus, .omit_zero = false },
} };

pub const core_v1_ServiceAccount: Message = .{ .fields = &.{
    .{ .number = 1, .json = "metadata", .type = .message, .message = &meta_v1_ObjectMeta, .omit_zero = false },
    .{ .number = 2, .json = "secrets", .type = .message, .message = &core_v1_ObjectReference, .repeated = true },
    .{ .number = 3, .json = "imagePullSecrets", .type = .message, .message = &core_v1_LocalObjectReference, .repeated = true },
    .{ .number = 4, .json = "automountServiceAccountToken", .type = .bool, .omit_zero = false },
} };

pub const core_v1_ServiceAccountTokenProjection: Message = .{ .fields = &.{
    .{ .number = 1, .json = "audience", .type = .string },
    .{ .number = 2, .json = "expirationSeconds", .type = .int64, .omit_zero = false },
    .{ .number = 3, .json = "path", .type = .string, .omit_zero = false },
    .{ .number = 4, .json = "user", .type = .int64, .omit_zero = false },
} };

pub const core_v1_ServicePort: Message = .{ .fields = &.{
    .{ .number = 1, .json = "name", .type = .string },
    .{ .number = 2, .json = "protocol", .type = .string },
    .{ .number = 6, .json = "appProtocol", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "port", .type = .int32, .omit_zero = false },
    .{ .number = 4, .json = "targetPort", .type = .int_or_string },
    .{ .number = 5, .json = "nodePort", .type = .int32 },
} };

pub const core_v1_ServiceSpec: Message = .{ .fields = &.{
    .{ .number = 1, .json = "ports", .type = .message, .message = &core_v1_ServicePort, .repeated = true },
    .{ .number = 2, .json = "selector", .type = .string, .map = true },
    .{ .number = 3, .json = "clusterIP", .type = .string },
    .{ .number = 18, .json = "clusterIPs", .type = .string, .repeated = true },
    .{ .number = 4, .json = "type", .type = .string },
    .{ .number = 5, .json = "externalIPs", .type = .string, .repeated = true },
    .{ .number = 7, .json = "sessionAffinity", .type = .string },
    .{ .number = 8, .json = "loadBalancerIP", .type = .string },
    .{ .number = 9, .json = "loadBalancerSourceRanges", .type = .string, .repeated = true },
    .{ .number = 10, .json = "externalName", .type = .string },
    .{ .number = 11, .json = "externalTrafficPolicy", .type = .string },
    .{ .number = 12, .json = "healthCheckNodePort", .type = .int32 },
    .{ .number = 13, .json = "publishNotReadyAddresses", .type = .bool },
    .{ .number = 14, .json = "sessionAffinityConfig", .type = .message, .message = &core_v1_SessionAffinityConfig, .omit_zero = false },
    .{ .number = 19, .json = "ipFamilies", .type = .string, .repeated = true },
    .{ .number = 17, .json = "ipFamilyPolicy", .type = .string, .omit_zero = false },
    .{ .number = 20, .json = "allocateLoadBalancerNodePorts", .type = .bool, .omit_zero = false },
    .{ .number = 21, .json = "loadBalancerClass", .type = .string, .omit_zero = false },
    .{ .number = 22, .json = "internalTrafficPolicy", .type = .string, .omit_zero = false },
    .{ .number = 23, .json = "trafficDistribution", .type = .string, .omit_zero = false },
} };

pub const core_v1_ServiceStatus: Message = .{ .fields = &.{
    .{ .number = 1, .json = "loadBalancer", .type = .message, .message = &core_v1_LoadBalancerStatus, .omit_zero = false },
    .{ .number = 2, .json = "conditions", .type = .message, .message = &meta_v1_Condition, .repeated = true },
} };

pub const core_v1_SessionAffinityConfig: Message = .{ .fields = &.{
    .{ .number = 1, .json = "clientIP", .type = .message, .message = &core_v1_ClientIPConfig, .omit_zero = false },
} };

pub const core_v1_SleepAction: Message = .{ .fields = &.{
    .{ .number = 1, .json = "seconds", .type = .int64, .omit_zero = false },
} };

pub const core_v1_StorageOSPersistentVolumeSource: Message = .{ .fields = &.{
    .{ .number = 1, .json = "volumeName", .type = .string },
    .{ .number = 2, .json = "volumeNamespace", .type = .string },
    .{ .number = 3, .json = "fsType", .type = .string },
    .{ .number = 4, .json = "readOnly", .type = .bool },
    .{ .number = 5, .json = "secretRef", .type = .message, .message = &core_v1_ObjectReference, .omit_zero = false },
} };

pub const core_v1_StorageOSVolumeSource: Message = .{ .fields = &.{
    .{ .number = 1, .json = "volumeName", .type = .string },
    .{ .number = 2, .json = "volumeNamespace", .type = .string },
    .{ .number = 3, .json = "fsType", .type = .string },
    .{ .number = 4, .json = "readOnly", .type = .bool },
    .{ .number = 5, .json = "secretRef", .type = .message, .message = &core_v1_LocalObjectReference, .omit_zero = false },
} };

pub const core_v1_Sysctl: Message = .{ .fields = &.{
    .{ .number = 1, .json = "name", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "value", .type = .string, .omit_zero = false },
} };

pub const core_v1_TCPSocketAction: Message = .{ .fields = &.{
    .{ .number = 1, .json = "port", .type = .int_or_string, .omit_zero = false },
    .{ .number = 2, .json = "host", .type = .string },
} };

pub const core_v1_Taint: Message = .{ .fields = &.{
    .{ .number = 1, .json = "key", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "value", .type = .string },
    .{ .number = 3, .json = "effect", .type = .string, .omit_zero = false },
    .{ .number = 4, .json = "timeAdded", .type = .time, .omit_zero = false },
} };

pub const core_v1_Toleration: Message = .{ .fields = &.{
    .{ .number = 1, .json = "key", .type = .string },
    .{ .number = 2, .json = "operator", .type = .string },
    .{ .number = 3, .json = "value", .type = .string },
    .{ .number = 4, .json = "effect", .type = .string },
    .{ .number = 5, .json = "tolerationSeconds", .type = .int64, .omit_zero = false },
} };

pub const core_v1_TopologySelectorLabelRequirement: Message = .{ .fields = &.{
    .{ .number = 1, .json = "key", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "values", .type = .string, .repeated = true },
} };

pub const core_v1_TopologySelectorTerm: Message = .{ .fields = &.{
    .{ .number = 1, .json = "matchLabelExpressions", .type = .message, .message = &core_v1_TopologySelectorLabelRequirement, .repeated = true },
} };

pub const core_v1_TopologySpreadConstraint: Message = .{ .fields = &.{
    .{ .number = 1, .json = "maxSkew", .type = .int32, .omit_zero = false },
    .{ .number = 2, .json = "topologyKey", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "whenUnsatisfiable", .type = .string, .omit_zero = false },
    .{ .number = 4, .json = "labelSelector", .type = .message, .message = &meta_v1_LabelSelector, .omit_zero = false },
    .{ .number = 5, .json = "minDomains", .type = .int32, .omit_zero = false },
    .{ .number = 6, .json = "nodeAffinityPolicy", .type = .string, .omit_zero = false },
    .{ .number = 7, .json = "nodeTaintsPolicy", .type = .string, .omit_zero = false },
    .{ .number = 8, .json = "matchLabelKeys", .type = .string, .repeated = true },
} };

pub const core_v1_TypedLocalObjectReference: Message = .{ .fields = &.{
    .{ .number = 1, .json = "apiGroup", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "kind", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "name", .type = .string, .omit_zero = false },
} };

pub const core_v1_TypedObjectReference: Message = .{ .fields = &.{
    .{ .number = 1, .json = "apiGroup", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "kind", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "name", .type = .string, .omit_zero = false },
    .{ .number = 4, .json = "namespace", .type = .string, .omit_zero = false },
} };

pub const core_v1_Volume: Message = .{ .fields = &.{
    .{ .number = 1, .json = "name", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "", .type = .message, .message = &core_v1_VolumeSource, .embedded = true },
} };

pub const core_v1_VolumeDevice: Message = .{ .fields = &.{
    .{ .number = 1, .json = "name", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "devicePath", .type = .string, .omit_zero = false },
} };

pub const core_v1_VolumeHealthCondition: Message = .{ .fields = &.{
    .{ .number = 1, .json = "status", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "reason", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "message", .type = .string },
} };

pub const core_v1_VolumeHealthStatus: Message = .{ .fields = &.{
    .{ .number = 1, .json = "healthConditions", .type = .message, .message = &core_v1_VolumeHealthCondition, .repeated = true },
    .{ .number = 2, .json = "lastTransitionTime", .type = .time },
} };

pub const core_v1_VolumeMount: Message = .{ .fields = &.{
    .{ .number = 1, .json = "name", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "readOnly", .type = .bool },
    .{ .number = 7, .json = "recursiveReadOnly", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "mountPath", .type = .string, .omit_zero = false },
    .{ .number = 4, .json = "subPath", .type = .string },
    .{ .number = 5, .json = "mountPropagation", .type = .string, .omit_zero = false },
    .{ .number = 6, .json = "subPathExpr", .type = .string },
    .{ .number = 8, .json = "bindMountOptions", .type = .string, .repeated = true },
} };

pub const core_v1_VolumeMountStatus: Message = .{ .fields = &.{
    .{ .number = 1, .json = "name", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "mountPath", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "readOnly", .type = .bool },
    .{ .number = 4, .json = "recursiveReadOnly", .type = .string, .omit_zero = false },
    .{ .number = 5, .json = "volumeStatus", .type = .message, .message = &core_v1_VolumeStatus, .omit_zero = false },
} };

pub const core_v1_VolumeNodeAffinity: Message = .{ .fields = &.{
    .{ .number = 1, .json = "required", .type = .message, .message = &core_v1_NodeSelector, .omit_zero = false },
} };

pub const core_v1_VolumeProjection: Message = .{ .fields = &.{
    .{ .number = 1, .json = "secret", .type = .message, .message = &core_v1_SecretProjection, .omit_zero = false },
    .{ .number = 2, .json = "downwardAPI", .type = .message, .message = &core_v1_DownwardAPIProjection, .omit_zero = false },
    .{ .number = 3, .json = "configMap", .type = .message, .message = &core_v1_ConfigMapProjection, .omit_zero = false },
    .{ .number = 4, .json = "serviceAccountToken", .type = .message, .message = &core_v1_ServiceAccountTokenProjection, .omit_zero = false },
    .{ .number = 5, .json = "clusterTrustBundle", .type = .message, .message = &core_v1_ClusterTrustBundleProjection, .omit_zero = false },
    .{ .number = 6, .json = "podCertificate", .type = .message, .message = &core_v1_PodCertificateProjection, .omit_zero = false },
} };

pub const core_v1_VolumeResourceRequirements: Message = .{ .fields = &.{
    .{ .number = 1, .json = "limits", .type = .quantity, .map = true },
    .{ .number = 2, .json = "requests", .type = .quantity, .map = true },
} };

pub const core_v1_VolumeSource: Message = .{ .fields = &.{
    .{ .number = 1, .json = "hostPath", .type = .message, .message = &core_v1_HostPathVolumeSource, .omit_zero = false },
    .{ .number = 2, .json = "emptyDir", .type = .message, .message = &core_v1_EmptyDirVolumeSource, .omit_zero = false },
    .{ .number = 3, .json = "gcePersistentDisk", .type = .message, .message = &core_v1_GCEPersistentDiskVolumeSource, .omit_zero = false },
    .{ .number = 4, .json = "awsElasticBlockStore", .type = .message, .message = &core_v1_AWSElasticBlockStoreVolumeSource, .omit_zero = false },
    .{ .number = 5, .json = "gitRepo", .type = .message, .message = &core_v1_GitRepoVolumeSource, .omit_zero = false },
    .{ .number = 6, .json = "secret", .type = .message, .message = &core_v1_SecretVolumeSource, .omit_zero = false },
    .{ .number = 7, .json = "nfs", .type = .message, .message = &core_v1_NFSVolumeSource, .omit_zero = false },
    .{ .number = 8, .json = "iscsi", .type = .message, .message = &core_v1_ISCSIVolumeSource, .omit_zero = false },
    .{ .number = 9, .json = "glusterfs", .type = .message, .message = &core_v1_GlusterfsVolumeSource, .omit_zero = false },
    .{ .number = 10, .json = "persistentVolumeClaim", .type = .message, .message = &core_v1_PersistentVolumeClaimVolumeSource, .omit_zero = false },
    .{ .number = 11, .json = "rbd", .type = .message, .message = &core_v1_RBDVolumeSource, .omit_zero = false },
    .{ .number = 12, .json = "flexVolume", .type = .message, .message = &core_v1_FlexVolumeSource, .omit_zero = false },
    .{ .number = 13, .json = "cinder", .type = .message, .message = &core_v1_CinderVolumeSource, .omit_zero = false },
    .{ .number = 14, .json = "cephfs", .type = .message, .message = &core_v1_CephFSVolumeSource, .omit_zero = false },
    .{ .number = 15, .json = "flocker", .type = .message, .message = &core_v1_FlockerVolumeSource, .omit_zero = false },
    .{ .number = 16, .json = "downwardAPI", .type = .message, .message = &core_v1_DownwardAPIVolumeSource, .omit_zero = false },
    .{ .number = 17, .json = "fc", .type = .message, .message = &core_v1_FCVolumeSource, .omit_zero = false },
    .{ .number = 18, .json = "azureFile", .type = .message, .message = &core_v1_AzureFileVolumeSource, .omit_zero = false },
    .{ .number = 19, .json = "configMap", .type = .message, .message = &core_v1_ConfigMapVolumeSource, .omit_zero = false },
    .{ .number = 20, .json = "vsphereVolume", .type = .message, .message = &core_v1_VsphereVirtualDiskVolumeSource, .omit_zero = false },
    .{ .number = 21, .json = "quobyte", .type = .message, .message = &core_v1_QuobyteVolumeSource, .omit_zero = false },
    .{ .number = 22, .json = "azureDisk", .type = .message, .message = &core_v1_AzureDiskVolumeSource, .omit_zero = false },
    .{ .number = 23, .json = "photonPersistentDisk", .type = .message, .message = &core_v1_PhotonPersistentDiskVolumeSource, .omit_zero = false },
    .{ .number = 26, .json = "projected", .type = .message, .message = &core_v1_ProjectedVolumeSource, .omit_zero = false },
    .{ .number = 24, .json = "portworxVolume", .type = .message, .message = &core_v1_PortworxVolumeSource, .omit_zero = false },
    .{ .number = 25, .json = "scaleIO", .type = .message, .message = &core_v1_ScaleIOVolumeSource, .omit_zero = false },
    .{ .number = 27, .json = "storageos", .type = .message, .message = &core_v1_StorageOSVolumeSource, .omit_zero = false },
    .{ .number = 28, .json = "csi", .type = .message, .message = &core_v1_CSIVolumeSource, .omit_zero = false },
    .{ .number = 29, .json = "ephemeral", .type = .message, .message = &core_v1_EphemeralVolumeSource, .omit_zero = false },
    .{ .number = 30, .json = "image", .type = .message, .message = &core_v1_ImageVolumeSource, .omit_zero = false },
} };

pub const core_v1_VolumeStatus: Message = .{ .fields = &.{
    .{ .number = 1, .json = "image", .type = .message, .message = &core_v1_ImageVolumeStatus, .omit_zero = false },
} };

pub const core_v1_VsphereVirtualDiskVolumeSource: Message = .{ .fields = &.{
    .{ .number = 1, .json = "volumePath", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "fsType", .type = .string },
    .{ .number = 3, .json = "storagePolicyName", .type = .string },
    .{ .number = 4, .json = "storagePolicyID", .type = .string },
} };

pub const core_v1_WeightedPodAffinityTerm: Message = .{ .fields = &.{
    .{ .number = 1, .json = "weight", .type = .int32, .omit_zero = false },
    .{ .number = 2, .json = "podAffinityTerm", .type = .message, .message = &core_v1_PodAffinityTerm, .omit_zero = false },
} };

pub const core_v1_WindowsSecurityContextOptions: Message = .{ .fields = &.{
    .{ .number = 1, .json = "gmsaCredentialSpecName", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "gmsaCredentialSpec", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "runAsUserName", .type = .string, .omit_zero = false },
    .{ .number = 4, .json = "hostProcess", .type = .bool, .omit_zero = false },
} };

pub const discovery_v1_Endpoint: Message = .{ .fields = &.{
    .{ .number = 1, .json = "addresses", .type = .string, .repeated = true },
    .{ .number = 2, .json = "conditions", .type = .message, .message = &discovery_v1_EndpointConditions, .omit_zero = false },
    .{ .number = 3, .json = "hostname", .type = .string, .omit_zero = false },
    .{ .number = 4, .json = "targetRef", .type = .message, .message = &core_v1_ObjectReference, .omit_zero = false },
    .{ .number = 5, .json = "deprecatedTopology", .type = .string, .map = true },
    .{ .number = 6, .json = "nodeName", .type = .string, .omit_zero = false },
    .{ .number = 7, .json = "zone", .type = .string, .omit_zero = false },
    .{ .number = 8, .json = "hints", .type = .message, .message = &discovery_v1_EndpointHints, .omit_zero = false },
} };

pub const discovery_v1_EndpointConditions: Message = .{ .fields = &.{
    .{ .number = 1, .json = "ready", .type = .bool, .omit_zero = false },
    .{ .number = 2, .json = "serving", .type = .bool, .omit_zero = false },
    .{ .number = 3, .json = "terminating", .type = .bool, .omit_zero = false },
} };

pub const discovery_v1_EndpointHints: Message = .{ .fields = &.{
    .{ .number = 1, .json = "forZones", .type = .message, .message = &discovery_v1_ForZone, .repeated = true },
    .{ .number = 2, .json = "forNodes", .type = .message, .message = &discovery_v1_ForNode, .repeated = true },
} };

pub const discovery_v1_EndpointPort: Message = .{ .fields = &.{
    .{ .number = 1, .json = "name", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "protocol", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "port", .type = .int32, .omit_zero = false },
    .{ .number = 4, .json = "appProtocol", .type = .string, .omit_zero = false },
} };

pub const discovery_v1_EndpointSlice: Message = .{ .fields = &.{
    .{ .number = 1, .json = "metadata", .type = .message, .message = &meta_v1_ObjectMeta, .omit_zero = false },
    .{ .number = 4, .json = "addressType", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "endpoints", .type = .message, .message = &discovery_v1_Endpoint, .repeated = true },
    .{ .number = 3, .json = "ports", .type = .message, .message = &discovery_v1_EndpointPort, .repeated = true },
} };

pub const discovery_v1_ForNode: Message = .{ .fields = &.{
    .{ .number = 1, .json = "name", .type = .string, .omit_zero = false },
} };

pub const discovery_v1_ForZone: Message = .{ .fields = &.{
    .{ .number = 1, .json = "name", .type = .string, .omit_zero = false },
} };

pub const meta_v1_Condition: Message = .{ .fields = &.{
    .{ .number = 1, .json = "type", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "status", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "observedGeneration", .type = .int64 },
    .{ .number = 4, .json = "lastTransitionTime", .type = .time, .omit_zero = false },
    .{ .number = 5, .json = "reason", .type = .string, .omit_zero = false },
    .{ .number = 6, .json = "message", .type = .string, .omit_zero = false },
} };

pub const meta_v1_GroupResource: Message = .{ .fields = &.{
    .{ .number = 1, .json = "group", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "resource", .type = .string, .omit_zero = false },
} };

pub const meta_v1_LabelSelector: Message = .{ .fields = &.{
    .{ .number = 1, .json = "matchLabels", .type = .string, .map = true },
    .{ .number = 2, .json = "matchExpressions", .type = .message, .message = &meta_v1_LabelSelectorRequirement, .repeated = true },
} };

pub const meta_v1_LabelSelectorRequirement: Message = .{ .fields = &.{
    .{ .number = 1, .json = "key", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "operator", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "values", .type = .string, .repeated = true },
} };

pub const meta_v1_ManagedFieldsEntry: Message = .{ .fields = &.{
    .{ .number = 1, .json = "manager", .type = .string },
    .{ .number = 2, .json = "operation", .type = .string },
    .{ .number = 3, .json = "apiVersion", .type = .string },
    .{ .number = 4, .json = "time", .type = .time, .omit_zero = false },
    .{ .number = 6, .json = "fieldsType", .type = .string },
    .{ .number = 7, .json = "fieldsV1", .type = .raw_json, .omit_zero = false },
    .{ .number = 8, .json = "subresource", .type = .string },
} };

pub const meta_v1_ObjectMeta: Message = .{ .fields = &.{
    .{ .number = 1, .json = "name", .type = .string },
    .{ .number = 2, .json = "generateName", .type = .string },
    .{ .number = 3, .json = "namespace", .type = .string },
    .{ .number = 4, .json = "selfLink", .type = .string },
    .{ .number = 5, .json = "uid", .type = .string },
    .{ .number = 6, .json = "resourceVersion", .type = .string },
    .{ .number = 7, .json = "generation", .type = .int64 },
    .{ .number = 8, .json = "creationTimestamp", .type = .time },
    .{ .number = 9, .json = "deletionTimestamp", .type = .time, .omit_zero = false },
    .{ .number = 10, .json = "deletionGracePeriodSeconds", .type = .int64, .omit_zero = false },
    .{ .number = 11, .json = "labels", .type = .string, .map = true },
    .{ .number = 12, .json = "annotations", .type = .string, .map = true },
    .{ .number = 13, .json = "ownerReferences", .type = .message, .message = &meta_v1_OwnerReference, .repeated = true },
    .{ .number = 14, .json = "finalizers", .type = .string, .repeated = true },
    .{ .number = 17, .json = "managedFields", .type = .message, .message = &meta_v1_ManagedFieldsEntry, .repeated = true },
} };

pub const meta_v1_OwnerReference: Message = .{ .fields = &.{
    .{ .number = 5, .json = "apiVersion", .type = .string, .omit_zero = false },
    .{ .number = 1, .json = "kind", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "name", .type = .string, .omit_zero = false },
    .{ .number = 4, .json = "uid", .type = .string, .omit_zero = false },
    .{ .number = 6, .json = "controller", .type = .bool, .omit_zero = false },
    .{ .number = 7, .json = "blockOwnerDeletion", .type = .bool, .omit_zero = false },
} };

pub const networking_v1_HTTPIngressPath: Message = .{ .fields = &.{
    .{ .number = 1, .json = "path", .type = .string },
    .{ .number = 3, .json = "pathType", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "backend", .type = .message, .message = &networking_v1_IngressBackend, .omit_zero = false },
} };

pub const networking_v1_HTTPIngressRuleValue: Message = .{ .fields = &.{
    .{ .number = 1, .json = "paths", .type = .message, .message = &networking_v1_HTTPIngressPath, .repeated = true },
} };

pub const networking_v1_IPAddress: Message = .{ .fields = &.{
    .{ .number = 1, .json = "metadata", .type = .message, .message = &meta_v1_ObjectMeta, .omit_zero = false },
    .{ .number = 2, .json = "spec", .type = .message, .message = &networking_v1_IPAddressSpec, .omit_zero = false },
} };

pub const networking_v1_IPAddressSpec: Message = .{ .fields = &.{
    .{ .number = 1, .json = "parentRef", .type = .message, .message = &networking_v1_ParentReference, .omit_zero = false },
} };

pub const networking_v1_IPBlock: Message = .{ .fields = &.{
    .{ .number = 1, .json = "cidr", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "except", .type = .string, .repeated = true },
} };

pub const networking_v1_Ingress: Message = .{ .fields = &.{
    .{ .number = 1, .json = "metadata", .type = .message, .message = &meta_v1_ObjectMeta, .omit_zero = false },
    .{ .number = 2, .json = "spec", .type = .message, .message = &networking_v1_IngressSpec, .omit_zero = false },
    .{ .number = 3, .json = "status", .type = .message, .message = &networking_v1_IngressStatus, .omit_zero = false },
} };

pub const networking_v1_IngressBackend: Message = .{ .fields = &.{
    .{ .number = 4, .json = "service", .type = .message, .message = &networking_v1_IngressServiceBackend, .omit_zero = false },
    .{ .number = 3, .json = "resource", .type = .message, .message = &core_v1_TypedLocalObjectReference, .omit_zero = false },
} };

pub const networking_v1_IngressClass: Message = .{ .fields = &.{
    .{ .number = 1, .json = "metadata", .type = .message, .message = &meta_v1_ObjectMeta, .omit_zero = false },
    .{ .number = 2, .json = "spec", .type = .message, .message = &networking_v1_IngressClassSpec, .omit_zero = false },
} };

pub const networking_v1_IngressClassParametersReference: Message = .{ .fields = &.{
    .{ .number = 1, .json = "apiGroup", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "kind", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "name", .type = .string, .omit_zero = false },
    .{ .number = 4, .json = "scope", .type = .string, .omit_zero = false },
    .{ .number = 5, .json = "namespace", .type = .string, .omit_zero = false },
} };

pub const networking_v1_IngressClassSpec: Message = .{ .fields = &.{
    .{ .number = 1, .json = "controller", .type = .string },
    .{ .number = 2, .json = "parameters", .type = .message, .message = &networking_v1_IngressClassParametersReference, .omit_zero = false },
} };

pub const networking_v1_IngressLoadBalancerIngress: Message = .{ .fields = &.{
    .{ .number = 1, .json = "ip", .type = .string },
    .{ .number = 2, .json = "hostname", .type = .string },
    .{ .number = 4, .json = "ports", .type = .message, .message = &networking_v1_IngressPortStatus, .repeated = true },
} };

pub const networking_v1_IngressLoadBalancerStatus: Message = .{ .fields = &.{
    .{ .number = 1, .json = "ingress", .type = .message, .message = &networking_v1_IngressLoadBalancerIngress, .repeated = true },
} };

pub const networking_v1_IngressPortStatus: Message = .{ .fields = &.{
    .{ .number = 1, .json = "port", .type = .int32, .omit_zero = false },
    .{ .number = 2, .json = "protocol", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "error", .type = .string, .omit_zero = false },
} };

pub const networking_v1_IngressRule: Message = .{ .fields = &.{
    .{ .number = 1, .json = "host", .type = .string },
    .{ .number = 2, .json = "", .type = .message, .message = &networking_v1_IngressRuleValue, .embedded = true },
} };

pub const networking_v1_IngressRuleValue: Message = .{ .fields = &.{
    .{ .number = 1, .json = "http", .type = .message, .message = &networking_v1_HTTPIngressRuleValue, .omit_zero = false },
} };

pub const networking_v1_IngressServiceBackend: Message = .{ .fields = &.{
    .{ .number = 1, .json = "name", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "port", .type = .message, .message = &networking_v1_ServiceBackendPort, .omit_zero = false },
} };

pub const networking_v1_IngressSpec: Message = .{ .fields = &.{
    .{ .number = 4, .json = "ingressClassName", .type = .string, .omit_zero = false },
    .{ .number = 1, .json = "defaultBackend", .type = .message, .message = &networking_v1_IngressBackend, .omit_zero = false },
    .{ .number = 2, .json = "tls", .type = .message, .message = &networking_v1_IngressTLS, .repeated = true },
    .{ .number = 3, .json = "rules", .type = .message, .message = &networking_v1_IngressRule, .repeated = true },
} };

pub const networking_v1_IngressStatus: Message = .{ .fields = &.{
    .{ .number = 1, .json = "loadBalancer", .type = .message, .message = &networking_v1_IngressLoadBalancerStatus, .omit_zero = false },
} };

pub const networking_v1_IngressTLS: Message = .{ .fields = &.{
    .{ .number = 1, .json = "hosts", .type = .string, .repeated = true },
    .{ .number = 2, .json = "secretName", .type = .string },
} };

pub const networking_v1_NetworkPolicy: Message = .{ .fields = &.{
    .{ .number = 1, .json = "metadata", .type = .message, .message = &meta_v1_ObjectMeta, .omit_zero = false },
    .{ .number = 2, .json = "spec", .type = .message, .message = &networking_v1_NetworkPolicySpec, .omit_zero = false },
} };

pub const networking_v1_NetworkPolicyEgressRule: Message = .{ .fields = &.{
    .{ .number = 1, .json = "ports", .type = .message, .message = &networking_v1_NetworkPolicyPort, .repeated = true },
    .{ .number = 2, .json = "to", .type = .message, .message = &networking_v1_NetworkPolicyPeer, .repeated = true },
} };

pub const networking_v1_NetworkPolicyIngressRule: Message = .{ .fields = &.{
    .{ .number = 1, .json = "ports", .type = .message, .message = &networking_v1_NetworkPolicyPort, .repeated = true },
    .{ .number = 2, .json = "from", .type = .message, .message = &networking_v1_NetworkPolicyPeer, .repeated = true },
} };

pub const networking_v1_NetworkPolicyPeer: Message = .{ .fields = &.{
    .{ .number = 1, .json = "podSelector", .type = .message, .message = &meta_v1_LabelSelector, .omit_zero = false },
    .{ .number = 2, .json = "namespaceSelector", .type = .message, .message = &meta_v1_LabelSelector, .omit_zero = false },
    .{ .number = 3, .json = "ipBlock", .type = .message, .message = &networking_v1_IPBlock, .omit_zero = false },
} };

pub const networking_v1_NetworkPolicyPort: Message = .{ .fields = &.{
    .{ .number = 1, .json = "protocol", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "port", .type = .int_or_string, .omit_zero = false },
    .{ .number = 3, .json = "endPort", .type = .int32, .omit_zero = false },
} };

pub const networking_v1_NetworkPolicySpec: Message = .{ .fields = &.{
    .{ .number = 1, .json = "podSelector", .type = .message, .message = &meta_v1_LabelSelector, .omit_zero = false },
    .{ .number = 2, .json = "ingress", .type = .message, .message = &networking_v1_NetworkPolicyIngressRule, .repeated = true },
    .{ .number = 3, .json = "egress", .type = .message, .message = &networking_v1_NetworkPolicyEgressRule, .repeated = true },
    .{ .number = 4, .json = "policyTypes", .type = .string, .repeated = true },
} };

pub const networking_v1_ParentReference: Message = .{ .fields = &.{
    .{ .number = 1, .json = "group", .type = .string },
    .{ .number = 2, .json = "resource", .type = .string },
    .{ .number = 3, .json = "namespace", .type = .string },
    .{ .number = 4, .json = "name", .type = .string },
} };

pub const networking_v1_ServiceBackendPort: Message = .{ .fields = &.{
    .{ .number = 1, .json = "name", .type = .string },
    .{ .number = 2, .json = "number", .type = .int32 },
} };

pub const networking_v1_ServiceCIDR: Message = .{ .fields = &.{
    .{ .number = 1, .json = "metadata", .type = .message, .message = &meta_v1_ObjectMeta, .omit_zero = false },
    .{ .number = 2, .json = "spec", .type = .message, .message = &networking_v1_ServiceCIDRSpec, .omit_zero = false },
    .{ .number = 3, .json = "status", .type = .message, .message = &networking_v1_ServiceCIDRStatus, .omit_zero = false },
} };

pub const networking_v1_ServiceCIDRSpec: Message = .{ .fields = &.{
    .{ .number = 1, .json = "cidrs", .type = .string, .repeated = true },
} };

pub const networking_v1_ServiceCIDRStatus: Message = .{ .fields = &.{
    .{ .number = 1, .json = "conditions", .type = .message, .message = &meta_v1_Condition, .repeated = true },
} };

pub const node_v1_Overhead: Message = .{ .fields = &.{
    .{ .number = 1, .json = "podFixed", .type = .quantity, .map = true },
} };

pub const node_v1_RuntimeClass: Message = .{ .fields = &.{
    .{ .number = 1, .json = "metadata", .type = .message, .message = &meta_v1_ObjectMeta, .omit_zero = false },
    .{ .number = 2, .json = "handler", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "overhead", .type = .message, .message = &node_v1_Overhead, .omit_zero = false },
    .{ .number = 4, .json = "scheduling", .type = .message, .message = &node_v1_Scheduling, .omit_zero = false },
} };

pub const node_v1_Scheduling: Message = .{ .fields = &.{
    .{ .number = 1, .json = "nodeSelector", .type = .string, .map = true },
    .{ .number = 2, .json = "tolerations", .type = .message, .message = &core_v1_Toleration, .repeated = true },
} };

pub const policy_v1_PodDisruptionBudget: Message = .{ .fields = &.{
    .{ .number = 1, .json = "metadata", .type = .message, .message = &meta_v1_ObjectMeta, .omit_zero = false },
    .{ .number = 2, .json = "spec", .type = .message, .message = &policy_v1_PodDisruptionBudgetSpec, .omit_zero = false },
    .{ .number = 3, .json = "status", .type = .message, .message = &policy_v1_PodDisruptionBudgetStatus, .omit_zero = false },
} };

pub const policy_v1_PodDisruptionBudgetSpec: Message = .{ .fields = &.{
    .{ .number = 1, .json = "minAvailable", .type = .int_or_string, .omit_zero = false },
    .{ .number = 2, .json = "selector", .type = .message, .message = &meta_v1_LabelSelector, .omit_zero = false },
    .{ .number = 3, .json = "maxUnavailable", .type = .int_or_string, .omit_zero = false },
    .{ .number = 4, .json = "unhealthyPodEvictionPolicy", .type = .string, .omit_zero = false },
} };

pub const policy_v1_PodDisruptionBudgetStatus: Message = .{ .fields = &.{
    .{ .number = 1, .json = "observedGeneration", .type = .int64 },
    .{ .number = 2, .json = "disruptedPods", .type = .time, .map = true },
    .{ .number = 3, .json = "disruptionsAllowed", .type = .int32, .omit_zero = false },
    .{ .number = 4, .json = "currentHealthy", .type = .int32, .omit_zero = false },
    .{ .number = 5, .json = "desiredHealthy", .type = .int32, .omit_zero = false },
    .{ .number = 6, .json = "expectedPods", .type = .int32, .omit_zero = false },
    .{ .number = 7, .json = "conditions", .type = .message, .message = &meta_v1_Condition, .repeated = true },
} };

pub const rbac_v1_AggregationRule: Message = .{ .fields = &.{
    .{ .number = 1, .json = "clusterRoleSelectors", .type = .message, .message = &meta_v1_LabelSelector, .repeated = true },
} };

pub const rbac_v1_ClusterRole: Message = .{ .fields = &.{
    .{ .number = 1, .json = "metadata", .type = .message, .message = &meta_v1_ObjectMeta, .omit_zero = false },
    .{ .number = 2, .json = "rules", .type = .message, .message = &rbac_v1_PolicyRule, .repeated = true },
    .{ .number = 3, .json = "aggregationRule", .type = .message, .message = &rbac_v1_AggregationRule, .omit_zero = false },
} };

pub const rbac_v1_ClusterRoleBinding: Message = .{ .fields = &.{
    .{ .number = 1, .json = "metadata", .type = .message, .message = &meta_v1_ObjectMeta, .omit_zero = false },
    .{ .number = 2, .json = "subjects", .type = .message, .message = &rbac_v1_Subject, .repeated = true },
    .{ .number = 3, .json = "roleRef", .type = .message, .message = &rbac_v1_RoleRef, .omit_zero = false },
} };

pub const rbac_v1_PolicyRule: Message = .{ .fields = &.{
    .{ .number = 1, .json = "verbs", .type = .string, .repeated = true },
    .{ .number = 2, .json = "apiGroups", .type = .string, .repeated = true },
    .{ .number = 3, .json = "resources", .type = .string, .repeated = true },
    .{ .number = 4, .json = "resourceNames", .type = .string, .repeated = true },
    .{ .number = 5, .json = "nonResourceURLs", .type = .string, .repeated = true },
} };

pub const rbac_v1_Role: Message = .{ .fields = &.{
    .{ .number = 1, .json = "metadata", .type = .message, .message = &meta_v1_ObjectMeta, .omit_zero = false },
    .{ .number = 2, .json = "rules", .type = .message, .message = &rbac_v1_PolicyRule, .repeated = true },
} };

pub const rbac_v1_RoleBinding: Message = .{ .fields = &.{
    .{ .number = 1, .json = "metadata", .type = .message, .message = &meta_v1_ObjectMeta, .omit_zero = false },
    .{ .number = 2, .json = "subjects", .type = .message, .message = &rbac_v1_Subject, .repeated = true },
    .{ .number = 3, .json = "roleRef", .type = .message, .message = &rbac_v1_RoleRef, .omit_zero = false },
} };

pub const rbac_v1_RoleRef: Message = .{ .fields = &.{
    .{ .number = 1, .json = "apiGroup", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "kind", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "name", .type = .string, .omit_zero = false },
} };

pub const rbac_v1_Subject: Message = .{ .fields = &.{
    .{ .number = 1, .json = "kind", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "apiGroup", .type = .string },
    .{ .number = 3, .json = "name", .type = .string, .omit_zero = false },
    .{ .number = 4, .json = "namespace", .type = .string },
} };

pub const resource_v1_AllocatedDeviceStatus: Message = .{ .fields = &.{
    .{ .number = 1, .json = "driver", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "pool", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "device", .type = .string, .omit_zero = false },
    .{ .number = 7, .json = "shareID", .type = .string, .omit_zero = false },
    .{ .number = 4, .json = "conditions", .type = .message, .message = &meta_v1_Condition, .repeated = true },
    .{ .number = 5, .json = "data", .type = .raw_json, .omit_zero = false },
    .{ .number = 6, .json = "networkData", .type = .message, .message = &resource_v1_NetworkDeviceData, .omit_zero = false },
} };

pub const resource_v1_AllocationResult: Message = .{ .fields = &.{
    .{ .number = 1, .json = "devices", .type = .message, .message = &resource_v1_DeviceAllocationResult, .omit_zero = false },
    .{ .number = 3, .json = "nodeSelector", .type = .message, .message = &core_v1_NodeSelector, .omit_zero = false },
    .{ .number = 5, .json = "allocationTimestamp", .type = .time, .omit_zero = false },
} };

pub const resource_v1_CELDeviceSelector: Message = .{ .fields = &.{
    .{ .number = 1, .json = "expression", .type = .string, .omit_zero = false },
} };

pub const resource_v1_CapacityRequirements: Message = .{ .fields = &.{
    .{ .number = 1, .json = "requests", .type = .quantity, .map = true },
} };

pub const resource_v1_DeviceAllocationConfiguration: Message = .{ .fields = &.{
    .{ .number = 1, .json = "source", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "requests", .type = .string, .repeated = true },
    .{ .number = 3, .json = "", .type = .message, .message = &resource_v1_DeviceConfiguration, .embedded = true },
} };

pub const resource_v1_DeviceAllocationResult: Message = .{ .fields = &.{
    .{ .number = 1, .json = "results", .type = .message, .message = &resource_v1_DeviceRequestAllocationResult, .repeated = true },
    .{ .number = 2, .json = "config", .type = .message, .message = &resource_v1_DeviceAllocationConfiguration, .repeated = true },
} };

pub const resource_v1_DeviceClaim: Message = .{ .fields = &.{
    .{ .number = 1, .json = "requests", .type = .message, .message = &resource_v1_DeviceRequest, .repeated = true },
    .{ .number = 2, .json = "constraints", .type = .message, .message = &resource_v1_DeviceConstraint, .repeated = true },
    .{ .number = 3, .json = "config", .type = .message, .message = &resource_v1_DeviceClaimConfiguration, .repeated = true },
} };

pub const resource_v1_DeviceClaimConfiguration: Message = .{ .fields = &.{
    .{ .number = 1, .json = "requests", .type = .string, .repeated = true },
    .{ .number = 2, .json = "", .type = .message, .message = &resource_v1_DeviceConfiguration, .embedded = true },
} };

pub const resource_v1_DeviceClass: Message = .{ .fields = &.{
    .{ .number = 1, .json = "metadata", .type = .message, .message = &meta_v1_ObjectMeta, .omit_zero = false },
    .{ .number = 2, .json = "spec", .type = .message, .message = &resource_v1_DeviceClassSpec, .omit_zero = false },
} };

pub const resource_v1_DeviceClassConfiguration: Message = .{ .fields = &.{
    .{ .number = 1, .json = "", .type = .message, .message = &resource_v1_DeviceConfiguration, .embedded = true },
} };

pub const resource_v1_DeviceClassSpec: Message = .{ .fields = &.{
    .{ .number = 1, .json = "selectors", .type = .message, .message = &resource_v1_DeviceSelector, .repeated = true },
    .{ .number = 2, .json = "config", .type = .message, .message = &resource_v1_DeviceClassConfiguration, .repeated = true },
    .{ .number = 4, .json = "extendedResourceName", .type = .string, .omit_zero = false },
} };

pub const resource_v1_DeviceConfiguration: Message = .{ .fields = &.{
    .{ .number = 1, .json = "opaque", .type = .message, .message = &resource_v1_OpaqueDeviceConfiguration, .omit_zero = false },
} };

pub const resource_v1_DeviceConstraint: Message = .{ .fields = &.{
    .{ .number = 1, .json = "requests", .type = .string, .repeated = true },
    .{ .number = 2, .json = "matchAttribute", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "distinctAttribute", .type = .string, .omit_zero = false },
} };

pub const resource_v1_DeviceDerivedAttribute: Message = .{ .fields = &.{
    .{ .number = 1, .json = "name", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "expression", .type = .string, .omit_zero = false },
} };

pub const resource_v1_DeviceRequest: Message = .{ .fields = &.{
    .{ .number = 1, .json = "name", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "exactly", .type = .message, .message = &resource_v1_ExactDeviceRequest, .omit_zero = false },
    .{ .number = 3, .json = "firstAvailable", .type = .message, .message = &resource_v1_DeviceSubRequest, .repeated = true },
} };

pub const resource_v1_DeviceRequestAllocationResult: Message = .{ .fields = &.{
    .{ .number = 1, .json = "request", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "driver", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "pool", .type = .string, .omit_zero = false },
    .{ .number = 4, .json = "device", .type = .string, .omit_zero = false },
    .{ .number = 5, .json = "adminAccess", .type = .bool, .omit_zero = false },
    .{ .number = 6, .json = "tolerations", .type = .message, .message = &resource_v1_DeviceToleration, .repeated = true },
    .{ .number = 7, .json = "bindingConditions", .type = .string, .repeated = true },
    .{ .number = 8, .json = "bindingFailureConditions", .type = .string, .repeated = true },
    .{ .number = 9, .json = "shareID", .type = .string, .omit_zero = false },
    .{ .number = 10, .json = "consumedCapacity", .type = .quantity, .map = true },
    .{ .number = 11, .json = "skipNodeOperations", .type = .string, .repeated = true },
} };

pub const resource_v1_DeviceSelector: Message = .{ .fields = &.{
    .{ .number = 1, .json = "cel", .type = .message, .message = &resource_v1_CELDeviceSelector, .omit_zero = false },
} };

pub const resource_v1_DeviceSubRequest: Message = .{ .fields = &.{
    .{ .number = 1, .json = "name", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "deviceClassName", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "selectors", .type = .message, .message = &resource_v1_DeviceSelector, .repeated = true },
    .{ .number = 4, .json = "allocationMode", .type = .string },
    .{ .number = 5, .json = "count", .type = .int64 },
    .{ .number = 6, .json = "tolerations", .type = .message, .message = &resource_v1_DeviceToleration, .repeated = true },
    .{ .number = 7, .json = "capacity", .type = .message, .message = &resource_v1_CapacityRequirements, .omit_zero = false },
    .{ .number = 8, .json = "derivedAttributes", .type = .message, .message = &resource_v1_DeviceDerivedAttribute, .repeated = true },
} };

pub const resource_v1_DeviceToleration: Message = .{ .fields = &.{
    .{ .number = 1, .json = "key", .type = .string },
    .{ .number = 2, .json = "operator", .type = .string },
    .{ .number = 3, .json = "value", .type = .string },
    .{ .number = 4, .json = "effect", .type = .string },
    .{ .number = 5, .json = "tolerationSeconds", .type = .int64, .omit_zero = false },
} };

pub const resource_v1_ExactDeviceRequest: Message = .{ .fields = &.{
    .{ .number = 1, .json = "deviceClassName", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "selectors", .type = .message, .message = &resource_v1_DeviceSelector, .repeated = true },
    .{ .number = 3, .json = "allocationMode", .type = .string },
    .{ .number = 4, .json = "count", .type = .int64 },
    .{ .number = 5, .json = "adminAccess", .type = .bool, .omit_zero = false },
    .{ .number = 6, .json = "tolerations", .type = .message, .message = &resource_v1_DeviceToleration, .repeated = true },
    .{ .number = 7, .json = "capacity", .type = .message, .message = &resource_v1_CapacityRequirements, .omit_zero = false },
    .{ .number = 8, .json = "derivedAttributes", .type = .message, .message = &resource_v1_DeviceDerivedAttribute, .repeated = true },
} };

pub const resource_v1_NetworkDeviceData: Message = .{ .fields = &.{
    .{ .number = 1, .json = "interfaceName", .type = .string },
    .{ .number = 2, .json = "ips", .type = .string, .repeated = true },
    .{ .number = 3, .json = "hardwareAddress", .type = .string },
} };

pub const resource_v1_OpaqueDeviceConfiguration: Message = .{ .fields = &.{
    .{ .number = 1, .json = "driver", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "parameters", .type = .raw_json, .omit_zero = false },
} };

pub const resource_v1_ResourceClaim: Message = .{ .fields = &.{
    .{ .number = 1, .json = "metadata", .type = .message, .message = &meta_v1_ObjectMeta, .omit_zero = false },
    .{ .number = 2, .json = "spec", .type = .message, .message = &resource_v1_ResourceClaimSpec, .omit_zero = false },
    .{ .number = 3, .json = "status", .type = .message, .message = &resource_v1_ResourceClaimStatus, .omit_zero = false },
} };

pub const resource_v1_ResourceClaimConsumerReference: Message = .{ .fields = &.{
    .{ .number = 1, .json = "apiGroup", .type = .string },
    .{ .number = 3, .json = "resource", .type = .string, .omit_zero = false },
    .{ .number = 4, .json = "name", .type = .string, .omit_zero = false },
    .{ .number = 5, .json = "uid", .type = .string, .omit_zero = false },
} };

pub const resource_v1_ResourceClaimSpec: Message = .{ .fields = &.{
    .{ .number = 1, .json = "devices", .type = .message, .message = &resource_v1_DeviceClaim, .omit_zero = false },
} };

pub const resource_v1_ResourceClaimStatus: Message = .{ .fields = &.{
    .{ .number = 1, .json = "allocation", .type = .message, .message = &resource_v1_AllocationResult, .omit_zero = false },
    .{ .number = 2, .json = "reservedFor", .type = .message, .message = &resource_v1_ResourceClaimConsumerReference, .repeated = true },
    .{ .number = 4, .json = "devices", .type = .message, .message = &resource_v1_AllocatedDeviceStatus, .repeated = true },
} };

pub const scheduling_v1_PriorityClass: Message = .{ .fields = &.{
    .{ .number = 1, .json = "metadata", .type = .message, .message = &meta_v1_ObjectMeta, .omit_zero = false },
    .{ .number = 2, .json = "value", .type = .int32, .omit_zero = false },
    .{ .number = 3, .json = "globalDefault", .type = .bool },
    .{ .number = 4, .json = "description", .type = .string },
    .{ .number = 5, .json = "preemptionPolicy", .type = .string, .omit_zero = false },
} };

pub const scheduling_v1alpha3_TopologyConstraint: Message = .{ .fields = &.{
    .{ .number = 1, .json = "key", .type = .string, .omit_zero = false },
} };

pub const scheduling_v1alpha3_WorkloadPodGroupAllDisruptionMode: Message = .{ .fields = &.{} };

pub const scheduling_v1alpha3_WorkloadPodGroupBasicSchedulingPolicy: Message = .{ .fields = &.{} };

pub const scheduling_v1alpha3_WorkloadPodGroupDisruptionMode: Message = .{ .fields = &.{
    .{ .number = 1, .json = "single", .type = .message, .message = &scheduling_v1alpha3_WorkloadPodGroupSingleDisruptionMode, .omit_zero = false },
    .{ .number = 2, .json = "all", .type = .message, .message = &scheduling_v1alpha3_WorkloadPodGroupAllDisruptionMode, .omit_zero = false },
} };

pub const scheduling_v1alpha3_WorkloadPodGroupGangSchedulingPolicy: Message = .{ .fields = &.{
    .{ .number = 1, .json = "minCount", .type = .int32, .omit_zero = false },
} };

pub const scheduling_v1alpha3_WorkloadPodGroupResourceClaim: Message = .{ .fields = &.{
    .{ .number = 1, .json = "name", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "resourceClaimName", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "resourceClaimTemplateName", .type = .string, .omit_zero = false },
} };

pub const scheduling_v1alpha3_WorkloadPodGroupSchedulingConstraints: Message = .{ .fields = &.{
    .{ .number = 1, .json = "topology", .type = .message, .message = &scheduling_v1alpha3_TopologyConstraint, .repeated = true },
} };

pub const scheduling_v1alpha3_WorkloadPodGroupSchedulingPolicy: Message = .{ .fields = &.{
    .{ .number = 1, .json = "basic", .type = .message, .message = &scheduling_v1alpha3_WorkloadPodGroupBasicSchedulingPolicy, .omit_zero = false },
    .{ .number = 2, .json = "gang", .type = .message, .message = &scheduling_v1alpha3_WorkloadPodGroupGangSchedulingPolicy, .omit_zero = false },
} };

pub const scheduling_v1alpha3_WorkloadPodGroupSingleDisruptionMode: Message = .{ .fields = &.{} };

pub const storage_v1_CSIDriver: Message = .{ .fields = &.{
    .{ .number = 1, .json = "metadata", .type = .message, .message = &meta_v1_ObjectMeta, .omit_zero = false },
    .{ .number = 2, .json = "spec", .type = .message, .message = &storage_v1_CSIDriverSpec, .omit_zero = false },
} };

pub const storage_v1_CSIDriverSpec: Message = .{ .fields = &.{
    .{ .number = 1, .json = "attachRequired", .type = .bool, .omit_zero = false },
    .{ .number = 2, .json = "podInfoOnMount", .type = .bool, .omit_zero = false },
    .{ .number = 3, .json = "volumeLifecycleModes", .type = .string, .repeated = true },
    .{ .number = 4, .json = "storageCapacity", .type = .bool, .omit_zero = false },
    .{ .number = 5, .json = "fsGroupPolicy", .type = .string, .omit_zero = false },
    .{ .number = 6, .json = "tokenRequests", .type = .message, .message = &storage_v1_TokenRequest, .repeated = true },
    .{ .number = 7, .json = "requiresRepublish", .type = .bool, .omit_zero = false },
    .{ .number = 8, .json = "seLinuxMount", .type = .bool, .omit_zero = false },
    .{ .number = 9, .json = "nodeAllocatableUpdatePeriodSeconds", .type = .int64, .omit_zero = false },
    .{ .number = 10, .json = "serviceAccountTokenInSecrets", .type = .bool, .omit_zero = false },
    .{ .number = 11, .json = "preventPodSchedulingIfMissing", .type = .bool, .omit_zero = false },
} };

pub const storage_v1_StorageClass: Message = .{ .fields = &.{
    .{ .number = 1, .json = "metadata", .type = .message, .message = &meta_v1_ObjectMeta, .omit_zero = false },
    .{ .number = 2, .json = "provisioner", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "parameters", .type = .string, .map = true },
    .{ .number = 4, .json = "reclaimPolicy", .type = .string, .omit_zero = false },
    .{ .number = 5, .json = "mountOptions", .type = .string, .repeated = true },
    .{ .number = 6, .json = "allowVolumeExpansion", .type = .bool, .omit_zero = false },
    .{ .number = 7, .json = "volumeBindingMode", .type = .string, .omit_zero = false },
    .{ .number = 8, .json = "allowedTopologies", .type = .message, .message = &core_v1_TopologySelectorTerm, .repeated = true },
} };

pub const storage_v1_TokenRequest: Message = .{ .fields = &.{
    .{ .number = 1, .json = "audience", .type = .string, .omit_zero = false },
    .{ .number = 2, .json = "expirationSeconds", .type = .int64, .omit_zero = false },
} };

pub const storage_v1_VolumeAttributesClass: Message = .{ .fields = &.{
    .{ .number = 1, .json = "metadata", .type = .message, .message = &meta_v1_ObjectMeta, .omit_zero = false },
    .{ .number = 2, .json = "driverName", .type = .string, .omit_zero = false },
    .{ .number = 3, .json = "parameters", .type = .string, .map = true },
} };

pub const storagemigration_v1_StorageVersionMigration: Message = .{ .fields = &.{
    .{ .number = 1, .json = "metadata", .type = .message, .message = &meta_v1_ObjectMeta, .omit_zero = false },
    .{ .number = 2, .json = "spec", .type = .message, .message = &storagemigration_v1_StorageVersionMigrationSpec, .omit_zero = false },
    .{ .number = 3, .json = "status", .type = .message, .message = &storagemigration_v1_StorageVersionMigrationStatus, .omit_zero = false },
} };

pub const storagemigration_v1_StorageVersionMigrationSpec: Message = .{ .fields = &.{
    .{ .number = 1, .json = "resource", .type = .message, .message = &meta_v1_GroupResource, .omit_zero = false },
} };

pub const storagemigration_v1_StorageVersionMigrationStatus: Message = .{ .fields = &.{
    .{ .number = 1, .json = "conditions", .type = .message, .message = &meta_v1_Condition, .repeated = true },
    .{ .number = 2, .json = "resourceVersion", .type = .string },
} };
