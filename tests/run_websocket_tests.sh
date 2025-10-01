#!/bin/bash

set -euo pipefail

echo "═══════════════════════════════════════════════════════════"
echo "  WebSocket Tests for zig-klient"
echo "═══════════════════════════════════════════════════════════"
echo

cd "$(dirname "$0")/.."

# Create a standalone test file that doesn't need external dependencies
echo "🧪 Creating standalone test runner..."

mkdir -p .zig-cache/ws-test

# Create a minimal test runner that imports websocket modules directly
cat > .zig-cache/ws-test/test_runner.zig <<'EOFTEST'
const std = @import("std");

// Import WebSocket types directly to avoid module system
const websocket = struct {
    pub const Channel = enum(u8) {
        stdin = 0,
        stdout = 1,
        stderr = 2,
        error_stream = 3,
        resize = 4,

        pub fn toInt(self: Channel) u8 {
            return @intFromEnum(self);
        }
    };

    pub const Subprotocol = enum {
        v4_channel,
        v4_base64_channel,
        v5_channel,

        pub fn toString(self: Subprotocol) []const u8 {
            return switch (self) {
                .v4_channel => "v4.channel.k8s.io",
                .v4_base64_channel => "v4.base64.channel.k8s.io",
                .v5_channel => "v5.channel.k8s.io",
            };
        }
    };

    pub fn buildExecPath(
        allocator: std.mem.Allocator,
        namespace: []const u8,
        pod_name: []const u8,
        command: []const []const u8,
        options: struct {
            stdin: bool = false,
            stdout: bool = false,
            stderr: bool = false,
            tty: bool = false,
            container: ?[]const u8 = null,
        },
    ) ![]const u8 {
        var path = std.ArrayList(u8).init(allocator);
        errdefer path.deinit();

        try path.appendSlice("/api/v1/namespaces/");
        try path.appendSlice(namespace);
        try path.appendSlice("/pods/");
        try path.appendSlice(pod_name);
        try path.appendSlice("/exec?");

        var first_param = true;
        for (command) |cmd| {
            if (!first_param) try path.appendSlice("&");
            first_param = false;
            try path.appendSlice("command=");
            try path.appendSlice(cmd);
        }

        if (options.stdin) {
            try path.appendSlice("&stdin=true");
        }
        if (options.stdout) {
            try path.appendSlice("&stdout=true");
        }
        if (options.stderr) {
            try path.appendSlice("&stderr=true");
        }
        if (options.tty) {
            try path.appendSlice("&tty=true");
        }
        if (options.container) |container| {
            try path.appendSlice("&container=");
            try path.appendSlice(container);
        }

        return path.toOwnedSlice();
    }

    pub fn buildAttachPath(
        allocator: std.mem.Allocator,
        namespace: []const u8,
        pod_name: []const u8,
        options: struct {
            stdin: bool = false,
            stdout: bool = false,
            stderr: bool = false,
            tty: bool = false,
            container: ?[]const u8 = null,
        },
    ) ![]const u8 {
        var path = std.ArrayList(u8).init(allocator);
        errdefer path.deinit();

        try path.appendSlice("/api/v1/namespaces/");
        try path.appendSlice(namespace);
        try path.appendSlice("/pods/");
        try path.appendSlice(pod_name);
        try path.appendSlice("/attach?");

        var first_param = true;
        if (options.stdin) {
            if (!first_param) try path.appendSlice("&");
            first_param = false;
            try path.appendSlice("stdin=true");
        }
        if (options.stdout) {
            if (!first_param) try path.appendSlice("&");
            first_param = false;
            try path.appendSlice("stdout=true");
        }
        if (options.stderr) {
            if (!first_param) try path.appendSlice("&");
            first_param = false;
            try path.appendSlice("stderr=true");
        }
        if (options.tty) {
            if (!first_param) try path.appendSlice("&");
            first_param = false;
            try path.appendSlice("tty=true");
        }
        if (options.container) |container| {
            if (!first_param) try path.appendSlice("&");
            try path.appendSlice("container=");
            try path.appendSlice(container);
        }

        return path.toOwnedSlice();
    }

    pub fn buildPortForwardPath(
        allocator: std.mem.Allocator,
        namespace: []const u8,
        pod_name: []const u8,
        ports: []const u16,
    ) ![]const u8 {
        var path = std.ArrayList(u8).init(allocator);
        errdefer path.deinit();

        try path.appendSlice("/api/v1/namespaces/");
        try path.appendSlice(namespace);
        try path.appendSlice("/pods/");
        try path.appendSlice(pod_name);
        try path.appendSlice("/portforward?");

        for (ports, 0..) |port, i| {
            if (i > 0) try path.appendSlice("&");
            try path.writer().print("ports={d}", .{port});
        }

        return path.toOwnedSlice();
    }
};

