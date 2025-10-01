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

/// NetworkPolicy specification
pub const NetworkPolicySpec = struct {
    podSelector: ?std.json.Value = null,
    policyTypes: ?[][]const u8 = null,
    ingress: ?[]std.json.Value = null,
    egress: ?[]std.json.Value = null,
};

/// HorizontalPodAutoscaler specification
pub const HorizontalPodAutoscalerSpec = struct {
    scaleTargetRef: ?std.json.Value = null,
    minReplicas: ?i32 = null,
    maxReplicas: i32,
    metrics: ?[]std.json.Value = null,
    behavior: ?std.json.Value = null,
};

/// StorageClass specification
pub const StorageClassSpec = struct {
    provisioner: []const u8,
    parameters: ?std.json.Value = null,
    reclaimPolicy: ?[]const u8 = null,
    volumeBindingMode: ?[]const u8 = null,
    allowVolumeExpansion: ?bool = null,
    mountOptions: ?[][]const u8 = null,
    allowedTopologies: ?[]std.json.Value = null,
};

/// ResourceQuota specification
pub const ResourceQuotaSpec = struct {
    hard: ?std.json.Value = null,
    scopes: ?[][]const u8 = null,
    scopeSelector: ?std.json.Value = null,
};

/// LimitRange specification
pub const LimitRangeSpec = struct {
    limits: []std.json.Value,
};

/// PodDisruptionBudget specification
pub const PodDisruptionBudgetSpec = struct {
    minAvailable: ?std.json.Value = null,
    maxUnavailable: ?std.json.Value = null,
    selector: ?std.json.Value = null,
    unhealthyPodEvictionPolicy: ?[]const u8 = null,
};

/// IngressClass specification
pub const IngressClassSpec = struct {
    controller: []const u8,
    parameters: ?std.json.Value = null,
};

/// Endpoints specification
pub const EndpointsSpec = struct {
    subsets: ?[]std.json.Value = null,
};

/// EndpointSlice specification (for efficient service discovery)
pub const EndpointSliceSpec = struct {
    addressType: []const u8,
    endpoints: ?[]std.json.Value = null,
    ports: ?[]std.json.Value = null,
};

/// Event specification (cluster events)
pub const EventSpec = struct {
    action: ?[]const u8 = null,
    reason: ?[]const u8 = null,
    message: ?[]const u8 = null,
    type: ?[]const u8 = null,
    eventTime: ?[]const u8 = null,
    reportingController: ?[]const u8 = null,
    reportingInstance: ?[]const u8 = null,
    regarding: ?std.json.Value = null,
    related: ?std.json.Value = null,
};

/// ReplicationController specification (legacy controller)
pub const ReplicationControllerSpec = struct {
    replicas: ?i32 = null,
    selector: ?std.json.Value = null,
    template: ?std.json.Value = null,
    minReadySeconds: ?i32 = null,
};

/// PodTemplate resource specification
pub const PodTemplateResourceSpec = struct {
    template: ?std.json.Value = null,
};

/// ControllerRevision specification (for StatefulSet/DaemonSet history)
pub const ControllerRevisionSpec = struct {
    revision: i64,
    data: ?std.json.Value = null,
};

/// Lease specification (for leader election and coordination)
pub const LeaseSpec = struct {
    holderIdentity: ?[]const u8 = null,
    leaseDurationSeconds: ?i32 = null,
    acquireTime: ?[]const u8 = null,
    renewTime: ?[]const u8 = null,
    leaseTransitions: ?i32 = null,
};

/// PriorityClass specification (pod scheduling priority) - cluster-scoped
pub const PriorityClassSpec = struct {
    value: i32,
    globalDefault: ?bool = null,
    description: ?[]const u8 = null,
    preemptionPolicy: ?[]const u8 = null,
};

/// Binding specification (pod-to-node binding)
pub const BindingSpec = struct {
    target: std.json.Value,
};

/// ComponentStatus specification (cluster component health) - cluster-scoped
pub const ComponentStatusSpec = struct {
    conditions: ?[]std.json.Value = null,
};

/// VolumeAttachment specification (storage attachment)
pub const VolumeAttachmentSpec = struct {
    attacher: []const u8,
    source: std.json.Value,
    nodeName: []const u8,
};

