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
}

test "QueryWriter: single field selector" {
    const allocator = std.testing.allocator;
    const opts = klient.ListOptions{
        .field_selector = "metadata.name=test",
    };
    const qs = try opts.buildQueryString(allocator);
    defer allocator.free(qs);

    try std.testing.expectEqualStrings("fieldSelector=metadata.name%3Dtest", qs);
}

// A set-based selector contains spaces and parentheses. Emitted raw, they landed
// in the HTTP request target and every such query came back 400 Bad Request.
test "QueryWriter: set-based label selector is percent-encoded" {
    const allocator = std.testing.allocator;

    var sel = try klient.LabelSelector.init(allocator);
    defer sel.deinit();
    try sel.addIn("app", &.{ "traefik", "coredns" });
    const built = try sel.build();
    defer allocator.free(built);
    try std.testing.expectEqualStrings("app in (traefik,coredns)", built);

    const qs = try (klient.ListOptions{ .label_selector = built }).buildQueryString(allocator);
    defer allocator.free(qs);

    try std.testing.expectEqualStrings("labelSelector=app%20in%20%28traefik%2Ccoredns%29", qs);
    // Nothing that would terminate or split the request target may survive raw.
    try std.testing.expect(std.mem.indexOfAny(u8, qs["labelSelector=".len..], " ()") == null);
}

test "QueryWriter: continue token round-trips unencoded (URL-safe base64)" {
    const allocator = std.testing.allocator;
    // Real token shape: the API server uses RawURLEncoding, so it is already safe.
    const token = "eyJ2IjoibWV0YS5rOHMuaW8vdjEiLCJydiI6MTA3MDM2fQ";
    const qs = try (klient.ListOptions{ .continue_token = token }).buildQueryString(allocator);
    defer allocator.free(qs);
    try std.testing.expectEqualStrings("continue=eyJ2IjoibWV0YS5rOHMuaW8vdjEiLCJydiI6MTA3MDM2fQ", qs);
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
    try std.testing.expect(std.mem.indexOf(u8, qs, "fieldSelector=metadata.name%3Dtest") != null);
    try std.testing.expect(std.mem.indexOf(u8, qs, "labelSelector=app%3Dnginx") != null);
    try std.testing.expect(std.mem.indexOf(u8, qs, "limit=10") != null);
    // Verify & separators
    try std.testing.expect(std.mem.indexOf(u8, qs, "&") != null);
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
}
