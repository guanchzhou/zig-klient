const std = @import("std");
const meta = @import("meta.zig");
const ObjectMeta = meta.ObjectMeta;
const Resource = meta.Resource;

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

/// Pod type alias
pub const Pod = Resource(PodSpec);

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

/// Service type alias
pub const Service = Resource(ServiceSpec);

/// ConfigMap data
pub const ConfigMapData = struct {
    data: ?std.json.Value = null,
    binaryData: ?std.json.Value = null,
};

/// ConfigMap type alias
pub const ConfigMap = Resource(ConfigMapData);

/// Secret data
pub const SecretData = struct {
    data: ?std.json.Value = null,
    stringData: ?std.json.Value = null,
    type_: ?[]const u8 = null,
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

/// Node type alias
pub const Node = Resource(NodeSpec);

/// ServiceAccount (custom struct)
pub const ServiceAccount = struct {
    apiVersion: ?[]const u8 = null,
    kind: ?[]const u8 = null,
    metadata: ObjectMeta,
    secrets: ?[]std.json.Value = null,
    imagePullSecrets: ?[]std.json.Value = null,
    automountServiceAccountToken: ?bool = null,
};

/// Endpoints specification
pub const EndpointsSpec = struct {
    subsets: ?[]std.json.Value = null,
};

/// Endpoints (service endpoints)
pub const Endpoints = Resource(EndpointsSpec);

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

/// Event (cluster events)
pub const Event = Resource(EventSpec);

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

/// PodTemplate resource specification
pub const PodTemplateResourceSpec = struct {
    template: ?std.json.Value = null,
};

/// PodTemplate (reusable pod templates)
pub const PodTemplate = Resource(PodTemplateResourceSpec);

/// Binding specification (pod-to-node binding)
pub const BindingSpec = struct {
    target: std.json.Value,
};

/// Binding (pod-to-node binding)
pub const Binding = Resource(BindingSpec);

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
