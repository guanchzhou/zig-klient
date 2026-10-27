//! ListClient against the scripted HTTP/2 fixture. Not part of `zig build test`:
//! `zig build test-list-client -Dh2=true` starts tests/entrypoints/list_fixture_server.py.
//! The pause and stall cases use the production low-speed window (30 s).

const std = @import("std");
const klient = @import("klient");
const list_client = @import("klient-list");
const policy = klient.list_policy;
const Io = std.Io;
const testing = std.testing;

const pause_bytes = 60_000;
const pause_queue = 32 * 1024;

const Case = struct {
    name: []const u8,
    path: []const u8,
    refresh: bool = false,
    pause_ms: u32 = 0,
    raw: bool = false,
    queue: usize = klient.byte_queue.default_capacity,
    want_error: ?anyerror = null,
    want_waits: []const u32 = &.{},
    want_hits: usize,
    want_retry_after: ?u32 = null,
    want_body: ?usize = null,
    want_http1: bool = false,
};

test "low-speed defaults are one byte per second for 30 seconds" {
    const options: list_client.Options = .{};
    try testing.expectEqual(@as(u32, 1), options.low_speed_limit_bytes);
    try testing.expectEqual(@as(u32, 30), options.low_speed_time_s);
}

test "scripted HTTP/2 fixture covers retry, pause, and stall" {
    const keys = try KeyRoot.create();
    defer keys.deinit();
    var fixture = try Fixture.start();
    defer fixture.deinit();

    const base = fixture.credentials("stale");
    const refreshed = fixture.credentials("refreshed");

    try rejectMissingClientCert(&fixture, &keys, base);

    const cases = [_]Case{
        .{ .name = "ok", .path = "/ok", .want_hits = 1 },
        .{ .name = "401 refresh", .path = "/401", .refresh = true, .want_hits = 2 },
        .{ .name = "403", .path = "/403", .want_error = error.HttpStatus, .want_hits = 1 },
        .{ .name = "404", .path = "/404", .want_error = error.HttpStatus, .want_hits = 1 },
        .{ .name = "500", .path = "/500", .want_error = error.HttpStatus, .want_hits = 1 },
        .{ .name = "429 capped", .path = "/429", .want_hits = 3, .want_waits = &.{10} },
        .{ .name = "429 absent", .path = "/429-absent", .want_hits = 2, .want_waits = &.{1} },
        .{
            .name = "429 twice",
            .path = "/429-twice",
            .want_error = error.HttpStatus,
            .want_hits = 3,
            .want_waits = &.{2},
            .want_retry_after = 30,
        },
        .{ .name = "410 restart", .path = "/410", .want_hits = 4, .want_waits = &.{1} },
        .{ .name = "bad magic", .path = "/bad-magic", .want_hits = 2, .want_http1 = true },
        .{ .name = "truncated", .path = "/truncated", .want_hits = 2, .want_http1 = true },
        .{ .name = "goaway", .path = "/goaway", .want_hits = 2 },
        .{ .name = "reset before body", .path = "/reset-early", .want_hits = 2 },
        .{ .name = "reset mid-body", .path = "/reset-mid", .want_hits = 2, .want_http1 = true },
        .{
            .name = "paused stream is not aborted",
            .path = "/pause",
            .pause_ms = 32_000,
            .raw = true,
            .queue = pause_queue,
            .want_hits = 1,
            .want_body = pause_bytes,
        },
        .{ .name = "stall retries over HTTP/1.1", .path = "/stall", .want_hits = 2, .want_http1 = true },
    };
    for (cases) |case| {
        runCase(&fixture, &keys, base, refreshed, case) catch |err| {
            std.debug.print("fixture case {s} failed: {s}\n", .{ case.name, @errorName(err) });
            return err;
        };
    }
}

fn rejectMissingClientCert(fixture: *Fixture, keys: *const KeyRoot, creds: list_client.Credentials) !void {
    var without = creds;
    without.client_cert_pem = null;
    without.client_key_pem = null;
    const client = try list_client.ListClient.init(testing.allocator, testing.io, without, .{
        .connect_timeout_ms = 5_000,
        .key_dir_prefix = keys.prefix,
    });
    defer client.deinit();
    const transfer = try client.open(.{ .path = "/ok", .protocol = .http2, .accept = .protobuf_first });
    defer transfer.close();
    if (transfer.waitHeaders()) |_| {
        return error.MissingCertificateAccepted;
    } else |err| switch (err) {
        error.TlsFailure, error.ConnectionReset => {},
        else => return err,
    }
    try testing.expectEqual(@as(usize, 0), try fixture.hitCount("/ok"));
}

