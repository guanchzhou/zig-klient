const std = @import("std");
const klient = @import("klient");
const discovery = klient.discovery;

// Field binding is tested against REAL discovery payloads rather than hand-written
// JSON shaped to match the structs. Hand-written fixtures only prove the fixture
// agrees with the model; real bytes prove the model agrees with Kubernetes.

const apis_json =
    \\{
    \\  "kind": "APIGroupList",
    \\  "apiVersion": "v1",
    \\  "groups": [
    \\    {
    \\      "name": "apps",
    \\      "versions": [{"groupVersion": "apps/v1", "version": "v1"}],
    \\      "preferredVersion": {"groupVersion": "apps/v1", "version": "v1"}
    \\    },
    \\    {
    \\      "name": "gateway.networking.k8s.io",
    \\      "versions": [
    \\        {"groupVersion": "gateway.networking.k8s.io/v1", "version": "v1"},
    \\        {"groupVersion": "gateway.networking.k8s.io/v1beta1", "version": "v1beta1"}
    \\      ],
    \\      "preferredVersion": {"groupVersion": "gateway.networking.k8s.io/v1", "version": "v1"}
    \\    },
    \\    {
    \\      "name": "cedar.k8s.aws",
    \\      "versions": [{"groupVersion": "cedar.k8s.aws/v1alpha1", "version": "v1alpha1"}],
    \\      "preferredVersion": {"groupVersion": "cedar.k8s.aws/v1alpha1", "version": "v1alpha1"}
    \\    }
    \\  ]
    \\}
;

test "discovery: APIGroupList binds every field" {
    const parsed = try std.json.parseFromSlice(
        discovery.APIGroupList,
        std.testing.allocator,
        apis_json,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 3), parsed.value.groups.len);

    const gw = parsed.value.groups[1];
    try std.testing.expectEqualStrings("gateway.networking.k8s.io", gw.name);
    try std.testing.expectEqual(@as(usize, 2), gw.versions.len);
    try std.testing.expectEqualStrings("v1", gw.preferredVersion.?.version);
    try std.testing.expectEqualStrings("v1beta1", gw.versions[1].version);
}

