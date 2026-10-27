//! In-process list reads over libcurl: one multi handle and one I/O thread per
//! client, so concurrent lists share one HTTP/2 connection as separate streams.
//! Only the I/O thread calls libcurl; consumers reach it through a command
//! queue and `curl_multi_wakeup`. Each transfer's body crosses to its consumer
//! through a bounded `ByteQueue`; a full queue pauses only that stream.

const std = @import("std");
const Io = std.Io;
const klient = @import("klient");
const c = @import("curl_c");

const ByteQueue = klient.byte_queue.ByteQueue;
const policy = klient.list_policy;

pub const Credentials = struct {
    server: []const u8,
    token: ?[]const u8 = null,
    ca_pem: ?[]const u8 = null,
    client_cert_pem: ?[]const u8 = null,
    client_key_pem: ?[]const u8 = null,
};

pub const Options = struct {
    connect_timeout_ms: u32 = 400,
    accept_compressed: bool = true,
    low_speed_limit_bytes: u32 = 1,
    low_speed_time_s: u32 = 30,
    queue_capacity: usize = klient.byte_queue.default_capacity,
    /// Used when the credentials carry no CA; null searches the system bundles.
    ca_bundle_path: ?[:0]const u8 = null,
    key_dir_prefix: []const u8 = "/tmp/klient-list-",
};

/// Applied to every transfer; `Options` cannot change them.
pub const fixed = struct {
    pub const protocols = "https";
    pub const max_redirects: u8 = 0;
    pub const no_proxy = "*";
};

pub const Error = error{
    ConnectionRefused,
    UnknownHost,
    Timeout,
    TlsFailure,
    ConnectionReset,
    Http2ProtocolError,
    HttpStreamReset,
    TruncatedResponse,
    Canceled,
    NoCaBundle,
    ClientShutDown,
    CurlFailed,
};

const reader_buffer_len = 64 << 10;

