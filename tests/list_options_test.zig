const std = @import("std");
const klient = @import("klient");
const testing = std.testing;

test "ListOptions - buildQueryString with all options" {
    const allocator = testing.allocator;

    const options = klient.ListOptions{
        .field_selector = "metadata.name=my-pod",
        .label_selector = "app=nginx",
        .limit = 10,
        .timeout_seconds = 30,
        .pretty = true,
    };

    const query_string = try options.buildQueryString(allocator);
    defer allocator.free(query_string);

    // Check that all options are present
    try testing.expect(std.mem.indexOf(u8, query_string, "fieldSelector=metadata.name=my-pod") != null);
    try testing.expect(std.mem.indexOf(u8, query_string, "labelSelector=app=nginx") != null);
    try testing.expect(std.mem.indexOf(u8, query_string, "limit=10") != null);
    try testing.expect(std.mem.indexOf(u8, query_string, "timeoutSeconds=30") != null);
    try testing.expect(std.mem.indexOf(u8, query_string, "pretty=true") != null);
}

test "ListOptions - buildQueryString with no options" {
    const allocator = testing.allocator;

    const options = klient.ListOptions{};

    const query_string = try options.buildQueryString(allocator);
    defer allocator.free(query_string);

    try testing.expectEqualStrings("", query_string);
}

test "ListOptions - buildQueryString with pagination" {
    const allocator = testing.allocator;

    const options = klient.ListOptions{
        .limit = 50,
        .continue_token = "continue-token-123",
        .resource_version = "12345",
    };

    const query_string = try options.buildQueryString(allocator);
    defer allocator.free(query_string);

    try testing.expect(std.mem.indexOf(u8, query_string, "limit=50") != null);
    try testing.expect(std.mem.indexOf(u8, query_string, "continue=continue-token-123") != null);
    try testing.expect(std.mem.indexOf(u8, query_string, "resourceVersion=12345") != null);
}

test "LabelSelector - equality selector" {
    const allocator = testing.allocator;

    var selector = klient.LabelSelector.init(allocator);
    defer selector.deinit();

    try selector.addEquals("app", "nginx");
    try selector.addEquals("tier", "frontend");

    const result = try selector.build();
    defer allocator.free(result);

    try testing.expectEqualStrings("app=nginx,tier=frontend", result);
}

test "LabelSelector - inequality selector" {
    const allocator = testing.allocator;

    var selector = klient.LabelSelector.init(allocator);
    defer selector.deinit();

    try selector.addEquals("env", "prod");
    try selector.addNotEquals("version", "v1");

    const result = try selector.build();
    defer allocator.free(result);

    try testing.expectEqualStrings("env=prod,version!=v1", result);
}

test "LabelSelector - set-based selectors" {
    const allocator = testing.allocator;

    var selector = klient.LabelSelector.init(allocator);
    defer selector.deinit();

    const values = [_][]const u8{ "v1", "v2", "v3" };
    try selector.addIn("version", &values);

    const result = try selector.build();
    defer allocator.free(result);

    try testing.expectEqualStrings("version in (v1,v2,v3)", result);
}

test "LabelSelector - existence selectors" {
    const allocator = testing.allocator;

    var selector = klient.LabelSelector.init(allocator);
    defer selector.deinit();

    try selector.addExists("app");
    try selector.addNotExists("debug");

    const result = try selector.build();
    defer allocator.free(result);

    try testing.expectEqualStrings("app,!debug", result);
}

test "FieldSelector - equality selector" {
    const allocator = testing.allocator;

    var selector = klient.FieldSelector.init(allocator);
    defer selector.deinit();

    try selector.addEquals("metadata.name", "my-pod");
    try selector.addEquals("status.phase", "Running");

    const result = try selector.build();
    defer allocator.free(result);

    try testing.expectEqualStrings("metadata.name=my-pod,status.phase=Running", result);
}

test "FieldSelector - inequality selector" {
    const allocator = testing.allocator;

    var selector = klient.FieldSelector.init(allocator);
    defer selector.deinit();

    try selector.addEquals("status.phase", "Running");
    try selector.addNotEquals("metadata.name", "excluded-pod");

    const result = try selector.build();
    defer allocator.free(result);

    try testing.expectEqualStrings("status.phase=Running,metadata.name!=excluded-pod", result);
}

test "FieldSelector - empty selector" {
    const allocator = testing.allocator;

    var selector = klient.FieldSelector.init(allocator);
    defer selector.deinit();

    const result = try selector.build();
    defer allocator.free(result);

    try testing.expectEqualStrings("", result);
}