fn runCase(
    fixture: *Fixture,
    keys: *const KeyRoot,
    base: list_client.Credentials,
    refreshed: list_client.Credentials,
    case: Case,
) !void {
    var waits: std.ArrayList(u32) = .empty;
    defer waits.deinit(testing.allocator);
    const client = try list_client.ListClient.init(testing.allocator, testing.io, base, .{
        .connect_timeout_ms = 5_000,
        .queue_capacity = case.queue,
        .key_dir_prefix = keys.prefix,
    });
    defer client.deinit();

    const Hooks = struct {
        refreshed: list_client.Credentials,
        waits: *std.ArrayList(u32),
        pub fn refresh(self: @This()) !list_client.Credentials {
            return self.refreshed;
        }
        pub fn wait(self: @This(), seconds: u32) !void {
            try self.waits.append(testing.allocator, seconds);
        }
    };
    const hooks: Hooks = .{
        .refreshed = if (case.refresh) refreshed else base,
        .waits = &waits,
    };
    var driver: list_client.Driver(Hooks) = .{ .client = client, .hooks = hooks };
    var consumer: Consumer = .{
        .gpa = testing.allocator,
        .io = testing.io,
        .pause_ms = case.pause_ms,
        .raw = case.raw,
    };
    const result = policy.run(testing.allocator, case.path, &driver, &consumer);
    if (case.want_error) |want| try testing.expectError(want, result) else try result;
    try testing.expectEqualSlices(u32, case.want_waits, waits.items);
    try testing.expectEqual(case.want_hits, try fixture.hitCount(case.path));
    try testing.expectEqual(case.want_http1, try fixture.sawProtocol(case.path, "http/1.1"));
    if (case.want_retry_after) |seconds| try testing.expectEqual(seconds, consumer.last_retry_after);
    if (case.want_body) |len| try testing.expectEqual(len, consumer.body_len);
}

const Consumer = struct {
    gpa: std.mem.Allocator,
    io: Io,
    pause_ms: u32,
    raw: bool,
    last_retry_after: ?u32 = null,
    body_len: usize = 0,
    token_buf: [64]u8 = undefined,
    token_len: usize = 0,

    pub fn page(self: *Consumer, _: policy.PageStart, meta: policy.Meta, reader: *Io.Reader) ![]const u8 {
        self.last_retry_after = meta.retry_after_seconds;
        if (meta.status.class() != .success) return error.HttpStatus;
        if (self.pause_ms > 0) try self.io.sleep(.fromMilliseconds(self.pause_ms), .awake);
        const body = try readAll(self.gpa, reader);
        defer self.gpa.free(body);
        self.body_len = body.len;
        if (self.raw) return "";
        const content_type = meta.content_type orelse "";
        if (std.mem.indexOf(u8, content_type, "protobuf") != null) {
            if (!std.mem.startsWith(u8, body, "k8s\x00")) return error.BadMagic;
            return error.Truncated;
        }
        if (!std.mem.startsWith(u8, body, "next:")) return error.UnexpectedBody;
        const token = body["next:".len..];
        if (token.len > self.token_buf.len) return error.UnexpectedBody;
        @memcpy(self.token_buf[0..token.len], token);
        self.token_len = token.len;
        return self.token_buf[0..self.token_len];
    }

    pub fn isHttp1Retryable(_: *Consumer, err: anyerror) bool {
        return switch (err) {
            error.BadMagic, error.Truncated, error.ReadFailed, error.Timeout => true,
            else => false,
        };
    }
};

fn readAll(gpa: std.mem.Allocator, reader: *Io.Reader) ![]u8 {
    var allocating: Io.Writer.Allocating = .init(gpa);
    defer allocating.deinit();
    _ = try reader.streamRemaining(&allocating.writer);
    return try allocating.toOwnedSlice();
}

