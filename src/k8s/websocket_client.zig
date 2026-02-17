const std = @import("std");
const crypto = std.crypto;

/// WebSocket client for Kubernetes SPDY protocol
/// Implements the Kubernetes WebSocket streaming protocol with SPDY framing
/// Used for: exec, attach, port-forward operations
pub const WebSocketClient = struct {
    allocator: std.mem.Allocator,
    api_server: []const u8,
    token: ?[]const u8,
    ca_cert_data: ?[]const u8,
    http_client: std.http.Client,

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
            .http_client = std.http.Client{
                .allocator = allocator,
                .read_buffer_size = 4096,
                .write_buffer_size = 4096,
            },
        };
    }

    pub fn deinit(self: *WebSocketClient) void {
        self.allocator.free(self.api_server);
        if (self.token) |t| self.allocator.free(t);
        if (self.ca_cert_data) |ca| self.allocator.free(ca);
        self.http_client.deinit();
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

        // Generate WebSocket key
        var key_bytes: [16]u8 = undefined;
        crypto.random.bytes(&key_bytes);
        var ws_key: [24]u8 = undefined;
        _ = std.base64.standard.Encoder.encode(&ws_key, &key_bytes);

        // Build request headers
        var headers = std.http.Headers{ .allocator = self.allocator };
        defer headers.deinit();

        try headers.append("Upgrade", "websocket");
        try headers.append("Connection", "Upgrade");
        try headers.append("Sec-WebSocket-Version", "13");
        try headers.append("Sec-WebSocket-Key", &ws_key);
        try headers.append("Sec-WebSocket-Protocol", subprotocol);

        if (self.token) |token| {
            const auth_header = try std.fmt.allocPrint(self.allocator, "Bearer {s}", .{token});
            defer self.allocator.free(auth_header);
            try headers.append("Authorization", auth_header);
        }

        // Perform WebSocket handshake
        var req = try self.http_client.open(.GET, uri, headers, .{});
        defer req.deinit();

        try req.send(.{});
        try req.wait();

        // Verify handshake response
        if (req.response.status != .switching_protocols) {
            return error.WebSocketHandshakeFailed;
        }

        // Verify Sec-WebSocket-Accept header
        const accept_header = req.response.headers.getFirstValue("Sec-WebSocket-Accept") orelse return error.MissingAcceptHeader;

        // Calculate expected accept value
        var hasher = crypto.hash.Sha1.init(.{});
        hasher.update(&ws_key);
        hasher.update("258EAFA5-E914-47DA-95CA-C5AB0DC85B11"); // RFC 6455 Section 4.2.2 magic GUID
        var hash: [20]u8 = undefined;
        hasher.final(&hash);
        var expected_accept: [28]u8 = undefined;
        _ = std.base64.standard.Encoder.encode(&expected_accept, &hash);

        if (!std.mem.eql(u8, accept_header, &expected_accept)) {
            return error.InvalidAcceptHeader;
        }

        return WebSocketConnection{
            .allocator = self.allocator,
            .uri = uri,
            .token = self.token,
            .subprotocol = try self.allocator.dupe(u8, subprotocol),
            .connected = true,
            .stream = req.connection.?,
            .read_buffer = try std.ArrayList(u8).initCapacity(self.allocator, 4096),
            .write_buffer = try std.ArrayList(u8).initCapacity(self.allocator, 4096),
        };
    }
};

/// WebSocket frame opcode
pub const OpCode = enum(u8) {
    continuation = 0x0,
    text = 0x1,
    binary = 0x2,
    close = 0x8,
    ping = 0x9,
    pong = 0xA,
};

