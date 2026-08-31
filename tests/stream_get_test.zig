const std = @import("std");
const klient = @import("klient");

const ResponseSpec = struct {
    status: std.http.Status = .ok,
    body: []const u8 = "",
    content_type: ?[]const u8 = null,
    content_encoding: ?[]const u8 = null,
    retry_after: ?[]const u8 = null,
    location: ?[]const u8 = null,
    close_without_response: bool = false,
    headers_sent: ?*std.Io.Event = null,
    release_response: ?*std.Io.Event = null,
};

const RequestRecord = struct {
    target_len: usize = 0,
    target: [512]u8 = undefined,
    authorization_len: usize = 0,
    authorization: [512]u8 = undefined,

    fn targetSlice(self: *const RequestRecord) []const u8 {
        return self.target[0..self.target_len];
    }

    fn authorizationSlice(self: *const RequestRecord) ?[]const u8 {
        if (self.authorization_len == 0) return null;
        return self.authorization[0..self.authorization_len];
    }
};

const TestServer = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    listener: std.Io.net.Server,
    responses: []const ResponseSpec,
    records: [16]RequestRecord = undefined,
    request_count: usize = 0,
    future: std.Io.Future(anyerror!void),
    future_live: bool,
    listener_live: bool,

    fn init(
        self: *TestServer,
        allocator: std.mem.Allocator,
        io: std.Io,
        responses: []const ResponseSpec,
    ) !void {
        const address: std.Io.net.IpAddress = .{ .ip4 = .loopback(0) };
        const listener = try address.listen(io, .{});
        errdefer {
            var owned_listener = listener;
            owned_listener.deinit(io);
        }

        self.* = .{
            .allocator = allocator,
            .io = io,
            .listener = listener,
            .responses = responses,
            .future = undefined,
            .future_live = false,
            .listener_live = true,
        };
        self.future = try std.Io.concurrent(io, run, .{self});
        self.future_live = true;
    }

    fn deinit(self: *TestServer) void {
        if (self.future_live) {
            self.future_live = false;
            self.future.cancel(self.io) catch |err| {
                if (err != error.Canceled and err != error.WriteFailed) @panic(@errorName(err));
            };
        }
        if (self.listener_live) {
            self.listener_live = false;
            self.listener.deinit(self.io);
        }
    }

    fn finish(self: *TestServer) !void {
        if (self.future_live) {
            self.future_live = false;
            try self.future.await(self.io);
        }
        if (self.listener_live) {
            self.listener_live = false;
            self.listener.deinit(self.io);
        }
    }

    fn port(self: *const TestServer) u16 {
        return self.listener.socket.address.getPort();
    }

    fn baseUrl(self: *const TestServer, allocator: std.mem.Allocator) ![]u8 {
        return std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{self.port()});
    }

    fn run(self: *TestServer) anyerror!void {
        for (self.responses) |response| {
            const stream = try self.listener.accept(self.io);
            try self.serve(stream, response);
        }
    }

    fn serve(self: *TestServer, stream: std.Io.net.Stream, response: ResponseSpec) !void {
        defer stream.close(self.io);

        var receive_buffer: [8192]u8 = undefined;
        var send_buffer: [8192]u8 = undefined;
        var stream_reader = stream.reader(self.io, &receive_buffer);
        var stream_writer = stream.writer(self.io, &send_buffer);
        var server = std.http.Server.init(&stream_reader.interface, &stream_writer.interface);
        var request = try server.receiveHead();

        const record = &self.records[self.request_count];
        record.* = .{};
        record.target_len = @min(request.head.target.len, record.target.len);
        @memcpy(record.target[0..record.target_len], request.head.target[0..record.target_len]);

        var headers = request.iterateHeaders();
        while (headers.next()) |header| {
            if (std.ascii.eqlIgnoreCase(header.name, "authorization")) {
                record.authorization_len = @min(header.value.len, record.authorization.len);
                @memcpy(
                    record.authorization[0..record.authorization_len],
                    header.value[0..record.authorization_len],
                );
            }
        }
        self.request_count += 1;

        if (response.close_without_response) return;

        var response_headers: [4]std.http.Header = undefined;
        var response_header_count: usize = 0;
        if (response.content_type) |value| {
            response_headers[response_header_count] = .{ .name = "Content-Type", .value = value };
            response_header_count += 1;
        }
        if (response.content_encoding) |value| {
            response_headers[response_header_count] = .{ .name = "Content-Encoding", .value = value };
            response_header_count += 1;
        }
        if (response.retry_after) |value| {
            response_headers[response_header_count] = .{ .name = "Retry-After", .value = value };
            response_header_count += 1;
        }
        if (response.location) |value| {
            response_headers[response_header_count] = .{ .name = "Location", .value = value };
            response_header_count += 1;
        }

        if (response.release_response) |release_response| {
            var body_buffer: [1]u8 = undefined;
            var body_writer = try request.respondStreaming(&body_buffer, .{
                .content_length = 1,
                .respond_options = .{
                    .status = response.status,
                    .keep_alive = false,
                    .extra_headers = response_headers[0..response_header_count],
                },
            });
            try body_writer.flush();
            if (response.headers_sent) |headers_sent| headers_sent.set(self.io);
            try release_response.wait(self.io);
            return;
        }

        try request.respond(response.body, .{
            .status = response.status,
            .keep_alive = false,
            .extra_headers = response_headers[0..response_header_count],
        });
    }
};

