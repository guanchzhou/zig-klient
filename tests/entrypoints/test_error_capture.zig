//! Regression check for caller-owned API error detail and client sharing.
//!
//! Run against a cluster through `kubectl proxy` (see README, Connecting & TLS):
//!
//!     kubectl proxy --port=8001 &
//!     ./zig-out/integration-tests/test_error_capture
//!
//! Covers what replaced the old `client.last_api_error` field:
//!   * `requestCapturing` fills caller-owned storage on a Kubernetes Status error;
//!   * a success leaves that storage untouched, so nothing goes stale;
//!   * `ResourceClient.error_sink` carries detail out of the typed resource methods;
//!   * one `K8sClient` drives concurrent threads, each with its own sink — the field
//!     it replaced was unsynchronised state that made this unsound.
const std = @import("std");
const klient = @import("klient");

const server = "http://127.0.0.1:8001";
const namespace = "kube-system";
const thread_count = 4;
const lists_per_thread = 5;

const Worker = struct {
    client: *klient.K8sClient,
    allocator: std.mem.Allocator,
    listed: usize = 0,
    captured_code: ?i64 = null,

    fn run(self: *Worker) void {
        // Own ResourceClient value, own sink, shared K8sClient underneath.
        var api_err: ?klient.K8sClient.ApiError = null;
        defer if (api_err) |*e| e.deinit(self.allocator);

        var pods = klient.Pods.init(self.client);
        pods.client.error_sink = &api_err;

        for (0..lists_per_thread) |_| {
            const parsed = pods.client.list(namespace) catch continue;
            defer parsed.deinit();
            self.listed += parsed.value.items.len;
        }

        _ = pods.client.get("no-such-pod", namespace) catch {};
        if (api_err) |e| self.captured_code = e.code;
    }
};

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var threaded = std.Io.Threaded.init(allocator, .{});
    defer threaded.deinit();

    var client = try klient.K8sClient.init(allocator, threaded.io(), .{ .server = server });
    defer client.deinit();

    // 1. A Status error fills caller-owned storage.
    var api_err: ?klient.K8sClient.ApiError = null;
    defer if (api_err) |*e| e.deinit(allocator);

    const missing = "/api/v1/namespaces/" ++ namespace ++ "/pods/no-such-pod";
    _ = client.requestCapturing(.GET, missing, null, &api_err) catch {};

    const captured = api_err orelse {
        std.debug.print("FAIL: no detail captured for a 404\n", .{});
        return error.NoDetailCaptured;
    };
    std.debug.print("capture: code={?d} reason={s} message={s}\n", .{
        captured.code, captured.reason orelse "-", captured.message orelse "-",
    });
    if (captured.code != 404) return error.WrongStatusCaptured;

    // 2. A success must not write into the caller's storage.
    var after_success: ?klient.K8sClient.ApiError = null;
    const version = try client.requestCapturing(.GET, "/version", null, &after_success);
    allocator.free(version);
    if (after_success != null) {
        std.debug.print("FAIL: success wrote into the error sink\n", .{});
        return error.SuccessPollutedSink;
    }

    // 3. Concurrent use of one client, one sink per thread.
    var workers: [thread_count]Worker = undefined;
    var threads: [thread_count]std.Thread = undefined;
    for (&workers) |*w| w.* = .{ .client = &client, .allocator = allocator };
    for (&threads, 0..) |*t, i| t.* = try std.Thread.spawn(.{}, Worker.run, .{&workers[i]});
    for (&threads) |*t| t.join();

    for (workers, 0..) |w, i| {
        std.debug.print("thread {d}: listed {d}, captured {?d}\n", .{ i, w.listed, w.captured_code });
        if (w.listed == 0) return error.ThreadListedNothing;
        if (w.captured_code != 404) return error.ThreadLostItsOwnError;
    }

    std.debug.print("OK: detail is caller-owned and one client served {d} threads\n", .{thread_count});
}
