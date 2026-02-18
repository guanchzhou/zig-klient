const std = @import("std");

// Sub-modules
pub const meta = @import("types/meta.zig");
pub const core = @import("types/core.zig");
pub const apps = @import("types/apps.zig");
pub const batch = @import("types/batch.zig");
pub const networking = @import("types/networking.zig");
pub const storage = @import("types/storage.zig");
pub const rbac = @import("types/rbac.zig");
pub const policy = @import("types/policy.zig");
pub const cluster = @import("types/cluster.zig");
pub const gateway = @import("types/gateway.zig");
pub const api_error = @import("types/api_error.zig");

// Re-export all types at top level for backward compatibility
// (types.Pod, types.Deployment, etc. all still work)

// === meta.zig ===
pub const ObjectMeta = meta.ObjectMeta;
pub const Resource = meta.Resource;
pub const List = meta.List;

// === core.zig ===
pub const PodSpec = core.PodSpec;
pub const Container = core.Container;
pub const ContainerPort = core.ContainerPort;
pub const EnvVar = core.EnvVar;
pub const EnvVarSource = core.EnvVarSource;
pub const ConfigMapKeySelector = core.ConfigMapKeySelector;
pub const SecretKeySelector = core.SecretKeySelector;
pub const VolumeMount = core.VolumeMount;
pub const Volume = core.Volume;
pub const ConfigMapVolumeSource = core.ConfigMapVolumeSource;
pub const SecretVolumeSource = core.SecretVolumeSource;
pub const ResourceRequirements = core.ResourceRequirements;
pub const PodStatus = core.PodStatus;
pub const ContainerStatus = core.ContainerStatus;
pub const Pod = core.Pod;
pub const ServiceSpec = core.ServiceSpec;
pub const ServicePort = core.ServicePort;
pub const Service = core.Service;
pub const ConfigMapData = core.ConfigMapData;
pub const ConfigMap = core.ConfigMap;
pub const SecretData = core.SecretData;
pub const Secret = core.Secret;
pub const NamespaceSpec = core.NamespaceSpec;
pub const Namespace = core.Namespace;
pub const NodeSpec = core.NodeSpec;
pub const Node = core.Node;
pub const ServiceAccount = core.ServiceAccount;
pub const EndpointsSpec = core.EndpointsSpec;
pub const Endpoints = core.Endpoints;
pub const EventSpec = core.EventSpec;
pub const Event = core.Event;
pub const ResourceQuotaSpec = core.ResourceQuotaSpec;
pub const ResourceQuota = core.ResourceQuota;
pub const LimitRangeSpec = core.LimitRangeSpec;
pub const LimitRange = core.LimitRange;
pub const ReplicationControllerSpec = core.ReplicationControllerSpec;
pub const ReplicationController = core.ReplicationController;
pub const PodTemplateResourceSpec = core.PodTemplateResourceSpec;
pub const PodTemplate = core.PodTemplate;
pub const BindingSpec = core.BindingSpec;
pub const Binding = core.Binding;
pub const ComponentStatusSpec = core.ComponentStatusSpec;
pub const ComponentStatus = core.ComponentStatus;

// === apps.zig ===
pub const DeploymentSpec = apps.DeploymentSpec;
pub const LabelSelector = apps.LabelSelector;
pub const LabelSelectorRequirement = apps.LabelSelectorRequirement;
pub const PodTemplateSpec = apps.PodTemplateSpec;
pub const DeploymentStrategy = apps.DeploymentStrategy;
pub const RollingUpdateDeployment = apps.RollingUpdateDeployment;
pub const Deployment = apps.Deployment;
pub const ReplicaSetSpec = apps.ReplicaSetSpec;
pub const ReplicaSet = apps.ReplicaSet;
pub const StatefulSetSpec = apps.StatefulSetSpec;
pub const StatefulSetUpdateStrategy = apps.StatefulSetUpdateStrategy;
pub const RollingUpdateStatefulSetStrategy = apps.RollingUpdateStatefulSetStrategy;
pub const StatefulSet = apps.StatefulSet;
pub const DaemonSetSpec = apps.DaemonSetSpec;
pub const DaemonSetUpdateStrategy = apps.DaemonSetUpdateStrategy;
pub const RollingUpdateDaemonSet = apps.RollingUpdateDaemonSet;
pub const DaemonSet = apps.DaemonSet;
pub const ControllerRevisionSpec = apps.ControllerRevisionSpec;
pub const ControllerRevision = apps.ControllerRevision;

// === batch.zig ===
pub const JobSpec = batch.JobSpec;
pub const Job = batch.Job;
pub const CronJobSpec = batch.CronJobSpec;
pub const CronJob = batch.CronJob;
pub const JobTemplateSpec = batch.JobTemplateSpec;

// === networking.zig ===
pub const IngressSpec = networking.IngressSpec;
pub const Ingress = networking.Ingress;
pub const NetworkPolicySpec = networking.NetworkPolicySpec;
pub const NetworkPolicy = networking.NetworkPolicy;
pub const IPAddressSpec = networking.IPAddressSpec;
pub const IPAddress = networking.IPAddress;
pub const ServiceCIDRSpec = networking.ServiceCIDRSpec;
pub const ServiceCIDR = networking.ServiceCIDR;
pub const IngressClassSpec = networking.IngressClassSpec;
pub const IngressClass = networking.IngressClass;
pub const EndpointSliceSpec = networking.EndpointSliceSpec;
pub const EndpointSlice = networking.EndpointSlice;