test "watch accepts an event at the four MiB line bound" {
    const allocator = std.testing.allocator;
    var threaded = std.Io.Threaded.init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    const max_event_bytes = 4 << 20;
    const prefix = "{\"type\":\"ADDED\",\"object\":{\"metadata\":{\"name\":\"large\"},\"padding\":\"";
    const suffix = "\"}}\n";
    const padding_len = max_event_bytes - prefix.len - (suffix.len - 1);

    var body: std.ArrayList(u8) = .empty;
    defer body.deinit(allocator);
    try body.appendSlice(allocator, prefix);
    const padding_start = body.items.len;
    try body.resize(allocator, padding_start + padding_len);
    @memset(body.items[padding_start..], 'x');
    try body.appendSlice(allocator, suffix);
    try std.testing.expectEqual(max_event_bytes + 1, body.items.len);

    const responses = [_]ResponseSpec{.{ .body = body.items }};
    var server: TestServer = undefined;
    try server.init(allocator, io, &responses);
    defer server.deinit();

    const base_url = try server.baseUrl(allocator);
    defer allocator.free(base_url);
    var client = try klient.K8sClient.init(allocator, io, .{ .server = base_url });
    defer client.deinit();

    var watcher = klient.Watcher(klient.Pod).init(
        &client,
        "/api/v1",
        "pods",
        null,
        .{},
    );
    defer watcher.deinit();

    const Capture = struct {
        count: usize = 0,

        fn callback(self: *@This(), event: *klient.watch.WatchEvent(klient.Pod)) anyerror!void {
            defer event.deinit();
            self.count += 1;
        }
    };
    var capture: Capture = .{};

    try watcher.watchWithContext(*Capture, &capture, Capture.callback);
    try server.finish();
    try std.testing.expectEqual(1, capture.count);
}

test "WatchOutcome rejects an event above the four MiB line bound" {
    const allocator = std.testing.allocator;
    var threaded = std.Io.Threaded.init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    const max_event_bytes = 4 << 20;
    const prefix = "{\"type\":\"ADDED\",\"object\":{\"metadata\":{\"name\":\"large\"},\"padding\":\"";
    const suffix = "\"}}\n";
    const padding_len = max_event_bytes + 1 - prefix.len - (suffix.len - 1);

    var body: std.ArrayList(u8) = .empty;
    defer body.deinit(allocator);
    try body.appendSlice(allocator, prefix);
    const padding_start = body.items.len;
    try body.resize(allocator, padding_start + padding_len);
    @memset(body.items[padding_start..], 'x');
    try body.appendSlice(allocator, suffix);

    const responses = [_]ResponseSpec{.{ .body = body.items }};
    var server: TestServer = undefined;
    try server.init(allocator, io, &responses);
    defer server.deinit();

    const base_url = try server.baseUrl(allocator);
    defer allocator.free(base_url);
    var client = try klient.K8sClient.init(allocator, io, .{ .server = base_url });
    defer client.deinit();

    var watcher = klient.Watcher(klient.Pod).init(&client, "/api/v1", "pods", null, .{});
    defer watcher.deinit();

    const outcome = try watcher.watchOutcome(discardPodEvent);
    try server.finish();
    try std.testing.expectEqual(.malformed_event, std.meta.activeTag(outcome));
    try std.testing.expectEqual(256, outcome.malformed_event.payloadSlice().len);
    try std.testing.expect(outcome.malformed_event.payload_truncated);
}

