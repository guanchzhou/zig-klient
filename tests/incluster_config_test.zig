const std = @import("std");
const klient = @import("klient");
const testing = std.testing;

test "InClusterConfig - check if in cluster" {
    // This test just checks the isInCluster function
    // It will return false if not running in a cluster
    const in_cluster = klient.isInCluster(std.testing.io);

    // We can't assert true/false as it depends on environment
    // Just make sure it doesn't crash
    _ = in_cluster;
}

test "InClusterConfig - paths constants" {
    const paths = klient.incluster.ServiceAccountPaths;

    try testing.expectEqualStrings("/var/run/secrets/kubernetes.io/serviceaccount/token", paths.token);
    try testing.expectEqualStrings("/var/run/secrets/kubernetes.io/serviceaccount/ca.crt", paths.ca_cert);
    try testing.expectEqualStrings("/var/run/secrets/kubernetes.io/serviceaccount/namespace", paths.namespace);
}

test "InClusterConfig - env vars constants" {
    const env_vars = klient.incluster.EnvVars;

    try testing.expectEqualStrings("KUBERNETES_SERVICE_HOST", env_vars.host);
    try testing.expectEqualStrings("KUBERNETES_SERVICE_PORT", env_vars.port);
}

test "InClusterConfig - loadInClusterConfig error handling" {
    const allocator = testing.allocator;

    // This should fail when not in a cluster
    const result = klient.loadInClusterConfig(std.testing.io, allocator);

    // We expect an error when not running in a cluster
    try testing.expectError(error.ServiceAccountTokenNotFound, result);
}

test "InClusterConfig - formatServerUrl brackets IPv6 hosts" {
    const allocator = testing.allocator;
    const cases = [_]struct { host: []const u8, port: []const u8, expected: []const u8 }{
        .{ .host = "fd00::1", .port = "443", .expected = "https://[fd00::1]:443" },
        .{ .host = "2001:db8::a:1", .port = "6443", .expected = "https://[2001:db8::a:1]:6443" },
        .{ .host = "[fd00::1]", .port = "443", .expected = "https://[fd00::1]:443" },
        .{ .host = "10.96.0.1", .port = "443", .expected = "https://10.96.0.1:443" },
        .{ .host = "kubernetes.default.svc", .port = "443", .expected = "https://kubernetes.default.svc:443" },
    };
    for (cases) |case| {
        const url = try klient.incluster.formatServerUrl(allocator, case.host, case.port);
        defer allocator.free(url);
        try testing.expectEqualStrings(case.expected, url);
    }
}
