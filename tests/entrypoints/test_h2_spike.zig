//! Build spike for the in-process list client: read-only GETs to the current
//! kubeconfig context through the vendored libcurl (HTTP/2 via nghttp2, TLS via
//! mbedTLS), reusing one connection. Prints status, protocol, connection count
//! and timing only; never tokens, certificates or bodies.
//!
//!   zig build h2-spike -Dh2=true -- [--context NAME] [--path /version] [--count 2]
//!     [--connect-timeout-ms 400] [--trace] [--accept MIME] [--output FILE]
//!
//! `--output` writes the last response body to FILE (mode 0600).
//! `--lists N` runs N concurrent Pod lists at `--path` through ListClient and
//! the list retry policy, decoding Protobuf; prints counts and timings only.
//! `--gate N` runs the Pod list acceptance checks N times, each on fresh
//! clients, and prints the medians against their budgets.

const std = @import("std");
const klient = @import("klient");
const c = @import("curl_c");
const list_client = @import("klient-list");
const policy = klient.list_policy;

const Options = struct {
    context: ?[]const u8 = null,
    path: []const u8 = "/version",
    count: u32 = 2,
    connect_timeout_ms: c_long = 400,
    trace: bool = false,
    accept: []const u8 = "application/json",
    output: ?[]const u8 = null,
    lists: u32 = 0,
    gate: u32 = 0,
};