const StreamCapture = struct {
    called: bool = false,
    status: std.http.Status = undefined,
    retry_after_seconds: ?u32 = null,
    content_type_len: usize = 0,
    content_type: [128]u8 = undefined,
    body_len: usize = 0,
    body: [128]u8 = undefined,

    fn callback(
        self: *StreamCapture,
        meta: klient.StreamResponseMeta,
        reader: *std.Io.Reader,
    ) anyerror!void {
        self.called = true;
        self.status = meta.status;
        self.retry_after_seconds = meta.retry_after_seconds;
        if (meta.content_type) |content_type| {
            self.content_type_len = @min(content_type.len, self.content_type.len);
            @memcpy(self.content_type[0..self.content_type_len], content_type[0..self.content_type_len]);
        }
        var body: std.ArrayList(u8) = .empty;
        defer body.deinit(std.testing.allocator);
        try reader.appendRemaining(std.testing.allocator, &body, .limited(self.body.len));
        self.body_len = body.items.len;
        @memcpy(self.body[0..self.body_len], body.items);
    }

    fn contentType(self: *const StreamCapture) []const u8 {
        return self.content_type[0..self.content_type_len];
    }

    fn bodySlice(self: *const StreamCapture) []const u8 {
        return self.body[0..self.body_len];
    }
};

test "streamGet exposes callback-scoped metadata and a decompressed reader" {
    const allocator = std.testing.allocator;
    var threaded = std.Io.Threaded.init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    const gzip_hello = [_]u8{
        0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x03,
        0xf3, 0x48, 0xcd, 0xc9, 0xc9, 0x57, 0x28, 0xcf, 0x2f, 0xca,
        0x49, 0xe1, 0x02, 0x00, 0xd5, 0xe0, 0x39, 0xb7, 0x0c, 0x00,
        0x00, 0x00,
    };
    const responses = [_]ResponseSpec{.{
        .status = .too_many_requests,
        .body = &gzip_hello,
        .content_type = "application/json",
        .content_encoding = "gzip",
        .retry_after = "7",
    }};
    var server: TestServer = undefined;
    try server.init(allocator, io, &responses);
    defer server.deinit();

    const base_url = try server.baseUrl(allocator);
    defer allocator.free(base_url);
    var client = try klient.K8sClient.init(allocator, io, .{
        .server = base_url,
        .token = "secret-token",
    });
    defer client.deinit();

    var capture: StreamCapture = .{};
    try client.streamGet(
        io,
        "/api/v1/pods",
        .{ .pretty = false },
        &capture,
        StreamCapture.callback,
    );
    try server.finish();

    try std.testing.expect(capture.called);
    try std.testing.expectEqual(std.http.Status.too_many_requests, capture.status);
    try std.testing.expectEqual(@as(?u32, 7), capture.retry_after_seconds);
    try std.testing.expectEqualStrings("application/json", capture.contentType());
    try std.testing.expectEqualStrings("Hello world\n", capture.bodySlice());
    try std.testing.expectEqualStrings("/api/v1/pods?pretty=false", server.records[0].targetSlice());
    try std.testing.expectEqualStrings("Bearer secret-token", server.records[0].authorizationSlice().?);
}

