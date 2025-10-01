const std = @import("std");

/// WebSocket client for Kubernetes SPDY protocol
/// Implements the Kubernetes WebSocket streaming protocol with SPDY framing
/// Used for: exec, attach, port-forward operations
pub const WebSocketClient = struct {
    allocator: std.mem.Allocator,
    api_server: []const u8,
    token: ?[]const u8,
    ca_cert_data: ?[]const u8,

    pub fn init(
        allocator: std.mem.Allocator,
        api_server: []const u8,
        token: ?[]const u8,
        ca_cert_data: ?[]const u8,
    ) !WebSocketClient {
        return WebSocketClient{
            .allocator = allocator,
            .api_server = try allocator.dupe(u8, api_server),
            .token = if (token) |t| try allocator.dupe(u8, t) else null,
            .ca_cert_data = if (ca_cert_data) |ca| try allocator.dupe(u8, ca) else null,
        };
    }

    pub fn deinit(self: *WebSocketClient) void {
        self.allocator.free(self.api_server);
        if (self.token) |t| self.allocator.free(t);
        if (self.ca_cert_data) |ca| self.allocator.free(ca);
    }

    /// Connect to WebSocket endpoint with Kubernetes SPDY protocol
    pub fn connect(
        self: *WebSocketClient,
        path: []const u8,
        subprotocol: []const u8,
    ) !WebSocketConnection {
        // Build WebSocket URL
        const ws_url = try std.fmt.allocPrint(
            self.allocator,
            "{s}{s}",
            .{ self.api_server, path },
        );
        defer self.allocator.free(ws_url);

        // Parse URL
        const uri = try std.Uri.parse(ws_url);

        // For now, return a placeholder connection
        // Full implementation will use websocket.zig library
        return WebSocketConnection{
            .allocator = self.allocator,
            .uri = uri,
            .token = self.token,
            .subprotocol = try self.allocator.dupe(u8, subprotocol),
            .connected = false,
        };
    }
};

/// WebSocket connection for Kubernetes streaming
pub const WebSocketConnection = struct {
    allocator: std.mem.Allocator,
    uri: std.Uri,
    token: ?[]const u8,
    subprotocol: []const u8,
    connected: bool,

    pub fn deinit(self: *WebSocketConnection) void {
        self.allocator.free(self.subprotocol);
    }

    /// Send data on a specific SPDY channel
    pub fn sendChannel(self: *WebSocketConnection, channel: u8, data: []const u8) !void {
        if (!self.connected) return error.NotConnected;

        // SPDY frame format: [channel byte][data...]
        var frame = try self.allocator.alloc(u8, data.len + 1);
        defer self.allocator.free(frame);

        frame[0] = channel;
        @memcpy(frame[1..], data);

        // TODO: Send frame via WebSocket
        // This will be implemented when websocket.zig is integrated
        // For now, just validate the frame was created
        if (frame.len == 0) return error.InvalidFrame;
    }

    /// Receive data from any channel
    pub fn receive(self: *WebSocketConnection) !ChannelMessage {
        if (!self.connected) return error.NotConnected;

        // TODO: Receive frame via WebSocket
        // This will be implemented when websocket.zig is integrated

        // Placeholder
        return ChannelMessage{
            .channel = 0,
            .data = try self.allocator.dupe(u8, ""),
        };
    }

    /// Close the WebSocket connection
    pub fn close(self: *WebSocketConnection) void {
        self.connected = false;
    }
};

/// Message received from a specific SPDY channel
pub const ChannelMessage = struct {
    channel: u8,
    data: []const u8,

    pub fn deinit(self: ChannelMessage, allocator: std.mem.Allocator) void {
        allocator.free(self.data);
    }
};

/// SPDY channel numbers used by Kubernetes
pub const Channel = enum(u8) {
    stdin = 0,
    stdout = 1,
    stderr = 2,
    error_stream = 3,
    resize = 4, // For TTY resize events

    pub fn toInt(self: Channel) u8 {
        return @intFromEnum(self);
    }
};