const Credentials = struct {
    ca_pem: ?[]const u8 = null,
    ca_path: ?[]const u8 = null,
    cert_pem: ?[]const u8 = null,
    cert_path: ?[]const u8 = null,
    key_pem: ?[]const u8 = null,
    key_path: ?[]const u8 = null,
    token: ?[]const u8 = null,
};

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const io = init.io;
    const options = try parseArgs(try init.minimal.args.toSlice(arena));

    var parser = klient.KubeconfigParser.init(arena, io);
    var config = try parser.load();
    defer config.deinit(arena);
    const context = if (options.context) |name|
        config.getContextByName(name) orelse return error.ContextNotFound
    else
        config.getCurrentContext() orelse return error.NoCurrentContext;
    const cluster = config.getClusterByName(context.cluster) orelse return error.ClusterNotFound;
    const user = config.getUserByName(context.user) orelse return error.UserNotFound;
    if (cluster.insecure_skip_tls_verify orelse false) return error.InsecureSkipVerifyUnsupported;

    const creds = try resolveCredentials(arena, io, cluster, user);
    if (options.lists > 0) return runLists(init.gpa, arena, io, cluster.server, creds, options);
    if (options.gate > 0) return runGate(init.gpa, arena, io, cluster.server, creds, options);
    var key_file: ?StagedKey = null;
    if (creds.key_pem) |pem| key_file = try StagedKey.stage(arena, io, pem);
    defer if (key_file) |*k| k.deinit();

    if (c.curl_global_init(c.CURL_GLOBAL_DEFAULT) != c.CURLE_OK) return error.CurlInitFailed;
    defer c.curl_global_cleanup();
    const easy = c.curl_easy_init() orelse return error.CurlInitFailed;
    defer c.curl_easy_cleanup(easy);

    const url = try std.fmt.allocPrintSentinel(arena, "{s}{s}", .{ std.mem.trimEnd(u8, cluster.server, "/"), options.path }, 0);
    try setopt(easy, c.CURLOPT_URL, url.ptr);
    try setopt(easy, c.CURLOPT_HTTP_VERSION, @as(c_long, c.CURL_HTTP_VERSION_2TLS));
    try setopt(easy, c.CURLOPT_PROTOCOLS_STR, "https");
    try setopt(easy, c.CURLOPT_FOLLOWLOCATION, @as(c_long, 0));
    try setopt(easy, c.CURLOPT_CONNECTTIMEOUT_MS, options.connect_timeout_ms);
    if (options.trace) {
        try setopt(easy, c.CURLOPT_DEBUGFUNCTION, &traceText);
        try setopt(easy, c.CURLOPT_VERBOSE, @as(c_long, 1));
    }
    try setopt(easy, c.CURLOPT_NOPROXY, "*");
    try setopt(easy, c.CURLOPT_ACCEPT_ENCODING, "");
    try setopt(easy, c.CURLOPT_NOSIGNAL, @as(c_long, 1));
    try setopt(easy, c.CURLOPT_WRITEFUNCTION, &countBytes);

    var ca_blob: c.struct_curl_blob = undefined;
    if (creds.ca_pem) |pem| {
        ca_blob = .{ .data = @constCast(pem.ptr), .len = pem.len, .flags = c.CURL_BLOB_COPY };
        try setopt(easy, c.CURLOPT_CAINFO_BLOB, &ca_blob);
    } else if (creds.ca_path) |path| {
        try setopt(easy, c.CURLOPT_CAINFO, (try arena.dupeSentinel(u8, path, 0)).ptr);
    } else {
        try setopt(easy, c.CURLOPT_CAINFO, systemCaBundle());
    }

    var cert_blob: c.struct_curl_blob = undefined;
    if (creds.cert_pem) |pem| {
        cert_blob = .{ .data = @constCast(pem.ptr), .len = pem.len, .flags = c.CURL_BLOB_COPY };
        try setopt(easy, c.CURLOPT_SSLCERT_BLOB, &cert_blob);
        try setopt(easy, c.CURLOPT_SSLCERTTYPE, "PEM");
    } else if (creds.cert_path) |path| {
        try setopt(easy, c.CURLOPT_SSLCERT, (try arena.dupeSentinel(u8, path, 0)).ptr);
    }
    if (key_file) |k| {
        try setopt(easy, c.CURLOPT_SSLKEY, k.path.ptr);
    } else if (creds.key_path) |path| {
        try setopt(easy, c.CURLOPT_SSLKEY, (try arena.dupeSentinel(u8, path, 0)).ptr);
    }

    var headers: ?*c.struct_curl_slist = null;
    defer c.curl_slist_free_all(headers);
    const accept_line = try std.fmt.allocPrintSentinel(arena, "Accept: {s}", .{options.accept}, 0);
    headers = c.curl_slist_append(headers, accept_line.ptr);
    if (creds.token) |token| {
        const line = try std.fmt.allocPrintSentinel(arena, "Authorization: Bearer {s}", .{token}, 0);
        headers = c.curl_slist_append(headers, line.ptr);
        std.crypto.secureZero(u8, line);
    }
    try setopt(easy, c.CURLOPT_HTTPHEADER, headers);

    const auth = if (creds.cert_pem != null or creds.cert_path != null)
        "client certificate"
    else if (creds.token != null)
        "bearer token"
    else
        "none";
    std.debug.print("libcurl {s}\ncontext {s}, auth {s}, path {s}\n", .{ std.mem.span(c.curl_version()), context.name, auth, options.path });

    var i: u32 = 0;
    while (i < options.count) : (i += 1) {
        var sink: Sink = .{ .gpa = arena, .keep = options.output != null };
        try setopt(easy, c.CURLOPT_WRITEDATA, &sink);
        const rc = c.curl_easy_perform(easy);
        if (rc != c.CURLE_OK) {
            std.debug.print("request {d}: {s}\n", .{ i + 1, std.mem.span(c.curl_easy_strerror(rc)) });
            return error.RequestFailed;
        }
        const status = getinfo(c_long, easy, c.CURLINFO_RESPONSE_CODE);
        const version = getinfo(c_long, easy, c.CURLINFO_HTTP_VERSION);
        const connects = getinfo(c_long, easy, c.CURLINFO_NUM_CONNECTS);
        const total = getinfo(c.curl_off_t, easy, c.CURLINFO_TOTAL_TIME_T);
        const tls = getinfo(c.curl_off_t, easy, c.CURLINFO_APPCONNECT_TIME_T);
        std.debug.print("request {d}: HTTP {d}, protocol {s}, new connections {d}, {d} bytes, total {d} ms, tls done at {d} ms\n", .{
            i + 1, status, protocolName(version), connects, sink.bytes, @divTrunc(total, 1000), @divTrunc(tls, 1000),
        });
        if (sink.failed) return error.OutOfMemory;
        if (options.output) |path| try writeBody(io, path, sink.body.items);
    }
}