pub const ListClient = struct {
    gpa: std.mem.Allocator,
    io: Io,
    options: Options,
    multi: *c.CURLM,
    thread: std.Thread = undefined,

    mutex: Io.Mutex = .init,
    commands: std.ArrayList(Command) = .empty,
    credentials: OwnedCredentials,
    credentials_changed: bool = false,
    stopped: bool = false,
    shutdown_requested: std.atomic.Value(bool) = .init(false),
    /// Connections libcurl opened for finished transfers; reuse leaves it unchanged.
    connections_opened: std.atomic.Value(u64) = .init(0),
    open_transfers: usize = 0,
    all_closed: Io.Condition = .init,

    // I/O thread only.
    active: std.ArrayList(*Transfer) = .empty,
    key: ?*StagedKey = null,

    const Command = union(enum) {
        add: *Transfer,
        resume_transfer: *Transfer,
        cancel: *Transfer,
    };

    pub fn init(gpa: std.mem.Allocator, io: Io, credentials: Credentials, options: Options) !*ListClient {
        if (!std.mem.startsWith(u8, credentials.server, "https://")) return error.InvalidApiServer;
        if (c.curl_global_init(c.CURL_GLOBAL_DEFAULT) != c.CURLE_OK) return error.CurlInitFailed;
        errdefer c.curl_global_cleanup();
        const self = try gpa.create(ListClient);
        errdefer gpa.destroy(self);
        var owned = try OwnedCredentials.dupe(gpa, credentials);
        errdefer owned.deinit(gpa);
        const multi = c.curl_multi_init() orelse return error.CurlInitFailed;
        errdefer _ = c.curl_multi_cleanup(multi);
        _ = c.curl_multi_setopt(multi, c.CURLMOPT_PIPELINING, @as(c_long, c.CURLPIPE_MULTIPLEX));
        self.* = .{ .gpa = gpa, .io = io, .options = options, .multi = multi, .credentials = owned };
        self.thread = try std.Thread.spawn(.{}, ioLoop, .{self});
        return self;
    }

    /// Fails every open transfer with `error.Canceled`, stops the I/O thread,
    /// then waits until each transfer's owner has called `Transfer.close`.
    pub fn deinit(self: *ListClient) void {
        self.shutdown_requested.store(true, .release);
        _ = c.curl_multi_wakeup(self.multi);
        self.thread.join();
        self.mutex.lockUncancelable(self.io);
        while (self.open_transfers > 0) self.all_closed.waitUncancelable(self.io, &self.mutex);
        self.mutex.unlock(self.io);

        _ = c.curl_multi_cleanup(self.multi);
        self.commands.deinit(self.gpa);
        self.active.deinit(self.gpa);
        self.credentials.deinit(self.gpa);
        const gpa = self.gpa;
        gpa.destroy(self);
        c.curl_global_cleanup();
    }

    /// New credentials apply to transfers opened afterwards; a changed client
    /// key is re-staged the next time a transfer starts.
    pub fn setCredentials(self: *ListClient, credentials: Credentials) !void {
        var owned = try OwnedCredentials.dupe(self.gpa, credentials);
        self.mutex.lockUncancelable(self.io);
        defer self.mutex.unlock(self.io);
        std.mem.swap(OwnedCredentials, &self.credentials, &owned);
        self.credentials_changed = true;
        owned.deinit(self.gpa);
    }

    pub fn open(self: *ListClient, attempt: policy.Attempt) !*Transfer {
        const transfer = try self.gpa.create(Transfer);
        errdefer self.gpa.destroy(transfer);
        transfer.* = .{ .client = self, .queue = undefined, .easy = undefined };
        transfer.queue = try ByteQueue.init(self.gpa, self.io, self.options.queue_capacity, &transfer.reader_buffer);
        errdefer transfer.queue.deinit();
        transfer.queue.resume_hook = .{ .context = transfer, .call = Transfer.requestResume };
        transfer.easy = c.curl_easy_init() orelse return error.CurlInitFailed;
        errdefer c.curl_easy_cleanup(transfer.easy);
        errdefer if (transfer.headers) |list| c.curl_slist_free_all(list);
        errdefer if (transfer.url) |url| self.gpa.free(url);
        {
            self.mutex.lockUncancelable(self.io);
            defer self.mutex.unlock(self.io);
            if (self.stopped) return error.ClientShutDown;
            try transfer.configure(attempt, &self.credentials, self.options);
            self.open_transfers += 1;
        }
        self.post(.{ .add = transfer }) catch |err| {
            self.mutex.lockUncancelable(self.io);
            self.open_transfers -= 1;
            self.mutex.unlock(self.io);
            return err;
        };
        return transfer;
    }

    fn post(self: *ListClient, command: Command) !void {
        {
            self.mutex.lockUncancelable(self.io);
            defer self.mutex.unlock(self.io);
            if (self.stopped) return error.ClientShutDown;
            try self.commands.append(self.gpa, command);
        }
        _ = c.curl_multi_wakeup(self.multi);
    }

    fn ioLoop(self: *ListClient) void {
        var batch: std.ArrayList(Command) = .empty;
        defer batch.deinit(self.gpa);
        while (true) {
            {
                self.mutex.lockUncancelable(self.io);
                defer self.mutex.unlock(self.io);
                std.mem.swap(std.ArrayList(Command), &batch, &self.commands);
            }
            if (self.shutdown_requested.load(.acquire)) {
                self.shutdown(batch.items);
                return;
            }
            for (batch.items) |command| switch (command) {
                .add => |transfer| self.start(transfer),
                .resume_transfer => |transfer| if (transfer.state == .active) {
                    _ = c.curl_easy_pause(transfer.easy, c.CURLPAUSE_CONT);
                },
                .cancel => |transfer| {
                    if (transfer.state == .active) self.finishTransfer(transfer, error.Canceled);
                    transfer.cancel_acknowledged.set(self.io);
                },
            };
            batch.clearRetainingCapacity();

            var running: c_int = 0;
            _ = c.curl_multi_perform(self.multi, &running);
            var remaining: c_int = 0;
            while (c.curl_multi_info_read(self.multi, &remaining)) |message| {
                if (message.*.msg != c.CURLMSG_DONE) continue;
                const transfer = self.findActive(message.*.easy_handle) orelse continue;
                const code = message.*.data.result;
                self.finishTransfer(transfer, if (code == c.CURLE_OK) null else mapCurlError(code, transfer));
            }
            _ = c.curl_multi_poll(self.multi, null, 0, 1000, null);
        }
    }

    fn start(self: *ListClient, transfer: *Transfer) void {
        if (transfer.state != .pending) return;
        transfer.state = .active;
        self.active.append(self.gpa, transfer) catch {
            self.failUnstarted(transfer, error.OutOfMemory);
            return;
        };
        self.prepareKey(transfer) catch |err| {
            _ = self.active.pop();
            self.failUnstarted(transfer, err);
            return;
        };
        if (c.curl_multi_add_handle(self.multi, transfer.easy) != c.CURLM_OK) {
            _ = self.active.pop();
            self.failUnstarted(transfer, error.CurlFailed);
            self.releaseTransferKey(transfer);
            self.releaseKeyIfIdle();
        }
    }

    fn failUnstarted(self: *ListClient, transfer: *Transfer, err: anyerror) void {
        transfer.state = .finished;
        transfer.queue.finish(.{ .failed = err });
        transfer.headers_done.set(self.io);
    }

    fn prepareKey(self: *ListClient, transfer: *Transfer) !void {
        var pem: ?[]const u8 = null;
        var changed = false;
        {
            self.mutex.lockUncancelable(self.io);
            defer self.mutex.unlock(self.io);
            changed = self.credentials_changed;
            self.credentials_changed = false;
            if (self.credentials.client_key_pem) |value| pem = try self.gpa.dupe(u8, value);
        }
        defer if (pem) |value| {
            std.crypto.secureZero(u8, @constCast(value));
            self.gpa.free(value);
        };
        // A replaced key stays on disk until its last transfer finishes.
        if (changed) if (self.key) |key| {
            self.key = null;
            if (key.users == 0) self.destroyKey(key);
        };
        const value = pem orelse return;
        if (self.key == null) {
            const key = try self.gpa.create(StagedKey);
            errdefer self.gpa.destroy(key);
            key.* = try StagedKey.stage(self.gpa, self.io, self.options.key_dir_prefix, value);
            self.key = key;
        }
        const key = self.key.?;
        try setopt(transfer.easy, c.CURLOPT_SSLKEY, key.path.ptr);
        key.users += 1;
        transfer.key = key;
    }

    fn releaseTransferKey(self: *ListClient, transfer: *Transfer) void {
        const key = transfer.key orelse return;
        transfer.key = null;
        key.users -= 1;
        if (key.users == 0 and key != self.key) self.destroyKey(key);
    }

    fn releaseKeyIfIdle(self: *ListClient) void {
        if (self.active.items.len > 0) return;
        if (self.key) |key| self.destroyKey(key);
        self.key = null;
    }

    fn destroyKey(self: *ListClient, key: *StagedKey) void {
        key.deinit(self.gpa);
        self.gpa.destroy(key);
    }

    fn findActive(self: *ListClient, easy: ?*c.CURL) ?*Transfer {
        for (self.active.items) |transfer| if (transfer.easy == easy) return transfer;
        return null;
    }

    fn finishTransfer(self: *ListClient, transfer: *Transfer, err: ?anyerror) void {
        var connects: c_long = 0;
        if (c.curl_easy_getinfo(transfer.easy, c.CURLINFO_NUM_CONNECTS, &connects) == c.CURLE_OK and connects > 0)
            _ = self.connections_opened.fetchAdd(@intCast(connects), .monotonic);
        _ = c.curl_multi_remove_handle(self.multi, transfer.easy);
        for (self.active.items, 0..) |item, index| if (item == transfer) {
            _ = self.active.swapRemove(index);
            break;
        };
        transfer.state = .finished;
        transfer.queue.finish(if (err) |e| .{ .failed = e } else .complete);
        transfer.headers_done.set(self.io);
        self.releaseTransferKey(transfer);
        self.releaseKeyIfIdle();
    }

    fn shutdown(self: *ListClient, batch: []const Command) void {
        self.mutex.lockUncancelable(self.io);
        self.stopped = true;
        const late = self.commands.toOwnedSlice(self.gpa) catch &.{};
        self.mutex.unlock(self.io);
        defer self.gpa.free(late);
        for ([_][]const Command{ batch, late }) |commands| for (commands) |command| switch (command) {
            .add => |transfer| if (transfer.state == .pending) self.failUnstarted(transfer, error.Canceled),
            .cancel => |transfer| transfer.cancel_acknowledged.set(self.io),
            .resume_transfer => {},
        };
        while (self.active.items.len > 0) self.finishTransfer(self.active.items[0], error.Canceled);
        self.releaseKeyIfIdle();
    }
};

