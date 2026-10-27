//! Retry rules for one streamed list read, independent of the HTTP stack.
//!
//! - A transport failure before the first body byte on HTTP/2 is re-sent once.
//! - 401 refreshes credentials and retries once.
//! - The first 429 waits Retry-After (capped at 10 s, 1 s when absent) and
//!   re-runs the list paginated at `limit=500`; any later 429 reaches the consumer.
//! - 410 on a continue token restarts the paginated list once.
//! - A transport failure, or a consumer error it marks retryable (bad Protobuf),
//!   restarts the list once over HTTP/1.1 with JSON.
//! - Any other status reaches the consumer, which maps it to an error.

const std = @import("std");

pub const max_retry_after_seconds: u32 = 10;
pub const default_retry_after_seconds: u32 = 1;
pub const page_limit = 500;

pub const Protocol = enum { http2, http1 };
pub const Accept = enum {
    protobuf_first,
    json,

    pub fn header(self: Accept) []const u8 {
        return switch (self) {
            .protobuf_first => "application/vnd.kubernetes.protobuf, application/json",
            .json => "application/json",
        };
    }
};

pub const Attempt = struct {
    path: []const u8,
    protocol: Protocol,
    accept: Accept,
};

pub const Meta = struct {
    status: std.http.Status,
    retry_after_seconds: ?u32 = null,
    content_type: ?[]const u8 = null,
};

/// What a driver reports after one request. `transport_error` covers failures
/// outside the consumer: connect, TLS, reset, timeout, HTTP/2 protocol.
pub const Outcome = struct {
    transport_error: ?anyerror = null,
    body_started: bool = false,
};

/// `first_page` starts a new row set that replaces any earlier partial one.
pub const PageStart = struct {
    first_page: bool,
    paginated: bool,
    protocol: Protocol,
};

pub fn retryAfterWait(header_seconds: ?u32) u32 {
    const seconds = header_seconds orelse return default_retry_after_seconds;
    return @min(seconds, max_retry_after_seconds);
}

/// Driver: `send(Attempt, receiver: anytype) Outcome`, calling
/// `receiver.receive(Meta, *std.Io.Reader) anyerror!void` once headers arrive;
/// `refreshCredentials() !void`; `waitRetryAfter(seconds: u32) !void`.
/// Consumer: `page(PageStart, Meta, *std.Io.Reader) anyerror![]const u8`
/// returning the continue token (borrowed until the next call), and
/// `isHttp1Retryable(anyerror) bool`.
pub fn run(
    gpa: std.mem.Allocator,
    base_path: []const u8,
    driver: anytype,
    consumer: anytype,
) !void {
    return runWithAccept(gpa, base_path, .protobuf_first, driver, consumer);
}