fn parseArgs(args: []const [:0]const u8) !Options {
    var options: Options = .{};
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--trace")) {
            options.trace = true;
            continue;
        }
        if (i + 1 >= args.len) return error.MissingArgumentValue;
        if (std.mem.eql(u8, arg, "--context")) {
            i += 1;
            options.context = args[i];
        } else if (std.mem.eql(u8, arg, "--path")) {
            i += 1;
            if (!std.mem.startsWith(u8, args[i], "/")) return error.PathMustStartWithSlash;
            options.path = args[i];
        } else if (std.mem.eql(u8, arg, "--count")) {
            i += 1;
            options.count = try std.fmt.parseInt(u32, args[i], 10);
        } else if (std.mem.eql(u8, arg, "--accept")) {
            i += 1;
            options.accept = args[i];
        } else if (std.mem.eql(u8, arg, "--output")) {
            i += 1;
            options.output = args[i];
        } else if (std.mem.eql(u8, arg, "--gate")) {
            i += 1;
            options.gate = try std.fmt.parseInt(u32, args[i], 10);
        } else if (std.mem.eql(u8, arg, "--lists")) {
            i += 1;
            options.lists = try std.fmt.parseInt(u32, args[i], 10);
        } else if (std.mem.eql(u8, arg, "--connect-timeout-ms")) {
            i += 1;
            options.connect_timeout_ms = try std.fmt.parseInt(c_long, args[i], 10);
        } else return error.UnknownArgument;
    }
    return options;
}

fn resolveCredentials(
    arena: std.mem.Allocator,
    io: std.Io,
    cluster: anytype,
    user: anytype,
) !Credentials {
    var creds: Credentials = .{
        .ca_path = cluster.certificate_authority,
        .cert_path = user.client_certificate,
        .key_path = user.client_key,
        .token = user.token,
    };
    if (cluster.certificate_authority_data) |b64| creds.ca_pem = try decodeBase64(arena, b64);
    if (user.client_certificate_data) |b64| creds.cert_pem = try decodeBase64(arena, b64);
    if (user.client_key_data) |b64| creds.key_pem = try decodeBase64(arena, b64);

    if (user.exec) |exec| {
        const command = exec.command orelse return error.ExecCommandMissing;
        const parsed = try klient.exec_credential.executeCredentialPlugin(arena, io, .{
            .command = command,
            .args = exec.args,
            .apiVersion = exec.api_version orelse "client.authentication.k8s.io/v1",
        });
        const status = parsed.value.status orelse return error.ExecCredentialMissingStatus;
        if (status.token) |token| creds.token = token;
        if (status.clientCertificateData) |pem| creds.cert_pem = pem;
        if (status.clientKeyData) |pem| creds.key_pem = pem;
    }
    return creds;
}

fn decodeBase64(allocator: std.mem.Allocator, b64: []const u8) ![]u8 {
    const decoder = std.base64.standard.Decoder;
    const buf = try allocator.alloc(u8, try decoder.calcSizeForSlice(b64));
    try decoder.decode(buf, b64);
    return buf;
}

/// mbedTLS cannot take the client key from memory (no CURLOPT_SSLKEY_BLOB), so
/// it lives in a 0600 file inside a fresh 0700 directory for the run only.
const StagedKey = struct {
    io: std.Io,
    dir_path: []const u8,
    path: [:0]const u8,

    fn stage(allocator: std.mem.Allocator, io: std.Io, pem: []const u8) !StagedKey {
        var random: [16]u8 = undefined;
        try io.randomSecure(&random);
        const hex = std.fmt.bytesToHex(random, .lower);
        const dir_path = try std.fmt.allocPrint(allocator, "/tmp/klient-h2-{s}", .{&hex});
        try std.Io.Dir.createDirAbsolute(io, dir_path, std.Io.File.Permissions.fromMode(0o700));
        errdefer std.Io.Dir.deleteDirAbsolute(io, dir_path) catch {};
        const path = try std.fmt.allocPrintSentinel(allocator, "{s}/client.key", .{dir_path}, 0);
        const file = try std.Io.Dir.createFileAbsolute(io, path, .{
            .exclusive = true,
            .permissions = std.Io.File.Permissions.fromMode(0o600),
        });
        defer file.close(io);
        var buffer: [4096]u8 = undefined;
        var writer = file.writerStreaming(io, &buffer);
        try writer.interface.writeAll(pem);
        try writer.flush();
        return .{ .io = io, .dir_path = dir_path, .path = path };
    }

    fn deinit(self: *StagedKey) void {
        std.Io.Dir.deleteFileAbsolute(self.io, self.path) catch {};
        std.Io.Dir.deleteDirAbsolute(self.io, self.dir_path) catch {};
    }
};