pub const Transfer = struct {
    client: *ListClient,
    easy: *c.CURL,
    queue: ByteQueue,
    reader_buffer: [reader_buffer_len]u8 = undefined,
    headers: ?*c.struct_curl_slist = null,
    url: ?[:0]u8 = null,
    /// I/O thread only.
    key: ?*StagedKey = null,
    /// I/O thread only once added.
    state: enum { pending, active, finished } = .pending,
    headers_done: Io.Event = .unset,
    cancel_acknowledged: Io.Event = .unset,
    body_started: std.atomic.Value(bool) = .init(false),
    status: u16 = 0,
    retry_after_seconds: ?u32 = null,
    content_type_buffer: [128]u8 = undefined,
    content_type_len: usize = 0,
    in_final_headers: bool = false,
    error_buffer: [c.CURL_ERROR_SIZE]u8 = @splat(0),

    fn configure(self: *Transfer, attempt: policy.Attempt, creds: *const OwnedCredentials, options: Options) !void {
        const gpa = self.client.gpa;
        const easy = self.easy;
        self.url = try std.fmt.allocPrintSentinel(gpa, "{s}{s}", .{ std.mem.trimEnd(u8, creds.server, "/"), attempt.path }, 0);
        try klient.path.validateRequestUrl(self.url.?);
        try setopt(easy, c.CURLOPT_URL, self.url.?.ptr);
        try setopt(easy, c.CURLOPT_HTTP_VERSION, @as(c_long, switch (attempt.protocol) {
            .http2 => c.CURL_HTTP_VERSION_2TLS,
            .http1 => c.CURL_HTTP_VERSION_1_1,
        }));
        try setopt(easy, c.CURLOPT_PROTOCOLS_STR, fixed.protocols);
        try setopt(easy, c.CURLOPT_REDIR_PROTOCOLS_STR, fixed.protocols);
        try setopt(easy, c.CURLOPT_FOLLOWLOCATION, @as(c_long, @intFromBool(fixed.max_redirects != 0)));
        try setopt(easy, c.CURLOPT_MAXREDIRS, @as(c_long, fixed.max_redirects));
        try setopt(easy, c.CURLOPT_CONNECTTIMEOUT_MS, @as(c_long, options.connect_timeout_ms));
        try setopt(easy, c.CURLOPT_LOW_SPEED_LIMIT, @as(c_long, options.low_speed_limit_bytes));
        try setopt(easy, c.CURLOPT_LOW_SPEED_TIME, @as(c_long, options.low_speed_time_s));
        try setopt(easy, c.CURLOPT_NOPROXY, fixed.no_proxy);
        if (options.accept_compressed) try setopt(easy, c.CURLOPT_ACCEPT_ENCODING, "");
        try setopt(easy, c.CURLOPT_NOSIGNAL, @as(c_long, 1));
        try setopt(easy, c.CURLOPT_PIPEWAIT, @as(c_long, 1));
        try setopt(easy, c.CURLOPT_ERRORBUFFER, &self.error_buffer);
        try setopt(easy, c.CURLOPT_HEADERFUNCTION, &onHeader);
        try setopt(easy, c.CURLOPT_HEADERDATA, self);
        try setopt(easy, c.CURLOPT_WRITEFUNCTION, &onBody);
        try setopt(easy, c.CURLOPT_WRITEDATA, self);

        if (creds.ca_pem) |pem| {
            var blob: c.struct_curl_blob = .{ .data = @constCast(pem.ptr), .len = pem.len, .flags = c.CURL_BLOB_COPY };
            try setopt(easy, c.CURLOPT_CAINFO_BLOB, &blob);
        } else {
            const bundle = options.ca_bundle_path orelse systemCaBundle() orelse return error.NoCaBundle;
            try setopt(easy, c.CURLOPT_CAINFO, bundle.ptr);
        }
        if (creds.client_cert_pem) |pem| {
            var blob: c.struct_curl_blob = .{ .data = @constCast(pem.ptr), .len = pem.len, .flags = c.CURL_BLOB_COPY };
            try setopt(easy, c.CURLOPT_SSLCERT_BLOB, &blob);
            try setopt(easy, c.CURLOPT_SSLCERTTYPE, "PEM");
        }

        var line_buffer: [96]u8 = undefined;
        const accept = try std.fmt.bufPrintSentinel(&line_buffer, "Accept: {s}", .{attempt.accept.header()}, 0);
        try self.appendHeader(accept);
        if (creds.token) |token| {
            try klient.path.validateBearerToken(token);
            const line = try std.fmt.allocPrintSentinel(gpa, "Authorization: Bearer {s}", .{token}, 0);
            defer {
                std.crypto.secureZero(u8, line);
                gpa.free(line);
            }
            try self.appendHeader(line);
        }
        try setopt(easy, c.CURLOPT_HTTPHEADER, self.headers);
    }

    fn appendHeader(self: *Transfer, line: [:0]const u8) !void {
        self.headers = c.curl_slist_append(self.headers, line.ptr) orelse return error.OutOfMemory;
    }

    /// Blocks until the final response headers arrive or the transfer fails first.
    pub fn waitHeaders(self: *Transfer) !policy.Meta {
        self.headers_done.waitUncancelable(self.client.io);
        if (self.status < 200 or self.in_final_headers) return self.queue.failure() orelse error.CurlFailed;
        return .{
            .status = @fromBackingInt(@intCast(self.status)),
            .retry_after_seconds = self.retry_after_seconds,
            .content_type = if (self.content_type_len > 0) self.content_type_buffer[0..self.content_type_len] else null,
        };
    }

    pub fn reader(self: *Transfer) *Io.Reader {
        return &self.queue.interface;
    }

    pub fn bodyStarted(self: *const Transfer) bool {
        return self.body_started.load(.acquire);
    }

    /// The transport failure that ended this transfer, if any. `error.Canceled`
    /// from `close` is not reported.
    pub fn failure(self: *Transfer) ?anyerror {
        return self.queue.failure();
    }

    /// Cancels the transfer if still running and frees it.
    pub fn close(self: *Transfer) void {
        const client = self.client;
        self.queue.close();
        if (client.post(.{ .cancel = self })) {
            self.cancel_acknowledged.waitUncancelable(client.io);
        } else |_| {}
        self.headers_done.waitUncancelable(client.io);
        c.curl_easy_cleanup(self.easy);
        if (self.headers) |list| c.curl_slist_free_all(list);
        if (self.url) |url| client.gpa.free(url);
        self.queue.deinit();
        client.gpa.destroy(self);

        client.mutex.lockUncancelable(client.io);
        defer client.mutex.unlock(client.io);
        client.open_transfers -= 1;
        if (client.open_transfers == 0) client.all_closed.broadcast(client.io);
    }

    fn requestResume(context: *anyopaque) void {
        const self: *Transfer = @ptrCast(@alignCast(context));
        self.client.post(.{ .resume_transfer = self }) catch {};
    }

    fn onHeader(data: [*c]u8, size: usize, count: usize, user: ?*anyopaque) callconv(.c) usize {
        const self: *Transfer = @ptrCast(@alignCast(user.?));
        const n = size * count;
        if (self.headers_done.isSet()) return n;
        const line = std.mem.trimEnd(u8, data[0..n], "\r\n");
        if (std.mem.startsWith(u8, line, "HTTP/")) {
            var fields = std.mem.tokenizeScalar(u8, line, ' ');
            _ = fields.next();
            self.status = std.fmt.parseInt(u16, fields.next() orelse "0", 10) catch 0;
            self.retry_after_seconds = null;
            self.content_type_len = 0;
            self.in_final_headers = self.status >= 200;
            return n;
        }
        if (line.len == 0) {
            if (self.in_final_headers) {
                self.in_final_headers = false;
                self.headers_done.set(self.client.io);
            }
            return n;
        }
        const colon = std.mem.indexOfScalar(u8, line, ':') orelse return n;
        const name = line[0..colon];
        const value = std.mem.trim(u8, line[colon + 1 ..], " \t");
        if (std.ascii.eqlIgnoreCase(name, "retry-after")) {
            self.retry_after_seconds = std.fmt.parseInt(u32, value, 10) catch null;
        } else if (std.ascii.eqlIgnoreCase(name, "content-type")) {
            self.content_type_len = @min(value.len, self.content_type_buffer.len);
            @memcpy(self.content_type_buffer[0..self.content_type_len], value[0..self.content_type_len]);
        }
        return n;
    }

    fn onBody(data: [*c]u8, size: usize, count: usize, user: ?*anyopaque) callconv(.c) usize {
        const self: *Transfer = @ptrCast(@alignCast(user.?));
        const n = size * count;
        const offer = self.queue.offer(data[0..n]) catch return 0;
        return switch (offer) {
            .accepted => {
                if (n > 0) self.body_started.store(true, .release);
                return n;
            },
            .pause => c.CURL_WRITEFUNC_PAUSE,
            .closed => 0,
        };
    }
};

