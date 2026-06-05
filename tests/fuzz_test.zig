// Fuzz target for the kubeconfig YAML parser — the main untrusted-input surface
// (our parser + zig-yaml). Run a fuzzing campaign with:  zig build test-fuzz --fuzz
// Under a plain `zig build test` it executes once (regression + leak check via the
// testing allocator).
const std = @import("std");
const klient = @import("klient");

fn parseArbitraryKubeconfig(_: void, smith: *std.testing.Smith) anyerror!void {
    var buf: [8192]u8 = undefined;
    const n = smith.sliceWithHash(&buf, 0x6b756265); // distinct call-site id ("kube")
    const input = buf[0..n];

    const allocator = std.testing.allocator;
    var threaded = std.Io.Threaded.init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    var parser = klient.KubeconfigParser.init(allocator, io);
    // Malformed input must return an error (not crash) and leak nothing. On success
    // the returned config owns its memory and is freed here.
    var cfg = parser.parseYaml(input) catch return;
    cfg.deinit(allocator);
}

test "fuzz: kubeconfig YAML parser does not crash or leak" {
    try std.testing.fuzz({}, parseArbitraryKubeconfig, .{});
}
