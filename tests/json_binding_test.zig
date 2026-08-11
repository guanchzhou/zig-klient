// Regression tests for JSON field binding of reserved-ish names. Zig's std.json
// matches field names with a plain compare (no trailing-underscore stripping), so
// fields that mirror wire names like "type"/"continue" must be declared as such.
const std = @import("std");
const klient = @import("klient");

test "ServiceSpec.type binds the wire \"type\" field" {
    const allocator = std.testing.allocator;
    const json =
        \\{"apiVersion":"v1","kind":"Service","metadata":{"name":"svc"},
        \\ "spec":{"type":"ClusterIP","clusterIP":"10.0.0.1"}}
    ;
    var parsed = try std.json.parseFromSlice(klient.Service, allocator, json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    try std.testing.expectEqualStrings("ClusterIP", parsed.value.spec.?.type.?);
}

test "List(T).metadata.continue binds the wire \"continue\" token (pagination)" {
    const allocator = std.testing.allocator;
    const json =
        \\{"apiVersion":"v1","kind":"PodList",
        \\ "metadata":{"resourceVersion":"123","continue":"next-page-token"},
        \\ "items":[]}
    ;
    var parsed = try std.json.parseFromSlice(klient.types.List(klient.Pod), allocator, json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    try std.testing.expectEqualStrings("next-page-token", parsed.value.metadata.@"continue".?);
}

test "WatchEvent.type binds the wire \"type\" field" {
    const allocator = std.testing.allocator;
    const json =
        \\{"type":"ADDED","object":{"kind":"Pod"}}
    ;
    var parsed = try std.json.parseFromSlice(klient.types.WatchEvent, allocator, json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    try std.testing.expectEqualStrings("ADDED", parsed.value.type);
}

// A series-aggregated Event (kubelet BackOff etc.) leaves the deprecated
// count/lastTimestamp unset; the real count and last-seen live under "series".
test "Event binds top-level fields and the series aggregation" {
    const allocator = std.testing.allocator;
    const json =
        \\{"apiVersion":"v1","kind":"Event","metadata":{"name":"pod.17f"},
        \\ "involvedObject":{"kind":"Pod","name":"web-0","fieldPath":"spec.containers{app}"},
        \\ "reason":"BackOff","message":"Back-off restarting failed container","type":"Warning",
        \\ "eventTime":"2026-08-10T09:00:00.000000Z",
        \\ "series":{"count":40,"lastObservedTime":"2026-08-10T09:10:00.000000Z"}}
    ;
    var parsed = try std.json.parseFromSlice(klient.types.Event, allocator, json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    const ev = parsed.value;
    try std.testing.expectEqualStrings("Warning", ev.type.?);
    try std.testing.expectEqualStrings("BackOff", ev.reason.?);
    try std.testing.expectEqualStrings("web-0", ev.involvedObject.?.name.?);
    // The deprecated fields are absent — only `series` carries the truth.
    try std.testing.expect(ev.count == null);
    try std.testing.expect(ev.lastTimestamp == null);
    try std.testing.expectEqual(@as(i32, 40), ev.series.?.count.?);
    try std.testing.expectEqualStrings("2026-08-10T09:10:00.000000Z", ev.series.?.lastObservedTime.?);
}

// `Pod.status` is a typed `PodStatus`, not a `std.json.Value` DOM. Parsing it as
// a DOM cost ~16% more time and ~2x the memory on a 500-pod list, and forced every
// consumer through `status.object.get("phase").?.string`.
test "Pod.status binds as a typed struct" {
    const allocator = std.testing.allocator;
    const json =
        \\{"apiVersion":"v1","kind":"Pod","metadata":{"name":"web-0","namespace":"default"},
        \\ "spec":{"nodeName":"node-1","containers":[{"name":"app","image":"nginx:1.27"}]},
        \\ "status":{"phase":"Running","podIP":"10.42.0.8","hostIP":"192.168.1.10",
        \\   "podIPs":[{"ip":"10.42.0.8"}],"qosClass":"Burstable",
        \\   "startTime":"2026-08-10T09:00:00Z",
        \\   "conditions":[{"type":"Ready","status":"True","lastTransitionTime":"2026-08-10T09:00:05Z"}],
        \\   "containerStatuses":[{"name":"app","ready":false,"restartCount":7,
        \\     "image":"nginx:1.27","containerID":"containerd://abc",
        \\     "state":{"waiting":{"reason":"CrashLoopBackOff","message":"back-off 5m0s"}},
        \\     "lastState":{"terminated":{"exitCode":1,"reason":"Error","finishedAt":"2026-08-10T08:59:00Z"}}}]}}
    ;
    var parsed = try std.json.parseFromSlice(klient.Pod, allocator, json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    const s = parsed.value.status.?;

    try std.testing.expectEqualStrings("Running", s.phase.?);
    try std.testing.expectEqualStrings("10.42.0.8", s.podIP.?);
    try std.testing.expectEqualStrings("Burstable", s.qosClass.?);
    try std.testing.expectEqualStrings("10.42.0.8", s.podIPs.?[0].ip.?);
    try std.testing.expectEqualStrings("Ready", s.conditions.?[0].type);
    try std.testing.expectEqualStrings("True", s.conditions.?[0].status);

    const cs = s.containerStatuses.?[0];
    try std.testing.expectEqual(@as(i32, 7), cs.restartCount);
    try std.testing.expect(!cs.ready);
    try std.testing.expectEqualStrings("nginx:1.27", cs.image.?);
    // The reason a pod is not running — what kubectl shows in the STATUS column.
    try std.testing.expectEqualStrings("CrashLoopBackOff", cs.state.?.waiting.?.reason.?);
    try std.testing.expect(cs.state.?.running == null);
    try std.testing.expectEqual(@as(i32, 1), cs.lastState.?.terminated.?.exitCode);
}

test "Node.status binds as a typed struct" {
    const allocator = std.testing.allocator;
    const json =
        \\{"apiVersion":"v1","kind":"Node","metadata":{"name":"node-1"},
        \\ "spec":{"podCIDR":"10.42.0.0/24"},
        \\ "status":{"capacity":{"cpu":"8","memory":"16Gi"},
        \\   "conditions":[{"type":"Ready","status":"True","reason":"KubeletReady"}],
        \\   "addresses":[{"type":"InternalIP","address":"192.168.1.10"}],
        \\   "nodeInfo":{"kubeletVersion":"v1.33.1","architecture":"arm64"},
        \\   "images":[{"names":["nginx:1.27"],"sizeBytes":56000000}]}}
    ;
    var parsed = try std.json.parseFromSlice(klient.Node, allocator, json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    const s = parsed.value.status.?;

    try std.testing.expectEqualStrings("Ready", s.conditions.?[0].type);
    try std.testing.expectEqualStrings("KubeletReady", s.conditions.?[0].reason.?);
    try std.testing.expectEqualStrings("InternalIP", s.addresses.?[0].type);
    try std.testing.expectEqualStrings("v1.33.1", s.nodeInfo.?.kubeletVersion.?);
    try std.testing.expectEqual(@as(i64, 56000000), s.images.?[0].sizeBytes.?);
    // Resource maps keep arbitrary keys, so they stay dynamic.
    try std.testing.expectEqualStrings("8", s.capacity.?.object.get("cpu").?.string);
}

// A handful of kinds carry their payload at the TOP LEVEL instead of under
// `spec`. Modelling those as Resource(T) parses cleanly but silently drops
// everything: `spec` lands as null and ignore_unknown_fields eats the real data.
test "spec-less kinds bind their payload at the top level" {
    const allocator = std.testing.allocator;

    {
        const json =
            \\{"apiVersion":"v1","kind":"ConfigMap","metadata":{"name":"cm"},
            \\ "data":{"KEY":"value"},"immutable":true}
        ;
        var p = try std.json.parseFromSlice(klient.ConfigMap, allocator, json, .{ .ignore_unknown_fields = true });
        defer p.deinit();
        try std.testing.expectEqualStrings("value", p.value.data.?.object.get("KEY").?.string);
        try std.testing.expect(p.value.immutable.?);
    }
    {
        const json =
            \\{"apiVersion":"v1","kind":"Endpoints","metadata":{"name":"ep"},
            \\ "subsets":[{"addresses":[{"ip":"10.0.0.1"}]}]}
        ;
        var p = try std.json.parseFromSlice(klient.Endpoints, allocator, json, .{ .ignore_unknown_fields = true });
        defer p.deinit();
        try std.testing.expectEqual(@as(usize, 1), p.value.subsets.?.len);
    }
    {
        const json =
            \\{"apiVersion":"v1","kind":"PodTemplate","metadata":{"name":"pt"},
            \\ "template":{"spec":{"containers":[]}}}
        ;
        var p = try std.json.parseFromSlice(klient.PodTemplate, allocator, json, .{ .ignore_unknown_fields = true });
        defer p.deinit();
        try std.testing.expect(p.value.template.?.object.contains("spec"));
    }
    {
        const json =
            \\{"apiVersion":"v1","kind":"Binding","metadata":{"name":"web-0"},
            \\ "target":{"kind":"Node","name":"node-1"}}
        ;
        var p = try std.json.parseFromSlice(klient.Binding, allocator, json, .{ .ignore_unknown_fields = true });
        defer p.deinit();
        try std.testing.expectEqualStrings("node-1", p.value.target.object.get("name").?.string);
    }
    {
        const json =
            \\{"apiVersion":"apps/v1","kind":"ControllerRevision","metadata":{"name":"cr"},
            \\ "revision":7,"data":{"spec":{}}}
        ;
        var p = try std.json.parseFromSlice(klient.ControllerRevision, allocator, json, .{ .ignore_unknown_fields = true });
        defer p.deinit();
        try std.testing.expectEqual(@as(i64, 7), p.value.revision);
    }
    {
        const json =
            \\{"apiVersion":"discovery.k8s.io/v1","kind":"EndpointSlice","metadata":{"name":"es"},
            \\ "addressType":"IPv4","endpoints":[{"addresses":["10.0.0.1"]}],"ports":[{"port":8080}]}
        ;
        var p = try std.json.parseFromSlice(klient.EndpointSlice, allocator, json, .{ .ignore_unknown_fields = true });
        defer p.deinit();
        try std.testing.expectEqualStrings("IPv4", p.value.addressType);
        try std.testing.expectEqual(@as(usize, 1), p.value.endpoints.?.len);
    }
    {
        const json =
            \\{"apiVersion":"storage.k8s.io/v1","kind":"CSIStorageCapacity","metadata":{"name":"sc"},
            \\ "storageClassName":"fast-ssd","capacity":"100Gi"}
        ;
        var p = try std.json.parseFromSlice(klient.CSIStorageCapacity, allocator, json, .{ .ignore_unknown_fields = true });
        defer p.deinit();
        try std.testing.expectEqualStrings("fast-ssd", p.value.storageClassName);
        try std.testing.expectEqualStrings("100Gi", p.value.capacity.?);
    }
}

// Binding is write-only in practice: the API server reads `target` from the top
// level, so a `{"spec":{"target":…}}` body binds nothing and reports no error.
test "Binding serializes target at the top level" {
    const allocator = std.testing.allocator;
    const binding = klient.Binding{
        .apiVersion = "v1",
        .kind = "Binding",
        .metadata = .{ .name = "web-0", .namespace = "default" },
        .target = .{ .string = "node-1" },
    };
    const out = try std.json.Stringify.valueAlloc(allocator, binding, .{});
    defer allocator.free(out);
    try std.testing.expect(std.mem.indexOf(u8, out, "\"target\":\"node-1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "\"spec\"") == null);
}

test "StrategicMergePatch.build emits a JSON object" {
    const allocator = std.testing.allocator;
    var patch = klient.apply.StrategicMergePatch.init(allocator);
    defer patch.deinit();
    try patch.addPatch("replicas", .{ .integer = 3 });
    const out = try patch.build();
    defer allocator.free(out);
    try std.testing.expect(std.mem.containsAtLeast(u8, out, 1, "\"replicas\":3"));
}

test "JsonPatch.build emits an array of operations" {
    const allocator = std.testing.allocator;
    var patch = klient.apply.JsonPatch.init(allocator);
    defer patch.deinit();
    try patch.replace("/spec/replicas", .{ .integer = 5 });
    const out = try patch.build();
    defer allocator.free(out);
    try std.testing.expect(out[0] == '[');
    try std.testing.expect(std.mem.containsAtLeast(u8, out, 1, "\"op\":\"replace\""));
    try std.testing.expect(std.mem.containsAtLeast(u8, out, 1, "\"path\":\"/spec/replicas\""));
}

test "ServiceSpec.type also serializes back as \"type\"" {
    const allocator = std.testing.allocator;
    const svc = klient.Service{
        .apiVersion = "v1",
        .kind = "Service",
        .metadata = .{ .name = "svc" },
        .spec = .{ .type = "NodePort" },
    };
    const out = try std.json.Stringify.valueAlloc(allocator, svc, .{});
    defer allocator.free(out);
    try std.testing.expect(std.mem.containsAtLeast(u8, out, 1, "\"type\":\"NodePort\""));
    try std.testing.expect(!std.mem.containsAtLeast(u8, out, 1, "type_"));
}