/// CSIDriver specification (CSI driver info) - cluster-scoped
pub const CSIDriverSpec = struct {
    attachRequired: ?bool = null,
    podInfoOnMount: ?bool = null,
    volumeLifecycleModes: ?[][]const u8 = null,
    storageCapacity: ?bool = null,
    fsGroupPolicy: ?[]const u8 = null,
    tokenRequests: ?[]std.json.Value = null,
    requiresRepublish: ?bool = null,
    seLinuxMount: ?bool = null,
};

/// CSINode specification (CSI node info) - cluster-scoped
pub const CSINodeSpec = struct {
    drivers: []std.json.Value,
};

/// CSIStorageCapacity specification
pub const CSIStorageCapacitySpec = struct {
    storageClassName: []const u8,
    capacity: ?[]const u8 = null,
    maximumVolumeSize: ?[]const u8 = null,
    nodeTopology: ?std.json.Value = null,
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

/// NetworkPolicy (network security)
pub const NetworkPolicy = Resource(NetworkPolicySpec);

/// HorizontalPodAutoscaler (auto-scaling)
pub const HorizontalPodAutoscaler = Resource(HorizontalPodAutoscalerSpec);

/// StorageClass (storage configuration) - cluster-scoped
pub const StorageClass = struct {
    apiVersion: ?[]const u8 = null,
    kind: ?[]const u8 = null,
    metadata: ObjectMeta,
    provisioner: []const u8,
    parameters: ?std.json.Value = null,
    reclaimPolicy: ?[]const u8 = null,
    volumeBindingMode: ?[]const u8 = null,
    allowVolumeExpansion: ?bool = null,
    mountOptions: ?[][]const u8 = null,
    allowedTopologies: ?[]std.json.Value = null,
};

/// ResourceQuota (resource limits)
pub const ResourceQuota = Resource(ResourceQuotaSpec);

/// LimitRange (resource constraints)
pub const LimitRange = Resource(LimitRangeSpec);

/// PodDisruptionBudget (availability)
pub const PodDisruptionBudget = Resource(PodDisruptionBudgetSpec);

/// IngressClass (ingress controller configuration) - cluster-scoped
pub const IngressClass = struct {
    apiVersion: ?[]const u8 = null,
    kind: ?[]const u8 = null,
    metadata: ObjectMeta,
    controller: []const u8,
    parameters: ?std.json.Value = null,
};

/// Endpoints (service endpoints)
pub const Endpoints = Resource(EndpointsSpec);

/// EndpointSlice (efficient service discovery)
pub const EndpointSlice = Resource(EndpointSliceSpec);

/// Event (cluster events)
pub const Event = Resource(EventSpec);

/// ReplicationController (legacy pod controller)
pub const ReplicationController = Resource(ReplicationControllerSpec);

/// PodTemplate (reusable pod templates)
pub const PodTemplate = Resource(PodTemplateResourceSpec);

/// ControllerRevision (workload history)
pub const ControllerRevision = Resource(ControllerRevisionSpec);

/// Lease (leader election and coordination)
pub const Lease = Resource(LeaseSpec);

/// PriorityClass (pod scheduling priority) - cluster-scoped
pub const PriorityClass = struct {
    apiVersion: ?[]const u8 = null,
    kind: ?[]const u8 = null,
    metadata: ObjectMeta,
    value: i32,
    globalDefault: ?bool = null,
    description: ?[]const u8 = null,
    preemptionPolicy: ?[]const u8 = null,
};

/// Binding (pod-to-node binding)
pub const Binding = Resource(BindingSpec);

/// ComponentStatus (cluster component health) - cluster-scoped
pub const ComponentStatus = struct {
    apiVersion: ?[]const u8 = null,
    kind: ?[]const u8 = null,
    metadata: ObjectMeta,
    conditions: ?[]std.json.Value = null,
};

/// VolumeAttachment (storage attachment) - cluster-scoped
pub const VolumeAttachment = Resource(VolumeAttachmentSpec);

/// CSIDriver (CSI driver info) - cluster-scoped
pub const CSIDriver = struct {
    apiVersion: ?[]const u8 = null,
    kind: ?[]const u8 = null,
    metadata: ObjectMeta,
    spec: CSIDriverSpec,
};

/// CSINode (CSI node info) - cluster-scoped
pub const CSINode = struct {
    apiVersion: ?[]const u8 = null,
    kind: ?[]const u8 = null,
    metadata: ObjectMeta,
    spec: CSINodeSpec,
};

/// CSIStorageCapacity (CSI storage capacity)
pub const CSIStorageCapacity = Resource(CSIStorageCapacitySpec);

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