test "corrupt compressed 401 preserves K8sApiError status and is not retried" {
    const allocator = std.testing.allocator;
    var threaded = std.Io.Threaded.init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    const corrupt_gzip = [_]u8{ 0x1f, 0x8b, 0x00, 0xff };
    const response: ResponseSpec = .{
        .status = .unauthorized,
        .body = &corrupt_gzip,
        .content_type = "application/json",
        .content_encoding = "gzip",
    };
    const responses = [_]ResponseSpec{response} ** 4;
    var server: TestServer = undefined;
    try server.init(allocator, io, &responses);
    defer server.deinit();

    const base_url = try server.baseUrl(allocator);
    defer allocator.free(base_url);
    var client = try klient.K8sClient.init(allocator, io, .{ .server = base_url });
    defer client.deinit();

    var api_error: ?klient.K8sClient.ApiError = null;
    defer if (api_error) |*detail| detail.deinit(allocator);
    try std.testing.expectError(
        error.K8sApiError,
        client.requestCapturing(.GET, "/unauthorized", null, &api_error),
    );
    try std.testing.expectEqual(@as(?i64, 401), api_error.?.code);
    try std.testing.expectEqual(@as(usize, 1), server.request_count);
}

test "truncated compressed 403 preserves K8sApiError status and is not retried" {
    const allocator = std.testing.allocator;
    var threaded = std.Io.Threaded.init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    const truncated_gzip = [_]u8{
        0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x04, 0x03, 0xf3, 0x48, 0xcd, 0xc9, 0xc9,
    };
    const response: ResponseSpec = .{
        .status = .forbidden,
        .body = &truncated_gzip,
        .content_type = "application/json",
        .content_encoding = "gzip",
    };
    const responses = [_]ResponseSpec{response} ** 4;
    var server: TestServer = undefined;
    try server.init(allocator, io, &responses);
    defer server.deinit();

    const base_url = try server.baseUrl(allocator);
    defer allocator.free(base_url);
    var client = try klient.K8sClient.init(allocator, io, .{ .server = base_url });
    defer client.deinit();

    var api_error: ?klient.K8sClient.ApiError = null;
    defer if (api_error) |*detail| detail.deinit(allocator);
    try std.testing.expectError(
        error.K8sApiError,
        client.requestCapturing(.GET, "/forbidden", null, &api_error),
    );
    try std.testing.expectEqual(@as(?i64, 403), api_error.?.code);
    try std.testing.expectEqual(@as(usize, 1), server.request_count);
}

test "streamGet normalizes explicit pretty without disturbing query or fragment" {
    const allocator = std.testing.allocator;
    var threaded = std.Io.Threaded.init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    const Case = struct {
        path: []const u8,
        pretty: ?bool,
        expected: []const u8,
    };
    const cases = [_]Case{
        .{ .path = "/pods", .pretty = true, .expected = "/pods?pretty=true" },
        .{ .path = "/pods?watch=true", .pretty = false, .expected = "/pods?watch=true&pretty=false" },
        .{ .path = "/pods#items", .pretty = true, .expected = "/pods?pretty=true" },
        .{ .path = "/pods?watch=true#items", .pretty = false, .expected = "/pods?watch=true&pretty=false" },
        .{ .path = "/pods?pretty=true&watch=true", .pretty = true, .expected = "/pods?pretty=true&watch=true" },
        .{ .path = "/pods?watch=true&pretty=true&limit=1", .pretty = false, .expected = "/pods?watch=true&pretty=false&limit=1" },
        .{ .path = "/pods?prettier=true&value=pretty%3Dtrue", .pretty = false, .expected = "/pods?prettier=true&value=pretty%3Dtrue&pretty=false" },
        .{ .path = "/pods?pretty=false#items", .pretty = null, .expected = "/pods?pretty=false" },
    };

    const responses = [_]ResponseSpec{.{}} ** cases.len;
    var server: TestServer = undefined;
    try server.init(allocator, io, &responses);
    defer server.deinit();

    const base_url = try server.baseUrl(allocator);
    defer allocator.free(base_url);
    var client = try klient.K8sClient.init(allocator, io, .{ .server = base_url });
    defer client.deinit();

    for (cases) |case| {
        var capture: StreamCapture = .{};
        try client.streamGet(io, case.path, .{ .pretty = case.pretty }, &capture, StreamCapture.callback);
    }
    try server.finish();

    for (cases, 0..) |case, index| {
        try std.testing.expectEqualStrings(case.expected, server.records[index].targetSlice());
    }
}

