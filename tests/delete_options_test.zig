const std = @import("std");
const klient = @import("klient");
const delete_opts = klient.delete_options;

test "DeleteOptions - buildQueryString with grace period" {
    const allocator = std.testing.allocator;

    const options = delete_opts.DeleteOptions{
        .grace_period_seconds = 30,
    };

    const query_string = try options.buildQueryString(allocator);
    defer allocator.free(query_string);

    try std.testing.expectEqualStrings("gracePeriodSeconds=30", query_string);
    std.debug.print("✅ DeleteOptions grace period test passed\n", .{});
}

test "DeleteOptions - buildQueryString with propagation policy" {
    const allocator = std.testing.allocator;

    const options = delete_opts.DeleteOptions{
        .propagation_policy = "Foreground",
    };

    const query_string = try options.buildQueryString(allocator);
    defer allocator.free(query_string);

    try std.testing.expectEqualStrings("propagationPolicy=Foreground", query_string);
    std.debug.print("✅ DeleteOptions propagation policy test passed\n", .{});
}

test "DeleteOptions - buildQueryString with dry run" {
    const allocator = std.testing.allocator;

    const options = delete_opts.DeleteOptions{
        .dry_run = "All",
    };

    const query_string = try options.buildQueryString(allocator);
    defer allocator.free(query_string);

    try std.testing.expectEqualStrings("dryRun=All", query_string);
    std.debug.print("✅ DeleteOptions dry run test passed\n", .{});
}

test "DeleteOptions - buildQueryString with multiple options" {
    const allocator = std.testing.allocator;

    const options = delete_opts.DeleteOptions{
        .grace_period_seconds = 0,
        .propagation_policy = "Background",
        .dry_run = "All",
    };

    const query_string = try options.buildQueryString(allocator);
    defer allocator.free(query_string);

    // Check that all parameters are present
    try std.testing.expect(std.mem.containsAtLeast(u8, query_string, 1, "gracePeriodSeconds=0"));
    try std.testing.expect(std.mem.containsAtLeast(u8, query_string, 1, "propagationPolicy=Background"));
    try std.testing.expect(std.mem.containsAtLeast(u8, query_string, 1, "dryRun=All"));
    std.debug.print("✅ DeleteOptions multiple options test passed\n", .{});
}

test "DeleteOptions - buildQueryString with no options" {
    const allocator = std.testing.allocator;

    const options = delete_opts.DeleteOptions{};
    const query_string = try options.buildQueryString(allocator);
    defer allocator.free(query_string);

    try std.testing.expectEqualStrings("", query_string);
    std.debug.print("✅ DeleteOptions no options test passed\n", .{});
}

test "DeleteOptions - buildBody with preconditions" {
    const allocator = std.testing.allocator;

    const options = delete_opts.DeleteOptions{
        .grace_period_seconds = 30,
        .propagation_policy = "Foreground",
        .preconditions = .{
            .resource_version = "12345",
            .uid = "abc-def-123",
        },
    };

    const body = try options.buildBody(allocator);
    defer allocator.free(body);

    // Verify body contains expected fields
    try std.testing.expect(std.mem.containsAtLeast(u8, body, 1, "DeleteOptions"));
    try std.testing.expect(std.mem.containsAtLeast(u8, body, 1, "gracePeriodSeconds"));
    try std.testing.expect(std.mem.containsAtLeast(u8, body, 1, "propagationPolicy"));
    try std.testing.expect(std.mem.containsAtLeast(u8, body, 1, "preconditions"));
    try std.testing.expect(std.mem.containsAtLeast(u8, body, 1, "12345"));
    try std.testing.expect(std.mem.containsAtLeast(u8, body, 1, "abc-def-123"));
    std.debug.print("✅ DeleteOptions buildBody test passed\n", .{});
}

test "CreateOptions - buildQueryString with field manager" {
    const allocator = std.testing.allocator;

    const options = delete_opts.CreateOptions{
        .field_manager = "my-controller",
    };

    const query_string = try options.buildQueryString(allocator);
    defer allocator.free(query_string);

    try std.testing.expectEqualStrings("fieldManager=my-controller", query_string);
    std.debug.print("✅ CreateOptions field manager test passed\n", .{});
}

test "CreateOptions - buildQueryString with field validation" {
    const allocator = std.testing.allocator;

    const options = delete_opts.CreateOptions{
        .field_validation = "Strict",
    };

    const query_string = try options.buildQueryString(allocator);
    defer allocator.free(query_string);

    try std.testing.expectEqualStrings("fieldValidation=Strict", query_string);
    std.debug.print("✅ CreateOptions field validation test passed\n", .{});
}

test "CreateOptions - buildQueryString with all options" {
    const allocator = std.testing.allocator;

    const options = delete_opts.CreateOptions{
        .field_manager = "test-manager",
        .field_validation = "Warn",
        .dry_run = "All",
        .pretty = true,
    };

    const query_string = try options.buildQueryString(allocator);
    defer allocator.free(query_string);

    // Check all parameters are present
    try std.testing.expect(std.mem.containsAtLeast(u8, query_string, 1, "fieldManager=test-manager"));
    try std.testing.expect(std.mem.containsAtLeast(u8, query_string, 1, "fieldValidation=Warn"));
    try std.testing.expect(std.mem.containsAtLeast(u8, query_string, 1, "dryRun=All"));
    try std.testing.expect(std.mem.containsAtLeast(u8, query_string, 1, "pretty=true"));
    std.debug.print("✅ CreateOptions all options test passed\n", .{});
}

test "UpdateOptions - buildQueryString with options" {
    const allocator = std.testing.allocator;

    const options = delete_opts.UpdateOptions{
        .field_manager = "update-controller",
        .field_validation = "Ignore",
    };

    const query_string = try options.buildQueryString(allocator);
    defer allocator.free(query_string);

    // Check parameters are present
    try std.testing.expect(std.mem.containsAtLeast(u8, query_string, 1, "fieldManager=update-controller"));
    try std.testing.expect(std.mem.containsAtLeast(u8, query_string, 1, "fieldValidation=Ignore"));
    std.debug.print("✅ UpdateOptions test passed\n", .{});
}

test "PropagationPolicy - toString" {
    try std.testing.expectEqualStrings("Orphan", delete_opts.PropagationPolicy.orphan.toString());
    try std.testing.expectEqualStrings("Background", delete_opts.PropagationPolicy.background.toString());
    try std.testing.expectEqualStrings("Foreground", delete_opts.PropagationPolicy.foreground.toString());
    std.debug.print("✅ PropagationPolicy toString test passed\n", .{});
}

test "FieldValidation - toString" {
    try std.testing.expectEqualStrings("Strict", delete_opts.FieldValidation.strict.toString());
    try std.testing.expectEqualStrings("Warn", delete_opts.FieldValidation.warn.toString());
    try std.testing.expectEqualStrings("Ignore", delete_opts.FieldValidation.ignore.toString());
    std.debug.print("✅ FieldValidation toString test passed\n", .{});
}