/// Adapts a client to `list_policy.run`'s driver interface. `refresh` supplies
/// new credentials after a 401; `wait` shows the busy state and sleeps.
pub fn Driver(comptime Hooks: type) type {
    return struct {
        client: *ListClient,
        hooks: Hooks,

        pub fn send(self: *@This(), attempt: policy.Attempt, receiver: anytype) policy.Outcome {
            const transfer = self.client.open(attempt) catch |err| return .{ .transport_error = err };
            defer transfer.close();
            const meta = transfer.waitHeaders() catch |err| return .{
                .transport_error = err,
                .body_started = transfer.bodyStarted(),
            };
            receiver.receive(meta, transfer.reader()) catch {};
            return .{ .transport_error = transfer.failure(), .body_started = transfer.bodyStarted() };
        }

        pub fn refreshCredentials(self: *@This()) !void {
            try self.client.setCredentials(try self.hooks.refresh());
        }

        pub fn waitRetryAfter(self: *@This(), seconds: u32) !void {
            try self.hooks.wait(seconds);
        }
    };
}

fn mapCurlError(code: c.CURLcode, transfer: *Transfer) anyerror {
    return switch (code) {
        c.CURLE_COULDNT_CONNECT => error.ConnectionRefused,
        c.CURLE_COULDNT_RESOLVE_HOST => error.UnknownHost,
        c.CURLE_OPERATION_TIMEDOUT => error.Timeout,
        c.CURLE_SSL_CONNECT_ERROR,
        c.CURLE_PEER_FAILED_VERIFICATION,
        c.CURLE_SSL_CERTPROBLEM,
        c.CURLE_SSL_CIPHER,
        c.CURLE_SSL_CACERT_BADFILE,
        => error.TlsFailure,
        c.CURLE_RECV_ERROR, c.CURLE_SEND_ERROR, c.CURLE_GOT_NOTHING => error.ConnectionReset,
        c.CURLE_HTTP2 => error.Http2ProtocolError,
        c.CURLE_HTTP2_STREAM => error.HttpStreamReset,
        c.CURLE_PARTIAL_FILE => error.TruncatedResponse,
        c.CURLE_WRITE_ERROR => if (transfer.queue.isClosed()) error.Canceled else error.CurlFailed,
        else => error.CurlFailed,
    };
}