/// WebSocket connection for Kubernetes streaming
pub const WebSocketConnection = struct {
    allocator: std.mem.Allocator,
    uri: std.Uri,
    token: ?[]const u8,
    subprotocol: []const u8,
    connected: bool,
    stream: std.net.Stream,
    read_buffer: std.ArrayList(u8),
    write_buffer: std.ArrayList(u8),

    pub fn deinit(self: *WebSocketConnection) void {
        self.allocator.free(self.subprotocol);
        self.read_buffer.deinit(self.allocator);
        self.write_buffer.deinit(self.allocator);
        if (self.connected) {
            self.stream.close();
        }
    }

    /// Send a WebSocket frame
    fn sendFrame(self: *WebSocketConnection, opcode: OpCode, payload: []const u8) !void {
        if (!self.connected) return error.NotConnected;

        // Clear write buffer
        self.write_buffer.clearRetainingCapacity();

        // Build WebSocket frame header
        const fin: u8 = 0x80; // FIN bit set
        const header_byte1 = fin | @intFromEnum(opcode);
        try self.write_buffer.append(self.allocator, header_byte1);

        // Payload length and masking (RFC 6455 Section 5.2 - network byte order / big-endian)
        const mask_bit: u8 = 0x80; // Client must mask
        if (payload.len < 126) {
            const len_byte = @as(u8, @intCast(payload.len)) | mask_bit;
            try self.write_buffer.append(self.allocator, len_byte);
        } else if (payload.len <= 65535) {
            try self.write_buffer.append(self.allocator, 126 | mask_bit);
            var len_bytes: [2]u8 = undefined;
            std.mem.writeInt(u16, &len_bytes, @intCast(payload.len), .big);
            try self.write_buffer.appendSlice(self.allocator, &len_bytes);
        } else {
            try self.write_buffer.append(self.allocator, 127 | mask_bit);
            var len_bytes: [8]u8 = undefined;
            std.mem.writeInt(u64, &len_bytes, @intCast(payload.len), .big);
            try self.write_buffer.appendSlice(self.allocator, &len_bytes);
        }

        // Generate masking key
        var masking_key: [4]u8 = undefined;
        crypto.random.bytes(&masking_key);
        try self.write_buffer.appendSlice(self.allocator, &masking_key);

        // Mask and append payload
        const payload_start = self.write_buffer.items.len;
        try self.write_buffer.appendSlice(self.allocator, payload);
        for (self.write_buffer.items[payload_start..], 0..) |*byte, i| {
            byte.* ^= masking_key[i % 4];
        }

        // Send frame
        try self.stream.writeAll(self.write_buffer.items);
    }

    /// Receive a WebSocket frame
    fn receiveFrame(self: *WebSocketConnection) !struct { opcode: OpCode, payload: []const u8 } {
        if (!self.connected) return error.NotConnected;

        // Clear read buffer
        self.read_buffer.clearRetainingCapacity();

        // Read frame header (first 2 bytes)
        var header: [2]u8 = undefined;
        const bytes_read = try self.stream.read(&header);
        if (bytes_read < 2) return error.ConnectionClosed;

        // Parse header
        const fin = (header[0] & 0x80) != 0;
        const opcode = @as(OpCode, @enumFromInt(header[0] & 0x0F));
        const masked = (header[1] & 0x80) != 0;
        var payload_len: u64 = header[1] & 0x7F;

        // Extended payload length
        if (payload_len == 126) {
            var len_bytes: [2]u8 = undefined;
            _ = try self.stream.read(&len_bytes);
            payload_len = std.mem.readInt(u16, &len_bytes, .big);
        } else if (payload_len == 127) {
            var len_bytes: [8]u8 = undefined;
            _ = try self.stream.read(&len_bytes);
            payload_len = std.mem.readInt(u64, &len_bytes, .big);
        }

        // Read masking key (if masked)
        var masking_key: [4]u8 = undefined;
        if (masked) {
            _ = try self.stream.read(&masking_key);
        }

        // Read payload (loop to handle partial reads)
        try self.read_buffer.resize(self.allocator, payload_len);
        var total_read: usize = 0;
        while (total_read < payload_len) {
            const bytes = try self.stream.read(self.read_buffer.items[total_read..]);
            if (bytes == 0) return error.ConnectionClosed;
            total_read += bytes;
        }

        // Unmask payload (if masked)
        if (masked) {
            for (self.read_buffer.items, 0..) |*byte, i| {
                byte.* ^= masking_key[i % 4];
            }
        }

        if (!fin) {
            // Handle fragmented frames (not common in Kubernetes)
            return error.FragmentedFramesNotSupported;
        }

        return .{
            .opcode = opcode,
            .payload = self.read_buffer.items,
        };
    }

    /// Send data on a specific SPDY channel
    pub fn sendChannel(self: *WebSocketConnection, channel: u8, data: []const u8) !void {
        if (!self.connected) return error.NotConnected;

        // SPDY frame format: [channel byte][data...]
        var frame = try self.allocator.alloc(u8, data.len + 1);
        defer self.allocator.free(frame);

        frame[0] = channel;
        @memcpy(frame[1..], data);

        // Send as binary WebSocket frame
        try self.sendFrame(.binary, frame);
    }

    /// Receive data from any channel
    pub fn receive(self: *WebSocketConnection) !ChannelMessage {
        if (!self.connected) return error.NotConnected;

        const frame = try self.receiveFrame();

        // Handle control frames
        switch (frame.opcode) {
            .close => {
                self.connected = false;
                return error.ConnectionClosed;
            },
            .ping => {
                try self.sendFrame(.pong, frame.payload);
                return try self.receive(); // Receive next frame
            },
            .pong => {
                return try self.receive(); // Receive next frame
            },
            .binary, .text => {
                // Parse SPDY frame
                if (frame.payload.len < 1) return error.InvalidSPDYFrame;

                const channel = frame.payload[0];
                const data = try self.allocator.dupe(u8, frame.payload[1..]);

                return ChannelMessage{
                    .channel = channel,
                    .data = data,
                };
            },
            else => return error.UnexpectedFrameType,
        }
    }

    /// Close the WebSocket connection
    pub fn close(self: *WebSocketConnection) void {
        if (!self.connected) return;

        // Send close frame
        self.sendFrame(.close, &[_]u8{}) catch {};
        self.connected = false;
        self.stream.close();
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
    var query_parts = try std.ArrayList([]const u8).initCapacity(allocator, 0);
    defer {
        for (query_parts.items) |part| allocator.free(part);
        query_parts.deinit(allocator);
    }

    // Add command parts
    for (command) |cmd| {
        const part = try std.fmt.allocPrint(allocator, "command={s}", .{cmd});
        try query_parts.append(allocator, part);
    }

    // Add stream options
    if (options.stdin) try query_parts.append(allocator, try allocator.dupe(u8, "stdin=true"));
    if (options.stdout) try query_parts.append(allocator, try allocator.dupe(u8, "stdout=true"));
    if (options.stderr) try query_parts.append(allocator, try allocator.dupe(u8, "stderr=true"));
    if (options.tty) try query_parts.append(allocator, try allocator.dupe(u8, "tty=true"));

    if (options.container) |container| {
        const part = try std.fmt.allocPrint(allocator, "container={s}", .{container});
        try query_parts.append(allocator, part);
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
    var query_parts = try std.ArrayList([]const u8).initCapacity(allocator, 0);
    defer {
        for (query_parts.items) |part| allocator.free(part);
        query_parts.deinit(allocator);
    }

    if (options.stdin) try query_parts.append(allocator, try allocator.dupe(u8, "stdin=true"));
    if (options.stdout) try query_parts.append(allocator, try allocator.dupe(u8, "stdout=true"));
    if (options.stderr) try query_parts.append(allocator, try allocator.dupe(u8, "stderr=true"));
    if (options.tty) try query_parts.append(allocator, try allocator.dupe(u8, "tty=true"));

    if (options.container) |container| {
        const part = try std.fmt.allocPrint(allocator, "container={s}", .{container});
        try query_parts.append(allocator, part);
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
    var query_parts = try std.ArrayList([]const u8).initCapacity(allocator, 0);
    defer {
        for (query_parts.items) |part| allocator.free(part);
        query_parts.deinit(allocator);
    }

    for (ports) |port| {
        const part = try std.fmt.allocPrint(allocator, "ports={d}", .{port});
        try query_parts.append(allocator, part);
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
