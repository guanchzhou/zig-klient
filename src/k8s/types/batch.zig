const std = @import("std");
const meta = @import("meta.zig");
const ObjectMeta = meta.ObjectMeta;
const Resource = meta.Resource;

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

/// Job type alias
pub const Job = Resource(JobSpec);

/// CronJob specification
pub const CronJobSpec = struct {
    schedule: ?[]const u8 = null,
    jobTemplate: ?std.json.Value = null,
    concurrencyPolicy: ?[]const u8 = null,
    suspended: ?bool = null,
    successfulJobsHistoryLimit: ?i32 = null,
    failedJobsHistoryLimit: ?i32 = null,
};

/// CronJob type alias
pub const CronJob = Resource(CronJobSpec);

pub const JobTemplateSpec = struct {
    metadata: ?ObjectMeta = null,
    spec: ?JobSpec = null,
};