const OwnedCredentials = struct {
    server: []u8,
    token: ?[]u8 = null,
    ca_pem: ?[]u8 = null,
    client_cert_pem: ?[]u8 = null,
    client_key_pem: ?[]u8 = null,

    fn dupe(gpa: std.mem.Allocator, from: Credentials) !OwnedCredentials {
        var owned: OwnedCredentials = .{ .server = try gpa.dupe(u8, from.server) };
        errdefer owned.deinit(gpa);
        inline for (.{ "token", "ca_pem", "client_cert_pem", "client_key_pem" }) |name| {
            if (@field(from, name)) |value| @field(owned, name) = try gpa.dupe(u8, value);
        }
        return owned;
    }

    fn deinit(self: *OwnedCredentials, gpa: std.mem.Allocator) void {
        gpa.free(self.server);
        inline for (.{ "token", "ca_pem", "client_cert_pem", "client_key_pem" }) |name| {
            if (@field(self, name)) |value| {
                std.crypto.secureZero(u8, value);
                gpa.free(value);
            }
        }
        self.* = undefined;
    }
};

/// mbedTLS libcurl cannot load a client key from memory, so it is a 0600 file
/// in a fresh 0700 directory, present only while transfers are in flight.
const StagedKey = struct {
    io: Io,
    /// Active transfers whose handle points at this file.
    users: usize = 0,
    dir_path: []u8,
    path: [:0]u8,

    fn stage(gpa: std.mem.Allocator, io: Io, prefix: []const u8, pem: []const u8) !StagedKey {
        var random: [16]u8 = undefined;
        try io.randomSecure(&random);
        const hex = std.fmt.bytesToHex(random, .lower);
        const dir_path = try std.fmt.allocPrint(gpa, "{s}{s}", .{ prefix, &hex });
        errdefer gpa.free(dir_path);
        try Io.Dir.createDirAbsolute(io, dir_path, Io.File.Permissions.fromMode(0o700));
        errdefer Io.Dir.deleteDirAbsolute(io, dir_path) catch {};
        const path = try std.fmt.allocPrintSentinel(gpa, "{s}/client.key", .{dir_path}, 0);
        errdefer gpa.free(path);
        const file = try Io.Dir.createFileAbsolute(io, path, .{
            .exclusive = true,
            .permissions = Io.File.Permissions.fromMode(0o600),
        });
        defer file.close(io);
        errdefer Io.Dir.deleteFileAbsolute(io, path) catch {};
        var buffer: [4096]u8 = undefined;
        var writer = file.writerStreaming(io, &buffer);
        try writer.interface.writeAll(pem);
        try writer.flush();
        return .{ .io = io, .dir_path = dir_path, .path = path };
    }

    fn deinit(self: *StagedKey, gpa: std.mem.Allocator) void {
        Io.Dir.deleteFileAbsolute(self.io, self.path) catch {};
        Io.Dir.deleteDirAbsolute(self.io, self.dir_path) catch {};
        gpa.free(self.path);
        gpa.free(self.dir_path);
        self.* = undefined;
    }
};

