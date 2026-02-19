const std = @import("std");
const klient = @import("klient");

// Import QueryWriter through the list_options module path
const query = @import("klient").list_options;

test "QueryWriter: empty query produces empty string" {
    const allocator = std.testing.allocator;
    const opts = klient.ListOptions{};
    const qw = try opts.buildQueryString(allocator);
    defer allocator.free(qw);

    try std.testing.expectEqualStrings("", qw);
    std.debug.print("✅ QueryWriter empty string test passed\n", .{});
}

test "QueryWriter: single field selector" {
    const allocator = std.testing.allocator;
    const opts = klient.ListOptions{
        .field_selector = "metadata.name=test",
    };
    const qs = try opts.buildQueryString(allocator);
    defer allocator.free(qs);

    try std.testing.expectEqualStrings("fieldSelector=metadata.name=test", qs);
    std.debug.print("✅ QueryWriter single field selector test passed\n", .{});
}

test "QueryWriter: multiple options combined with &" {
    const allocator = std.testing.allocator;
    const opts = klient.ListOptions{
        .field_selector = "metadata.name=test",
        .label_selector = "app=nginx",
        .limit = 10,
    };
    const qs = try opts.buildQueryString(allocator);
    defer allocator.free(qs);

    // Verify all parts present
    try std.testing.expect(std.mem.indexOf(u8, qs, "fieldSelector=metadata.name=test") != null);
    try std.testing.expect(std.mem.indexOf(u8, qs, "labelSelector=app=nginx") != null);
    try std.testing.expect(std.mem.indexOf(u8, qs, "limit=10") != null);
    // Verify & separators
    try std.testing.expect(std.mem.indexOf(u8, qs, "&") != null);
    std.debug.print("✅ QueryWriter multiple options test passed\n", .{});
}

test "QueryWriter: boolean flags only added when true" {
    const allocator = std.testing.allocator;
    const opts = klient.ListOptions{
        .pretty = true,
        .allow_watch_bookmarks = false, // should NOT appear
        .send_initial_events = true,
    };
    const qs = try opts.buildQueryString(allocator);
    defer allocator.free(qs);

    try std.testing.expect(std.mem.indexOf(u8, qs, "pretty=true") != null);
    try std.testing.expect(std.mem.indexOf(u8, qs, "sendInitialEvents=true") != null);
    try std.testing.expect(std.mem.indexOf(u8, qs, "allowWatchBookmarks") == null);
    std.debug.print("✅ QueryWriter boolean flags test passed\n", .{});
}

test "QueryWriter: DeleteOptions grace period and propagation" {
    const allocator = std.testing.allocator;
    const opts = klient.DeleteOptions{
        .grace_period_seconds = 30,
        .propagation_policy = "Background",
    };
    const qs = try opts.buildQueryString(allocator);
    defer allocator.free(qs);

    try std.testing.expect(std.mem.indexOf(u8, qs, "gracePeriodSeconds=30") != null);
    try std.testing.expect(std.mem.indexOf(u8, qs, "propagationPolicy=Background") != null);
    std.debug.print("✅ QueryWriter DeleteOptions test passed\n", .{});
}

test "QueryWriter: CreateOptions all fields" {
    const allocator = std.testing.allocator;
    const opts = klient.CreateOptions{
        .field_manager = "zig-klient",
        .field_validation = "Strict",
        .dry_run = "All",
        .pretty = true,
    };
    const qs = try opts.buildQueryString(allocator);
    defer allocator.free(qs);

    try std.testing.expect(std.mem.indexOf(u8, qs, "fieldManager=zig-klient") != null);
    try std.testing.expect(std.mem.indexOf(u8, qs, "fieldValidation=Strict") != null);
    try std.testing.expect(std.mem.indexOf(u8, qs, "dryRun=All") != null);
    try std.testing.expect(std.mem.indexOf(u8, qs, "pretty=true") != null);
    std.debug.print("✅ QueryWriter CreateOptions test passed\n", .{});
}

test "QueryWriter: ApplyOptions always includes fieldManager" {
    const allocator = std.testing.allocator;
    const opts = klient.ApplyOptions{
        .field_manager = "zig-controller",
        .force = true,
    };
    const qs = try opts.buildQueryString(allocator);
    defer allocator.free(qs);

    try std.testing.expect(std.mem.indexOf(u8, qs, "fieldManager=zig-controller") != null);
    try std.testing.expect(std.mem.indexOf(u8, qs, "force=true") != null);
    std.debug.print("✅ QueryWriter ApplyOptions test passed\n", .{});
}

test "QueryWriter: no memory leaks on allocation" {
    // Using std.testing.allocator which detects leaks
    const allocator = std.testing.allocator;
    const opts = klient.ListOptions{
        .field_selector = "status.phase=Running",
        .label_selector = "app=web,tier=frontend",
        .limit = 100,
        .timeout_seconds = 30,
        .pretty = true,
    };
    const qs = try opts.buildQueryString(allocator);
    defer allocator.free(qs);

    try std.testing.expect(qs.len > 0);
    std.debug.print("✅ QueryWriter memory safety test passed\n", .{});
}
