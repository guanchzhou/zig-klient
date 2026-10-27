const std = @import("std");
const klient = @import("klient");
const policy = klient.list_policy;
const testing = std.testing;

const Step = struct {
    status: std.http.Status = .ok,
    retry_after: ?u32 = null,
    /// `next:<token>` ends the page with that continue token; `bad` is a decode failure.
    body: []const u8 = "next:",
    transport_error: ?anyerror = null,
    /// With a transport error: whether headers arrived before it.
    headers: bool = false,
    body_started: bool = false,
};

const Driver = struct {
    steps: []const Step,
    index: usize = 0,
    sent: std.ArrayList(policy.Attempt) = .empty,
    paths: std.ArrayList([]u8) = .empty,
    refreshes: usize = 0,
    waits: std.ArrayList(u32) = .empty,

    fn deinit(self: *Driver) void {
        for (self.paths.items) |path| testing.allocator.free(path);
        self.paths.deinit(testing.allocator);
        self.sent.deinit(testing.allocator);
        self.waits.deinit(testing.allocator);
    }

    pub fn send(self: *Driver, attempt: policy.Attempt, receiver: anytype) policy.Outcome {
        const path = testing.allocator.dupe(u8, attempt.path) catch @panic("oom");
        self.paths.append(testing.allocator, path) catch @panic("oom");
        var recorded = attempt;
        recorded.path = path;
        self.sent.append(testing.allocator, recorded) catch @panic("oom");
        const step = self.steps[self.index];
        self.index += 1;
        if (step.transport_error) |err| {
            if (step.headers) {
                var reader = std.Io.Reader.failing;
                receiver.receive(.{ .status = .ok }, &reader) catch {};
            }
            return .{ .transport_error = err, .body_started = step.body_started };
        }
        var reader = std.Io.Reader.fixed(step.body);
        receiver.receive(.{ .status = step.status, .retry_after_seconds = step.retry_after }, &reader) catch {};
        return .{ .body_started = step.body.len > 0 };
    }

    pub fn refreshCredentials(self: *Driver) !void {
        self.refreshes += 1;
    }

    pub fn waitRetryAfter(self: *Driver, seconds: u32) !void {
        try self.waits.append(testing.allocator, seconds);
    }
};

const Consumer = struct {
    starts: std.ArrayList(policy.PageStart) = .empty,
    statuses: std.ArrayList(std.http.Status) = .empty,

    fn deinit(self: *Consumer) void {
        self.starts.deinit(testing.allocator);
        self.statuses.deinit(testing.allocator);
    }

    pub fn page(self: *Consumer, start: policy.PageStart, meta: policy.Meta, reader: *std.Io.Reader) anyerror![]const u8 {
        try self.starts.append(testing.allocator, start);
        try self.statuses.append(testing.allocator, meta.status);
        if (meta.status != .ok) return error.HttpStatus;
        const body = try reader.take(reader.bufferedLen());
        if (std.mem.eql(u8, body, "bad")) return error.MalformedProtobuf;
        if (!std.mem.startsWith(u8, body, "next:")) return error.Unexpected;
        return body["next:".len..];
    }

    pub fn isHttp1Retryable(_: *Consumer, err: anyerror) bool {
        return err == error.MalformedProtobuf;
    }
};

const Run = struct {
    driver: Driver,
    consumer: Consumer = .{},
    result: anyerror!void = {},

    fn init(steps: []const Step) Run {
        var self: Run = .{ .driver = .{ .steps = steps } };
        self.result = policy.run(testing.allocator, "/api/v1/pods", &self.driver, &self.consumer);
        return self;
    }

    fn deinit(self: *Run) void {
        self.driver.deinit();
        self.consumer.deinit();
    }

    fn expectPaths(self: *const Run, expected: []const []const u8) !void {
        try testing.expectEqual(expected.len, self.driver.sent.items.len);
        for (expected, self.driver.sent.items) |want, got| try testing.expectEqualStrings(want, got.path);
        try testing.expectEqual(self.driver.steps.len, self.driver.index);
    }
};

test "one streamed list, Protobuf first over HTTP/2" {
    var run = Run.init(&.{.{}});
    defer run.deinit();
    try run.result;
    try run.expectPaths(&.{"/api/v1/pods"});
    const attempt = run.driver.sent.items[0];
    try testing.expectEqual(policy.Protocol.http2, attempt.protocol);
    try testing.expectEqualStrings("application/vnd.kubernetes.protobuf, application/json", attempt.accept.header());
    try testing.expectEqual(@as(usize, 1), run.consumer.starts.items.len);
    try testing.expect(run.consumer.starts.items[0].first_page);
}

