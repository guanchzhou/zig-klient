const std = @import("std");

/// Common metadata for all Kubernetes resources
pub const ObjectMeta = struct {
    name: []const u8,
    namespace: ?[]const u8 = null,
    labels: ?std.json.Value = null,
    annotations: ?std.json.Value = null,
    resourceVersion: ?[]const u8 = null,
    uid: ?[]const u8 = null,
    creationTimestamp: ?[]const u8 = null,
    deletionTimestamp: ?[]const u8 = null,
    generation: ?i64 = null,
};

/// Generic Kubernetes resource wrapper
pub fn Resource(comptime T: type) type {
    return struct {
        apiVersion: []const u8,
        kind: []const u8,
        metadata: ObjectMeta,
        spec: ?T = null,
        status: ?std.json.Value = null,
    };
}

/// List response wrapper for collections
pub fn List(comptime T: type) type {
    return struct {
        apiVersion: []const u8,
        kind: []const u8,
        items: []T,
        metadata: struct {
            resourceVersion: ?[]const u8 = null,
            continue_: ?[]const u8 = null,
        },
    };
}

/// Pod specification
pub const PodSpec = struct {
    containers: []Container,
    restartPolicy: ?[]const u8 = null,
    nodeName: ?[]const u8 = null,
    serviceAccountName: ?[]const u8 = null,
    volumes: ?[]Volume = null,
};

pub const Container = struct {
    name: []const u8,
    image: []const u8,
    command: ?[][]const u8 = null,
    args: ?[][]const u8 = null,
    ports: ?[]ContainerPort = null,
    env: ?[]EnvVar = null,
    volumeMounts: ?[]VolumeMount = null,
    resources: ?ResourceRequirements = null,
};

pub const ContainerPort = struct {
    name: ?[]const u8 = null,
    containerPort: i32,
    protocol: ?[]const u8 = null,
};

pub const EnvVar = struct {
    name: []const u8,
    value: ?[]const u8 = null,
    valueFrom: ?EnvVarSource = null,
};

pub const EnvVarSource = struct {
    configMapKeyRef: ?ConfigMapKeySelector = null,
    secretKeyRef: ?SecretKeySelector = null,
};

pub const ConfigMapKeySelector = struct {
    name: []const u8,
    key: []const u8,
};

pub const SecretKeySelector = struct {
    name: []const u8,
    key: []const u8,
};

pub const VolumeMount = struct {
    name: []const u8,
    mountPath: []const u8,
    readOnly: ?bool = null,
};

pub const Volume = struct {
    name: []const u8,
    configMap: ?ConfigMapVolumeSource = null,
    secret: ?SecretVolumeSource = null,
    emptyDir: ?std.json.Value = null,
};

pub const ConfigMapVolumeSource = struct {
    name: []const u8,
};

pub const SecretVolumeSource = struct {
    secretName: []const u8,
};

pub const ResourceRequirements = struct {
    limits: ?std.json.Value = null,
    requests: ?std.json.Value = null,
};

pub const PodStatus = struct {
    phase: ?[]const u8 = null,
    podIP: ?[]const u8 = null,
    hostIP: ?[]const u8 = null,
    containerStatuses: ?[]ContainerStatus = null,
};

pub const ContainerStatus = struct {
    name: []const u8,
    ready: bool,
    restartCount: i32,
    state: ?std.json.Value = null,
};

/// Deployment specification
pub const DeploymentSpec = struct {
    replicas: ?i32 = null,
    selector: LabelSelector,
    template: PodTemplateSpec,
    strategy: ?DeploymentStrategy = null,
};

pub const LabelSelector = struct {
    matchLabels: ?std.json.Value = null,
    matchExpressions: ?[]LabelSelectorRequirement = null,
};

pub const LabelSelectorRequirement = struct {
    key: []const u8,
    operator: []const u8,
    values: ?[][]const u8 = null,
};

pub const PodTemplateSpec = struct {
    metadata: ?ObjectMeta = null,
    spec: PodSpec,
};

pub const DeploymentStrategy = struct {
    type_: []const u8,
    rollingUpdate: ?RollingUpdateDeployment = null,
};

pub const RollingUpdateDeployment = struct {
    maxUnavailable: ?i32 = null,
    maxSurge: ?i32 = null,
};

/// Service specification
pub const ServiceSpec = struct {
    selector: ?std.json.Value = null,
    ports: []ServicePort,
    type_: ?[]const u8 = null,
    clusterIP: ?[]const u8 = null,
    externalIPs: ?[][]const u8 = null,
};

pub const ServicePort = struct {
    name: ?[]const u8 = null,
    protocol: ?[]const u8 = null,
    port: i32,
    targetPort: ?i32 = null,
    nodePort: ?i32 = null,
};