/// Build WebSocket path for exec operation
pub fn buildExecPath(
    allocator: std.mem.Allocator,
    namespace: []const u8,
    pod_name: []const u8,
    command: []const []const u8,
    options: ExecPathOptions,
) ![]const u8 {
    var query_parts = std.ArrayList([]const u8).init(allocator);
    defer {
        for (query_parts.items) |part| allocator.free(part);
        query_parts.deinit();
    }

    // Add command parts
    for (command) |cmd| {
        const part = try std.fmt.allocPrint(allocator, "command={s}", .{cmd});
        try query_parts.append(part);
    }

    // Add stream options
    if (options.stdin) try query_parts.append(try allocator.dupe(u8, "stdin=true"));
    if (options.stdout) try query_parts.append(try allocator.dupe(u8, "stdout=true"));
    if (options.stderr) try query_parts.append(try allocator.dupe(u8, "stderr=true"));
    if (options.tty) try query_parts.append(try allocator.dupe(u8, "tty=true"));

    if (options.container) |container| {
        const part = try std.fmt.allocPrint(allocator, "container={s}", .{container});
        try query_parts.append(part);
    }

    const query = try std.mem.join(allocator, "&", query_parts.items);
    defer allocator.free(query);

    return try std.fmt.allocPrint(
        allocator,
        "/api/v1/namespaces/{s}/pods/{s}/exec?{s}",
        .{ namespace, pod_name, query },
    );
}

pub const ExecPathOptions = struct {
    stdin: bool = false,
    stdout: bool = true,
    stderr: bool = true,
    tty: bool = false,
    container: ?[]const u8 = null,
};

/// Build WebSocket path for attach operation
pub fn buildAttachPath(
    allocator: std.mem.Allocator,
    namespace: []const u8,
    pod_name: []const u8,
    options: AttachPathOptions,
) ![]const u8 {
    var query_parts = std.ArrayList([]const u8).init(allocator);
    defer {
        for (query_parts.items) |part| allocator.free(part);
        query_parts.deinit();
    }

    if (options.stdin) try query_parts.append(try allocator.dupe(u8, "stdin=true"));
    if (options.stdout) try query_parts.append(try allocator.dupe(u8, "stdout=true"));
    if (options.stderr) try query_parts.append(try allocator.dupe(u8, "stderr=true"));
    if (options.tty) try query_parts.append(try allocator.dupe(u8, "tty=true"));

    if (options.container) |container| {
        const part = try std.fmt.allocPrint(allocator, "container={s}", .{container});
        try query_parts.append(part);
    }

    const query = try std.mem.join(allocator, "&", query_parts.items);
    defer allocator.free(query);

    return try std.fmt.allocPrint(
        allocator,
        "/api/v1/namespaces/{s}/pods/{s}/attach?{s}",
        .{ namespace, pod_name, query },
    );
}

pub const AttachPathOptions = struct {
    stdin: bool = false,
    stdout: bool = true,
    stderr: bool = true,
    tty: bool = false,
    container: ?[]const u8 = null,
};

/// Build WebSocket path for port-forward operation
pub fn buildPortForwardPath(
    allocator: std.mem.Allocator,
    namespace: []const u8,
    pod_name: []const u8,
    ports: []const u16,
) ![]const u8 {
    var query_parts = std.ArrayList([]const u8).init(allocator);
    defer {
        for (query_parts.items) |part| allocator.free(part);
        query_parts.deinit();
    }

    for (ports) |port| {
        const part = try std.fmt.allocPrint(allocator, "ports={d}", .{port});
        try query_parts.append(part);
    }

    const query = try std.mem.join(allocator, "&", query_parts.items);
    defer allocator.free(query);

    return try std.fmt.allocPrint(
        allocator,
        "/api/v1/namespaces/{s}/pods/{s}/portforward?{s}",
        .{ namespace, pod_name, query },
    );
}

/// Kubernetes WebSocket subprotocols
pub const Subprotocol = enum {
    /// SPDY version 4 with channel support
    v4_channel,
    /// Base64-encoded SPDY
    v4_base64_channel,
    /// Latest version
    v5_channel,

    pub fn toString(self: Subprotocol) []const u8 {
        return switch (self) {
            .v4_channel => "v4.channel.k8s.io",
            .v4_base64_channel => "v4.base64.channel.k8s.io",
            .v5_channel => "v5.channel.k8s.io",
        };
    }
};