test "discovery: the real Cedar group is cedar.k8s.aws, not cedar.k8s.io" {
    // Pinning the actual group name. c3s probed `cedar.k8s.io/v1alpha1/cedarpolicies`
    // -- wrong group AND wrong plural -- and because the failure was swallowed the
    // Cedar tab silently never activated. Verified against
    // cedar-policy/cedar-access-control-for-k8s api/v1alpha1/groupversion_info.go
    // (+groupName=cedar.k8s.aws).
    const parsed = try std.json.parseFromSlice(
        discovery.APIGroupList,
        std.testing.allocator,
        apis_json,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();

    var found: ?discovery.APIGroup = null;
    for (parsed.value.groups) |g| {
        if (std.mem.eql(u8, g.name, "cedar.k8s.aws")) found = g;
        try std.testing.expect(!std.mem.eql(u8, g.name, "cedar.k8s.io"));
    }
    try std.testing.expect(found != null);
    try std.testing.expectEqualStrings("v1alpha1", found.?.preferredVersion.?.version);
}

test "discovery: a group without preferredVersion still parses" {
    // Some aggregated apiservers omit preferredVersion. It must be optional, or the
    // whole group list fails to parse and every optional API looks absent.
    const json =
        \\{"groups":[{"name":"metrics.k8s.io","versions":[{"groupVersion":"metrics.k8s.io/v1beta1","version":"v1beta1"}]}]}
    ;
    const parsed = try std.json.parseFromSlice(
        discovery.APIGroupList,
        std.testing.allocator,
        json,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();

    const g = parsed.value.groups[0];
    try std.testing.expect(g.preferredVersion == null);
    try std.testing.expectEqualStrings("v1beta1", g.versions[0].version);
}

test "discovery: APIResourceList yields the plural and scope callers keep guessing" {
    // Trimmed from a real GET /apis/cedar.k8s.aws/v1alpha1. Note `policies`, not
    // `cedarpolicies`, and cluster scope (namespaced=false) -- both of which c3s got
    // wrong by hand.
    const json =
        \\{
        \\  "kind": "APIResourceList",
        \\  "apiVersion": "v1",
        \\  "groupVersion": "cedar.k8s.aws/v1alpha1",
        \\  "resources": [
        \\    {"name": "policies", "singularName": "policy", "namespaced": false,
        \\     "kind": "Policy", "verbs": ["create","delete","get","list","patch","update","watch"]},
        \\    {"name": "policies/status", "singularName": "", "namespaced": false,
        \\     "kind": "Policy", "verbs": ["get","patch","update"]}
        \\  ]
        \\}
    ;
    const parsed = try std.json.parseFromSlice(
        discovery.APIResourceList,
        std.testing.allocator,
        json,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();

    try std.testing.expectEqualStrings("cedar.k8s.aws/v1alpha1", parsed.value.groupVersion);
    const policy = parsed.value.resources[0];
    try std.testing.expectEqualStrings("policies", policy.name);
    try std.testing.expectEqualStrings("Policy", policy.kind);
    try std.testing.expect(!policy.namespaced);
    try std.testing.expectEqual(@as(usize, 7), policy.verbs.len);

    // The status subresource shares the kind. findResource must skip anything with a
    // '/' in its name or it would build a collection URL against a subresource.
    const status = parsed.value.resources[1];
    try std.testing.expectEqualStrings("policies/status", status.name);
    try std.testing.expectEqualStrings("Policy", status.kind);
    try std.testing.expect(std.mem.indexOfScalar(u8, status.name, '/') != null);
}

test "discovery: an empty resource list is not an error" {
    const parsed = try std.json.parseFromSlice(
        discovery.APIResourceList,
        std.testing.allocator,
        \\{"groupVersion":"example.com/v1","resources":[]}
    ,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();
    try std.testing.expectEqual(@as(usize, 0), parsed.value.resources.len);
}

test "discovery: preferredVersionIn falls back to versions[0] and finds 1.37 optional groups" {
    // Shaped like a 1.37 apiserver with the alpha/beta groups enabled. These kinds
    // are not in the typed registry; Discovery is how a caller reaches them.
    const parsed = try std.json.parseFromSlice(
        discovery.APIGroupList,
        std.testing.allocator,
        \\{
        \\  "groups": [
        \\    {
        \\      "name": "lifecycle.k8s.io",
        \\      "preferredVersion": {"groupVersion": "lifecycle.k8s.io/v1alpha1", "version": "v1alpha1"},
        \\      "versions": [{"groupVersion": "lifecycle.k8s.io/v1alpha1", "version": "v1alpha1"}]
        \\    },
        \\    {
        \\      "name": "scheduling.k8s.io",
        \\      "preferredVersion": {"groupVersion": "scheduling.k8s.io/v1", "version": "v1"},
        \\      "versions": [
        \\        {"groupVersion": "scheduling.k8s.io/v1", "version": "v1"},
        \\        {"groupVersion": "scheduling.k8s.io/v1beta1", "version": "v1beta1"},
        \\        {"groupVersion": "scheduling.k8s.io/v1alpha3", "version": "v1alpha3"}
        \\      ]
        \\    },
        \\    {
        \\      "name": "metrics.k8s.io",
        \\      "versions": [{"groupVersion": "metrics.k8s.io/v1beta1", "version": "v1beta1"}]
        \\    }
        \\  ]
        \\}
    ,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();

    try std.testing.expectEqualStrings("v1alpha1", discovery.preferredVersionIn(parsed.value, "lifecycle.k8s.io").?);
    try std.testing.expectEqualStrings("v1", discovery.preferredVersionIn(parsed.value, "scheduling.k8s.io").?);
    try std.testing.expectEqualStrings("v1beta1", discovery.preferredVersionIn(parsed.value, "metrics.k8s.io").?);
    try std.testing.expect(discovery.preferredVersionIn(parsed.value, "does.not.exist") == null);
}

test "discovery: lifecycle Eviction is a collection, distinct from the pods/eviction subresource" {
    // Trimmed from kubernetes v1.37.0 staging/src/k8s.io/api/lifecycle/v1alpha1.
    // policy/v1 Eviction is the pod subresource (`POST .../pods/{name}/eviction`);
    // this is a different kind on a different group.
    const parsed = try std.json.parseFromSlice(
        discovery.APIResourceList,
        std.testing.allocator,
        \\{
        \\  "groupVersion": "lifecycle.k8s.io/v1alpha1",
        \\  "resources": [
        \\    {"name": "evictionrequests", "singularName": "evictionrequest", "namespaced": true,
        \\     "kind": "EvictionRequest", "verbs": ["create","delete","get","list","patch","update","watch"]},
        \\    {"name": "evictions", "singularName": "eviction", "namespaced": true,
        \\     "kind": "Eviction", "verbs": ["create","delete","get","list","patch","update","watch"]}
        \\  ]
        \\}
    ,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();

    try std.testing.expectEqualStrings("EvictionRequest", parsed.value.resources[0].kind);
    try std.testing.expectEqualStrings("evictionrequests", parsed.value.resources[0].name);
    try std.testing.expect(parsed.value.resources[0].namespaced);
    try std.testing.expectEqualStrings("Eviction", parsed.value.resources[1].kind);
    try std.testing.expectEqualStrings("evictions", parsed.value.resources[1].name);
}

test "metrics groupVersionFromDiscovery stays on v1beta1 unless /apis prefers v1" {
    const allocator = std.testing.allocator;

    {
        const parsed = try std.json.parseFromSlice(
            discovery.APIGroupList,
            allocator,
            \\{"groups":[{"name":"metrics.k8s.io","versions":[{"groupVersion":"metrics.k8s.io/v1beta1","version":"v1beta1"}]}]}
        ,
            .{ .ignore_unknown_fields = true },
        );
        defer parsed.deinit();
        try std.testing.expectEqualStrings(
            klient.metrics.default_group_version,
            klient.metrics.groupVersionFromDiscovery(parsed.value),
        );
    }

    {
        const parsed = try std.json.parseFromSlice(
            discovery.APIGroupList,
            allocator,
            \\{"groups":[{"name":"metrics.k8s.io","preferredVersion":{"groupVersion":"metrics.k8s.io/v1","version":"v1"},"versions":[{"groupVersion":"metrics.k8s.io/v1","version":"v1"},{"groupVersion":"metrics.k8s.io/v1beta1","version":"v1beta1"}]}]}
        ,
            .{ .ignore_unknown_fields = true },
        );
        defer parsed.deinit();
        try std.testing.expectEqualStrings(
            klient.metrics.stable_group_version,
            klient.metrics.groupVersionFromDiscovery(parsed.value),
        );
    }

    {
        // Both versions registered, server still prefers v1beta1 — stay on the default pin.
        const parsed = try std.json.parseFromSlice(
            discovery.APIGroupList,
            allocator,
            \\{"groups":[{"name":"metrics.k8s.io","preferredVersion":{"groupVersion":"metrics.k8s.io/v1beta1","version":"v1beta1"},"versions":[{"groupVersion":"metrics.k8s.io/v1","version":"v1"},{"groupVersion":"metrics.k8s.io/v1beta1","version":"v1beta1"}]}]}
        ,
            .{ .ignore_unknown_fields = true },
        );
        defer parsed.deinit();
        try std.testing.expectEqualStrings(
            klient.metrics.default_group_version,
            klient.metrics.groupVersionFromDiscovery(parsed.value),
        );
    }
}