fn systemCaBundle() ?[:0]const u8 {
    const candidates = [_][:0]const u8{
        "/etc/ssl/cert.pem",
        "/etc/ssl/certs/ca-certificates.crt",
        "/etc/pki/tls/certs/ca-bundle.crt",
    };
    for (candidates) |path| {
        if (std.c.access(path, std.c.F_OK) == 0) return path;
    }
    return null;
}

fn setopt(easy: *c.CURL, option: c.CURLoption, value: anytype) !void {
    if (c.curl_easy_setopt(easy, option, value) != c.CURLE_OK) return error.CurlSetoptFailed;
}

const testing = std.testing;

const TestKeyDir = struct {
    path: []u8,
    prefix: []u8,

    fn init() !TestKeyDir {
        var random: [8]u8 = undefined;
        try testing.io.randomSecure(&random);
        const path = try std.fmt.allocPrint(testing.allocator, "/tmp/klient-list-test-{s}", .{&std.fmt.bytesToHex(random, .lower)});
        errdefer testing.allocator.free(path);
        try Io.Dir.createDirAbsolute(testing.io, path, Io.File.Permissions.fromMode(0o700));
        return .{ .path = path, .prefix = try std.fmt.allocPrint(testing.allocator, "{s}/k-", .{path}) };
    }

    fn entries(self: TestKeyDir) !usize {
        var dir = try Io.Dir.openDirAbsolute(testing.io, self.path, .{ .iterate = true });
        defer dir.close(testing.io);
        var iterator = dir.iterate();
        var count: usize = 0;
        while (try iterator.next(testing.io)) |_| count += 1;
        return count;
    }

    fn deinit(self: TestKeyDir) void {
        Io.Dir.deleteDirAbsolute(testing.io, self.path) catch {};
        testing.allocator.free(self.prefix);
        testing.allocator.free(self.path);
    }
};

