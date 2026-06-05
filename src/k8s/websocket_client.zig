const std = @import("std");
const crypto = std.crypto;
const tls = @import("tls.zig");

/// WebSocket client for the Kubernetes streaming protocol (SPDY channel framing
/// over WebSocket). Used for: exec, attach, port-forward.
///
/// Zig 0.16: all I/O is threaded through `std.Io`. The HTTP/1.1 Upgrade handshake
/// is performed with `std.http.Client`; after the 101 response the underlying
/// TLS-aware `Connection` is kept alive for raw WebSocket frame I/O.
pub const WebSocketClient = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    api_server: []const u8,
    token: ?[]const u8,
    ca_cert_data: ?[]const u8,
    http_client: std.http.Client,

    pub fn init(
        allocator: std.mem.Allocator,
        io: std.Io,
        api_server: []const u8,
        token: ?[]const u8,
        ca_cert_data: ?[]const u8,
    ) !WebSocketClient {
        var http_client = std.http.Client{ .allocator = allocator, .io = io };
        const now = std.Io.Timestamp.now(io, .real);
        http_client.ca_bundle.rescan(allocator, io, now) catch {};
        http_client.now = now;

        const api_server_owned = try allocator.dupe(u8, api_server);
        errdefer allocator.free(api_server_owned);
        const token_owned = if (token) |t| try allocator.dupe(u8, t) else null;
        errdefer if (token_owned) |t| allocator.free(t);
        const ca_owned = if (ca_cert_data) |ca| try allocator.dupe(u8, ca) else null;
        errdefer if (ca_owned) |c| allocator.free(c);

        // Load the cluster CA so wss:// to a private-CA API server verifies the
        // server certificate (previously the CA was ignored — a TLS trust gap).
        if (ca_owned) |ca| {
            try tls.addCaCertData(&http_client, allocator, io, now, ca);
        }

        return WebSocketClient{
            .allocator = allocator,
            .io = io,
            .api_server = api_server_owned,
            .token = token_owned,
            .ca_cert_data = ca_owned,
            .http_client = http_client,
        };
    }

    pub fn deinit(self: *WebSocketClient) void {
        self.allocator.free(self.api_server);
        if (self.token) |t| self.allocator.free(t);
        if (self.ca_cert_data) |ca| self.allocator.free(ca);
        self.http_client.deinit();
    }

    /// Connect to a Kubernetes streaming endpoint, performing the WebSocket
    /// (RFC 6455) handshake with the given subprotocol (e.g. "v4.channel.k8s.io").
    pub fn connect(
        self: *WebSocketClient,
        path: []const u8,
        subprotocol: []const u8,
    ) !WebSocketConnection {
        const ws_url = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ self.api_server, path });
        defer self.allocator.free(ws_url);
        const uri = try std.Uri.parse(ws_url);

        // RFC 6455 §4.1: random 16-byte nonce, base64-encoded.
        var key_bytes: [16]u8 = undefined;
        try self.io.randomSecure(&key_bytes);
        var ws_key: [24]u8 = undefined;
        _ = std.base64.standard.Encoder.encode(&ws_key, &key_bytes);

        var auth_buf: ?[]u8 = null;
        defer if (auth_buf) |b| self.allocator.free(b);

        var extra: [6]std.http.Header = undefined;
        var n: usize = 0;
        extra[n] = .{ .name = "Upgrade", .value = "websocket" };
        n += 1;
        extra[n] = .{ .name = "Connection", .value = "Upgrade" };
        n += 1;
        extra[n] = .{ .name = "Sec-WebSocket-Version", .value = "13" };
        n += 1;
        extra[n] = .{ .name = "Sec-WebSocket-Key", .value = &ws_key };
        n += 1;
        extra[n] = .{ .name = "Sec-WebSocket-Protocol", .value = subprotocol };
        n += 1;
        if (self.token) |token| {
            auth_buf = try std.fmt.allocPrint(self.allocator, "Bearer {s}", .{token});
            extra[n] = .{ .name = "Authorization", .value = auth_buf.? };
            n += 1;
        }

        var req = try self.http_client.request(.GET, uri, .{
            .keep_alive = false,
            // We emit "Connection: Upgrade" via extra_headers; suppress the auto header.
            .headers = .{ .connection = .omit },
            .extra_headers = extra[0..n],
        });
        errdefer req.deinit();

        try req.sendBodiless();

        var redirect_buf: [4096]u8 = undefined;
        const response = try req.receiveHead(&redirect_buf);
        if (response.head.status != .switching_protocols) {
            return error.WebSocketHandshakeFailed;
        }

        // Verify Sec-WebSocket-Accept (RFC 6455 §4.2.2).
        var accept_value: ?[]const u8 = null;
        var hit = response.head.iterateHeaders();
        while (hit.next()) |h| {
            if (std.ascii.eqlIgnoreCase(h.name, "sec-websocket-accept")) {
                accept_value = h.value;
                break;
            }
        }
        const accept_header = accept_value orelse return error.MissingAcceptHeader;

        var hasher = crypto.hash.Sha1.init(.{});
        hasher.update(&ws_key);
        hasher.update("258EAFA5-E914-47DA-95CA-C5AB0DC85B11"); // RFC 6455 magic GUID
        var hash: [20]u8 = undefined;
        hasher.final(&hash);
        var expected_accept: [28]u8 = undefined;
        _ = std.base64.standard.Encoder.encode(&expected_accept, &hash);
        if (!std.mem.eql(u8, accept_header, &expected_accept)) {
            return error.InvalidAcceptHeader;
        }

        return WebSocketConnection{
            .allocator = self.allocator,
            .io = self.io,
            .req = req,
            .subprotocol = try self.allocator.dupe(u8, subprotocol),
            .connected = true,
            .read_buffer = .empty,
            .write_buffer = .empty,
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

/// Maximum WebSocket frame payload we will buffer (defends against a malicious
/// cluster advertising a huge length to force an unbounded allocation).
const max_frame_payload: u64 = 16 * 1024 * 1024;

/// WebSocket connection for Kubernetes streaming.
/// Holds the upgraded HTTP request alive so its TLS-aware connection can be used
/// for raw frame I/O; releasing `req` (in deinit) tears the connection down.
pub const WebSocketConnection = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    req: std.http.Client.Request,
    subprotocol: []const u8,
    connected: bool,
    read_buffer: std.ArrayList(u8),
    write_buffer: std.ArrayList(u8),

    fn connWriter(self: *WebSocketConnection) *std.Io.Writer {
        return self.req.connection.?.writer();
    }

    fn connReader(self: *WebSocketConnection) *std.Io.Reader {
        return self.req.connection.?.reader();
    }

    pub fn deinit(self: *WebSocketConnection) void {
        self.allocator.free(self.subprotocol);
        self.read_buffer.deinit(self.allocator);
        self.write_buffer.deinit(self.allocator);
        // Releasing the (non-keep-alive) request closes the upgraded connection.
        self.req.deinit();
        self.connected = false;
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

        // Generate masking key (RFC 6455 §5.3 requires client frames be masked
        // with an unpredictable key).
        var masking_key: [4]u8 = undefined;
        try self.io.randomSecure(&masking_key);
        try self.write_buffer.appendSlice(self.allocator, &masking_key);

        // Mask and append payload
        const payload_start = self.write_buffer.items.len;
        try self.write_buffer.appendSlice(self.allocator, payload);
        for (self.write_buffer.items[payload_start..], 0..) |*byte, i| {
            byte.* ^= masking_key[i % 4];
        }

        // Send frame over the (TLS-aware) connection and flush.
        const w = self.connWriter();
        try w.writeAll(self.write_buffer.items);
        try self.req.connection.?.flush();
    }

    /// Receive a WebSocket frame
    fn receiveFrame(self: *WebSocketConnection) !struct { opcode: OpCode, payload: []const u8 } {
        if (!self.connected) return error.NotConnected;

        // Clear read buffer
        self.read_buffer.clearRetainingCapacity();

        const r = self.connReader();

        // Read frame header (first 2 bytes)
        var header: [2]u8 = undefined;
        try r.readSliceAll(&header);

        // Parse header
        const fin = (header[0] & 0x80) != 0;
        const opcode = @as(OpCode, @enumFromInt(header[0] & 0x0F));
        const masked = (header[1] & 0x80) != 0;
        var payload_len: u64 = header[1] & 0x7F;

        // Extended payload length
        if (payload_len == 126) {
            var len_bytes: [2]u8 = undefined;
            try r.readSliceAll(&len_bytes);
            payload_len = std.mem.readInt(u16, &len_bytes, .big);
        } else if (payload_len == 127) {
            var len_bytes: [8]u8 = undefined;
            try r.readSliceAll(&len_bytes);
            payload_len = std.mem.readInt(u64, &len_bytes, .big);
        }

        // Bound the advertised length so a malicious server cannot force an
        // unbounded allocation.
        if (payload_len > max_frame_payload) return error.FrameTooLarge;

        // Read masking key (if masked)
        var masking_key: [4]u8 = undefined;
        if (masked) {
            try r.readSliceAll(&masking_key);
        }

        // Read the full payload.
        try self.read_buffer.resize(self.allocator, @intCast(payload_len));
        try r.readSliceAll(self.read_buffer.items);

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

    /// Close the WebSocket connection (sends a close frame). The underlying
    /// connection is torn down in deinit() via req.deinit().
    pub fn close(self: *WebSocketConnection) void {
        if (!self.connected) return;

        // Send close frame (best-effort).
        self.sendFrame(.close, &[_]u8{}) catch {};
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
