//! Bounded byte queue from one producer thread to one consumer reading through
//! `std.Io.Reader`. A chunk that does not fit is refused whole, so a producer
//! such as a libcurl write callback can pause and have the same chunk delivered
//! again; the consumer fires the resume hook once the queue drains to half.

const std = @import("std");
const Io = std.Io;

pub const default_capacity = 8 << 20;

pub const Offer = enum { accepted, pause, closed };

pub const ResumeHook = struct {
    context: *anyopaque,
    call: *const fn (context: *anyopaque) void,
};

pub const ByteQueue = struct {
    io: Io,
    gpa: std.mem.Allocator,
    mutex: Io.Mutex = .init,
    readable: Io.Condition = .init,
    ring: []u8,
    head: usize = 0,
    len: usize = 0,
    paused: bool = false,
    consumer_closed: bool = false,
    end: ?End = null,
    resume_hook: ?ResumeHook = null,
    interface: Io.Reader,

    pub const End = union(enum) { complete, failed: anyerror };

    pub fn init(
        gpa: std.mem.Allocator,
        io: Io,
        capacity: usize,
        reader_buffer: []u8,
    ) error{OutOfMemory}!ByteQueue {
        std.debug.assert(capacity > 0 and reader_buffer.len > 0);
        return .{
            .io = io,
            .gpa = gpa,
            .ring = try gpa.alloc(u8, capacity),
            .interface = .{
                .vtable = &.{ .stream = stream, .readVec = readVec },
                .buffer = reader_buffer,
                .seek = 0,
                .end = 0,
            },
        };
    }

    pub fn deinit(self: *ByteQueue) void {
        self.gpa.free(self.ring);
        self.* = undefined;
    }

    /// Producer side. `.pause` means nothing was consumed and the producer must
    /// wait for the resume hook before offering the same bytes again.
    pub fn offer(self: *ByteQueue, chunk: []const u8) error{ChunkTooLarge}!Offer {
        if (chunk.len > self.ring.len) return error.ChunkTooLarge;
        self.mutex.lockUncancelable(self.io);
        defer self.mutex.unlock(self.io);
        if (self.consumer_closed) return .closed;
        if (self.len + chunk.len > self.ring.len) {
            self.paused = true;
            return .pause;
        }
        const tail = (self.head + self.len) % self.ring.len;
        const first = @min(chunk.len, self.ring.len - tail);
        @memcpy(self.ring[tail..][0..first], chunk[0..first]);
        @memcpy(self.ring[0 .. chunk.len - first], chunk[first..]);
        self.len += chunk.len;
        if (chunk.len > 0) self.readable.signal(self.io);
        return .accepted;
    }

    /// Producer side. Readers see `error.EndOfStream` after the buffered bytes
    /// on `.complete`, or `error.ReadFailed` (with `failure()` set) on `.failed`.
    pub fn finish(self: *ByteQueue, end: End) void {
        self.mutex.lockUncancelable(self.io);
        defer self.mutex.unlock(self.io);
        if (self.end == null) self.end = end;
        self.readable.broadcast(self.io);
    }

    /// Consumer side: later offers return `.closed` and pending reads stop.
    pub fn close(self: *ByteQueue) void {
        self.mutex.lockUncancelable(self.io);
        defer self.mutex.unlock(self.io);
        self.consumer_closed = true;
        self.readable.broadcast(self.io);
    }

    pub fn failure(self: *ByteQueue) ?anyerror {
        self.mutex.lockUncancelable(self.io);
        defer self.mutex.unlock(self.io);
        const end = self.end orelse return null;
        return switch (end) {
            .complete => null,
            .failed => |err| err,
        };
    }

    pub fn isClosed(self: *ByteQueue) bool {
        self.mutex.lockUncancelable(self.io);
        defer self.mutex.unlock(self.io);
        return self.consumer_closed;
    }

    pub fn isPaused(self: *ByteQueue) bool {
        self.mutex.lockUncancelable(self.io);
        defer self.mutex.unlock(self.io);
        return self.paused;
    }

    fn stream(r: *Io.Reader, _: *Io.Writer, _: Io.Limit) Io.Reader.StreamError!usize {
        try fill(r);
        return 0;
    }

    fn readVec(r: *Io.Reader, _: [][]u8) Io.Reader.Error!usize {
        try fill(r);
        return 0;
    }

    fn fill(r: *Io.Reader) Io.Reader.Error!void {
        const self: *ByteQueue = @alignCast(@fieldParentPtr("interface", r));
        if (r.seek > 0) {
            const kept = r.end - r.seek;
            @memmove(r.buffer[0..kept], r.buffer[r.seek..r.end]);
            r.seek = 0;
            r.end = kept;
        }
        if (r.end == r.buffer.len) return;

        var hook: ?ResumeHook = null;
        defer if (hook) |h| h.call(h.context);

        self.mutex.lockUncancelable(self.io);
        defer self.mutex.unlock(self.io);
        while (self.len == 0 and self.end == null and !self.consumer_closed)
            self.readable.waitUncancelable(self.io, &self.mutex);
        if (self.len == 0) {
            if (self.consumer_closed) return error.ReadFailed;
            return switch (self.end.?) {
                .complete => error.EndOfStream,
                .failed => error.ReadFailed,
            };
        }
        const n = @min(self.len, r.buffer.len - r.end, self.ring.len - self.head);
        @memcpy(r.buffer[r.end..][0..n], self.ring[self.head..][0..n]);
        r.end += n;
        self.head = (self.head + n) % self.ring.len;
        self.len -= n;
        if (self.paused and self.len <= self.ring.len / 2 and self.end == null) {
            self.paused = false;
            hook = self.resume_hook;
        }
    }
};

