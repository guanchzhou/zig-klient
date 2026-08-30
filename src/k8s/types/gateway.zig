const std = @import("std");
const meta = @import("meta.zig");
const ObjectMeta = meta.ObjectMeta;
const Resource = meta.Resource;

/// GatewayClass specification (gateway.networking.k8s.io/v1)
pub const GatewayClassSpec = struct {
    controllerName: []const u8,
    description: ?[]const u8 = null,
    parametersRef: ?std.json.Value = null,
};

/// GatewayClass type alias
pub const GatewayClass = Resource(GatewayClassSpec);

/// Gateway specification (gateway.networking.k8s.io/v1)
pub const GatewaySpec = struct {
    gatewayClassName: []const u8,
    listeners: []std.json.Value,
    addresses: ?[]std.json.Value = null,
};

/// Gateway type alias
pub const Gateway = Resource(GatewaySpec);

/// HTTPRoute specification (gateway.networking.k8s.io/v1)
pub const HTTPRouteSpec = struct {
    parentRefs: ?[]std.json.Value = null,
    hostnames: ?[][]const u8 = null,
    rules: ?[]std.json.Value = null,
};

/// HTTPRoute type alias
pub const HTTPRoute = Resource(HTTPRouteSpec);

/// GRPCRoute specification (gateway.networking.k8s.io/v1)
pub const GRPCRouteSpec = struct {
    parentRefs: ?[]std.json.Value = null,
    hostnames: ?[][]const u8 = null,
    rules: ?[]std.json.Value = null,
};

/// GRPCRoute type alias
pub const GRPCRoute = Resource(GRPCRouteSpec);

/// ReferenceGrant specification (gateway.networking.k8s.io/v1beta1)
pub const ReferenceGrantSpec = struct {
    from: []std.json.Value,
    to: []std.json.Value,
};

/// ReferenceGrant type alias
pub const ReferenceGrant = Resource(ReferenceGrantSpec);

/// TCPRoute specification (gateway.networking.k8s.io/v1).
/// `rules` is required by the CRD; kept optional here because a client should be
/// lenient on read -- a non-optional field that the server omits fails the whole parse.
pub const TCPRouteSpec = struct {
    parentRefs: ?[]std.json.Value = null,
    rules: ?[]std.json.Value = null,
};

/// TCPRoute type alias
pub const TCPRoute = Resource(TCPRouteSpec);

/// TLSRoute specification (gateway.networking.k8s.io/v1).
/// `hostnames` and `rules` are required by the CRD; see TCPRouteSpec on leniency.
pub const TLSRouteSpec = struct {
    parentRefs: ?[]std.json.Value = null,
    hostnames: ?[][]const u8 = null,
    rules: ?[]std.json.Value = null,
};

/// TLSRoute type alias
pub const TLSRoute = Resource(TLSRouteSpec);

/// UDPRoute specification (gateway.networking.k8s.io/v1).
/// `rules` is required by the CRD; see TCPRouteSpec on leniency.
pub const UDPRouteSpec = struct {
    parentRefs: ?[]std.json.Value = null,
    rules: ?[]std.json.Value = null,
};

/// UDPRoute type alias
pub const UDPRoute = Resource(UDPRouteSpec);

/// BackendTLSPolicy specification (gateway.networking.k8s.io/v1).
/// `targetRefs` and `validation` are required by the CRD; see TCPRouteSpec on leniency.
pub const BackendTLSPolicySpec = struct {
    targetRefs: ?[]std.json.Value = null,
    validation: ?std.json.Value = null,
    options: ?std.json.Value = null,
};

/// BackendTLSPolicy type alias
pub const BackendTLSPolicy = Resource(BackendTLSPolicySpec);

/// ListenerSet specification (gateway.networking.k8s.io/v1).
/// `parentRef` and `listeners` are required by the CRD; see TCPRouteSpec on leniency.
pub const ListenerSetSpec = struct {
    parentRef: ?std.json.Value = null,
    listeners: ?[]std.json.Value = null,
};

/// ListenerSet type alias
pub const ListenerSet = Resource(ListenerSetSpec);

/// ResourceClaim specification (resource.k8s.io/v1)
pub const ResourceClaimSpec = struct {
    devices: ?std.json.Value = null,
};

/// ResourceClaim type alias
pub const ResourceClaim = Resource(ResourceClaimSpec);

/// ResourceClaimTemplate specification (resource.k8s.io/v1)
pub const ResourceClaimTemplateSpec = struct {
    spec: std.json.Value,
};

/// ResourceClaimTemplate type alias
pub const ResourceClaimTemplate = Resource(ResourceClaimTemplateSpec);

/// ResourceSlice specification (resource.k8s.io/v1)
pub const ResourceSliceSpec = struct {
    driver: []const u8,
    nodeName: ?[]const u8 = null,
    pool: ?std.json.Value = null,
    devices: ?[]std.json.Value = null,
};

/// ResourceSlice type alias
pub const ResourceSlice = Resource(ResourceSliceSpec);

/// DeviceClass specification (resource.k8s.io/v1)
pub const DeviceClassSpec = struct {
    selectors: ?[]std.json.Value = null,
    config: ?[]std.json.Value = null,
    suitableNodes: ?std.json.Value = null,
};

/// DeviceClass type alias
pub const DeviceClass = Resource(DeviceClassSpec);

/// One taint applied to matching DRA devices. Effects: None, NoSchedule, NoExecute.
pub const DeviceTaint = struct {
    key: []const u8,
    value: ?[]const u8 = null,
    effect: []const u8,
    timeAdded: ?[]const u8 = null,
};

/// Selector for a DeviceTaintRule. Without a selector, no devices match.
/// `deviceClassName` and CEL `selectors` were tombstoned in 1.35 and are omitted.
pub const DeviceTaintSelector = struct {
    driver: ?[]const u8 = null,
    pool: ?[]const u8 = null,
    device: ?[]const u8 = null,
};

/// DeviceTaintRule specification (resource.k8s.io/v1) — K8s 1.37 GA
pub const DeviceTaintRuleSpec = struct {
    deviceSelector: ?DeviceTaintSelector = null,
    taint: DeviceTaint,
};

/// DeviceTaintRule (cluster-scoped admin taint for DRA devices) — K8s 1.37 GA
pub const DeviceTaintRule = Resource(DeviceTaintRuleSpec);
