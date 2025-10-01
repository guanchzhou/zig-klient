const std = @import("std");
const klient = @import("klient");
const ws = klient.websocket;

test "WebSocket - Channel enum values" {
    try std.testing.expectEqual(0, ws.Channel.stdin.toInt());
    try std.testing.expectEqual(1, ws.Channel.stdout.toInt());
    try std.testing.expectEqual(2, ws.Channel.stderr.toInt());
    try std.testing.expectEqual(3, ws.Channel.error_stream.toInt());
    try std.testing.expectEqual(4, ws.Channel.resize.toInt());

    std.debug.print("✅ WebSocket channel enum test passed\n", .{});
}

test "WebSocket - Subprotocol strings" {
    try std.testing.expectEqualStrings("v4.channel.k8s.io", ws.Subprotocol.v4_channel.toString());
    try std.testing.expectEqualStrings("v4.base64.channel.k8s.io", ws.Subprotocol.v4_base64_channel.toString());
    try std.testing.expectEqualStrings("v5.channel.k8s.io", ws.Subprotocol.v5_channel.toString());

    std.debug.print("✅ WebSocket subprotocol test passed\n", .{});
}

test "WebSocket - Build exec path with simple command" {
    const allocator = std.testing.allocator;

    const command = [_][]const u8{ "ls", "-la" };
    const path = try ws.buildExecPath(allocator, "default", "my-pod", &command, .{
        .stdout = true,
        .stderr = true,
    });
    defer allocator.free(path);

    // Verify path contains expected components
    try std.testing.expect(std.mem.containsAtLeast(u8, path, 1, "/api/v1/namespaces/default/pods/my-pod/exec"));
    try std.testing.expect(std.mem.containsAtLeast(u8, path, 1, "command=ls"));
    try std.testing.expect(std.mem.containsAtLeast(u8, path, 1, "command=-la"));
    try std.testing.expect(std.mem.containsAtLeast(u8, path, 1, "stdout=true"));
    try std.testing.expect(std.mem.containsAtLeast(u8, path, 1, "stderr=true"));

    std.debug.print("✅ Exec path builder test passed\n", .{});
}

test "WebSocket - Build exec path with stdin and container" {
    const allocator = std.testing.allocator;

    const command = [_][]const u8{"sh"};
    const path = try ws.buildExecPath(allocator, "production", "app-pod", &command, .{
        .stdin = true,
        .stdout = true,
        .tty = true,
        .container = "nginx",
    });
    defer allocator.free(path);

    try std.testing.expect(std.mem.containsAtLeast(u8, path, 1, "/api/v1/namespaces/production/pods/app-pod/exec"));
    try std.testing.expect(std.mem.containsAtLeast(u8, path, 1, "stdin=true"));
    try std.testing.expect(std.mem.containsAtLeast(u8, path, 1, "tty=true"));
    try std.testing.expect(std.mem.containsAtLeast(u8, path, 1, "container=nginx"));

    std.debug.print("✅ Exec path with stdin and container test passed\n", .{});
}

test "WebSocket - Build attach path" {
    const allocator = std.testing.allocator;

    const path = try ws.buildAttachPath(allocator, "default", "my-pod", .{
        .stdin = true,
        .stdout = true,
        .stderr = true,
        .tty = false,
    });
    defer allocator.free(path);

    try std.testing.expect(std.mem.containsAtLeast(u8, path, 1, "/api/v1/namespaces/default/pods/my-pod/attach"));
    try std.testing.expect(std.mem.containsAtLeast(u8, path, 1, "stdin=true"));
    try std.testing.expect(std.mem.containsAtLeast(u8, path, 1, "stdout=true"));
    try std.testing.expect(std.mem.containsAtLeast(u8, path, 1, "stderr=true"));

    std.debug.print("✅ Attach path builder test passed\n", .{});
}

test "WebSocket - Build port-forward path with single port" {
    const allocator = std.testing.allocator;

    const ports = [_]u16{8080};
    const path = try ws.buildPortForwardPath(allocator, "default", "my-pod", &ports);
    defer allocator.free(path);

    try std.testing.expect(std.mem.containsAtLeast(u8, path, 1, "/api/v1/namespaces/default/pods/my-pod/portforward"));
    try std.testing.expect(std.mem.containsAtLeast(u8, path, 1, "ports=8080"));

    std.debug.print("✅ Port-forward path with single port test passed\n", .{});
}

test "WebSocket - Build port-forward path with multiple ports" {
    const allocator = std.testing.allocator;

    const ports = [_]u16{ 8080, 5432, 3306 };
    const path = try ws.buildPortForwardPath(allocator, "production", "db-pod", &ports);
    defer allocator.free(path);

    try std.testing.expect(std.mem.containsAtLeast(u8, path, 1, "/api/v1/namespaces/production/pods/db-pod/portforward"));
    try std.testing.expect(std.mem.containsAtLeast(u8, path, 1, "ports=8080"));
    try std.testing.expect(std.mem.containsAtLeast(u8, path, 1, "ports=5432"));
    try std.testing.expect(std.mem.containsAtLeast(u8, path, 1, "ports=3306"));

    std.debug.print("✅ Port-forward path with multiple ports test passed\n", .{});
}

test "WebSocket - ExecOptions structure" {
    const command = [_][]const u8{ "echo", "hello" };
    const options = klient.ExecOptions{
        .command = &command,
        .stdin = false,
        .stdout = true,
        .stderr = true,
        .tty = false,
        .container = "nginx",
        .stdin_data = null,
    };

    try std.testing.expectEqual(false, options.stdin);
    try std.testing.expectEqual(true, options.stdout);
    try std.testing.expectEqualStrings("nginx", options.container.?);

    std.debug.print("✅ ExecOptions structure test passed\n", .{});
}

test "WebSocket - AttachOptions structure" {
    const options = klient.AttachOptions{
        .stdin = true,
        .stdout = true,
        .stderr = true,
        .tty = true,
        .container = "app",
    };

    try std.testing.expectEqual(true, options.stdin);
    try std.testing.expectEqual(true, options.tty);
    try std.testing.expectEqualStrings("app", options.container.?);

    std.debug.print("✅ AttachOptions structure test passed\n", .{});
}

test "WebSocket - PortMapping structure" {
    const mapping = klient.PortMapping{
        .local = 8080,
        .remote = 80,
    };

    try std.testing.expectEqual(@as(u16, 8080), mapping.local);
    try std.testing.expectEqual(@as(u16, 80), mapping.remote);

    std.debug.print("✅ PortMapping structure test passed\n", .{});
}

test "WebSocket - PortForwardOptions with multiple mappings" {
    const mappings = [_]klient.PortMapping{
        .{ .local = 8080, .remote = 80 },
        .{ .local = 5432, .remote = 5432 },
        .{ .local = 3306, .remote = 3306 },
    };

    const options = klient.PortForwardOptions{
        .ports = &mappings,
    };

    try std.testing.expectEqual(@as(usize, 3), options.ports.len);
    try std.testing.expectEqual(@as(u16, 8080), options.ports[0].local);
    try std.testing.expectEqual(@as(u16, 80), options.ports[0].remote);

    std.debug.print("✅ PortForwardOptions test passed\n", .{});
}