fn systemCaBundle() [*:0]const u8 {
    const candidates = [_][*:0]const u8{
        "/etc/ssl/cert.pem",
        "/etc/ssl/certs/ca-certificates.crt",
        "/etc/pki/tls/certs/ca-bundle.crt",
    };
    for (candidates) |path| {
        if (std.c.access(path, std.c.F_OK) == 0) return path;
    }
    return candidates[0];
}

/// Prints curl's informational lines only. Header and data lines can carry
/// credentials, and the HTTP/2 layer echoes request headers as text lines
/// ("[HTTP/2] [1] [authorization: ...]"), so those are dropped too.
fn traceText(_: ?*c.CURL, kind: c.curl_infotype, data: [*c]u8, size: usize, _: ?*anyopaque) callconv(.c) c_int {
    if (kind != c.CURLINFO_TEXT) return 0;
    const line = data[0..size];
    if (isHeaderEcho(line)) return 0;
    std.debug.print("* {s}", .{line});
    return 0;
}

fn isHeaderEcho(line: []const u8) bool {
    const prefix = "[HTTP/2] [";
    if (!std.mem.startsWith(u8, line, prefix)) return false;
    const stream_end = std.mem.indexOfScalarPos(u8, line, prefix.len, ']') orelse return false;
    return std.mem.startsWith(u8, line[stream_end..], "] [");
}

test "isHeaderEcho drops HTTP/2 header echoes only" {
    try std.testing.expect(isHeaderEcho("[HTTP/2] [1] [authorization: Bearer x]\n"));
    try std.testing.expect(isHeaderEcho("[HTTP/2] [13] [:path: /version]\n"));
    try std.testing.expect(!isHeaderEcho("[HTTP/2] [1] OPENED stream for https://h/version\n"));
    try std.testing.expect(!isHeaderEcho("using HTTP/2\n"));
}

const Sink = struct {
    gpa: std.mem.Allocator,
    keep: bool,
    bytes: usize = 0,
    body: std.ArrayList(u8) = .empty,
    failed: bool = false,
};

fn countBytes(ptr: [*c]u8, size: usize, nmemb: usize, user_data: ?*anyopaque) callconv(.c) usize {
    const sink: *Sink = @ptrCast(@alignCast(user_data.?));
    const n = size * nmemb;
    sink.bytes += n;
    if (sink.keep) sink.body.appendSlice(sink.gpa, ptr[0..n]) catch {
        sink.failed = true;
        return 0;
    };
    return n;
}

fn writeBody(io: std.Io, path: []const u8, body: []const u8) !void {
    const file = try std.Io.Dir.cwd().createFile(io, path, .{ .permissions = std.Io.File.Permissions.fromMode(0o600) });
    defer file.close(io);
    var buffer: [64 * 1024]u8 = undefined;
    var writer = file.writerStreaming(io, &buffer);
    try writer.interface.writeAll(body);
    try writer.flush();
}

fn setopt(easy: *c.CURL, option: c.CURLoption, value: anytype) !void {
    if (c.curl_easy_setopt(easy, option, value) != c.CURLE_OK) return error.CurlSetoptFailed;
}

fn getinfo(comptime T: type, easy: *c.CURL, info: c.CURLINFO) T {
    var value: T = 0;
    _ = c.curl_easy_getinfo(easy, info, &value);
    return value;
}

fn protocolName(version: c_long) []const u8 {
    return switch (version) {
        c.CURL_HTTP_VERSION_1_0 => "HTTP/1.0",
        c.CURL_HTTP_VERSION_1_1 => "HTTP/1.1",
        c.CURL_HTTP_VERSION_2_0 => "HTTP/2",
        c.CURL_HTTP_VERSION_3 => "HTTP/3",
        else => "unknown",
    };
}

fn readOptional(arena: std.mem.Allocator, io: std.Io, pem: ?[]const u8, path: ?[]const u8) !?[]const u8 {
    if (pem) |value| return value;
    const file_path = path orelse return null;
    return try std.Io.Dir.cwd().readFileAlloc(io, file_path, arena, .limited(1 << 20));
}

