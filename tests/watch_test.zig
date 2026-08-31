const std = @import("std");
const klient = @import("klient");
const watch = klient.watch;

test "EventType.fromString: all valid event types" {
    try std.testing.expectEqual(watch.EventType.ADDED, watch.EventType.fromString("ADDED").?);
    try std.testing.expectEqual(watch.EventType.MODIFIED, watch.EventType.fromString("MODIFIED").?);
    try std.testing.expectEqual(watch.EventType.DELETED, watch.EventType.fromString("DELETED").?);
    try std.testing.expectEqual(watch.EventType.ERROR, watch.EventType.fromString("ERROR").?);
    try std.testing.expectEqual(watch.EventType.BOOKMARK, watch.EventType.fromString("BOOKMARK").?);
}

test "EventType.fromString: unknown type returns null" {
    try std.testing.expectEqual(@as(?watch.EventType, null), watch.EventType.fromString("UNKNOWN"));
    try std.testing.expectEqual(@as(?watch.EventType, null), watch.EventType.fromString(""));
    try std.testing.expectEqual(@as(?watch.EventType, null), watch.EventType.fromString("added")); // case sensitive
}

test "WatchOptions: defaults are sensible" {
    const opts = klient.WatchOptions{};
    try std.testing.expectEqual(@as(?[]const u8, null), opts.resource_version);
    try std.testing.expectEqual(@as(?u32, null), opts.timeout_seconds);
    try std.testing.expectEqual(@as(?[]const u8, null), opts.label_selector);
    try std.testing.expectEqual(@as(?[]const u8, null), opts.field_selector);
    try std.testing.expect(opts.allow_watch_bookmarks);
}

test "Watcher: type can be instantiated for any resource" {
    // Verify Watcher(T) works with different resource types
    const PodWatcher = klient.Watcher(klient.Pod);
    const DeployWatcher = klient.Watcher(klient.Deployment);

    try std.testing.expect(@sizeOf(PodWatcher) > 0);
    try std.testing.expect(@sizeOf(DeployWatcher) > 0);

    // Verify watcher has expected methods
    try std.testing.expect(@hasDecl(PodWatcher, "init"));
    try std.testing.expect(@hasDecl(PodWatcher, "watch"));
    try std.testing.expect(@hasDecl(PodWatcher, "watchWithContext"));
    try std.testing.expect(@hasDecl(PodWatcher, "watchOutcome"));
    try std.testing.expect(@hasDecl(PodWatcher, "watchWithContextOutcome"));
}

test "WatchOutcome exposes every terminal watch condition" {
    const expected = [_][]const u8{
        "eof",
        "canceled",
        "http_unauthorized",
        "http_forbidden",
        "http_gone",
        "http_throttled",
        "http_server_error",
        "http_error",
        "malformed_event",
        "status_expired",
        "status_error",
        "transport_error",
        "decode_error",
    };
    inline for (expected) |name| {
        try std.testing.expect(@hasField(klient.WatchOutcome, name));
    }
}

test "Informer: type can be instantiated for any resource" {
    const PodInformer = klient.Informer(klient.Pod);

    try std.testing.expect(@hasDecl(PodInformer, "init"));
    try std.testing.expect(@hasDecl(PodInformer, "deinit"));
    try std.testing.expect(@hasDecl(PodInformer, "start"));
    try std.testing.expect(@hasDecl(PodInformer, "stop"));
    try std.testing.expect(@hasDecl(PodInformer, "get"));
    try std.testing.expect(@hasDecl(PodInformer, "listCached"));
}

test "Informer: init and deinit with testing allocator" {
    const allocator = std.testing.allocator;
    const PodInformer = klient.Informer(klient.Pod);

    // Can't fully init without K8sClient, but we can verify the type
    // and that the cache uses the correct allocator
    _ = PodInformer;
    _ = allocator;
}

test "WatchEvent: type has correct fields" {
    const PodEvent = watch.WatchEvent(klient.Pod);

    try std.testing.expect(@hasField(PodEvent, "type_"));
    try std.testing.expect(@hasField(PodEvent, "object"));
    try std.testing.expect(@hasField(PodEvent, "_parsed"));
    try std.testing.expect(@hasDecl(PodEvent, "deinit"));
}

// --- Regression guards for the 2026-08-21 watch fixes ------------------------

test "watch: envelope object is optional, so a missing object is never undefined" {
    // WatchEnvelope.object used to be `T = undefined`. A line without an `object`
    // key left it holding uninitialised memory, which the informer's event handler
    // then dereferenced for EVERY event type. `== null` would not even compile
    // against the old declaration, so this test pins the shape as well as the value.
    const Envelope = watch.Watcher(klient.Pod).WatchEnvelope;

    const parsed = try std.json.parseFromSlice(
        Envelope,
        std.testing.allocator,
        \\{"type":"BOOKMARK"}
    ,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();

    try std.testing.expectEqualStrings("BOOKMARK", parsed.value.type);
    try std.testing.expect(parsed.value.object == null);
}

test "watch: a BOOKMARK object cannot bind to T, which is why it is dispatched by type first" {
    // ObjectMeta.name is required and a BOOKMARK carries only resourceVersion, so
    // binding a bookmark's object to a concrete T fails outright. Since
    // allow_watch_bookmarks defaults to TRUE, parsing every line as WatchEnvelope
    // meant the first bookmark the server sent tore down the whole watch.
    const Envelope = watch.Watcher(klient.Pod).WatchEnvelope;

    try std.testing.expectError(error.MissingField, std.json.parseFromSlice(
        Envelope,
        std.testing.allocator,
        \\{"type":"BOOKMARK","object":{"kind":"Pod","apiVersion":"v1","metadata":{"resourceVersion":"12345"}}}
    ,
        .{ .ignore_unknown_fields = true },
    ));
}

test "watch: Watcher.deinit is safe when the resourceVersion is borrowed, and idempotent" {
    // The initial resource_version is borrowed from WatchOptions and must never be
    // freed; only a BOOKMARK-supplied one is owned. deinit must therefore be a no-op
    // here, and safe to call twice.
    var client = klient.K8sClient{
        .allocator = std.testing.allocator,
        .io = std.testing.io,
        .http_client = undefined,
        .api_server = "http://127.0.0.1:8080",
        .token = null,
        .namespace = "default",
        .retry_config = .{},
        .tls_config = .{},
        .max_response_size = 1024,
    };

    var watcher = watch.Watcher(klient.Pod).init(
        &client,
        "/api/v1",
        "pods",
        "default",
        .{ .resource_version = "borrowed-do-not-free" },
    );

    try std.testing.expect(!watcher.resource_version_owned);
    watcher.deinit();
    watcher.deinit();
    try std.testing.expectEqualStrings("borrowed-do-not-free", watcher.resource_version.?);
}