test "streamGet follows same-host redirects with authorization" {
    const allocator = std.testing.allocator;
    var threaded = std.Io.Threaded.init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    const responses = [_]ResponseSpec{
        .{ .status = .found, .location = "/final" },
        .{ .body = "redirected" },
    };
    var server: TestServer = undefined;
    try server.init(allocator, io, &responses);
    defer server.deinit();

    const base_url = try server.baseUrl(allocator);
    defer allocator.free(base_url);
    var client = try klient.K8sClient.init(allocator, io, .{
        .server = base_url,
        .token = "same-host-token",
    });
    defer client.deinit();

    var capture: StreamCapture = .{};
    try client.streamGet(io, "/start", .{}, &capture, StreamCapture.callback);
    try server.finish();

    try std.testing.expectEqualStrings("redirected", capture.bodySlice());
    try std.testing.expectEqualStrings("/start", server.records[0].targetSlice());
    try std.testing.expectEqualStrings("/final", server.records[1].targetSlice());
    try std.testing.expectEqualStrings("Bearer same-host-token", server.records[0].authorizationSlice().?);
    try std.testing.expectEqualStrings("Bearer same-host-token", server.records[1].authorizationSlice().?);
}

fn expectBodyRedirectRequiresResend(status: std.http.Status) !void {
    const allocator = std.testing.allocator;
    var threaded = std.Io.Threaded.init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    const responses = [_]ResponseSpec{.{
        .status = status,
        .location = "/must-not-resend",
    }};
    var server: TestServer = undefined;
    try server.init(allocator, io, &responses);
    defer server.deinit();

    const base_url = try server.baseUrl(allocator);
    defer allocator.free(base_url);
    var client = try klient.K8sClient.init(allocator, io, .{ .server = base_url });
    defer client.deinit();

    try std.testing.expectError(
        error.RedirectRequiresResend,
        client.request(.POST, "/start", "{}"),
    );
    try server.finish();
    try std.testing.expectEqual(@as(usize, 1), server.request_count);
}

test "307 with a body rejects replay without leaking the resolved URL" {
    try expectBodyRedirectRequiresResend(.temporary_redirect);
}

test "308 with a body rejects replay without leaking the resolved URL" {
    try expectBodyRedirectRequiresResend(.permanent_redirect);
}

test "streamGet strips authorization on a cross-host redirect" {
    const allocator = std.testing.allocator;
    var threaded = std.Io.Threaded.init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    const target_responses = [_]ResponseSpec{.{ .body = "cross-host" }};
    var target_server: TestServer = undefined;
    try target_server.init(allocator, io, &target_responses);
    defer target_server.deinit();

    const location = try std.fmt.allocPrint(
        allocator,
        "http://localhost:{d}/target",
        .{target_server.port()},
    );
    defer allocator.free(location);
    const source_responses = [_]ResponseSpec{.{ .status = .found, .location = location }};
    var source_server: TestServer = undefined;
    try source_server.init(allocator, io, &source_responses);
    defer source_server.deinit();

    const base_url = try source_server.baseUrl(allocator);
    defer allocator.free(base_url);
    var client = try klient.K8sClient.init(allocator, io, .{
        .server = base_url,
        .token = "source-only-token",
    });
    defer client.deinit();

    var capture: StreamCapture = .{};
    try client.streamGet(io, "/start", .{}, &capture, StreamCapture.callback);
    try source_server.finish();
    try target_server.finish();

    try std.testing.expectEqualStrings("cross-host", capture.bodySlice());
    try std.testing.expectEqualStrings("Bearer source-only-token", source_server.records[0].authorizationSlice().?);
    try std.testing.expect(target_server.records[0].authorizationSlice() == null);
}

test "resource registry is available through the public klient import" {
    const meta = klient.resource_registry.metaFor(klient.Pod);
    try std.testing.expectEqualStrings("/api/v1", meta.api_path);
    try std.testing.expectEqualStrings("pods", meta.resource_name);
    try std.testing.expectEqual(klient.resource_registry.Scope.namespaced, meta.scope);
}

