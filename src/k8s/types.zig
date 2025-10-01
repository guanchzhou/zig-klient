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
        apiVersion: ?[]const u8 = null,
        kind: ?[]const u8 = null,
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
    containers: ?[]Container = null,
    restartPolicy: ?[]const u8 = null,
    nodeName: ?[]const u8 = null,
    serviceAccountName: ?[]const u8 = null,
    volumes: ?[]Volume = null,
};

pub const Container = struct {
    name: ?[]const u8 = null,
    image: ?[]const u8 = null,
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
    selector: ?std.json.Value = null,
    template: ?std.json.Value = null,
    strategy: ?std.json.Value = null,
};

pub const LabelSelector = struct {
    matchLabels: ?std.json.Value = null,
    matchExpressions: ?[]LabelSelectorRequirement = null,
};

pub const LabelSelectorRequirement = struct {
    key: ?[]const u8 = null,
    operator: ?[]const u8 = null,
    values: ?[][]const u8 = null,
};

pub const PodTemplateSpec = struct {
    metadata: ?ObjectMeta = null,
    spec: ?PodSpec = null,
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
    ports: ?[]ServicePort = null,
    type_: ?[]const u8 = null,
    clusterIP: ?[]const u8 = null,
    externalIPs: ?[][]const u8 = null,
};

pub const ServicePort = struct {
    name: ?[]const u8 = null,
    protocol: ?[]const u8 = null,
    port: ?std.json.Value = null,
    targetPort: ?std.json.Value = null,
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
    selector: ?std.json.Value = null,
    template: ?std.json.Value = null,
};

/// StatefulSet specification
pub const StatefulSetSpec = struct {
    replicas: ?i32 = null,
    selector: ?std.json.Value = null,
    template: ?std.json.Value = null,
    serviceName: ?[]const u8 = null,
    volumeClaimTemplates: ?[]std.json.Value = null,
    updateStrategy: ?std.json.Value = null,
};

pub const StatefulSetUpdateStrategy = struct {
    type_: ?[]const u8 = null, // RollingUpdate or OnDelete
    rollingUpdate: ?RollingUpdateStatefulSetStrategy = null,
};

pub const RollingUpdateStatefulSetStrategy = struct {
    partition: ?i32 = null,
    maxUnavailable: ?i32 = null,
};

/// DaemonSet specification
pub const DaemonSetSpec = struct {
    selector: ?std.json.Value = null,
    template: ?std.json.Value = null,
    updateStrategy: ?std.json.Value = null,
};

pub const DaemonSetUpdateStrategy = struct {
    type_: ?[]const u8 = null, // RollingUpdate or OnDelete
    rollingUpdate: ?RollingUpdateDaemonSet = null,
};

pub const RollingUpdateDaemonSet = struct {
    maxUnavailable: ?i32 = null,
    maxSurge: ?i32 = null,
};

/// Job specification
pub const JobSpec = struct {
    template: ?std.json.Value = null,
    completions: ?i32 = null,
    parallelism: ?i32 = null,
    backoffLimit: ?i32 = null,
    activeDeadlineSeconds: ?i64 = null,
    ttlSecondsAfterFinished: ?i32 = null,
};

/// CronJob specification
pub const CronJobSpec = struct {
    schedule: ?[]const u8 = null,
    jobTemplate: ?std.json.Value = null,
    concurrencyPolicy: ?[]const u8 = null,
    suspended: ?bool = null,
    successfulJobsHistoryLimit: ?i32 = null,
    failedJobsHistoryLimit: ?i32 = null,
};

pub const JobTemplateSpec = struct {
    metadata: ?ObjectMeta = null,
    spec: ?JobSpec = null,
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

/// Ingress specification
pub const IngressSpec = struct {
    ingressClassName: ?[]const u8 = null,
    defaultBackend: ?std.json.Value = null,
    tls: ?[]std.json.Value = null,
    rules: ?[]const std.json.Value = null,
};

/// RBAC: PolicyRule for Role and ClusterRole
pub const PolicyRule = struct {
    apiGroups: ?[][]const u8 = null,
    resources: ?[][]const u8 = null,
    verbs: [][]const u8,
    resourceNames: ?[][]const u8 = null,
    nonResourceURLs: ?[][]const u8 = null,
};

/// RBAC: RoleRef for RoleBinding and ClusterRoleBinding
pub const RoleRef = struct {
    apiGroup: []const u8,
    kind: []const u8,
    name: []const u8,
};

/// RBAC: Subject for RoleBinding and ClusterRoleBinding
pub const Subject = struct {
    kind: []const u8,
    name: []const u8,
    namespace: ?[]const u8 = null,
    apiGroup: ?[]const u8 = null,
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
pub const Secret = struct {
    apiVersion: ?[]const u8 = null,
    kind: ?[]const u8 = null,
    metadata: ObjectMeta,
    data: ?std.json.Value = null,
    stringData: ?std.json.Value = null,
    type: ?[]const u8 = null,
};
pub const Namespace = Resource(NamespaceSpec);
pub const Node = Resource(NodeSpec);
pub const PersistentVolume = Resource(PersistentVolumeSpec);
pub const PersistentVolumeClaim = Resource(PersistentVolumeClaimSpec);
pub const Ingress = Resource(IngressSpec);
pub const ServiceAccount = struct {
    apiVersion: ?[]const u8 = null,
    kind: ?[]const u8 = null,
    metadata: ObjectMeta,
    secrets: ?[]std.json.Value = null,
    imagePullSecrets: ?[]std.json.Value = null,
    automountServiceAccountToken: ?bool = null,
};

/// RBAC: Role (namespace-scoped)
pub const Role = struct {
    apiVersion: ?[]const u8 = null,
    kind: ?[]const u8 = null,
    metadata: ObjectMeta,
    rules: ?[]PolicyRule = null,
};

/// RBAC: RoleBinding (namespace-scoped)
pub const RoleBinding = struct {
    apiVersion: ?[]const u8 = null,
    kind: ?[]const u8 = null,
    metadata: ObjectMeta,
    subjects: ?[]Subject = null,
    roleRef: RoleRef,
};

/// RBAC: ClusterRole (cluster-scoped)
pub const ClusterRole = struct {
    apiVersion: ?[]const u8 = null,
    kind: ?[]const u8 = null,
    metadata: ObjectMeta,
    rules: ?[]PolicyRule = null,
    aggregationRule: ?std.json.Value = null,
};

/// RBAC: ClusterRoleBinding (cluster-scoped)
pub const ClusterRoleBinding = struct {
    apiVersion: ?[]const u8 = null,
    kind: ?[]const u8 = null,
    metadata: ObjectMeta,
    subjects: ?[]Subject = null,
    roleRef: RoleRef,
};

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
