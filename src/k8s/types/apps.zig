const std = @import("std");
const meta = @import("meta.zig");
const ObjectMeta = meta.ObjectMeta;
const Resource = meta.Resource;

const core = @import("core.zig");
const PodSpec = core.PodSpec;

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

/// Deployment type alias
pub const Deployment = Resource(DeploymentSpec);

/// ReplicaSet specification
pub const ReplicaSetSpec = struct {
    replicas: ?i32 = null,
    selector: ?std.json.Value = null,
    template: ?std.json.Value = null,
};

/// ReplicaSet type alias
pub const ReplicaSet = Resource(ReplicaSetSpec);

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

/// StatefulSet type alias
pub const StatefulSet = Resource(StatefulSetSpec);

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

/// DaemonSet type alias
pub const DaemonSet = Resource(DaemonSetSpec);

/// ControllerRevision specification (for StatefulSet/DaemonSet history)
pub const ControllerRevisionSpec = struct {
    revision: i64,
    data: ?std.json.Value = null,
};

/// ControllerRevision (workload history)
pub const ControllerRevision = Resource(ControllerRevisionSpec);
