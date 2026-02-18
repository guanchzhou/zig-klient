const std = @import("std");
const meta = @import("meta.zig");
const ObjectMeta = meta.ObjectMeta;
const Resource = meta.Resource;

/// HorizontalPodAutoscaler specification
pub const HorizontalPodAutoscalerSpec = struct {
    scaleTargetRef: ?std.json.Value = null,
    minReplicas: ?i32 = null,
    maxReplicas: i32,
    metrics: ?[]std.json.Value = null,
    behavior: ?std.json.Value = null,
};

/// HorizontalPodAutoscaler (auto-scaling)
pub const HorizontalPodAutoscaler = Resource(HorizontalPodAutoscalerSpec);

/// PodDisruptionBudget specification
pub const PodDisruptionBudgetSpec = struct {
    minAvailable: ?std.json.Value = null,
    maxUnavailable: ?std.json.Value = null,
    selector: ?std.json.Value = null,
    unhealthyPodEvictionPolicy: ?[]const u8 = null,
};

/// PodDisruptionBudget (availability)
pub const PodDisruptionBudget = Resource(PodDisruptionBudgetSpec);

/// Lease specification (for leader election and coordination)
pub const LeaseSpec = struct {
    holderIdentity: ?[]const u8 = null,
    leaseDurationSeconds: ?i32 = null,
    acquireTime: ?[]const u8 = null,
    renewTime: ?[]const u8 = null,
    leaseTransitions: ?i32 = null,
};

/// Lease (leader election and coordination)
pub const Lease = Resource(LeaseSpec);

/// PriorityClass specification (pod scheduling priority) - cluster-scoped
pub const PriorityClassSpec = struct {
    value: i32,
    globalDefault: ?bool = null,
    description: ?[]const u8 = null,
    preemptionPolicy: ?[]const u8 = null,
};

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