/// ConfigMap data
pub const ConfigMapData = struct {
    data: ?std.json.Value = null,
    binaryData: ?std.json.Value = null,
};

/// Secret data
pub const SecretData = struct {
    data: ?std.json.Value = null,
    stringData: ?std.json.Value = null,
    type_: ?[]const u8 = null,
};

/// Namespace specification
pub const NamespaceSpec = struct {
    finalizers: ?[][]const u8 = null,
};

/// Node specification
pub const NodeSpec = struct {
    podCIDR: ?[]const u8 = null,
    providerID: ?[]const u8 = null,
    unschedulable: ?bool = null,
};

/// ReplicaSet specification
pub const ReplicaSetSpec = struct {
    replicas: ?i32 = null,
    selector: LabelSelector,
    template: PodTemplateSpec,
};

/// StatefulSet specification
pub const StatefulSetSpec = struct {
    replicas: ?i32 = null,
    selector: LabelSelector,
    template: PodTemplateSpec,
    serviceName: []const u8,
    volumeClaimTemplates: ?[]std.json.Value = null,
    updateStrategy: ?StatefulSetUpdateStrategy = null,
};

pub const StatefulSetUpdateStrategy = struct {
    type_: []const u8, // RollingUpdate or OnDelete
    rollingUpdate: ?RollingUpdateStatefulSetStrategy = null,
};

pub const RollingUpdateStatefulSetStrategy = struct {
    partition: ?i32 = null,
    maxUnavailable: ?i32 = null,
};

/// DaemonSet specification
pub const DaemonSetSpec = struct {
    selector: LabelSelector,
    template: PodTemplateSpec,
    updateStrategy: ?DaemonSetUpdateStrategy = null,
};

pub const DaemonSetUpdateStrategy = struct {
    type_: []const u8, // RollingUpdate or OnDelete
    rollingUpdate: ?RollingUpdateDaemonSet = null,
};

pub const RollingUpdateDaemonSet = struct {
    maxUnavailable: ?i32 = null,
    maxSurge: ?i32 = null,
};

/// Job specification
pub const JobSpec = struct {
    template: PodTemplateSpec,
    completions: ?i32 = null,
    parallelism: ?i32 = null,
    backoffLimit: ?i32 = null,
    activeDeadlineSeconds: ?i64 = null,
    ttlSecondsAfterFinished: ?i32 = null,
};

/// CronJob specification
pub const CronJobSpec = struct {
    schedule: []const u8,
    jobTemplate: JobTemplateSpec,
    concurrencyPolicy: ?[]const u8 = null,
    suspended: ?bool = null,
    successfulJobsHistoryLimit: ?i32 = null,
    failedJobsHistoryLimit: ?i32 = null,
};

pub const JobTemplateSpec = struct {
    metadata: ?ObjectMeta = null,
    spec: JobSpec,
};

/// PersistentVolume specification
pub const PersistentVolumeSpec = struct {
    capacity: ?std.json.Value = null,
    accessModes: ?[][]const u8 = null,
    persistentVolumeReclaimPolicy: ?[]const u8 = null,
    storageClassName: ?[]const u8 = null,
    mountOptions: ?[][]const u8 = null,
};

/// PersistentVolumeClaim specification
pub const PersistentVolumeClaimSpec = struct {
    accessModes: ?[][]const u8 = null,
    resources: ?ResourceRequirements = null,
    volumeName: ?[]const u8 = null,
    storageClassName: ?[]const u8 = null,
};

/// Type aliases for common resources
pub const Pod = Resource(PodSpec);
pub const Deployment = Resource(DeploymentSpec);
pub const ReplicaSet = Resource(ReplicaSetSpec);
pub const StatefulSet = Resource(StatefulSetSpec);
pub const DaemonSet = Resource(DaemonSetSpec);
pub const Job = Resource(JobSpec);
pub const CronJob = Resource(CronJobSpec);
pub const Service = Resource(ServiceSpec);
pub const ConfigMap = Resource(ConfigMapData);
pub const Secret = Resource(SecretData);
pub const Namespace = Resource(NamespaceSpec);
pub const Node = Resource(NodeSpec);
pub const PersistentVolume = Resource(PersistentVolumeSpec);
pub const PersistentVolumeClaim = Resource(PersistentVolumeClaimSpec);

/// API error from Kubernetes
pub const ApiError = struct {
    kind: []const u8 = "Status",
    apiVersion: []const u8 = "v1",
    metadata: std.json.Value = .null,
    status: []const u8,
    message: ?[]const u8 = null,
    reason: ?[]const u8 = null,
    code: ?i32 = null,
    details: ?std.json.Value = null,
};

/// Watch event types
pub const WatchEvent = struct {
    type_: []const u8, // ADDED, MODIFIED, DELETED, ERROR
    object: std.json.Value,
};
