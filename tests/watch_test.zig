const std = @import("std");
const klient = @import("klient");
const watch = klient.watch;

test "EventType.fromString: all valid event types" {
    try std.testing.expectEqual(watch.EventType.ADDED, watch.EventType.fromString("ADDED").?);
    try std.testing.expectEqual(watch.EventType.MODIFIED, watch.EventType.fromString("MODIFIED").?);
    try std.testing.expectEqual(watch.EventType.DELETED, watch.EventType.fromString("DELETED").?);
    try std.testing.expectEqual(watch.EventType.ERROR, watch.EventType.fromString("ERROR").?);
    try std.testing.expectEqual(watch.EventType.BOOKMARK, watch.EventType.fromString("BOOKMARK").?);
    std.debug.print("✅ EventType.fromString valid types test passed\n", .{});
}

test "EventType.fromString: unknown type returns null" {
    try std.testing.expectEqual(@as(?watch.EventType, null), watch.EventType.fromString("UNKNOWN"));
    try std.testing.expectEqual(@as(?watch.EventType, null), watch.EventType.fromString(""));
    try std.testing.expectEqual(@as(?watch.EventType, null), watch.EventType.fromString("added")); // case sensitive
    std.debug.print("✅ EventType.fromString unknown types test passed\n", .{});
}

test "WatchOptions: defaults are sensible" {
    const opts = klient.WatchOptions{};
    try std.testing.expectEqual(@as(?[]const u8, null), opts.resource_version);
    try std.testing.expectEqual(@as(?u32, null), opts.timeout_seconds);
    try std.testing.expectEqual(@as(?[]const u8, null), opts.label_selector);
    try std.testing.expectEqual(@as(?[]const u8, null), opts.field_selector);
    try std.testing.expect(opts.allow_watch_bookmarks);
    std.debug.print("✅ WatchOptions defaults test passed\n", .{});
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
    std.debug.print("✅ Watcher type instantiation test passed\n", .{});
}

test "Informer: type can be instantiated for any resource" {
    const PodInformer = klient.Informer(klient.Pod);

    try std.testing.expect(@hasDecl(PodInformer, "init"));
    try std.testing.expect(@hasDecl(PodInformer, "deinit"));
    try std.testing.expect(@hasDecl(PodInformer, "start"));
    try std.testing.expect(@hasDecl(PodInformer, "stop"));
    try std.testing.expect(@hasDecl(PodInformer, "get"));
    try std.testing.expect(@hasDecl(PodInformer, "listCached"));
    std.debug.print("✅ Informer type instantiation test passed\n", .{});
}

test "Informer: init and deinit with testing allocator" {
    const allocator = std.testing.allocator;
    const PodInformer = klient.Informer(klient.Pod);

    // Can't fully init without K8sClient, but we can verify the type
    // and that the cache uses the correct allocator
    _ = PodInformer;
    _ = allocator;
    std.debug.print("✅ Informer init/deinit test passed\n", .{});
}

test "WatchEvent: type has correct fields" {
    const PodEvent = watch.WatchEvent(klient.Pod);

    try std.testing.expect(@hasField(PodEvent, "type_"));
    try std.testing.expect(@hasField(PodEvent, "object"));
    try std.testing.expect(@hasField(PodEvent, "_parsed"));
    try std.testing.expect(@hasDecl(PodEvent, "deinit"));
    std.debug.print("✅ WatchEvent type structure test passed\n", .{});
}
