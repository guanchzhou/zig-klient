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
        if (options.stdin) {
            if (options.stdin_data) |stdin_data| {
                try conn.sendChannel(ws.Channel.stdin.toInt(), stdin_data);
            }
        }

        // Receive output until the server closes the stream or sends the terminal
        // status on the error channel. NOTE: Kubernetes sends an initial zero-length
        // frame on each channel, so an empty frame must NOT be treated as EOF.
        while (true) {
            const msg = conn.receive() catch |err| switch (err) {
                error.ConnectionClosed => break,
                else => return err,
            };
            defer msg.deinit(self.allocator);

            switch (msg.channel) {
                ws.Channel.stdout.toInt() => try result.stdout_buffer.appendSlice(self.allocator, msg.data),
                ws.Channel.stderr.toInt() => try result.stderr_buffer.appendSlice(self.allocator, msg.data),
                ws.Channel.error_stream.toInt() => {
                    // v4.channel terminal frame: a JSON metav1.Status. "Success" => 0,
                    // otherwise a non-zero exit (the code is in status.details.causes).
                    try result.error_buffer.appendSlice(self.allocator, msg.data);
                    result.exit_code = parseExecExitCode(self.allocator, msg.data);
                    break;
                },
                else => {},
            }
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

/// Parse the exit code from a v4.channel error-stream metav1.Status JSON.
/// `{"status":"Success"}` => 0; a Failure carrying an ExitCode cause => that code;
/// otherwise 1. Best-effort: any parse failure yields 1.
fn parseExecExitCode(allocator: std.mem.Allocator, status_json: []const u8) i32 {
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, status_json, .{
        .ignore_unknown_fields = true,
    }) catch return 1;
    defer parsed.deinit();

    if (parsed.value != .object) return 1;
    const obj = parsed.value.object;

    if (obj.get("status")) |s| {
        if (s == .string and std.mem.eql(u8, s.string, "Success")) return 0;
    }

    // Failure: status.details.causes[] where reason == "ExitCode" carries the code.
    if (obj.get("details")) |d| {
        if (d == .object) {
            if (d.object.get("causes")) |causes| {
                if (causes == .array) {
                    for (causes.array.items) |c| {
                        if (c != .object) continue;
                        const reason = c.object.get("reason") orelse continue;
                        if (reason != .string or !std.mem.eql(u8, reason.string, "ExitCode")) continue;
                        const m = c.object.get("message") orelse continue;
                        if (m == .string) return std.fmt.parseInt(i32, m.string, 10) catch 1;
                    }
                }
            }
        }
    }

    return 1;
}

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
            .stdout_buffer = .empty,
            .stderr_buffer = .empty,
            .error_buffer = .empty,
        };
    }

    pub fn deinit(self: ExecResult) void {
        // 0.16 ArrayList is unmanaged; deinit frees through a (copied) slice header.
        var stdout_buffer = self.stdout_buffer;
        var stderr_buffer = self.stderr_buffer;
        var error_buffer = self.error_buffer;
        stdout_buffer.deinit(self.allocator);
        stderr_buffer.deinit(self.allocator);
        error_buffer.deinit(self.allocator);
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
