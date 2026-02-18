const std = @import("std");
const meta = @import("meta.zig");
const ObjectMeta = meta.ObjectMeta;
const Resource = meta.Resource;

/// Ingress specification
pub const IngressSpec = struct {
    ingressClassName: ?[]const u8 = null,
    defaultBackend: ?std.json.Value = null,
    tls: ?[]std.json.Value = null,
    rules: ?[]const std.json.Value = null,
};

/// Ingress type alias
pub const Ingress = Resource(IngressSpec);

/// NetworkPolicy specification
pub const NetworkPolicySpec = struct {
    podSelector: ?std.json.Value = null,
    policyTypes: ?[][]const u8 = null,
    ingress: ?[]std.json.Value = null,
    egress: ?[]std.json.Value = null,
};

/// NetworkPolicy (network security)
pub const NetworkPolicy = Resource(NetworkPolicySpec);

/// IPAddress specification
pub const IPAddressSpec = struct {
    parentRef: std.json.Value,
};

/// IPAddress (IP address allocation)
pub const IPAddress = Resource(IPAddressSpec);

/// ServiceCIDR specification
pub const ServiceCIDRSpec = struct {
    cidrs: ?[][]const u8 = null,
};

/// ServiceCIDR (service CIDR management)
pub const ServiceCIDR = Resource(ServiceCIDRSpec);

/// IngressClass specification
pub const IngressClassSpec = struct {
    controller: []const u8,
    parameters: ?std.json.Value = null,
};

/// IngressClass (ingress controller configuration) - cluster-scoped
pub const IngressClass = struct {
    apiVersion: ?[]const u8 = null,
    kind: ?[]const u8 = null,
    metadata: ObjectMeta,
    controller: []const u8,
    parameters: ?std.json.Value = null,
};

/// EndpointSlice specification (for efficient service discovery)
pub const EndpointSliceSpec = struct {
    addressType: []const u8,
    endpoints: ?[]std.json.Value = null,
    ports: ?[]std.json.Value = null,
};

/// EndpointSlice (efficient service discovery)
pub const EndpointSlice = Resource(EndpointSliceSpec);