/// `run` starting from `accept`; `.json` suits consumers that cannot decode
/// Protobuf, so the server never sends a body they would throw away.
pub fn runWithAccept(
    gpa: std.mem.Allocator,
    base_path: []const u8,
    accept: Accept,
    driver: anytype,
    consumer: anytype,
) !void {
    var state: State = .{ .accept = accept };
    var token: ?[]u8 = null;
    defer if (token) |owned| gpa.free(owned);
    var first_page = true;

    while (true) {
        const path = try pagePath(gpa, base_path, state.paginated, token);
        defer gpa.free(path);

        const Receiver = ReceiverFor(@TypeOf(consumer));
        var receiver: Receiver = .{
            .consumer = consumer,
            .state = &state,
            .start = .{ .first_page = first_page, .paginated = state.paginated, .protocol = state.protocol },
            .has_token = token != null,
        };
        const outcome: Outcome = driver.send(
            .{ .path = path, .protocol = state.protocol, .accept = state.accept },
            &receiver,
        );

        if (receiver.intercepted) |status| {
            switch (status) {
                .unauthorized => {
                    state.refreshed = true;
                    try driver.refreshCredentials();
                },
                .too_many_requests => {
                    state.saw_429 = true;
                    try driver.waitRetryAfter(retryAfterWait(receiver.meta.?.retry_after_seconds));
                    state.paginated = true;
                    clearToken(gpa, &token);
                    first_page = true;
                },
                .gone => {
                    state.restarted_410 = true;
                    clearToken(gpa, &token);
                    first_page = true;
                },
                else => unreachable,
            }
            continue;
        }

        if (outcome.transport_error) |err| {
            if (state.protocol == .http2 and !state.resent and !outcome.body_started) {
                state.resent = true;
                continue;
            }
            if (state.switchToHttp1()) {
                clearToken(gpa, &token);
                first_page = true;
                continue;
            }
            return err;
        }
        if (!receiver.called) return error.NoResponse;
        if (receiver.err) |err| {
            if (consumer.isHttp1Retryable(err) and state.switchToHttp1()) {
                clearToken(gpa, &token);
                first_page = true;
                continue;
            }
            return err;
        }

        if (!state.paginated) return;
        const next = receiver.next_token;
        if (next.len == 0) return;
        const owned = try gpa.dupe(u8, next);
        clearToken(gpa, &token);
        token = owned;
        first_page = false;
    }
}

const State = struct {
    protocol: Protocol = .http2,
    accept: Accept = .protobuf_first,
    paginated: bool = false,
    resent: bool = false,
    refreshed: bool = false,
    saw_429: bool = false,
    restarted_410: bool = false,
    http1_used: bool = false,

    fn switchToHttp1(self: *State) bool {
        if (self.http1_used) return false;
        self.http1_used = true;
        self.protocol = .http1;
        self.accept = .json;
        return true;
    }

    fn intercepts(self: *const State, status: std.http.Status, has_token: bool) bool {
        return switch (status) {
            .unauthorized => !self.refreshed,
            .too_many_requests => !self.saw_429,
            .gone => self.paginated and has_token and !self.restarted_410,
            else => false,
        };
    }
};

fn ReceiverFor(comptime Consumer: type) type {
    return struct {
        consumer: Consumer,
        state: *const State,
        start: PageStart,
        has_token: bool,
        called: bool = false,
        meta: ?Meta = null,
        intercepted: ?std.http.Status = null,
        err: ?anyerror = null,
        next_token: []const u8 = "",

        pub fn receive(self: *@This(), meta: Meta, reader: *std.Io.Reader) anyerror!void {
            self.called = true;
            self.meta = meta;
            if (self.state.intercepts(meta.status, self.has_token)) {
                self.intercepted = meta.status;
                return;
            }
            self.next_token = self.consumer.page(self.start, meta, reader) catch |err| {
                self.err = err;
                return err;
            };
        }
    };
}

fn clearToken(gpa: std.mem.Allocator, token: *?[]u8) void {
    if (token.*) |owned| gpa.free(owned);
    token.* = null;
}

pub fn pagePath(
    gpa: std.mem.Allocator,
    base: []const u8,
    paginated: bool,
    continue_token: ?[]const u8,
) error{OutOfMemory}![]u8 {
    if (!paginated) return gpa.dupe(u8, base);
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(gpa);
    try out.appendSlice(gpa, base);
    try out.append(gpa, if (std.mem.findScalar(u8, base, '?') == null) '?' else '&');
    try out.print(gpa, "limit={d}", .{page_limit});
    if (continue_token) |value| {
        try out.appendSlice(gpa, "&continue=");
        const hex = "0123456789ABCDEF";
        for (value) |byte| {
            if (std.ascii.isAlphanumeric(byte) or byte == '-' or byte == '.' or byte == '_' or byte == '~') {
                try out.append(gpa, byte);
            } else {
                try out.appendSlice(gpa, &.{ '%', hex[byte >> 4], hex[byte & 0x0f] });
            }
        }
    }
    return out.toOwnedSlice(gpa);
}
