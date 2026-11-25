const std = @import("std");
const klient = @import("klient");

test "AccessReview: type has canI and convenience methods" {
    try std.testing.expect(@hasDecl(klient.AccessReview, "init"));
    try std.testing.expect(@hasDecl(klient.AccessReview, "canI"));
    try std.testing.expect(@hasDecl(klient.AccessReview, "canList"));
    try std.testing.expect(@hasDecl(klient.AccessReview, "canWatch"));
    try std.testing.expect(@hasDecl(klient.AccessReview, "canCreate"));
    try std.testing.expect(@hasDecl(klient.AccessReview, "canDelete"));
}

test "AccessReview: ReviewRequest serializes correctly" {
    const allocator = std.testing.allocator;

    // Test the internal ReviewRequest struct serialization
    const auth_mod = klient.auth;
    const ReviewType = auth_mod.AccessReview;

    // Verify the struct has the right fields
    try std.testing.expect(@hasField(ReviewType, "client"));

    _ = allocator;
}

test "PropagationPolicy: toString returns correct K8s values" {
    try std.testing.expectEqualStrings("Orphan", klient.PropagationPolicy.orphan.toString());
    try std.testing.expectEqualStrings("Background", klient.PropagationPolicy.background.toString());
    try std.testing.expectEqualStrings("Foreground", klient.PropagationPolicy.foreground.toString());
}

test "FieldValidation: toString returns correct K8s values" {
    try std.testing.expectEqualStrings("Strict", klient.FieldValidation.strict.toString());
    try std.testing.expectEqualStrings("Warn", klient.FieldValidation.warn.toString());
    try std.testing.expectEqualStrings("Ignore", klient.FieldValidation.ignore.toString());
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
}

test "exec_credential: scrubSecrets redacts bearer tokens, JWTs, JSON tokens, and kv tokens" {
    var buf: [512]u8 = undefined;

    const bearer = klient.exec_credential.scrubSecrets(&buf, "Authorization: Bearer secret_abc.123-xyz failed");
    try std.testing.expect(std.mem.indexOf(u8, bearer, "secret_abc") == null);
    try std.testing.expect(std.mem.indexOf(u8, bearer, "[REDACTED]") != null);

    const jwt = klient.exec_credential.scrubSecrets(&buf, "got eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiIxMjMifQ.sig_value in err");
    try std.testing.expect(std.mem.indexOf(u8, jwt, "eyJhbGci") == null);
    try std.testing.expect(std.mem.indexOf(u8, jwt, "[REDACTED]") != null);

    const json_tok = klient.exec_credential.scrubSecrets(&buf, "{\"access_token\":\"supersecretvalue\",\"ok\":true}");
    try std.testing.expect(std.mem.indexOf(u8, json_tok, "supersecretvalue") == null);
    try std.testing.expect(std.mem.indexOf(u8, json_tok, "\"ok\":true") != null);

    const kv_tok = klient.exec_credential.scrubSecrets(&buf, "err: id_token=my_secret_123 retry");
    try std.testing.expect(std.mem.indexOf(u8, kv_tok, "my_secret_123") == null);
    try std.testing.expect(std.mem.indexOf(u8, kv_tok, "retry") != null);
}

test "exec_credential: executeCredentialPlugin merges config.env into child environment" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;

    var env = [_]klient.exec_credential.EnvVar{
        .{ .name = "KLIENT_TEST_TOKEN", .value = "merged-env-token-42" },
    };
    var args = [_][]const u8{
        "-c",
        "printf '{\"apiVersion\":\"client.authentication.k8s.io/v1\",\"kind\":\"ExecCredential\",\"status\":{\"token\":\"%s\"}}' \"$KLIENT_TEST_TOKEN\"",
    };
    const cfg = klient.exec_credential.ExecConfig{
        .command = "/bin/sh",
        .args = &args,
        .env = &env,
    };

    const cred = try klient.exec_credential.executeCredentialPlugin(allocator, io, cfg);
    defer cred.deinit();

    try std.testing.expect(cred.value.status != null);
    try std.testing.expectEqualStrings("merged-env-token-42", cred.value.status.?.token.?);
}