test "a JSON-only list stays on HTTP/2 and asks for JSON" {
    var driver: Driver = .{ .steps = &.{.{}} };
    defer driver.deinit();
    var consumer: Consumer = .{};
    defer consumer.deinit();
    try policy.runWithAccept(testing.allocator, "/api/v1/pods", .json, &driver, &consumer);
    try testing.expectEqual(@as(usize, 1), driver.sent.items.len);
    try testing.expectEqual(policy.Protocol.http2, driver.sent.items[0].protocol);
    try testing.expectEqualStrings("application/json", driver.sent.items[0].accept.header());
}

test "transport failure before the first byte is re-sent once on HTTP/2" {
    var run = Run.init(&.{ .{ .transport_error = error.ConnectionReset }, .{} });
    defer run.deinit();
    try run.result;
    try run.expectPaths(&.{ "/api/v1/pods", "/api/v1/pods" });
    try testing.expectEqual(policy.Protocol.http2, run.driver.sent.items[1].protocol);
}

test "the re-send does not consume the HTTP/1.1 retry" {
    var run = Run.init(&.{
        .{ .transport_error = error.ConnectionReset },
        .{ .transport_error = error.ConnectionReset },
        .{},
    });
    defer run.deinit();
    try run.result;
    try run.expectPaths(&.{ "/api/v1/pods", "/api/v1/pods", "/api/v1/pods" });
    try testing.expectEqual(policy.Protocol.http1, run.driver.sent.items[2].protocol);
    try testing.expectEqual(policy.Accept.json, run.driver.sent.items[2].accept);
}

test "a mid-stream failure goes straight to HTTP/1.1 and starts a new row set" {
    var run = Run.init(&.{
        .{ .transport_error = error.HttpStreamReset, .headers = true, .body_started = true },
        .{},
    });
    defer run.deinit();
    try run.result;
    try testing.expectEqual(policy.Protocol.http1, run.driver.sent.items[1].protocol);
    const starts = run.consumer.starts.items;
    try testing.expectEqual(@as(usize, 2), starts.len);
    try testing.expect(starts[1].first_page);
    try testing.expectEqual(policy.Protocol.http1, starts[1].protocol);
}

test "a failed HTTP/1.1 retry returns the transport error" {
    var run = Run.init(&.{
        .{ .transport_error = error.ConnectionReset, .body_started = true },
        .{ .transport_error = error.ConnectionRefused },
    });
    defer run.deinit();
    try testing.expectError(error.ConnectionRefused, run.result);
}

test "a Protobuf decode failure retries over HTTP/1.1 with JSON" {
    var run = Run.init(&.{ .{ .body = "bad" }, .{} });
    defer run.deinit();
    try run.result;
    try testing.expectEqual(policy.Accept.json, run.driver.sent.items[1].accept);
    var second = Run.init(&.{ .{ .body = "bad" }, .{ .body = "bad" } });
    defer second.deinit();
    try testing.expectError(error.MalformedProtobuf, second.result);
}

test "401 refreshes credentials once, then reaches the consumer" {
    var run = Run.init(&.{ .{ .status = .unauthorized }, .{} });
    defer run.deinit();
    try run.result;
    try testing.expectEqual(@as(usize, 1), run.driver.refreshes);
    try testing.expectEqual(@as(usize, 1), run.consumer.starts.items.len);

    var twice = Run.init(&.{ .{ .status = .unauthorized }, .{ .status = .unauthorized } });
    defer twice.deinit();
    try testing.expectError(error.HttpStatus, twice.result);
    try testing.expectEqual(@as(usize, 1), twice.driver.refreshes);
    try testing.expectEqual(std.http.Status.unauthorized, twice.consumer.statuses.items[0]);
}

test "403, 404, 410 without a token and 5xx reach the consumer without retry" {
    for ([_]std.http.Status{ .forbidden, .not_found, .gone, .internal_server_error, .service_unavailable }) |status| {
        var run = Run.init(&.{.{ .status = status }});
        defer run.deinit();
        try testing.expectError(error.HttpStatus, run.result);
        try run.expectPaths(&.{"/api/v1/pods"});
        try testing.expectEqual(status, run.consumer.statuses.items[0]);
    }
}

