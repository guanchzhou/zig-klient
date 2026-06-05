// Live verification of the rewritten 0.16 WebSocket exec path.
// Drives klient.ExecClient against a real pod through kubectl proxy. Run:
//   kubectl run zig-klient-exec-test --image=busybox:1.36 --restart=Never --command -- sleep 3600
//   kubectl wait --for=condition=Ready pod/zig-klient-exec-test
//   kubectl proxy --port=8080 &
//   zig build test-pod-exec
const std = @import("std");
const klient = @import("klient");

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var threaded = std.Io.Threaded.init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  Test: Pod exec over WebSocket (zig-klient, K8s 1.36)\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n\n", .{});

    // Connect via kubectl proxy (plaintext; the proxy forwards the WS upgrade).
    var ws_client = try klient.WebSocketClient.init(allocator, io, "http://127.0.0.1:8080", null, null);
    defer ws_client.deinit();

    var exec_client = klient.ExecClient.init(allocator, &ws_client);

    const cmd = [_][]const u8{ "echo", "hello-from-zig-klient" };
    std.debug.print("🧪 exec: echo hello-from-zig-klient\n", .{});
    var result = exec_client.exec("zig-klient-exec-test", "default", .{
        .command = &cmd,
        .stdout = true,
        .stderr = true,
    }) catch |err| {
        std.debug.print("❌ exec failed: {}\n", .{err});
        return err;
    };
    defer result.deinit();

    std.debug.print("   stdout: \"{s}\"\n", .{result.stdout()});
    std.debug.print("   exit_code: {d}\n", .{result.exit_code});

    if (std.mem.indexOf(u8, result.stdout(), "hello-from-zig-klient") == null) {
        std.debug.print("\n❌ FAIL: stdout did not contain the expected echo output\n", .{});
        return error.ExecOutputMismatch;
    }
    if (result.exit_code != 0) {
        std.debug.print("\n❌ FAIL: expected exit_code 0, got {d}\n", .{result.exit_code});
        return error.ExecNonZeroExit;
    }

    std.debug.print("\n═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  ✅ exec WebSocket round-trip succeeded\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
}
