//! Kubernetes API discovery.
//!
//! Answers "what does THIS cluster actually serve?" instead of requiring callers to
//! hardcode a group/version/plural. Both endpoints are core Kubernetes `meta/v1`, so
//! this carries no knowledge of any third-party API:
//!
//!   GET /apis                      -> APIGroupList
//!   GET /apis/{group}/{version}    -> APIResourceList
//!
//! This exists because hardcoding those strings is a silent failure mode. A caller
//! that guesses `cedar.k8s.io/v1alpha1/cedarpolicies` when the real group is
//! `cedar.k8s.aws` gets a 404 it usually swallows, and the feature simply never
//! activates. Ask the server instead.
//!
//! Use it for optional/third-party APIs: if the group is present, work with it; if
//! not, there is nothing to do. Types that every cluster has belong in the compiled
//! resource registry, which is cheaper and typed.

const std = @import("std");
const K8sClient = @import("client.zig").K8sClient;
const CRDInfo = @import("crd.zig").CRDInfo;

const log = std.log.scoped(.klient_discovery);

/// One group/version string pair as the server reports it.
pub const GroupVersion = struct {
    groupVersion: []const u8 = "",
    version: []const u8 = "",
};

/// An entry in the /apis group list.
pub const APIGroup = struct {
    name: []const u8 = "",
    versions: []GroupVersion = &.{},
    /// The version the server prefers for this group. Absent on some aggregated
    /// apiservers, so callers must fall back to `versions`.
    preferredVersion: ?GroupVersion = null,
};

/// Response shape of GET /apis.
pub const APIGroupList = struct {
    groups: []APIGroup = &.{},
};

/// One resource within a group/version. `name` is the PLURAL used in URLs, which is
/// the field callers most often guess wrong.
pub const APIResource = struct {
    name: []const u8 = "",
    singularName: ?[]const u8 = null,
    namespaced: bool = false,
    kind: []const u8 = "",
    verbs: [][]const u8 = &.{},
};

/// Response shape of GET /apis/{group}/{version}.
pub const APIResourceList = struct {
    groupVersion: []const u8 = "",
    resources: []APIResource = &.{},
};

pub const Discovery = struct {
    client: *K8sClient,

    pub fn init(k8s_client: *K8sClient) Discovery {
        return .{ .client = k8s_client };
    }

    /// Fetch the server's API group list. Caller owns the returned Parsed arena.
    pub fn groups(self: Discovery) !std.json.Parsed(APIGroupList) {
        const body = try self.client.request(.GET, "/apis", null);
        defer self.client.allocator.free(body);

        return std.json.parseFromSlice(
            APIGroupList,
            self.client.allocator,
            body,
            .{ .ignore_unknown_fields = true, .allocate = .alloc_always },
        );
    }

    /// Fetch the resources served for one group/version. Caller owns the arena.
    pub fn resources(self: Discovery, group: []const u8, version: []const u8) !std.json.Parsed(APIResourceList) {
        const path = try std.fmt.allocPrint(self.client.allocator, "/apis/{s}/{s}", .{ group, version });
        defer self.client.allocator.free(path);

        const body = try self.client.request(.GET, path, null);
        defer self.client.allocator.free(body);

        return std.json.parseFromSlice(
            APIResourceList,
            self.client.allocator,
            body,
            .{ .ignore_unknown_fields = true, .allocate = .alloc_always },
        );
    }

    /// True if the server serves `group` at any version.
    ///
    /// Returns false rather than erroring when discovery itself fails, because the
    /// question being asked is "is this optional API available", and an unreachable
    /// or forbidden /apis means the answer is no either way.
    pub fn hasGroup(self: Discovery, group: []const u8) bool {
        const parsed = self.groups() catch |err| {
            log.warn("discovery: /apis failed: {t}", .{err});
            return false;
        };
        defer parsed.deinit();

        for (parsed.value.groups) |g| {
            if (std.mem.eql(u8, g.name, group)) return true;
        }
        return false;
    }

    /// The server's preferred version for `group`, or null if absent.
    ///
    /// Falls back to the first entry in `versions` when `preferredVersion` is absent,
    /// which happens on some aggregated apiservers. Caller owns the returned slice.
    pub fn preferredVersion(self: Discovery, group: []const u8) !?[]const u8 {
        const parsed = try self.groups();
        defer parsed.deinit();

        for (parsed.value.groups) |g| {
            if (!std.mem.eql(u8, g.name, group)) continue;

            if (g.preferredVersion) |pv| {
                if (pv.version.len > 0) return try self.client.allocator.dupe(u8, pv.version);
            }
            if (g.versions.len > 0 and g.versions[0].version.len > 0) {
                return try self.client.allocator.dupe(u8, g.versions[0].version);
            }
            return null;
        }
        return null;
    }

    /// Resolve a kind to a ready-to-use CRDInfo by asking the server for the group's
    /// preferred version and that kind's plural and scope.
    ///
    /// This is the point of the module: nothing about the group/version/plural is
    /// compiled in, so it cannot drift out of date. Returns null when the group is
    /// absent or serves no such kind. Caller owns the strings in the result.
    pub fn findResource(self: Discovery, group: []const u8, kind: []const u8) !?CRDInfo {
        const version = (try self.preferredVersion(group)) orelse return null;
        errdefer self.client.allocator.free(version);

        const parsed = try self.resources(group, version);
        defer parsed.deinit();

        for (parsed.value.resources) |r| {
            if (!std.mem.eql(u8, r.kind, kind)) continue;
            // Subresources appear as "pods/log"; they are not listable collections.
            if (std.mem.indexOfScalar(u8, r.name, '/') != null) continue;

            return CRDInfo{
                .group = try self.client.allocator.dupe(u8, group),
                .version = version,
                .kind = try self.client.allocator.dupe(u8, r.kind),
                .plural = try self.client.allocator.dupe(u8, r.name),
                .namespaced = r.namespaced,
            };
        }

        self.client.allocator.free(version);
        return null;
    }

    /// Free a CRDInfo returned by `findResource`.
    pub fn freeResource(self: Discovery, info: CRDInfo) void {
        const a = self.client.allocator;
        a.free(info.group);
        a.free(info.version);
        a.free(info.kind);
        a.free(info.plural);
    }
};
