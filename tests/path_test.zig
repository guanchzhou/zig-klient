const std = @import("std");
const klient = @import("klient");
const path = klient.path;

test "validatePathSegment accepts ordinary Kubernetes names" {
    for ([_][]const u8{ "default", "my-pod", "nginx-7d4b9c-x2z", "v1", "apps", "example.com", "a..b", ".hidden" }) |segment| {
        try klient.validatePathSegment(segment);
    }
}

test "validatePathSegment rejects CR, LF, slash, empty, dot segments, percent and whitespace" {
    const bad = [_][]const u8{
        "",
        ".",
        "..",
        "a/b",
        "/",
        "../kube-system",
        "pod\r\nX-Injected: 1",
        "pod\n",
        "pod\r",
        "%2e%2e",
        "a b",
        "a\tb",
        "a?watch=true",
        "a#frag",
        "a\x00",
        "a\x7f",
    };
    for (bad) |segment| {
        try std.testing.expectError(error.InvalidPathSegment, klient.validatePathSegment(segment));
    }
}

test "validateHeaderValue and validateBearerToken reject control characters" {
    try path.validateHeaderValue("application/json;q=0.9, */*\tx");
    try std.testing.expectError(error.InvalidHeaderValue, path.validateHeaderValue("a\r\nX-Injected: 1"));
    try std.testing.expectError(error.InvalidHeaderValue, path.validateHeaderValue("a\x7f"));

    try path.validateBearerToken("eyJhbGciOi.payload.sig");
    try std.testing.expectError(error.InvalidBearerToken, path.validateBearerToken("tok\nen"));
}

test "validateRequestUrl rejects whitespace and control characters" {
    try path.validateRequestUrl("https://10.0.0.1:6443/api/v1/pods?labelSelector=app%3Dweb");
    try std.testing.expectError(error.InvalidRequestUrl, path.validateRequestUrl("/api/v1/pods HTTP/1.1"));
    try std.testing.expectError(error.InvalidRequestUrl, path.validateRequestUrl("/api/v1/pods\r\nHost: evil"));
}

test "K8sClient.init rejects a token that would split the Authorization header" {
    try std.testing.expectError(
        error.InvalidBearerToken,
        klient.K8sClient.init(std.testing.allocator, std.testing.io, .{
            .server = "http://127.0.0.1:1",
            .token = "abc\r\nX-Injected: 1",
        }),
    );
}

test "resource clients reject unsafe names and namespaces before any request" {
    const allocator = std.testing.allocator;
    var client = try klient.K8sClient.init(allocator, std.testing.io, .{ .server = "http://127.0.0.1:1" });
    defer client.deinit();

    const pods = klient.Pods.init(&client);
    try std.testing.expectError(error.InvalidPathSegment, pods.client.get("../secrets/token", "default"));
    try std.testing.expectError(error.InvalidPathSegment, pods.client.get("web", "kube-system/secrets"));
    try std.testing.expectError(error.InvalidPathSegment, pods.client.get("", "default"));
    try std.testing.expectError(error.InvalidPathSegment, pods.client.list("bad\nns"));
}

test "exec path and CRD paths reject unsafe segments" {
    const allocator = std.testing.allocator;
    const command = [_][]const u8{"sh"};
    try std.testing.expectError(
        error.InvalidPathSegment,
        klient.websocket.buildExecPath(allocator, "default", "../nodes/n1/proxy", &command, .{}),
    );
    try std.testing.expectError(
        error.InvalidPathSegment,
        klient.websocket.buildExecPath(allocator, "..", "pod", &command, .{}),
    );

    const crd: klient.crd.CRDInfo = .{ .group = "example.com", .version = "v1", .kind = "Widget", .plural = "widgets" };
    try std.testing.expectError(error.InvalidPathSegment, crd.resourcePath(allocator, "default", "a/b"));
    try std.testing.expectError(error.InvalidPathSegment, crd.resourcePath(allocator, "..", "a"));

    const good = try crd.resourcePath(allocator, "default", "a");
    defer allocator.free(good);
    try std.testing.expectEqualStrings("/apis/example.com/v1/namespaces/default/widgets/a", good);
}