test "429 waits the capped Retry-After and pages at limit=500" {
    var run = Run.init(&.{
        .{ .status = .too_many_requests, .retry_after = 30 },
        .{ .body = "next:a/b" },
        .{ .body = "next:" },
    });
    defer run.deinit();
    try run.result;
    try run.expectPaths(&.{
        "/api/v1/pods",
        "/api/v1/pods?limit=500",
        "/api/v1/pods?limit=500&continue=a%2Fb",
    });
    try testing.expectEqualSlices(u32, &.{10}, run.driver.waits.items);
    const starts = run.consumer.starts.items;
    try testing.expect(starts[0].first_page and starts[0].paginated);
    try testing.expect(!starts[1].first_page and starts[1].paginated);
    try testing.expectEqual(policy.Protocol.http2, run.driver.sent.items[2].protocol);
}

test "429 without Retry-After waits one second" {
    var run = Run.init(&.{ .{ .status = .too_many_requests }, .{} });
    defer run.deinit();
    try run.result;
    try testing.expectEqualSlices(u32, &.{1}, run.driver.waits.items);
}

test "a second 429 on any page reaches the consumer with its Retry-After" {
    var run = Run.init(&.{
        .{ .status = .too_many_requests, .retry_after = 2 },
        .{ .body = "next:t" },
        .{ .status = .too_many_requests, .retry_after = 30 },
    });
    defer run.deinit();
    try testing.expectError(error.HttpStatus, run.result);
    try testing.expectEqual(std.http.Status.too_many_requests, run.consumer.statuses.items[1]);
    try testing.expectEqualSlices(u32, &.{2}, run.driver.waits.items);
}

test "a second 429 during the HTTP/1.1 retry reaches the consumer" {
    var run = Run.init(&.{
        .{ .status = .too_many_requests },
        .{ .body = "bad" },
        .{ .status = .too_many_requests },
    });
    defer run.deinit();
    try testing.expectError(error.HttpStatus, run.result);
    try testing.expectEqual(policy.Protocol.http1, run.driver.sent.items[2].protocol);
    try testing.expectEqualStrings("/api/v1/pods?limit=500", run.driver.sent.items[2].path);
}

test "410 on a continue token restarts the paginated list once" {
    var run = Run.init(&.{
        .{ .status = .too_many_requests },
        .{ .body = "next:t1" },
        .{ .status = .gone },
        .{ .body = "next:t2" },
        .{ .body = "next:" },
    });
    defer run.deinit();
    try run.result;
    try run.expectPaths(&.{
        "/api/v1/pods",
        "/api/v1/pods?limit=500",
        "/api/v1/pods?limit=500&continue=t1",
        "/api/v1/pods?limit=500",
        "/api/v1/pods?limit=500&continue=t2",
    });
    const starts = run.consumer.starts.items;
    try testing.expectEqual(@as(usize, 3), starts.len);
    try testing.expect(starts[1].first_page);
    try testing.expect(!starts[2].first_page);

    var twice = Run.init(&.{
        .{ .status = .too_many_requests },
        .{ .body = "next:t1" },
        .{ .status = .gone },
        .{ .body = "next:t2" },
        .{ .status = .gone },
    });
    defer twice.deinit();
    try testing.expectError(error.HttpStatus, twice.result);
}

test "page paths respect an existing query" {
    const path = try policy.pagePath(testing.allocator, "/api/v1/pods?pretty=false", true, "x y");
    defer testing.allocator.free(path);
    try testing.expectEqualStrings("/api/v1/pods?pretty=false&limit=500&continue=x%20y", path);
    try testing.expectEqual(@as(u32, 10), policy.retryAfterWait(3600));
    try testing.expectEqual(@as(u32, 7), policy.retryAfterWait(7));
}

test "policy cleans up on every allocation failure" {
    const steps = [_]Step{
        .{ .status = .too_many_requests },
        .{ .body = "next:t1" },
        .{ .body = "next:" },
    };
    try testing.checkAllAllocationFailures(testing.allocator, struct {
        fn run(gpa: std.mem.Allocator) !void {
            var driver: Driver = .{ .steps = &steps };
            defer driver.deinit();
            var consumer: Consumer = .{};
            defer consumer.deinit();
            try policy.run(gpa, "/api/v1/pods", &driver, &consumer);
        }
    }.run, .{});
}
