const std = @import("std");
const meta = @import("meta.zig");
const ObjectMeta = meta.ObjectMeta;
const Resource = meta.Resource;

const core = @import("core.zig");
const ResourceRequirements = core.ResourceRequirements;

/// PersistentVolume specification
pub const PersistentVolumeSpec = struct {
    capacity: ?std.json.Value = null,
    accessModes: ?[][]const u8 = null,
    persistentVolumeReclaimPolicy: ?[]const u8 = null,
    storageClassName: ?[]const u8 = null,
    mountOptions: ?[][]const u8 = null,
};

/// PersistentVolume type alias
pub const PersistentVolume = Resource(PersistentVolumeSpec);

/// PersistentVolumeClaim specification
pub const PersistentVolumeClaimSpec = struct {
    accessModes: ?[][]const u8 = null,
    resources: ?ResourceRequirements = null,
    volumeName: ?[]const u8 = null,
    storageClassName: ?[]const u8 = null,
};

/// PersistentVolumeClaim type alias
pub const PersistentVolumeClaim = Resource(PersistentVolumeClaimSpec);

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

/// VolumeAttachment specification (storage attachment)
pub const VolumeAttachmentSpec = struct {
    attacher: []const u8,
    source: std.json.Value,
    nodeName: []const u8,
};

/// VolumeAttachment (storage attachment) - cluster-scoped
pub const VolumeAttachment = Resource(VolumeAttachmentSpec);

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

/// CSIDriver (CSI driver info) - cluster-scoped
pub const CSIDriver = struct {
    apiVersion: ?[]const u8 = null,
    kind: ?[]const u8 = null,
    metadata: ObjectMeta,
    spec: CSIDriverSpec,
};

/// CSINode specification (CSI node info) - cluster-scoped
pub const CSINodeSpec = struct {
    drivers: []std.json.Value,
};

/// CSINode (CSI node info) - cluster-scoped
pub const CSINode = struct {
    apiVersion: ?[]const u8 = null,
    kind: ?[]const u8 = null,
    metadata: ObjectMeta,
    spec: CSINodeSpec,
};

/// CSIStorageCapacity specification
pub const CSIStorageCapacitySpec = struct {
    storageClassName: []const u8,
    capacity: ?[]const u8 = null,
    maximumVolumeSize: ?[]const u8 = null,
    nodeTopology: ?std.json.Value = null,
};

/// CSIStorageCapacity (CSI storage capacity)
pub const CSIStorageCapacity = Resource(CSIStorageCapacitySpec);

/// VolumeAttributesClass (storage.k8s.io/v1) - no spec, top-level fields
pub const VolumeAttributesClass = struct {
    apiVersion: ?[]const u8 = null,
    kind: ?[]const u8 = null,
    metadata: ObjectMeta,
    driverName: []const u8,
    parameters: ?std.json.Value = null,
};