const BlockedStreamContext = struct {
    client: *klient.K8sClient,
    io: std.Io,
    callback_started: *std.Io.Event,

    fn callback(
        self: *BlockedStreamContext,
        meta: klient.StreamResponseMeta,
        reader: *std.Io.Reader,
    ) anyerror!void {
        try std.testing.expectEqual(std.http.Status.ok, meta.status);
        self.callback_started.set(self.io);
        _ = try reader.takeByte();
    }

    fn run(self: *BlockedStreamContext) anyerror!void {
        return self.client.streamGet(
            self.io,
            "/held",
            .{},
            self,
            BlockedStreamContext.callback,
        );
    }
};

test "canceling the owning Future interrupts a blocked streamGet read" {
    const allocator = std.testing.allocator;
    var threaded = std.Io.Threaded.init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    var headers_sent: std.Io.Event = .unset;
    var release_response: std.Io.Event = .unset;
    const responses = [_]ResponseSpec{.{
        .headers_sent = &headers_sent,
        .release_response = &release_response,
    }};
    var server: TestServer = undefined;
    try server.init(allocator, io, &responses);
    defer server.deinit();

    const base_url = try server.baseUrl(allocator);
    defer allocator.free(base_url);
    var client = try klient.K8sClient.init(allocator, io, .{ .server = base_url });
    defer client.deinit();

    var callback_started: std.Io.Event = .unset;
    var context: BlockedStreamContext = .{
        .client = &client,
        .io = io,
        .callback_started = &callback_started,
    };
    var future = try std.Io.concurrent(io, BlockedStreamContext.run, .{&context});

    try headers_sent.wait(io);
    try callback_started.wait(io);
    try std.testing.expectError(error.Canceled, future.cancel(io));
    release_response.set(io);
    try server.finish();
}

fn discardPodEvent(event: *klient.watch.WatchEvent(klient.Pod)) anyerror!void {
    event.deinit();
}

test "WatchOutcome classifies HTTP status and copied Retry-After" {
    const allocator = std.testing.allocator;
    var threaded = std.Io.Threaded.init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    const responses = [_]ResponseSpec{
        .{ .status = .unauthorized },
        .{ .status = .forbidden },
        .{ .status = .gone },
        .{ .status = .too_many_requests, .retry_after = "11" },
        .{ .status = .internal_server_error },
        .{ .status = .gone },
    };
    var server: TestServer = undefined;
    try server.init(allocator, io, &responses);
    defer server.deinit();

    const base_url = try server.baseUrl(allocator);
    defer allocator.free(base_url);
    var client = try klient.K8sClient.init(allocator, io, .{ .server = base_url });
    defer client.deinit();

    var watcher = klient.Watcher(klient.Pod).init(&client, "/api/v1", "pods", null, .{});
    defer watcher.deinit();

    var outcome = try watcher.watchOutcome(discardPodEvent);
    try std.testing.expectEqual(.http_unauthorized, std.meta.activeTag(outcome));

    outcome = try watcher.watchOutcome(discardPodEvent);
    try std.testing.expectEqual(.http_forbidden, std.meta.activeTag(outcome));

    outcome = try watcher.watchOutcome(discardPodEvent);
    try std.testing.expectEqual(.http_gone, std.meta.activeTag(outcome));

    outcome = try watcher.watchOutcome(discardPodEvent);
    try std.testing.expectEqual(.http_throttled, std.meta.activeTag(outcome));
    try std.testing.expectEqual(@as(?u32, 11), outcome.http_throttled.retry_after_seconds);

    outcome = try watcher.watchOutcome(discardPodEvent);
    try std.testing.expectEqual(.http_server_error, std.meta.activeTag(outcome));
    try std.testing.expectEqual(std.http.Status.internal_server_error, outcome.http_server_error);

    try std.testing.expectError(error.ExpiredResourceVersion, watcher.watch(discardPodEvent));
    try server.finish();
}

