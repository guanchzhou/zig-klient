const std = @import("std");
const ws = @import("websocket_client.zig");

/// Pod exec client for executing commands in containers
pub const ExecClient = struct {
    allocator: std.mem.Allocator,
    ws_client: *ws.WebSocketClient,

    pub fn init(allocator: std.mem.Allocator, ws_client: *ws.WebSocketClient) ExecClient {
        return ExecClient{
            .allocator = allocator,
            .ws_client = ws_client,
        };
    }

    /// Execute a command in a pod container
    pub fn exec(
        self: *ExecClient,
        pod_name: []const u8,
        namespace: []const u8,
        options: ExecOptions,
    ) !ExecResult {
        // Build WebSocket path
        const path = try ws.buildExecPath(
            self.allocator,
            namespace,
            pod_name,
            options.command,
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
        var conn = try self.ws_client.connect(path, ws.Subprotocol.v4_channel.toString());
        defer conn.deinit();

        var result = ExecResult.init(self.allocator);
        errdefer result.deinit();

        // Send stdin if provided
        if (options.stdin and options.stdin_data) |stdin_data| {
            try conn.sendChannel(ws.Channel.stdin.toInt(), stdin_data);
        }

        // Receive output
        while (true) {
            const msg = try conn.receive();
            defer msg.deinit(self.allocator);

            switch (msg.channel) {
                ws.Channel.stdout.toInt() => {
                    try result.stdout_buffer.appendSlice(msg.data);
                },
                ws.Channel.stderr.toInt() => {
                    try result.stderr_buffer.appendSlice(msg.data);
                },
                ws.Channel.error_stream.toInt() => {
                    // Error from Kubernetes API
                    result.exit_code = 1;
                    try result.error_buffer.appendSlice(msg.data);
                    break;
                },
                else => {},
            }

            // Check if we've received all data
            // In real implementation, this would check for stream closure
            if (msg.data.len == 0) break;
        }

        return result;
    }

    /// Execute a command and return stdout as string
    pub fn execSimple(
        self: *ExecClient,
        pod_name: []const u8,
        namespace: []const u8,
        command: []const []const u8,
    ) ![]const u8 {
        const result = try self.exec(pod_name, namespace, .{
            .command = command,
            .stdout = true,
            .stderr = true,
        });
        defer result.deinit();

        if (result.exit_code != 0) {
            return error.CommandFailed;
        }

        return try self.allocator.dupe(u8, result.stdout());
    }
};

/// Options for exec operation
pub const ExecOptions = struct {
    /// Command and arguments to execute
    command: []const []const u8,

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

    /// Data to send to stdin (if stdin is enabled)
    stdin_data: ?[]const u8 = null,
};

/// Result of an exec operation
pub const ExecResult = struct {
    allocator: std.mem.Allocator,
    stdout_buffer: std.ArrayList(u8),
    stderr_buffer: std.ArrayList(u8),
    error_buffer: std.ArrayList(u8),
    exit_code: i32 = 0,

    pub fn init(allocator: std.mem.Allocator) ExecResult {
        return ExecResult{
            .allocator = allocator,
            .stdout_buffer = std.ArrayList(u8).init(allocator),
            .stderr_buffer = std.ArrayList(u8).init(allocator),
            .error_buffer = std.ArrayList(u8).init(allocator),
        };
    }

    pub fn deinit(self: ExecResult) void {
        self.stdout_buffer.deinit();
        self.stderr_buffer.deinit();
        self.error_buffer.deinit();
    }

    pub fn stdout(self: ExecResult) []const u8 {
        return self.stdout_buffer.items;
    }

    pub fn stderr(self: ExecResult) []const u8 {
        return self.stderr_buffer.items;
    }

    pub fn errorMessage(self: ExecResult) []const u8 {
        return self.error_buffer.items;
    }

    pub fn success(self: ExecResult) bool {
        return self.exit_code == 0;
    }
};

/// Interactive exec session for real-time I/O
pub const ExecSession = struct {
    allocator: std.mem.Allocator,
    conn: *ws.WebSocketConnection,

    pub fn init(allocator: std.mem.Allocator, conn: *ws.WebSocketConnection) ExecSession {
        return ExecSession{
            .allocator = allocator,
            .conn = conn,
        };
    }

    /// Send data to stdin
    pub fn writeStdin(self: *ExecSession, data: []const u8) !void {
        try self.conn.sendChannel(ws.Channel.stdin.toInt(), data);
    }

    /// Read next message from any stream
    pub fn read(self: *ExecSession) !StreamMessage {
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
    pub fn resize(self: *ExecSession, rows: u16, cols: u16) !void {
        // TTY resize message format: {"Width":cols,"Height":rows}
        const resize_msg = try std.fmt.allocPrint(
            self.allocator,
            "{{\"Width\":{d},\"Height\":{d}}}",
            .{ cols, rows },
        );
        defer self.allocator.free(resize_msg);

        try self.conn.sendChannel(ws.Channel.resize.toInt(), resize_msg);
    }

    /// Close the session
    pub fn close(self: *ExecSession) void {
        self.conn.close();
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
