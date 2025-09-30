const std = @import("std");
const klient = @import("klient");

test "KubeconfigParser - YAML parsing" {
    const allocator = std.testing.allocator;

    const yaml_config =
        \\apiVersion: v1
        \\kind: Config
        \\current-context: test-context
        \\clusters:
        \\- name: test-cluster
        \\  cluster:
        \\    server: https://kubernetes.example.com:6443
        \\    certificate-authority-data: Y2EtZGF0YQ==
        \\contexts:
        \\- name: test-context
        \\  context:
        \\    cluster: test-cluster
        \\    user: test-user
        \\    namespace: default
        \\users:
        \\- name: test-user
        \\  user:
        \\    token: my-bearer-token
    ;

    // Write to temp file
    var temp_dir = std.testing.tmpDir(.{});
    defer temp_dir.cleanup();

    var temp_file = try temp_dir.dir.createFile("config", .{});
    defer temp_file.close();
    try temp_file.writeAll(yaml_config);

    // Get temp file path
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const temp_path = try temp_dir.dir.realpath("config", &path_buf);

    // Parse kubeconfig
    var parser = klient.KubeconfigParser.init(allocator);
    var config = try parser.loadFromPath(temp_path);
    defer config.deinit(allocator);

    // Verify parsed data
    try std.testing.expectEqualStrings("test-context", config.current_context);
    try std.testing.expectEqual(@as(usize, 1), config.clusters.len);
    try std.testing.expectEqual(@as(usize, 1), config.contexts.len);
    try std.testing.expectEqual(@as(usize, 1), config.users.len);

    // Verify cluster
    const cluster = config.clusters[0];
    try std.testing.expectEqualStrings("test-cluster", cluster.name);
    try std.testing.expectEqualStrings("https://kubernetes.example.com:6443", cluster.server);
    try std.testing.expectEqualStrings("Y2EtZGF0YQ==", cluster.certificate_authority_data.?);

    // Verify context
    const context = config.contexts[0];
    try std.testing.expectEqualStrings("test-context", context.name);
    try std.testing.expectEqualStrings("test-cluster", context.cluster);
    try std.testing.expectEqualStrings("test-user", context.user);
    try std.testing.expectEqualStrings("default", context.namespace.?);

    // Verify user
    const user = config.users[0];
    try std.testing.expectEqualStrings("test-user", user.name);
    try std.testing.expectEqualStrings("my-bearer-token", user.token.?);

    std.debug.print("✅ YAML kubeconfig parsing test passed\n", .{});
}

test "KubeconfigParser - Get methods" {
    const allocator = std.testing.allocator;

    const yaml_config =
        \\apiVersion: v1
        \\kind: Config
        \\current-context: prod-context
        \\clusters:
        \\- name: prod-cluster
        \\  cluster:
        \\    server: https://prod.example.com:6443
        \\contexts:
        \\- name: prod-context
        \\  context:
        \\    cluster: prod-cluster
        \\    user: prod-user
        \\users:
        \\- name: prod-user
        \\  user:
        \\    client-certificate-data: Y2VydC1kYXRh
        \\    client-key-data: a2V5LWRhdGE=
    ;

    var temp_dir = std.testing.tmpDir(.{});
    defer temp_dir.cleanup();

    var temp_file = try temp_dir.dir.createFile("config", .{});
    defer temp_file.close();
    try temp_file.writeAll(yaml_config);

    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const temp_path = try temp_dir.dir.realpath("config", &path_buf);

    var parser = klient.KubeconfigParser.init(allocator);
    var config = try parser.loadFromPath(temp_path);
    defer config.deinit(allocator);

    // Test getCurrentContext
    const current_ctx = config.getCurrentContext().?;
    try std.testing.expectEqualStrings("prod-context", current_ctx.name);
    try std.testing.expectEqualStrings("prod-cluster", current_ctx.cluster);

    // Test getClusterByName
    const cluster = config.getClusterByName("prod-cluster").?;
    try std.testing.expectEqualStrings("https://prod.example.com:6443", cluster.server);

    // Test getUserByName
    const user = config.getUserByName("prod-user").?;
    try std.testing.expectEqualStrings("Y2VydC1kYXRh", user.client_certificate_data.?);
    try std.testing.expectEqualStrings("a2V5LWRhdGE=", user.client_key_data.?);

    std.debug.print("✅ YAML kubeconfig get methods test passed\n", .{});
}
