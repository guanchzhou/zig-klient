const std = @import("std");
const QueryWriter = @import("query.zig").QueryWriter;
const crypto = std.crypto;
const tls = @import("tls.zig");
const path_mod = @import("path.zig");

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
        if (token) |t| try path_mod.validateBearerToken(t);

        var http_client = std.http.Client{ .allocator = allocator, .io = io };
        errdefer http_client.deinit();
        const now = std.Io.Timestamp.now(io, .real);
        // A supplied cluster CA replaces the system roots rather than joining them.
        // Setting `now` is what stops std.http.Client from rescanning them lazily.
        if (ca_cert_data == null) http_client.ca_bundle.rescan(allocator, io, now) catch {};
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
        try path_mod.validateHeaderValue(subprotocol);
        const ws_url = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ self.api_server, path });
        defer self.allocator.free(ws_url);
        try path_mod.validateRequestUrl(ws_url);
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
            // Authorization is in extra_headers, which std.http.Client would replay
            // to whatever host a redirect names.
            .redirect_behavior = .not_allowed,
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

/// RFC 6455 §5.5: control frames carry at most 125 payload bytes and are never fragmented.
const max_control_payload: u64 = 125;

/// One decoded WebSocket frame. `payload` borrows the buffer passed to `readFrame`
/// and is valid until that buffer is next used.
pub const Frame = struct {
    opcode: OpCode,
    payload: []const u8,
};

/// Read and unmask one frame from a raw WebSocket byte stream into `buffer`.
///
/// Rejects reserved opcodes and RSV bits (no extension is negotiated), control
/// frames over 125 bytes or fragmented, payloads over 16 MiB, and fragmented data
/// frames.
pub fn readFrame(
    allocator: std.mem.Allocator,
    reader: *std.Io.Reader,
    buffer: *std.ArrayList(u8),
) !Frame {
    buffer.clearRetainingCapacity();

    var header: [2]u8 = undefined;
    try reader.readSliceAll(&header);

    const fin = (header[0] & 0x80) != 0;
    if ((header[0] & 0x70) != 0) return error.ReservedBitsSet;
    const raw_opcode: u4 = @truncate(header[0]);
    const opcode: OpCode = switch (raw_opcode) {
        0x0 => .continuation,
        0x1 => .text,
        0x2 => .binary,
        0x8 => .close,
        0x9 => .ping,
        0xA => .pong,
        else => return error.ReservedOpcode,
    };
    const masked = (header[1] & 0x80) != 0;
    var payload_len: u64 = header[1] & 0x7F;

    if ((raw_opcode & 0x8) != 0) {
        if (payload_len > max_control_payload) return error.ControlFrameTooLarge;
        if (!fin) return error.FragmentedControlFrame;
    }

    if (payload_len == 126) {
        var len_bytes: [2]u8 = undefined;
        try reader.readSliceAll(&len_bytes);
        payload_len = std.mem.readInt(u16, &len_bytes, .big);
    } else if (payload_len == 127) {
        var len_bytes: [8]u8 = undefined;
        try reader.readSliceAll(&len_bytes);
        payload_len = std.mem.readInt(u64, &len_bytes, .big);
    }

    // Bound the advertised length so a malicious server cannot force an
    // unbounded allocation.
    if (payload_len > max_frame_payload) return error.FrameTooLarge;

    var masking_key: [4]u8 = undefined;
    if (masked) try reader.readSliceAll(&masking_key);

    try buffer.resize(allocator, @intCast(payload_len));
    try reader.readSliceAll(buffer.items);

    if (masked) {
        for (buffer.items, 0..) |*byte, i| {
            byte.* ^= masking_key[i % 4];
        }
    }

    if (!fin) return error.FragmentedFramesNotSupported;

    return .{ .opcode = opcode, .payload = buffer.items };
}