const Fixture = struct {
    child: std.process.Child,
    io: Io,
    ca: []u8,
    cert: []u8,
    key: []u8,
    hits_path: []u8,
    server: []u8,

    fn start() !Fixture {
        const python = if (std.c.getenv("LIST_FIXTURE_PYTHON")) |value|
            std.mem.span(value)
        else
            "python3";
        var child = try std.process.spawn(testing.io, .{
            .argv = &.{ python, "tests/entrypoints/list_fixture_server.py" },
            .stdin = .ignore,
            .stdout = .pipe,
            .stderr = .inherit,
        });
        errdefer child.kill(testing.io);
        var buffer: [1024]u8 = undefined;
        var reader = child.stdout.?.readerStreaming(testing.io, &buffer);
        const line = std.mem.trimEnd(u8, (try reader.interface.takeDelimiter('\n')) orelse return error.FixtureFailed, "\r");
        var parts = std.mem.tokenizeScalar(u8, line, ' ');
        const tag = parts.next() orelse return error.FixtureProtocol;
        if (!std.mem.eql(u8, tag, "READY")) return error.FixtureProtocol;
        _ = parts.next() orelse return error.FixtureProtocol;
        const ca_path = parts.next() orelse return error.FixtureProtocol;
        const cert_path = parts.next() orelse return error.FixtureProtocol;
        const key_path = parts.next() orelse return error.FixtureProtocol;
        const hits_path = parts.next() orelse return error.FixtureProtocol;
        const ca = try readFile(ca_path);
        errdefer testing.allocator.free(ca);
        const cert = try readFile(cert_path);
        errdefer testing.allocator.free(cert);
        const key = try readFile(key_path);
        errdefer testing.allocator.free(key);
        const hits = try testing.allocator.dupe(u8, hits_path);
        errdefer testing.allocator.free(hits);
        const server = try std.fmt.allocPrint(testing.allocator, "https://127.0.0.1:{s}", .{parts_port(line)});
        return .{
            .child = child,
            .io = testing.io,
            .ca = ca,
            .cert = cert,
            .key = key,
            .hits_path = hits,
            .server = server,
        };
    }

    fn credentials(self: *const Fixture, token: []const u8) list_client.Credentials {
        return .{
            .server = self.server,
            .token = token,
            .ca_pem = self.ca,
            .client_cert_pem = self.cert,
            .client_key_pem = self.key,
        };
    }

    fn hitCount(self: *const Fixture, path: []const u8) !usize {
        const text = readFile(self.hits_path) catch return 0;
        defer testing.allocator.free(text);
        var count: usize = 0;
        var lines = std.mem.splitScalar(u8, text, '\n');
        while (lines.next()) |entry| {
            if (std.mem.startsWith(u8, entry, path) and entry.len > path.len and entry[path.len] == ' ') count += 1;
        }
        return count;
    }

    fn sawProtocol(self: *const Fixture, path: []const u8, protocol: []const u8) !bool {
        const text = readFile(self.hits_path) catch return false;
        defer testing.allocator.free(text);
        var lines = std.mem.splitScalar(u8, text, '\n');
        while (lines.next()) |entry| {
            if (std.mem.startsWith(u8, entry, path) and entry.len > path.len and entry[path.len] == ' ' and std.mem.endsWith(u8, entry, protocol)) return true;
        }
        return false;
    }

    fn deinit(self: *Fixture) void {
        self.child.kill(self.io);
        testing.allocator.free(self.ca);
        testing.allocator.free(self.cert);
        testing.allocator.free(self.key);
        testing.allocator.free(self.hits_path);
        testing.allocator.free(self.server);
    }
};

fn parts_port(line: []const u8) []const u8 {
    var parts = std.mem.tokenizeScalar(u8, line, ' ');
    _ = parts.next();
    return parts.next() orelse "0";
}

fn readFile(path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(testing.io, path, testing.allocator, .limited(1 << 20));
}

const KeyRoot = struct {
    path: []u8,
    prefix: []u8,

    fn create() !KeyRoot {
        var random: [8]u8 = undefined;
        try testing.io.randomSecure(&random);
        const path = try std.fmt.allocPrint(testing.allocator, "/tmp/klient-fx-{s}", .{&std.fmt.bytesToHex(random, .lower)});
        errdefer testing.allocator.free(path);
        try Io.Dir.createDirAbsolute(testing.io, path, Io.File.Permissions.fromMode(0o700));
        return .{
            .path = path,
            .prefix = try std.fmt.allocPrint(testing.allocator, "{s}/k-", .{path}),
        };
    }

    fn deinit(self: KeyRoot) void {
        Io.Dir.deleteDirAbsolute(testing.io, self.path) catch {};
        testing.allocator.free(self.prefix);
        testing.allocator.free(self.path);
    }
};