/// A throwaway P-256 key as SEC1 PEM, so TLS libraries can parse it.
fn testKeyPem(buffer: *[512]u8) ![]const u8 {
    const pair = std.crypto.sign.ecdsa.EcdsaP256Sha256.KeyPair.generate(testing.io);
    var der: [121]u8 = undefined;
    const prefix = [_]u8{ 0x30, 0x77, 0x02, 0x01, 0x01, 0x04, 0x20 };
    const curve = [_]u8{ 0xa0, 0x0a, 0x06, 0x08, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07, 0xa1, 0x44, 0x03, 0x42, 0x00 };
    @memcpy(der[0..7], &prefix);
    @memcpy(der[7..39], &pair.secret_key.toBytes());
    @memcpy(der[39..56], &curve);
    @memcpy(der[56..121], &pair.public_key.toUncompressedSec1());
    var writer = Io.Writer.fixed(buffer);
    try writer.writeAll("-----BEGIN EC PRIVATE KEY-----\n");
    var encoded: [164]u8 = undefined;
    try writer.writeAll(std.base64.standard.Encoder.encode(&encoded, &der));
    try writer.writeAll("\n-----END EC PRIVATE KEY-----\n");
    return writer.buffered();
}

const fake_credentials: Credentials = .{
    .server = "https://127.0.0.1:1",
    .token = "test-token",
    .ca_pem = "not a certificate",
    .client_key_pem = "not a key",
};

test "a replaced client key stays on disk until its last transfer finishes" {
    const keys = try TestKeyDir.init();
    defer keys.deinit();
    const client = try ListClient.init(testing.allocator, testing.io, fake_credentials, .{ .key_dir_prefix = keys.prefix });
    defer client.deinit();

    var first: Transfer = .{ .client = client, .queue = undefined, .easy = c.curl_easy_init().? };
    defer c.curl_easy_cleanup(first.easy);
    var second: Transfer = .{ .client = client, .queue = undefined, .easy = c.curl_easy_init().? };
    defer c.curl_easy_cleanup(second.easy);

    try client.prepareKey(&first);
    try testing.expectEqual(@as(usize, 1), try keys.entries());
    try client.setCredentials(fake_credentials);
    try client.prepareKey(&second);
    try testing.expectEqual(@as(usize, 2), try keys.entries());
    client.releaseTransferKey(&first);
    try testing.expectEqual(@as(usize, 1), try keys.entries());
    client.releaseTransferKey(&second);
    client.releaseKeyIfIdle();
    try testing.expectEqual(@as(usize, 0), try keys.entries());
}

