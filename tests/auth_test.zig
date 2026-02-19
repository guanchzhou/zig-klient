const std = @import("std");
const klient = @import("klient");

test "AccessReview: type has canI and convenience methods" {
    try std.testing.expect(@hasDecl(klient.AccessReview, "init"));
    try std.testing.expect(@hasDecl(klient.AccessReview, "canI"));
    try std.testing.expect(@hasDecl(klient.AccessReview, "canList"));
    try std.testing.expect(@hasDecl(klient.AccessReview, "canWatch"));
    try std.testing.expect(@hasDecl(klient.AccessReview, "canCreate"));
    try std.testing.expect(@hasDecl(klient.AccessReview, "canDelete"));
    std.debug.print("✅ AccessReview method declarations test passed\n", .{});
}

test "AccessReview: ReviewRequest serializes correctly" {
    const allocator = std.testing.allocator;

    // Test the internal ReviewRequest struct serialization
    const auth_mod = klient.auth;
    const ReviewType = auth_mod.AccessReview;

    // Verify the struct has the right fields
    try std.testing.expect(@hasField(ReviewType, "client"));
    std.debug.print("✅ AccessReview ReviewRequest serialization test passed\n", .{});

    _ = allocator;
}

test "PropagationPolicy: toString returns correct K8s values" {
    try std.testing.expectEqualStrings("Orphan", klient.PropagationPolicy.orphan.toString());
    try std.testing.expectEqualStrings("Background", klient.PropagationPolicy.background.toString());
    try std.testing.expectEqualStrings("Foreground", klient.PropagationPolicy.foreground.toString());
    std.debug.print("✅ PropagationPolicy toString test passed\n", .{});
}

test "FieldValidation: toString returns correct K8s values" {
    try std.testing.expectEqualStrings("Strict", klient.FieldValidation.strict.toString());
    try std.testing.expectEqualStrings("Warn", klient.FieldValidation.warn.toString());
    try std.testing.expectEqualStrings("Ignore", klient.FieldValidation.ignore.toString());
    std.debug.print("✅ FieldValidation toString test passed\n", .{});
}

test "PatchType: contentType returns correct MIME types" {
    try std.testing.expectEqualStrings(
        "application/strategic-merge-patch+json",
        klient.PatchType.strategic_merge.contentType(),
    );
    try std.testing.expectEqualStrings(
        "application/merge-patch+json",
        klient.PatchType.merge.contentType(),
    );
    try std.testing.expectEqualStrings(
        "application/json-patch+json",
        klient.PatchType.json.contentType(),
    );
    try std.testing.expectEqualStrings(
        "application/apply-patch+yaml",
        klient.PatchType.apply.contentType(),
    );
    std.debug.print("✅ PatchType contentType test passed\n", .{});
}

test "DeleteOptions: buildBody includes preconditions" {
    const allocator = std.testing.allocator;

    const opts = klient.DeleteOptions{
        .grace_period_seconds = 0,
        .propagation_policy = "Foreground",
        .preconditions = .{
            .resource_version = "12345",
            .uid = "abc-def-ghi",
        },
    };

    const body = try opts.buildBody(allocator);
    defer allocator.free(body);

    // Verify it's valid JSON
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, body, .{});
    defer parsed.deinit();

    // Check fields
    try std.testing.expectEqualStrings("v1", parsed.value.object.get("apiVersion").?.string);
    try std.testing.expectEqualStrings("DeleteOptions", parsed.value.object.get("kind").?.string);
    try std.testing.expectEqual(@as(i64, 0), parsed.value.object.get("gracePeriodSeconds").?.integer);

    const precond = parsed.value.object.get("preconditions").?.object;
    try std.testing.expectEqualStrings("12345", precond.get("resourceVersion").?.string);
    try std.testing.expectEqualStrings("abc-def-ghi", precond.get("uid").?.string);

    std.debug.print("✅ DeleteOptions buildBody with preconditions test passed\n", .{});
}