test "WatchOutcome owns bounded malformed and Status event details" {
    const allocator = std.testing.allocator;
    var threaded = std.Io.Threaded.init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    const responses = [_]ResponseSpec{
        .{ .body = "{\"type\":\"ADDED\",\"object\":not-json}\n" },
        .{ .body = "{\"type\":\"ERROR\",\"object\":{\"kind\":\"Status\",\"apiVersion\":\"v1\",\"status\":\"Failure\",\"message\":\"quota exhausted\",\"reason\":\"TooManyRequests\",\"code\":429}}\n" },
        .{ .body = "{\"type\":\"ERROR\",\"object\":{\"kind\":\"Status\",\"apiVersion\":\"v1\",\"status\":\"Failure\",\"message\":\"resource version expired\",\"reason\":\"Expired\",\"code\":410}}\n" },
        .{ .body = "{\"type\":\"BOOKMARK\",\"object\":{\"metadata\":{}}}\n" },
        .{ .close_without_response = true },
    };
    var server: TestServer = undefined;
    try server.init(allocator, io, &responses);
    defer server.deinit();

    const base_url = try server.baseUrl(allocator);
    defer allocator.free(base_url);
    var client = try klient.K8sClient.init(allocator, io, .{ .server = base_url });
    defer client.deinit();

    var watcher = klient.Watcher(klient.Pod).init(&client, "/api/v1", "pods", null, .{});
    defer watcher.deinit();

    var outcome = try watcher.watchOutcome(discardPodEvent);
    try std.testing.expectEqual(.malformed_event, std.meta.activeTag(outcome));
    try std.testing.expect(std.mem.startsWith(u8, outcome.malformed_event.payloadSlice(), "{\"type\":\"ADDED\""));

    outcome = try watcher.watchOutcome(discardPodEvent);
    try std.testing.expectEqual(.status_error, std.meta.activeTag(outcome));
    try std.testing.expectEqual(@as(?u16, 429), outcome.status_error.code);
    try std.testing.expectEqualStrings("TooManyRequests", outcome.status_error.reasonSlice());
    try std.testing.expectEqualStrings("quota exhausted", outcome.status_error.messageSlice());

    outcome = try watcher.watchOutcome(discardPodEvent);
    try std.testing.expectEqual(.status_expired, std.meta.activeTag(outcome));
    try std.testing.expectEqual(@as(?u16, 410), outcome.status_expired.code);
    try std.testing.expectEqualStrings("Expired", outcome.status_expired.reasonSlice());

    outcome = try watcher.watchOutcome(discardPodEvent);
    try std.testing.expectEqual(.decode_error, std.meta.activeTag(outcome));

    outcome = try watcher.watchOutcome(discardPodEvent);
    try std.testing.expectEqual(.transport_error, std.meta.activeTag(outcome));
    try server.finish();
}

test "code-only 410 Status is expired for structured and compatibility watch APIs" {
    const allocator = std.testing.allocator;
    var threaded = std.Io.Threaded.init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    const status_event =
        "{\"type\":\"ERROR\",\"object\":{\"kind\":\"Status\",\"apiVersion\":\"v1\"," ++
        "\"status\":\"Failure\",\"message\":\"too old resource version\",\"code\":410}}\n";
    const responses = [_]ResponseSpec{
        .{ .body = status_event },
        .{ .body = status_event },
    };
    var server: TestServer = undefined;
    try server.init(allocator, io, &responses);
    defer server.deinit();

    const base_url = try server.baseUrl(allocator);
    defer allocator.free(base_url);
    var client = try klient.K8sClient.init(allocator, io, .{ .server = base_url });
    defer client.deinit();

    var watcher = klient.Watcher(klient.Pod).init(&client, "/api/v1", "pods", null, .{});
    defer watcher.deinit();

    const outcome = try watcher.watchOutcome(discardPodEvent);
    try std.testing.expectEqual(.status_expired, std.meta.activeTag(outcome));
    try std.testing.expectEqual(@as(?u16, 410), outcome.status_expired.code);
    try std.testing.expectEqualStrings("", outcome.status_expired.reasonSlice());
    try std.testing.expectEqualStrings("too old resource version", outcome.status_expired.messageSlice());

    try std.testing.expectError(error.ExpiredResourceVersion, watcher.watch(discardPodEvent));
    try server.finish();
}