const testing = std.testing;

test "bytes cross in order and end cleanly" {
    var reader_buffer: [4]u8 = undefined;
    var queue = try ByteQueue.init(testing.allocator, testing.io, 8, &reader_buffer);
    defer queue.deinit();
    try testing.expectEqual(Offer.accepted, try queue.offer("abcde"));
    try testing.expectEqual(Offer.accepted, try queue.offer("fg"));
    queue.finish(.complete);
    var out: [16]u8 = undefined;
    var writer = Io.Writer.fixed(&out);
    _ = try queue.interface.streamRemaining(&writer);
    try testing.expectEqualStrings("abcdefg", writer.buffered());
}

test "a chunk that does not fit is refused whole and resumes at half" {
    const Hook = struct {
        calls: usize = 0,
        fn call(context: *anyopaque) void {
            const self: *@This() = @ptrCast(@alignCast(context));
            self.calls += 1;
        }
    };
    var hook: Hook = .{};
    var reader_buffer: [2]u8 = undefined;
    var queue = try ByteQueue.init(testing.allocator, testing.io, 8, &reader_buffer);
    defer queue.deinit();
    queue.resume_hook = .{ .context = &hook, .call = Hook.call };

    try testing.expectEqual(Offer.accepted, try queue.offer("1234567"));
    try testing.expectEqual(Offer.pause, try queue.offer("89"));
    try testing.expect(queue.isPaused());
    try testing.expectEqual(@as(usize, 7), queue.len);

    try testing.expectEqualStrings("12", try queue.interface.take(2));
    try testing.expectEqual(@as(usize, 0), hook.calls);
    try testing.expectEqualStrings("34", try queue.interface.take(2));
    try testing.expectEqual(@as(usize, 1), hook.calls);
    try testing.expect(!queue.isPaused());

    try testing.expectEqual(Offer.accepted, try queue.offer("89"));
    queue.finish(.complete);
    var out: [16]u8 = undefined;
    var writer = Io.Writer.fixed(&out);
    _ = try queue.interface.streamRemaining(&writer);
    try testing.expectEqualStrings("56789", writer.buffered());
    try testing.expectEqual(@as(usize, 1), hook.calls);
}

test "ring wraps around its end" {
    var reader_buffer: [3]u8 = undefined;
    var queue = try ByteQueue.init(testing.allocator, testing.io, 5, &reader_buffer);
    defer queue.deinit();
    _ = try queue.offer("abcd");
    try testing.expectEqualStrings("abc", try queue.interface.take(3));
    _ = try queue.offer("efgh");
    queue.finish(.complete);
    var out: [8]u8 = undefined;
    var writer = Io.Writer.fixed(&out);
    _ = try queue.interface.streamRemaining(&writer);
    try testing.expectEqualStrings("defgh", writer.buffered());
}

test "a failed end surfaces after buffered bytes" {
    var reader_buffer: [8]u8 = undefined;
    var queue = try ByteQueue.init(testing.allocator, testing.io, 8, &reader_buffer);
    defer queue.deinit();
    _ = try queue.offer("ab");
    queue.finish(.{ .failed = error.ConnectionReset });
    try testing.expectEqualStrings("ab", try queue.interface.take(2));
    try testing.expectError(error.ReadFailed, queue.interface.takeByte());
    try testing.expectEqual(@as(?anyerror, error.ConnectionReset), queue.failure());
}

test "a closed consumer refuses further bytes" {
    var reader_buffer: [8]u8 = undefined;
    var queue = try ByteQueue.init(testing.allocator, testing.io, 8, &reader_buffer);
    defer queue.deinit();
    queue.close();
    try testing.expectEqual(Offer.closed, try queue.offer("x"));
    try testing.expectError(error.ChunkTooLarge, queue.offer("123456789"));
}

test "producer thread and consumer stay in order under pause pressure" {
    const Producer = struct {
        queue: *ByteQueue,
        resumed: Io.Event = .unset,

        fn onResume(context: *anyopaque) void {
            const self: *@This() = @ptrCast(@alignCast(context));
            self.resumed.set(self.queue.io);
        }

        fn run(self: *@This()) void {
            var counter: u8 = 0;
            for (0..2000) |_| {
                var chunk: [7]u8 = undefined;
                for (&chunk) |*byte| {
                    byte.* = counter;
                    counter +%= 1;
                }
                while (true) {
                    self.resumed.reset();
                    switch (self.queue.offer(&chunk) catch unreachable) {
                        .accepted => break,
                        .pause => self.resumed.waitTimeout(self.queue.io, .{ .duration = .{
                            .raw = .fromMilliseconds(5),
                            .clock = .awake,
                        } }) catch {},
                        .closed => return,
                    }
                }
            }
            self.queue.finish(.complete);
        }
    };
    var reader_buffer: [5]u8 = undefined;
    var queue = try ByteQueue.init(testing.allocator, testing.io, 32, &reader_buffer);
    defer queue.deinit();
    var producer: Producer = .{ .queue = &queue };
    queue.resume_hook = .{ .context = &producer, .call = Producer.onResume };
    const thread = try std.Thread.spawn(.{}, Producer.run, .{&producer});
    defer thread.join();

    var expected: u8 = 0;
    var total: usize = 0;
    while (queue.interface.takeByte()) |byte| {
        try testing.expectEqual(expected, byte);
        expected +%= 1;
        total += 1;
    } else |err| try testing.expectEqual(error.EndOfStream, err);
    try testing.expectEqual(@as(usize, 14_000), total);
}
