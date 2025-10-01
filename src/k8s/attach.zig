const std = @import("std");
const ws = @import("websocket_client.zig");

/// Pod attach client for attaching to running containers
pub const AttachClient = struct {
    allocator: std.mem.Allocator,
    ws_client: *ws.WebSocketClient,

    pub fn init(allocator: std.mem.Allocator, ws_client: *ws.WebSocketClient) AttachClient {
        return AttachClient{
            .allocator = allocator,
            .ws_client = ws_client,
        };
    }

    /// Attach to a running container
    pub fn attach(
        self: *AttachClient,
        pod_name: []const u8,
        namespace: []const u8,
        options: AttachOptions,
    ) !AttachSession {
        // Build WebSocket path
        const path = try ws.buildAttachPath(
            self.allocator,
            namespace,
            pod_name,
            .{
                .stdin = options.stdin,
                .stdout = options.stdout,
                .stderr = options.stderr,
                .tty = options.tty,
                .container = options.container,
            },
        );
        defer self.allocator.free(path);

        // Connect via WebSocket
        const conn = try self.allocator.create(ws.WebSocketConnection);
        errdefer self.allocator.destroy(conn);

        conn.* = try self.ws_client.connect(path, ws.Subprotocol.v4_channel.toString());

        return AttachSession{
            .allocator = self.allocator,
            .conn = conn,
            .tty = options.tty,
        };
    }
};

/// Options for attach operation
pub const AttachOptions = struct {
    /// Enable stdin
    stdin: bool = false,

    /// Enable stdout
    stdout: bool = true,

    /// Enable stderr
    stderr: bool = true,

    /// Allocate a TTY
    tty: bool = false,

    /// Container name (optional, defaults to first container)
    container: ?[]const u8 = null,
};

/// Interactive attach session
pub const AttachSession = struct {
    allocator: std.mem.Allocator,
    conn: *ws.WebSocketConnection,
    tty: bool,

    pub fn deinit(self: *AttachSession) void {
        self.conn.close();
        self.conn.deinit();
        self.allocator.destroy(self.conn);
    }

    /// Send data to stdin
    pub fn writeStdin(self: *AttachSession, data: []const u8) !void {
        try self.conn.sendChannel(ws.Channel.stdin.toInt(), data);
    }

    /// Read next message from any stream
    pub fn read(self: *AttachSession) !StreamMessage {
        const msg = try self.conn.receive();

        return StreamMessage{
            .stream = switch (msg.channel) {
                ws.Channel.stdout.toInt() => .stdout,
                ws.Channel.stderr.toInt() => .stderr,
                ws.Channel.error_stream.toInt() => .error_stream,
                else => .unknown,
            },
            .data = msg.data,
        };
    }

    /// Resize TTY (if tty=true)
    pub fn resize(self: *AttachSession, rows: u16, cols: u16) !void {
        if (!self.tty) return error.NotATTY;

        // TTY resize message format: {"Width":cols,"Height":rows}
        const resize_msg = try std.fmt.allocPrint(
            self.allocator,
            "{{\"Width\":{d},\"Height\":{d}}}",
            .{ cols, rows },
        );
        defer self.allocator.free(resize_msg);

        try self.conn.sendChannel(ws.Channel.resize.toInt(), resize_msg);
    }

    /// Detach from container (close the session)
    pub fn detach(self: *AttachSession) void {
        self.conn.close();
    }

    /// Check if session is still connected
    pub fn isConnected(self: *AttachSession) bool {
        return self.conn.connected;
    }
};

pub const StreamMessage = struct {
    stream: Stream,
    data: []const u8,

    pub const Stream = enum {
        stdout,
        stderr,
        error_stream,
        unknown,
    };

    pub fn deinit(self: StreamMessage, allocator: std.mem.Allocator) void {
        allocator.free(self.data);
    }
};