/// Encode one masked client frame into `buffer` and write it to `writer`.
/// The caller flushes.
pub fn writeFrame(
    allocator: std.mem.Allocator,
    io: std.Io,
    writer: *std.Io.Writer,
    buffer: *std.ArrayList(u8),
    opcode: OpCode,
    payload: []const u8,
) !void {
    buffer.clearRetainingCapacity();

    const fin: u8 = 0x80;
    try buffer.append(allocator, fin | @backingInt(opcode));

    // RFC 6455 §5.2: network byte order; client frames must be masked.
    const mask_bit: u8 = 0x80;
    if (payload.len < 126) {
        try buffer.append(allocator, @as(u8, @intCast(payload.len)) | mask_bit);
    } else if (payload.len <= 65535) {
        try buffer.append(allocator, 126 | mask_bit);
        var len_bytes: [2]u8 = undefined;
        std.mem.writeInt(u16, &len_bytes, @intCast(payload.len), .big);
        try buffer.appendSlice(allocator, &len_bytes);
    } else {
        try buffer.append(allocator, 127 | mask_bit);
        var len_bytes: [8]u8 = undefined;
        std.mem.writeInt(u64, &len_bytes, @intCast(payload.len), .big);
        try buffer.appendSlice(allocator, &len_bytes);
    }

    // RFC 6455 §5.3 requires an unpredictable masking key.
    var masking_key: [4]u8 = undefined;
    try io.randomSecure(&masking_key);
    try buffer.appendSlice(allocator, &masking_key);

    const payload_start = buffer.items.len;
    try buffer.appendSlice(allocator, payload);
    for (buffer.items[payload_start..], 0..) |*byte, i| {
        byte.* ^= masking_key[i % 4];
    }

    try writer.writeAll(buffer.items);
}

/// Read frames until one carries a SPDY channel message. Pings are answered via
/// `pong(context, payload)`; control frames are consumed in a loop so a peer that
/// streams pings costs a pong each, never stack depth.
fn receiveChannelMessage(
    allocator: std.mem.Allocator,
    reader: *std.Io.Reader,
    read_buffer: *std.ArrayList(u8),
    context: anytype,
    pong: anytype,
) !ChannelMessage {
    while (true) {
        const frame = try readFrame(allocator, reader, read_buffer);
        switch (frame.opcode) {
            .close => return error.ConnectionClosed,
            .ping => try pong(context, frame.payload),
            .pong => {},
            .binary, .text => {
                if (frame.payload.len < 1) return error.InvalidSPDYFrame;
                return ChannelMessage{
                    .channel = frame.payload[0],
                    .data = try allocator.dupe(u8, frame.payload[1..]),
                };
            },
            .continuation => return error.UnexpectedFrameType,
        }
    }
}

/// `WebSocketConnection.receive` over an arbitrary raw WebSocket byte stream.
/// Pongs are written to `writer` and flushed. Caller owns the returned message.
pub fn receiveFromStream(
    allocator: std.mem.Allocator,
    io: std.Io,
    reader: *std.Io.Reader,
    writer: *std.Io.Writer,
) !ChannelMessage {
    var read_buffer: std.ArrayList(u8) = .empty;
    defer read_buffer.deinit(allocator);
    var write_buffer: std.ArrayList(u8) = .empty;
    defer write_buffer.deinit(allocator);

    const PongWriter = struct {
        allocator: std.mem.Allocator,
        io: std.Io,
        writer: *std.Io.Writer,
        buffer: *std.ArrayList(u8),

        fn pong(self: *const @This(), payload: []const u8) !void {
            try writeFrame(self.allocator, self.io, self.writer, self.buffer, .pong, payload);
            try self.writer.flush();
        }
    };
    const pong_writer: PongWriter = .{
        .allocator = allocator,
        .io = io,
        .writer = writer,
        .buffer = &write_buffer,
    };
    return receiveChannelMessage(allocator, reader, &read_buffer, &pong_writer, PongWriter.pong);
}

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
        try writeFrame(self.allocator, self.io, self.connWriter(), &self.write_buffer, opcode, payload);
        try self.req.connection.?.flush();
    }

    fn sendPong(self: *WebSocketConnection, payload: []const u8) !void {
        return self.sendFrame(.pong, payload);
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

        return receiveChannelMessage(
            self.allocator,
            self.connReader(),
            &self.read_buffer,
            self,
            sendPong,
        ) catch |err| {
            if (err == error.ConnectionClosed) self.connected = false;
            return err;
        };
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
        return @backingInt(self);
    }
};