// === storage.zig ===
pub const PersistentVolumeSpec = storage.PersistentVolumeSpec;
pub const PersistentVolume = storage.PersistentVolume;
pub const PersistentVolumeClaimSpec = storage.PersistentVolumeClaimSpec;
pub const PersistentVolumeClaim = storage.PersistentVolumeClaim;
pub const StorageClassSpec = storage.StorageClassSpec;
pub const StorageClass = storage.StorageClass;
pub const VolumeAttachmentSpec = storage.VolumeAttachmentSpec;
pub const VolumeAttachment = storage.VolumeAttachment;
pub const CSIDriverSpec = storage.CSIDriverSpec;
pub const CSIDriver = storage.CSIDriver;
pub const CSINodeSpec = storage.CSINodeSpec;
pub const CSINode = storage.CSINode;
pub const CSIStorageCapacitySpec = storage.CSIStorageCapacitySpec;
pub const CSIStorageCapacity = storage.CSIStorageCapacity;
pub const VolumeAttributesClass = storage.VolumeAttributesClass;

// === rbac.zig ===
pub const PolicyRule = rbac.PolicyRule;
pub const RoleRef = rbac.RoleRef;
pub const Subject = rbac.Subject;
pub const Role = rbac.Role;
pub const RoleBinding = rbac.RoleBinding;
pub const ClusterRole = rbac.ClusterRole;
pub const ClusterRoleBinding = rbac.ClusterRoleBinding;

// === policy.zig ===
pub const HorizontalPodAutoscalerSpec = policy.HorizontalPodAutoscalerSpec;
pub const HorizontalPodAutoscaler = policy.HorizontalPodAutoscaler;
pub const PodDisruptionBudgetSpec = policy.PodDisruptionBudgetSpec;
pub const PodDisruptionBudget = policy.PodDisruptionBudget;
pub const LeaseSpec = policy.LeaseSpec;
pub const Lease = policy.Lease;
pub const PriorityClassSpec = policy.PriorityClassSpec;
pub const PriorityClass = policy.PriorityClass;

// === cluster.zig ===
pub const CertificateSigningRequestSpec = cluster.CertificateSigningRequestSpec;
pub const CertificateSigningRequest = cluster.CertificateSigningRequest;
pub const ValidatingWebhookConfigurationSpec = cluster.ValidatingWebhookConfigurationSpec;
pub const ValidatingWebhookConfiguration = cluster.ValidatingWebhookConfiguration;
pub const MutatingWebhookConfigurationSpec = cluster.MutatingWebhookConfigurationSpec;
pub const MutatingWebhookConfiguration = cluster.MutatingWebhookConfiguration;
pub const ValidatingAdmissionPolicySpec = cluster.ValidatingAdmissionPolicySpec;
pub const ValidatingAdmissionPolicy = cluster.ValidatingAdmissionPolicy;
pub const ValidatingAdmissionPolicyBindingSpec = cluster.ValidatingAdmissionPolicyBindingSpec;
pub const ValidatingAdmissionPolicyBinding = cluster.ValidatingAdmissionPolicyBinding;
pub const APIServiceSpec = cluster.APIServiceSpec;
pub const APIService = cluster.APIService;
pub const FlowSchemaSpec = cluster.FlowSchemaSpec;
pub const FlowSchema = cluster.FlowSchema;
pub const PriorityLevelConfigurationSpec = cluster.PriorityLevelConfigurationSpec;
pub const PriorityLevelConfiguration = cluster.PriorityLevelConfiguration;
pub const RuntimeClassSpec = cluster.RuntimeClassSpec;
pub const RuntimeClass = cluster.RuntimeClass;
pub const StorageVersionMigrationSpec = cluster.StorageVersionMigrationSpec;
pub const StorageVersionMigration = cluster.StorageVersionMigration;

// === gateway.zig ===
pub const GatewayClassSpec = gateway.GatewayClassSpec;
pub const GatewayClass = gateway.GatewayClass;
pub const GatewaySpec = gateway.GatewaySpec;
pub const Gateway = gateway.Gateway;
pub const HTTPRouteSpec = gateway.HTTPRouteSpec;
pub const HTTPRoute = gateway.HTTPRoute;
pub const GRPCRouteSpec = gateway.GRPCRouteSpec;
pub const GRPCRoute = gateway.GRPCRoute;
pub const ReferenceGrantSpec = gateway.ReferenceGrantSpec;
pub const ReferenceGrant = gateway.ReferenceGrant;
pub const ResourceClaimSpec = gateway.ResourceClaimSpec;
pub const ResourceClaim = gateway.ResourceClaim;
pub const ResourceClaimTemplateSpec = gateway.ResourceClaimTemplateSpec;
pub const ResourceClaimTemplate = gateway.ResourceClaimTemplate;
pub const ResourceSliceSpec = gateway.ResourceSliceSpec;
pub const ResourceSlice = gateway.ResourceSlice;
pub const DeviceClassSpec = gateway.DeviceClassSpec;
pub const DeviceClass = gateway.DeviceClass;

// === api_error.zig ===
pub const ApiError = api_error.ApiError;
pub const WatchEvent = api_error.WatchEvent;
