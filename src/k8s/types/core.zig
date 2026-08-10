const std = @import("std");
const meta = @import("meta.zig");
const ObjectMeta = meta.ObjectMeta;
const Resource = meta.Resource;
const ResourceWithStatus = meta.ResourceWithStatus;

/// Pod specification
pub const PodSpec = struct {
    containers: ?[]Container = null,
    restartPolicy: ?[]const u8 = null,
    nodeName: ?[]const u8 = null,
    serviceAccountName: ?[]const u8 = null,
    volumes: ?[]Volume = null,
    /// Run the pod in a user namespace, mapping container UIDs/GIDs to a distinct
    /// host range. GA in K8s 1.36.
    hostUsers: ?bool = null,
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
    /// OCI image/artifact mounted as a read-only volume. Stable in K8s 1.36.
    image: ?ImageVolumeSource = null,
};

/// OCI image volume source (Volume.image). Stable in K8s 1.36.
pub const ImageVolumeSource = struct {
    /// Image or artifact reference, e.g. "registry.example.com/app:v1".
    reference: ?[]const u8 = null,
    /// "Always", "Never", or "IfNotPresent".
    pullPolicy: ?[]const u8 = null,
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

/// One entry of `status.podIPs` / `status.hostIPs`.
pub const PodIP = struct {
    ip: ?[]const u8 = null,
};

pub const PodCondition = struct {
    type: []const u8,
    status: []const u8,
    lastProbeTime: ?[]const u8 = null,
    lastTransitionTime: ?[]const u8 = null,
    reason: ?[]const u8 = null,
    message: ?[]const u8 = null,
};

pub const ContainerStateWaiting = struct {
    reason: ?[]const u8 = null,
    message: ?[]const u8 = null,
};

pub const ContainerStateRunning = struct {
    startedAt: ?[]const u8 = null,
};

pub const ContainerStateTerminated = struct {
    exitCode: i32,
    signal: ?i32 = null,
    reason: ?[]const u8 = null,
    message: ?[]const u8 = null,
    startedAt: ?[]const u8 = null,
    finishedAt: ?[]const u8 = null,
    containerID: ?[]const u8 = null,
};

/// Exactly one of the three is set. `waiting.reason` is what kubectl renders in
/// the STATUS column for a non-running container (CrashLoopBackOff, ImagePullBackOff, …).
pub const ContainerState = struct {
    waiting: ?ContainerStateWaiting = null,
    running: ?ContainerStateRunning = null,
    terminated: ?ContainerStateTerminated = null,
};

pub const ContainerStatus = struct {
    name: []const u8,
    ready: bool,
    restartCount: i32,
    image: ?[]const u8 = null,
    imageID: ?[]const u8 = null,
    containerID: ?[]const u8 = null,
    started: ?bool = null,
    state: ?ContainerState = null,
    lastState: ?ContainerState = null,
};

pub const PodStatus = struct {
    phase: ?[]const u8 = null,
    reason: ?[]const u8 = null,
    message: ?[]const u8 = null,
    podIP: ?[]const u8 = null,
    podIPs: ?[]PodIP = null,
    hostIP: ?[]const u8 = null,
    hostIPs: ?[]PodIP = null,
    startTime: ?[]const u8 = null,
    qosClass: ?[]const u8 = null,
    nominatedNodeName: ?[]const u8 = null,
    conditions: ?[]PodCondition = null,
    containerStatuses: ?[]ContainerStatus = null,
    initContainerStatuses: ?[]ContainerStatus = null,
    ephemeralContainerStatuses: ?[]ContainerStatus = null,
};

/// Pod type alias. Uses a typed status — see `meta.ResourceWithStatus` for why.
pub const Pod = ResourceWithStatus(PodSpec, PodStatus);

/// Service specification
pub const ServiceSpec = struct {
    selector: ?std.json.Value = null,
    ports: ?[]ServicePort = null,
    type: ?[]const u8 = null,
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

/// Service type alias
pub const Service = Resource(ServiceSpec);

/// ConfigMap (core/v1). Has no `spec` — `data`/`binaryData` are TOP-LEVEL,
/// like Secret. See the note on `Event`.
pub const ConfigMap = struct {
    apiVersion: ?[]const u8 = null,
    kind: ?[]const u8 = null,
    metadata: ObjectMeta,
    data: ?std.json.Value = null,
    binaryData: ?std.json.Value = null,
    immutable: ?bool = null,
};

/// Secret data
pub const SecretData = struct {
    data: ?std.json.Value = null,
    stringData: ?std.json.Value = null,
    type: ?[]const u8 = null,
};

/// Secret (custom struct)
pub const Secret = struct {
    apiVersion: ?[]const u8 = null,
    kind: ?[]const u8 = null,
    metadata: ObjectMeta,
    data: ?std.json.Value = null,
    stringData: ?std.json.Value = null,
    type: ?[]const u8 = null,
};

/// Namespace specification
pub const NamespaceSpec = struct {
    finalizers: ?[][]const u8 = null,
};

/// Namespace type alias
pub const Namespace = Resource(NamespaceSpec);

/// Node specification
pub const NodeSpec = struct {
    podCIDR: ?[]const u8 = null,
    providerID: ?[]const u8 = null,
    unschedulable: ?bool = null,
};

pub const NodeAddress = struct {
    type: []const u8,
    address: []const u8,
};

pub const NodeCondition = struct {
    type: []const u8,
    status: []const u8,
    lastHeartbeatTime: ?[]const u8 = null,
    lastTransitionTime: ?[]const u8 = null,
    reason: ?[]const u8 = null,
    message: ?[]const u8 = null,
};

pub const NodeSystemInfo = struct {
    machineID: ?[]const u8 = null,
    systemUUID: ?[]const u8 = null,
    bootID: ?[]const u8 = null,
    kernelVersion: ?[]const u8 = null,
    osImage: ?[]const u8 = null,
    containerRuntimeVersion: ?[]const u8 = null,
    kubeletVersion: ?[]const u8 = null,
    kubeProxyVersion: ?[]const u8 = null,
    operatingSystem: ?[]const u8 = null,
    architecture: ?[]const u8 = null,
};

/// One entry of `status.images` — every image cached on the node. Routinely the
/// largest part of a Node object, which is why it is typed rather than a DOM.
pub const NodeImage = struct {
    names: ?[][]const u8 = null,
    sizeBytes: ?i64 = null,
};

pub const NodeStatus = struct {
    /// Resource maps keep arbitrary keys (cpu, memory, hugepages-*, vendor
    /// devices), so they stay dynamic.
    capacity: ?std.json.Value = null,
    allocatable: ?std.json.Value = null,
    phase: ?[]const u8 = null,
    conditions: ?[]NodeCondition = null,
    addresses: ?[]NodeAddress = null,
    nodeInfo: ?NodeSystemInfo = null,
    images: ?[]NodeImage = null,
    daemonEndpoints: ?std.json.Value = null,
};

/// Node type alias. Uses a typed status — see `meta.ResourceWithStatus` for why.
pub const Node = ResourceWithStatus(NodeSpec, NodeStatus);

/// ServiceAccount (custom struct)
pub const ServiceAccount = struct {
    apiVersion: ?[]const u8 = null,
    kind: ?[]const u8 = null,
    metadata: ObjectMeta,
    secrets: ?[]std.json.Value = null,
    imagePullSecrets: ?[]std.json.Value = null,
    automountServiceAccountToken: ?bool = null,
};

/// Endpoints (core/v1). Has no `spec` — `subsets` is TOP-LEVEL.
pub const Endpoints = struct {
    apiVersion: ?[]const u8 = null,
    kind: ?[]const u8 = null,
    metadata: ObjectMeta,
    subsets: ?[]std.json.Value = null,
};

/// Event involvedObject reference (the object an Event regards).
pub const EventInvolvedObject = struct {
    kind: ?[]const u8 = null,
    namespace: ?[]const u8 = null,
    name: ?[]const u8 = null,
    uid: ?[]const u8 = null,
    apiVersion: ?[]const u8 = null,
    resourceVersion: ?[]const u8 = null,
    fieldPath: ?[]const u8 = null,
};

/// Aggregation state for a repeating Event. The modern `client-go/tools/events`
/// recorder (kubelet BackOff/Unhealthy, …) collapses repeats into `series` and
/// leaves the deprecated `count`/`lastTimestamp` unset — so consumers rendering
/// COUNT / LAST-SEEN must prefer this when present, as kubectl does.
pub const EventSeries = struct {
    count: ?i32 = null,
    lastObservedTime: ?[]const u8 = null,
};

/// Event (core/v1). Unlike most resources, core/v1 Events carry their payload
/// (type/reason/message/involvedObject/count/timestamps) as TOP-LEVEL fields,
/// not under spec/status — so this is a custom struct rather than Resource(T).
pub const Event = struct {
    apiVersion: ?[]const u8 = null,
    kind: ?[]const u8 = null,
    metadata: ObjectMeta,
    involvedObject: ?EventInvolvedObject = null,
    reason: ?[]const u8 = null,
    message: ?[]const u8 = null,
    type: ?[]const u8 = null,
    count: ?i32 = null,
    series: ?EventSeries = null,
    firstTimestamp: ?[]const u8 = null,
    lastTimestamp: ?[]const u8 = null,
    eventTime: ?[]const u8 = null,
    action: ?[]const u8 = null,
    source: ?std.json.Value = null,
    reportingComponent: ?[]const u8 = null,
    reportingInstance: ?[]const u8 = null,
};

/// ResourceQuota specification
pub const ResourceQuotaSpec = struct {
    hard: ?std.json.Value = null,
    scopes: ?[][]const u8 = null,
    scopeSelector: ?std.json.Value = null,
};

/// ResourceQuota (resource limits)
pub const ResourceQuota = Resource(ResourceQuotaSpec);

/// LimitRange specification
pub const LimitRangeSpec = struct {
    limits: []std.json.Value,
};

/// LimitRange (resource constraints)
pub const LimitRange = Resource(LimitRangeSpec);

/// ReplicationController specification (legacy controller)
pub const ReplicationControllerSpec = struct {
    replicas: ?i32 = null,
    selector: ?std.json.Value = null,
    template: ?std.json.Value = null,
    minReadySeconds: ?i32 = null,
};

/// ReplicationController (legacy pod controller)
pub const ReplicationController = Resource(ReplicationControllerSpec);

/// PodTemplate (core/v1). Has no `spec` — `template` is TOP-LEVEL.
pub const PodTemplate = struct {
    apiVersion: ?[]const u8 = null,
    kind: ?[]const u8 = null,
    metadata: ObjectMeta,
    template: ?std.json.Value = null,
};

/// Binding (core/v1, pod-to-node). Has no `spec` — `target` (an ObjectReference)
/// is TOP-LEVEL and required; nesting it under `spec` makes the bind a no-op.
pub const Binding = struct {
    apiVersion: ?[]const u8 = null,
    kind: ?[]const u8 = null,
    metadata: ObjectMeta,
    target: std.json.Value,
};

/// ComponentStatus specification (cluster component health) - cluster-scoped
pub const ComponentStatusSpec = struct {
    conditions: ?[]std.json.Value = null,
};

/// ComponentStatus (cluster component health) - cluster-scoped
pub const ComponentStatus = struct {
    apiVersion: ?[]const u8 = null,
    kind: ?[]const u8 = null,
    metadata: ObjectMeta,
    conditions: ?[]std.json.Value = null,
};