test "WatchOutcome preserves typed events and advances an owned BOOKMARK version" {
    const allocator = std.testing.allocator;
    var threaded = std.Io.Threaded.init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    const body =
        "{\"type\":\"BOOKMARK\",\"object\":{\"metadata\":{\"resourceVersion\":\"88\"}}}\n" ++
        "{\"type\":\"ADDED\",\"object\":{\"metadata\":{\"name\":\"added\",\"resourceVersion\":\"89\"}}}\n" ++
        "{\"type\":\"MODIFIED\",\"object\":{\"metadata\":{\"name\":\"modified\",\"resourceVersion\":\"90\"}}}\n" ++
        "{\"type\":\"DELETED\",\"object\":{\"metadata\":{\"name\":\"deleted\",\"resourceVersion\":\"91\"}}}\n";
    const responses = [_]ResponseSpec{.{ .body = body }};
    var server: TestServer = undefined;
    try server.init(allocator, io, &responses);
    defer server.deinit();

    const base_url = try server.baseUrl(allocator);
    defer allocator.free(base_url);
    var client = try klient.K8sClient.init(allocator, io, .{ .server = base_url });
    defer client.deinit();

    var watcher = klient.Watcher(klient.Pod).init(&client, "/api/v1", "pods", null, .{});
    defer watcher.deinit();

    const Capture = struct {
        count: usize = 0,
        types: [3]klient.watch.EventType = undefined,
        names: [3][16]u8 = undefined,
        name_lengths: [3]usize = undefined,

        fn callback(self: *@This(), event: *klient.watch.WatchEvent(klient.Pod)) anyerror!void {
            defer event.deinit();
            self.types[self.count] = event.type_;
            self.name_lengths[self.count] = event.object.metadata.name.len;
            @memcpy(
                self.names[self.count][0..self.name_lengths[self.count]],
                event.object.metadata.name,
            );
            self.count += 1;
        }
    };
    var capture: Capture = .{};

    const outcome = try watcher.watchWithContextOutcome(*Capture, &capture, Capture.callback);
    try server.finish();

    try std.testing.expectEqual(.eof, std.meta.activeTag(outcome));
    try std.testing.expectEqual(3, capture.count);
    try std.testing.expectEqualSlices(
        klient.watch.EventType,
        &.{ .ADDED, .MODIFIED, .DELETED },
        capture.types[0..capture.count],
    );
    try std.testing.expectEqualStrings("added", capture.names[0][0..capture.name_lengths[0]]);
    try std.testing.expectEqualStrings("modified", capture.names[1][0..capture.name_lengths[1]]);
    try std.testing.expectEqualStrings("deleted", capture.names[2][0..capture.name_lengths[2]]);
    try std.testing.expect(watcher.resource_version_owned);
    try std.testing.expectEqualStrings("88", watcher.resource_version.?);
}

const BlockedWatchContext = struct {
    watcher: *klient.Watcher(klient.Pod),

    fn run(self: *BlockedWatchContext) anyerror!klient.WatchOutcome {
        return self.watcher.watchOutcome(discardPodEvent);
    }
};

test "WatchOutcome reports cancellation from the owning Future" {
    const allocator = std.testing.allocator;
    var threaded = std.Io.Threaded.init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    var headers_sent: std.Io.Event = .unset;
    var release_response: std.Io.Event = .unset;
    const responses = [_]ResponseSpec{.{
        .headers_sent = &headers_sent,
        .release_response = &release_response,
    }};
    var server: TestServer = undefined;
    try server.init(allocator, io, &responses);
    defer server.deinit();

    const base_url = try server.baseUrl(allocator);
    defer allocator.free(base_url);
    var client = try klient.K8sClient.init(allocator, io, .{ .server = base_url });
    defer client.deinit();

    var watcher = klient.Watcher(klient.Pod).init(&client, "/api/v1", "pods", null, .{});
    defer watcher.deinit();
    var context: BlockedWatchContext = .{ .watcher = &watcher };
    var future = try std.Io.concurrent(io, BlockedWatchContext.run, .{&context});

    try headers_sent.wait(io);
    const outcome = try future.cancel(io);
    try std.testing.expectEqual(.canceled, std.meta.activeTag(outcome));
    release_response.set(io);
    try server.finish();
}