/// Join a pod subresource path with an already-built query string.
///
/// Shared by exec / attach / port-forward, which previously each carried their own
/// copy of the ArrayList-join-allocPrint scaffold.
fn buildStreamPath(
    allocator: std.mem.Allocator,
    namespace: []const u8,
    pod_name: []const u8,
    subresource: []const u8,
    query: *QueryWriter,
) ![]const u8 {
    try path_mod.validatePathSegment(namespace);
    try path_mod.validatePathSegment(pod_name);
    try path_mod.validatePathSegment(subresource);

    const query_string = try query.toOwnedSlice();
    defer allocator.free(query_string);

    return std.fmt.allocPrint(
        allocator,
        "/api/v1/namespaces/{s}/pods/{s}/{s}?{s}",
        .{ namespace, pod_name, subresource, query_string },
    );
}

/// Build WebSocket path for exec operation.
///
/// Every value is percent-encoded via QueryWriter. These builders used to
/// interpolate raw: `exec(&.{"sh", "-c", "a && b"})` emitted spaces and a literal
/// `&`, which both malformed the URL and let a command string inject query
/// parameters the caller never asked for (e.g. a trailing `&stdin=true`).
pub fn buildExecPath(
    allocator: std.mem.Allocator,
    namespace: []const u8,
    pod_name: []const u8,
    command: []const []const u8,
    options: ExecPathOptions,
) ![]const u8 {
    var query = try QueryWriter.init(allocator);
    defer query.deinit();

    for (command) |cmd| try query.addString("command", cmd);
    try query.addBoolFlag("stdin", options.stdin);
    try query.addBoolFlag("stdout", options.stdout);
    try query.addBoolFlag("stderr", options.stderr);
    try query.addBoolFlag("tty", options.tty);
    try query.addOptionalString("container", options.container);

    return buildStreamPath(allocator, namespace, pod_name, "exec", &query);
}

pub const ExecPathOptions = struct {
    stdin: bool = false,
    stdout: bool = true,
    stderr: bool = true,
    tty: bool = false,
    container: ?[]const u8 = null,
};

/// Build WebSocket path for attach operation. See buildExecPath on encoding.
pub fn buildAttachPath(
    allocator: std.mem.Allocator,
    namespace: []const u8,
    pod_name: []const u8,
    options: AttachPathOptions,
) ![]const u8 {
    var query = try QueryWriter.init(allocator);
    defer query.deinit();

    try query.addBoolFlag("stdin", options.stdin);
    try query.addBoolFlag("stdout", options.stdout);
    try query.addBoolFlag("stderr", options.stderr);
    try query.addBoolFlag("tty", options.tty);
    try query.addOptionalString("container", options.container);

    return buildStreamPath(allocator, namespace, pod_name, "attach", &query);
}

pub const AttachPathOptions = struct {
    stdin: bool = false,
    stdout: bool = true,
    stderr: bool = true,
    tty: bool = false,
    container: ?[]const u8 = null,
};

/// Build WebSocket path for port-forward operation.
pub fn buildPortForwardPath(
    allocator: std.mem.Allocator,
    namespace: []const u8,
    pod_name: []const u8,
    ports: []const u16,
) ![]const u8 {
    var query = try QueryWriter.init(allocator);
    defer query.deinit();

    for (ports) |port| try query.addInt("ports", port);

    return buildStreamPath(allocator, namespace, pod_name, "portforward", &query);
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