const ListRun = struct {
    client: *list_client.ListClient,
    gpa: std.mem.Allocator,
    io: std.Io,
    path: []const u8,
    started: std.Io.Timestamp,
    items: usize = 0,
    first_item_ms: ?i64 = null,
    content_type: [64]u8 = undefined,
    content_type_len: usize = 0,
    status: u16 = 0,
    pages: usize = 0,
    protocol: policy.Protocol = .http2,
    continue_token: ?[]u8 = null,
    decode_pods: bool = true,
    result: anyerror!void = {},

    const Hooks = struct {
        pub fn refresh(_: @This()) !list_client.Credentials {
            return error.CredentialRefreshUnsupported;
        }
        pub fn wait(_: @This(), seconds: u32) !void {
            std.debug.print("API server busy, retrying in {d} s\n", .{seconds});
        }
    };

    fn run(self: *ListRun) void {
        var driver: list_client.Driver(Hooks) = .{ .client = self.client, .hooks = .{} };
        self.result = policy.run(self.gpa, self.path, &driver, self);
        if (self.continue_token) |token| self.gpa.free(token);
    }

    pub fn page(self: *ListRun, start: policy.PageStart, meta: policy.Meta, reader: *std.Io.Reader) anyerror![]const u8 {
        if (start.first_page) self.items = 0;
        self.pages += 1;
        self.protocol = start.protocol;
        self.status = @backingInt(meta.status);
        const content_type = meta.content_type orelse "";
        self.content_type_len = @min(content_type.len, self.content_type.len);
        @memcpy(self.content_type[0..self.content_type_len], content_type[0..self.content_type_len]);
        if (meta.status.class() != .success) return error.HttpStatus;
        if (!self.decode_pods or !klient.protobuf.isContentType(content_type)) {
            _ = try reader.discardRemaining();
            return "";
        }
        var decoder = try klient.protobuf.ListDecoder(klient.Pod).init(self.gpa, reader, .{});
        defer decoder.deinit();
        var arena: std.heap.ArenaAllocator = .init(self.gpa);
        defer arena.deinit();
        while (try decoder.next(arena.allocator())) |_| {
            if (self.first_item_ms == null) self.first_item_ms = self.started.untilNow(self.io, .awake).toMilliseconds();
            self.items += 1;
            _ = arena.reset(.retain_capacity);
        }
        if (self.continue_token) |token| self.gpa.free(token);
        self.continue_token = try self.gpa.dupe(u8, decoder.listMeta().continue_token orelse "");
        return self.continue_token.?;
    }

    pub fn isHttp1Retryable(_: *ListRun, err: anyerror) bool {
        return switch (err) {
            error.BadMagic, error.Truncated, error.Malformed, error.UnsupportedWireType, error.WireTypeMismatch, error.MissingField, error.MissingRaw, error.UnsupportedContentEncoding, error.InvalidTime => true,
            else => false,
        };
    }
};

fn newListClient(gpa: std.mem.Allocator, arena: std.mem.Allocator, io: std.Io, server: []const u8, creds: Credentials, options: Options) !*list_client.ListClient {
    return list_client.ListClient.init(gpa, io, .{
        .server = server,
        .token = creds.token,
        .ca_pem = try readOptional(arena, io, creds.ca_pem, creds.ca_path),
        .client_cert_pem = try readOptional(arena, io, creds.cert_pem, creds.cert_path),
        .client_key_pem = try readOptional(arena, io, creds.key_pem, creds.key_path),
    }, .{ .connect_timeout_ms = @intCast(options.connect_timeout_ms) });
}

const Timed = struct { total_ms: i64, first_item_ms: ?i64, items: usize, protocol: policy.Protocol };

fn timedList(client: *list_client.ListClient, gpa: std.mem.Allocator, io: std.Io, path: []const u8, decode_pods: bool) !Timed {
    var run: ListRun = .{ .client = client, .gpa = gpa, .io = io, .path = path, .started = std.Io.Clock.awake.now(io), .decode_pods = decode_pods };
    run.run();
    const total_ms = run.started.untilNow(io, .awake).toMilliseconds();
    try run.result;
    return .{ .total_ms = total_ms, .first_item_ms = run.first_item_ms, .items = run.items, .protocol = run.protocol };
}

fn median(values: []i64) i64 {
    std.mem.sort(i64, values, {}, std.sort.asc(i64));
    return values[values.len / 2];
}

