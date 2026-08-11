//! Regression check for `ResourceClient.listPages`.
//!
//! Needs no cluster and no TLS — run the fake apiserver alongside it:
//!
//!     python3 tests/entrypoints/fake_paging_server.py &
//!     ./zig-out/integration-tests/test_list_pages
//!
//! Guards two things that are easy to get wrong:
//!   * the `continue` token is copied out of the page arena before that arena is
//!     freed (holding the raw slice is a use-after-free);
//!   * the walk terminates on the page that omits `continue`, rather than
//!     re-requesting the last page forever.
const std = @import("std");
const klient = @import("klient");

const expected_total = 250;
const expected_pages = 3;
const page_size = 100;

const Collector = struct {
    allocator: std.mem.Allocator,
    count: usize = 0,
    pages: usize = 0,
    first: []const u8 = "",
    last: []const u8 = "",

    fn deinit(self: *Collector) void {
        if (self.first.len > 0) self.allocator.free(self.first);
        if (self.last.len > 0) self.allocator.free(self.last);
    }
};

/// Page memory is released as soon as this returns, so anything kept is copied.
fn onPage(collector: *Collector, items: []klient.Pod) anyerror!void {
    collector.pages += 1;
    if (items.len == 0) return;

    if (collector.count == 0) {
        collector.first = try collector.allocator.dupe(u8, items[0].metadata.name);
    }
    if (collector.last.len > 0) collector.allocator.free(collector.last);
    collector.last = try collector.allocator.dupe(u8, items[items.len - 1].metadata.name);
    collector.count += items.len;
}

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var threaded = std.Io.Threaded.init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    var client = try klient.K8sClient.init(allocator, io, .{
        .server = "http://127.0.0.1:18082",
    });
    defer client.deinit();

    const pods = klient.Pods.init(&client);

    var collector = Collector{ .allocator = allocator };
    defer collector.deinit();

    try pods.client.listPages("default", page_size, *Collector, &collector, onPage);

    std.debug.print("pages={d} items={d} first={s} last={s}\n", .{
        collector.pages, collector.count, collector.first, collector.last,
    });

    if (collector.count != expected_total) {
        std.debug.print("FAIL: expected {d} items, got {d}\n", .{ expected_total, collector.count });
        return error.WrongItemCount;
    }
    if (collector.pages != expected_pages) {
        std.debug.print("FAIL: expected {d} pages, got {d}\n", .{ expected_pages, collector.pages });
        return error.WrongPageCount;
    }
    if (!std.mem.eql(u8, collector.first, "pod-0") or !std.mem.eql(u8, collector.last, "pod-249")) {
        std.debug.print("FAIL: page boundaries lost items\n", .{});
        return error.WrongOrdering;
    }

    std.debug.print("OK: walked {d} items across {d} pages\n", .{ collector.count, collector.pages });
}