test "a control character in the token or path is rejected before the request" {
    const keys = try TestKeyDir.init();
    defer keys.deinit();
    var credentials = fake_credentials;
    credentials.token = "token\r\nX-Injected: 1";
    const client = try ListClient.init(testing.allocator, testing.io, credentials, .{ .key_dir_prefix = keys.prefix });
    defer client.deinit();
    const attempt: policy.Attempt = .{ .path = "/api/v1/pods", .protocol = .http2, .accept = .protobuf_first };
    try testing.expectError(error.InvalidBearerToken, client.open(attempt));

    try client.setCredentials(fake_credentials);
    var bad_path = attempt;
    bad_path.path = "/api/v1/pods HTTP/1.1\r\nHost: x";
    try testing.expectError(error.InvalidRequestUrl, client.open(bad_path));
}

test "a refused connection is a transport error before any body byte" {
    const keys = try TestKeyDir.init();
    defer keys.deinit();
    const client = try ListClient.init(testing.allocator, testing.io, fake_credentials, .{ .key_dir_prefix = keys.prefix });
    defer client.deinit();

    const Hooks = struct {
        fn refresh(_: @This()) !Credentials {
            return fake_credentials;
        }
        fn wait(_: @This(), _: u32) !void {}
    };
    var driver: Driver(Hooks) = .{ .client = client, .hooks = .{} };
    const Receiver = struct {
        called: bool = false,
        pub fn receive(self: *@This(), _: policy.Meta, _: *Io.Reader) anyerror!void {
            self.called = true;
        }
    };
    var receiver: Receiver = .{};
    const outcome = driver.send(.{ .path = "/api/v1/pods", .protocol = .http2, .accept = .protobuf_first }, &receiver);
    try testing.expectEqual(@as(?anyerror, error.ConnectionRefused), outcome.transport_error);
    try testing.expect(!outcome.body_started);
    try testing.expect(!receiver.called);
    try testing.expectEqual(@as(usize, 0), try keys.entries());
}

test "deinit fails a stalled transfer and waits for its owner to close it" {
    const keys = try TestKeyDir.init();
    defer keys.deinit();
    var address = try Io.net.IpAddress.parse("127.0.0.1", 0);
    var server = try address.listen(testing.io, .{});
    defer server.deinit(testing.io);
    const Silent = struct {
        release: Io.Event = .unset,
        fn run(self: *@This(), listener: *Io.net.Server) void {
            const stream = listener.accept(testing.io) catch return;
            defer stream.close(testing.io);
            self.release.waitUncancelable(testing.io);
        }
    };
    var silent: Silent = .{};
    const silent_thread = try std.Thread.spawn(.{}, Silent.run, .{ &silent, &server });
    defer silent_thread.join();
    defer silent.release.set(testing.io);
    const server_url = try std.fmt.allocPrint(testing.allocator, "https://127.0.0.1:{d}", .{server.socket.address.getPort()});
    defer testing.allocator.free(server_url);

    var credentials = fake_credentials;
    credentials.server = server_url;
    credentials.ca_pem = null;
    var key_buffer: [512]u8 = undefined;
    credentials.client_key_pem = try testKeyPem(&key_buffer);
    const client = try ListClient.init(testing.allocator, testing.io, credentials, .{
        .key_dir_prefix = keys.prefix,
        .connect_timeout_ms = 30_000,
    });
    var client_live = true;
    errdefer if (client_live) client.deinit();
    const transfer = try client.open(.{ .path = "/api/v1/pods", .protocol = .http2, .accept = .protobuf_first });
    var transfer_owned = true;
    errdefer if (transfer_owned) transfer.close();

    var key_seen = false;
    for (0..200) |_| {
        if (try keys.entries() > 0) {
            key_seen = true;
            break;
        }
        try testing.io.sleep(.fromMilliseconds(5), .awake);
    }
    try testing.expect(key_seen);

    const Owner = struct {
        fn run(t: *Transfer, result: *?anyerror) void {
            _ = t.waitHeaders() catch |err| {
                result.* = err;
            };
            t.close();
        }
    };
    var owner_result: ?anyerror = null;
    const owner = try std.Thread.spawn(.{}, Owner.run, .{ transfer, &owner_result });
    transfer_owned = false;
    client_live = false;
    client.deinit();
    owner.join();
    try testing.expectEqual(@as(?anyerror, error.Canceled), owner_result);
    try testing.expectEqual(@as(usize, 0), try keys.entries());
}