fn runGate(gpa: std.mem.Allocator, arena: std.mem.Allocator, io: std.Io, server: []const u8, creds: Credentials, options: Options) !void {
    const n = options.gate;
    const page_ms = try arena.alloc(i64, n);
    const follow_ms = try arena.alloc(i64, n);
    const full_ms = try arena.alloc(i64, n);
    var follow_reused = true;
    var first_before_end = true;
    for (0..n) |i| {
        {
            const client = try newListClient(gpa, arena, io, server, creds, options);
            defer client.deinit();
            const page = try timedList(client, gpa, io, "/api/v1/pods?limit=500", true);
            const before = client.connections_opened.load(.monotonic);
            const follow = try timedList(client, gpa, io, "/api/v1/namespaces?limit=500", false);
            const new_connections = client.connections_opened.load(.monotonic) - before;
            follow_reused = follow_reused and new_connections == 0;
            page_ms[i] = page.total_ms;
            follow_ms[i] = follow.total_ms;
            std.debug.print("run {d}: 500-pod page {d} ms ({d} items, {s}); namespaces {d} ms, new connections {d}\n", .{
                i + 1, page.total_ms, page.items, @tagName(page.protocol), follow.total_ms, new_connections,
            });
        }
        {
            const client = try newListClient(gpa, arena, io, server, creds, options);
            defer client.deinit();
            const full = try timedList(client, gpa, io, "/api/v1/pods", true);
            full_ms[i] = full.total_ms;
            const first = full.first_item_ms orelse full.total_ms;
            first_before_end = first_before_end and first < full.total_ms;
            std.debug.print("run {d}: full list {d} ms ({d} items, {s}), first item {d} ms\n", .{
                i + 1, full.total_ms, full.items, @tagName(full.protocol), first,
            });
        }
    }
    const page_median = median(page_ms);
    const full_median = median(full_ms);
    const follow_median = median(follow_ms);
    const checks = [_]struct { name: []const u8, ok: bool, value: i64, budget: i64 }{
        .{ .name = "500-pod page", .ok = page_median < 1000, .value = page_median, .budget = 1000 },
        .{ .name = "full list", .ok = full_median < 8000 and first_before_end, .value = full_median, .budget = 8000 },
        .{ .name = "follow-up namespaces page", .ok = follow_median < 350 and follow_reused, .value = follow_median, .budget = 350 },
    };
    var passed = true;
    for (checks) |check| {
        passed = passed and check.ok;
        std.debug.print("{s}: median {d} ms, budget {d} ms: {s}\n", .{ check.name, check.value, check.budget, if (check.ok) "pass" else "FAIL" });
    }
    std.debug.print("first item before body end on every full list: {}\nfollow-up reused the connection every run: {}\n", .{ first_before_end, follow_reused });
    if (!passed) return error.GateMissed;
}

fn runLists(gpa: std.mem.Allocator, arena: std.mem.Allocator, io: std.Io, server: []const u8, creds: Credentials, options: Options) !void {
    const client = try newListClient(gpa, arena, io, server, creds, options);
    defer client.deinit();

    const runs = try arena.alloc(ListRun, options.lists);
    const threads = try arena.alloc(std.Thread, options.lists);
    const started = std.Io.Clock.awake.now(io);
    for (runs, threads) |*run, *thread| {
        run.* = .{ .client = client, .gpa = gpa, .io = io, .path = options.path, .started = started };
        thread.* = try std.Thread.spawn(.{}, ListRun.run, .{run});
    }
    for (threads) |thread| thread.join();
    const total_ms = started.untilNow(io, .awake).toMilliseconds();
    var failed = false;
    for (runs, 1..) |run, index| {
        std.debug.print("list {d}: HTTP {d}, {s}, {s}, {d} items, {d} page(s), first item {?d} ms", .{
            index, run.status, run.content_type[0..run.content_type_len], @tagName(run.protocol), run.items, run.pages, run.first_item_ms,
        });
        if (run.result) |_| std.debug.print("\n", .{}) else |err| {
            failed = true;
            std.debug.print(", error {s}\n", .{@errorName(err)});
        }
    }
    std.debug.print("all lists done in {d} ms\n", .{total_ms});
    if (failed) return error.ListFailed;
}
