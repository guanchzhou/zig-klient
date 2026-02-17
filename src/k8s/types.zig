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
    managedBy: ?[]const u8 = null, // K8s 1.35 GA: external controller (e.g., Kueue)
    podReplacementPolicy: ?[]const u8 = null, // K8s 1.34 GA: Failed or TerminatingOrFailed
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

/// IPAddress specification
pub const IPAddressSpec = struct {
    parentRef: std.json.Value,
};

/// ServiceCIDR specification
pub const ServiceCIDRSpec = struct {
    cidrs: ?[][]const u8 = null,
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

/// ValidatingWebhookConfiguration specification
pub const ValidatingWebhookConfigurationSpec = struct {
    webhooks: ?[]std.json.Value = null,
};

/// MutatingWebhookConfiguration specification
pub const MutatingWebhookConfigurationSpec = struct {
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

/// ValidatingAdmissionPolicyBinding specification
pub const ValidatingAdmissionPolicyBindingSpec = struct {
    policyName: []const u8,
    paramRef: ?std.json.Value = null,
    matchResources: ?std.json.Value = null,
    validationActions: ?[][]const u8 = null,
};

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

/// FlowSchema specification
pub const FlowSchemaSpec = struct {
    priorityLevelConfiguration: std.json.Value,
    matchingPrecedence: ?i32 = null,
    distinguisherMethod: ?std.json.Value = null,
    rules: ?[]std.json.Value = null,
};

/// PriorityLevelConfiguration specification
pub const PriorityLevelConfigurationSpec = struct {
    type: []const u8,
    limited: ?std.json.Value = null,
    exempt: ?std.json.Value = null,
};

/// RuntimeClass specification
pub const RuntimeClassSpec = struct {
    handler: []const u8,
    overhead: ?std.json.Value = null,
    scheduling: ?std.json.Value = null,
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

/// IPAddress (IP address allocation)
pub const IPAddress = Resource(IPAddressSpec);

/// ServiceCIDR (service CIDR management)
pub const ServiceCIDR = Resource(ServiceCIDRSpec);

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

/// CertificateSigningRequest (certificate signing) - cluster-scoped
pub const CertificateSigningRequest = Resource(CertificateSigningRequestSpec);

/// ValidatingWebhookConfiguration (admission validation webhook) - cluster-scoped
pub const ValidatingWebhookConfiguration = struct {
    apiVersion: ?[]const u8 = null,
    kind: ?[]const u8 = null,
    metadata: ObjectMeta,
    webhooks: ?[]std.json.Value = null,
};

/// MutatingWebhookConfiguration (admission mutation webhook) - cluster-scoped
pub const MutatingWebhookConfiguration = struct {
    apiVersion: ?[]const u8 = null,
    kind: ?[]const u8 = null,
    metadata: ObjectMeta,
    webhooks: ?[]std.json.Value = null,
};

/// ValidatingAdmissionPolicy (admission policy) - cluster-scoped
pub const ValidatingAdmissionPolicy = Resource(ValidatingAdmissionPolicySpec);

/// ValidatingAdmissionPolicyBinding (admission policy binding) - cluster-scoped
pub const ValidatingAdmissionPolicyBinding = Resource(ValidatingAdmissionPolicyBindingSpec);

/// APIService (API service registration) - cluster-scoped
pub const APIService = struct {
    apiVersion: ?[]const u8 = null,
    kind: ?[]const u8 = null,
    metadata: ObjectMeta,
    spec: APIServiceSpec,
};

/// FlowSchema (API flow control) - cluster-scoped
pub const FlowSchema = Resource(FlowSchemaSpec);

/// PriorityLevelConfiguration (API priority level) - cluster-scoped
pub const PriorityLevelConfiguration = Resource(PriorityLevelConfigurationSpec);

/// RuntimeClass (container runtime) - cluster-scoped
pub const RuntimeClass = struct {
    apiVersion: ?[]const u8 = null,
    kind: ?[]const u8 = null,
    metadata: ObjectMeta,
    handler: []const u8,
    overhead: ?std.json.Value = null,
    scheduling: ?std.json.Value = null,
};

/// GatewayClass specification (gateway.networking.k8s.io/v1)
pub const GatewayClassSpec = struct {
    controllerName: []const u8,
    description: ?[]const u8 = null,
    parametersRef: ?std.json.Value = null,
};

/// Gateway specification (gateway.networking.k8s.io/v1)
pub const GatewaySpec = struct {
    gatewayClassName: []const u8,
    listeners: []std.json.Value,
    addresses: ?[]std.json.Value = null,
};

/// HTTPRoute specification (gateway.networking.k8s.io/v1)
pub const HTTPRouteSpec = struct {
    parentRefs: ?[]std.json.Value = null,
    hostnames: ?[][]const u8 = null,
    rules: ?[]std.json.Value = null,
};

/// GRPCRoute specification (gateway.networking.k8s.io/v1)
pub const GRPCRouteSpec = struct {
    parentRefs: ?[]std.json.Value = null,
    hostnames: ?[][]const u8 = null,
    rules: ?[]std.json.Value = null,
};

/// ReferenceGrant specification (gateway.networking.k8s.io/v1beta1)
pub const ReferenceGrantSpec = struct {
    from: []std.json.Value,
    to: []std.json.Value,
};

/// ResourceClaim specification (resource.k8s.io/v1)
pub const ResourceClaimSpec = struct {
    devices: ?std.json.Value = null,
};

/// ResourceClaimTemplate specification (resource.k8s.io/v1)
pub const ResourceClaimTemplateSpec = struct {
    spec: std.json.Value,
};

/// ResourceSlice specification (resource.k8s.io/v1)
pub const ResourceSliceSpec = struct {
    driver: []const u8,
    nodeName: ?[]const u8 = null,
    pool: ?std.json.Value = null,
    devices: ?[]std.json.Value = null,
};

/// DeviceClass specification (resource.k8s.io/v1)
pub const DeviceClassSpec = struct {
    selectors: ?[]std.json.Value = null,
    config: ?[]std.json.Value = null,
    suitableNodes: ?std.json.Value = null,
};

/// VolumeAttributesClass (storage.k8s.io/v1) - no spec, top-level fields
pub const VolumeAttributesClass = struct {
    apiVersion: ?[]const u8 = null,
    kind: ?[]const u8 = null,
    metadata: ObjectMeta,
    driverName: []const u8,
    parameters: ?std.json.Value = null,
};

/// Gateway API resources (gateway.networking.k8s.io/v1)
pub const GatewayClass = Resource(GatewayClassSpec);
pub const Gateway = Resource(GatewaySpec);
pub const HTTPRoute = Resource(HTTPRouteSpec);
pub const GRPCRoute = Resource(GRPCRouteSpec);
pub const ReferenceGrant = Resource(ReferenceGrantSpec);

/// Dynamic Resource Allocation resources (resource.k8s.io/v1)
pub const ResourceClaim = Resource(ResourceClaimSpec);
pub const ResourceClaimTemplate = Resource(ResourceClaimTemplateSpec);
pub const ResourceSlice = Resource(ResourceSliceSpec);
pub const DeviceClass = Resource(DeviceClassSpec);

/// StorageVersionMigration specification (storagemigration.k8s.io/v1beta1) - K8s 1.35
pub const StorageVersionMigrationSpec = struct {
    resource: std.json.Value,
};

/// StorageVersionMigration (cluster-scoped)
pub const StorageVersionMigration = Resource(StorageVersionMigrationSpec);

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