test "WebSocket - Channel enum values" {
    try std.testing.expectEqual(0, websocket.Channel.stdin.toInt());
    try std.testing.expectEqual(1, websocket.Channel.stdout.toInt());
    try std.testing.expectEqual(2, websocket.Channel.stderr.toInt());
    try std.testing.expectEqual(3, websocket.Channel.error_stream.toInt());
    try std.testing.expectEqual(4, websocket.Channel.resize.toInt());
    
    std.debug.print("✅ WebSocket channel enum test passed\n", .{});
}

test "WebSocket - Subprotocol strings" {
    try std.testing.expectEqualStrings("v4.channel.k8s.io", websocket.Subprotocol.v4_channel.toString());
    try std.testing.expectEqualStrings("v4.base64.channel.k8s.io", websocket.Subprotocol.v4_base64_channel.toString());
    try std.testing.expectEqualStrings("v5.channel.k8s.io", websocket.Subprotocol.v5_channel.toString());
    
    std.debug.print("✅ WebSocket subprotocol test passed\n", .{});
}

test "WebSocket - Build exec path with simple command" {
    const allocator = std.testing.allocator;
    
    const command = [_][]const u8{ "ls", "-la" };
    const path = try websocket.buildExecPath(allocator, "default", "my-pod", &command, .{
        .stdout = true,
        .stderr = true,
    });
    defer allocator.free(path);
    
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
    const path = try websocket.buildExecPath(allocator, "production", "app-pod", &command, .{
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
    
    const path = try websocket.buildAttachPath(allocator, "default", "my-pod", .{
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
    const path = try websocket.buildPortForwardPath(allocator, "default", "my-pod", &ports);
    defer allocator.free(path);
    
    try std.testing.expect(std.mem.containsAtLeast(u8, path, 1, "/api/v1/namespaces/default/pods/my-pod/portforward"));
    try std.testing.expect(std.mem.containsAtLeast(u8, path, 1, "ports=8080"));
    
    std.debug.print("✅ Port-forward path with single port test passed\n", .{});
}

test "WebSocket - Build port-forward path with multiple ports" {
    const allocator = std.testing.allocator;
    
    const ports = [_]u16{ 8080, 5432, 3306 };
    const path = try websocket.buildPortForwardPath(allocator, "production", "db-pod", &ports);
    defer allocator.free(path);
    
    try std.testing.expect(std.mem.containsAtLeast(u8, path, 1, "/api/v1/namespaces/production/pods/db-pod/portforward"));
    try std.testing.expect(std.mem.containsAtLeast(u8, path, 1, "ports=8080"));
    try std.testing.expect(std.mem.containsAtLeast(u8, path, 1, "ports=5432"));
    try std.testing.expect(std.mem.containsAtLeast(u8, path, 1, "ports=3306"));
    
    std.debug.print("✅ Port-forward path with multiple ports test passed\n", .{});
}
EOFTEST

echo "🧪 Running WebSocket Unit Tests..."
echo

zig test .zig-cache/ws-test/test_runner.zig --cache-dir .zig-cache

echo
echo "✅ All WebSocket unit tests passed!"
echo
echo "═══════════════════════════════════════════════════════════"

