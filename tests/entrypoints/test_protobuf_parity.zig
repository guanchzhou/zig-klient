//! Compares a Protobuf Pod list body with a JSON Pod list body of the same
//! cluster: every Pod present in both, at the same resourceVersion, must
//! decode into the same struct. Prints counts and decode times only.
//!
//!   zig build test-protobuf-parity -- --protobuf pods.pb --json pods.json

const std = @import("std");
const klient = @import("klient");
const pb = klient.protobuf;

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const io = init.io;
    const args = try init.minimal.args.toSlice(arena);

    var pb_path: ?[]const u8 = null;
    var json_path: ?[]const u8 = null;
    var i: usize = 1;
    while (i + 1 < args.len) : (i += 2) {
        if (std.mem.eql(u8, args[i], "--protobuf")) pb_path = args[i + 1] else if (std.mem.eql(u8, args[i], "--json")) json_path = args[i + 1] else return error.UnknownArgument;
    }
    const pb_body = try readFile(arena, io, pb_path orelse return error.MissingProtobufPath);
    const json_body = try readFile(arena, io, json_path orelse return error.MissingJsonPath);

    const started = std.Io.Clock.awake.now(io);
    var reader: std.Io.Reader = .fixed(pb_body);
    var decoder = try pb.ListDecoder(klient.Pod).init(arena, &reader, .{});
    var from_pb: std.ArrayList(klient.Pod) = .empty;
    while (try decoder.next(arena)) |pod| try from_pb.append(arena, pod);
    const pb_done = std.Io.Clock.awake.now(io);
    const pb_ms = started.durationTo(pb_done).toMilliseconds();

    const parsed = try std.json.parseFromSliceLeaky(struct { items: []klient.Pod }, arena, json_body, .{ .ignore_unknown_fields = true });
    const json_ms = pb_done.untilNow(io, .awake).toMilliseconds();

    var by_key: std.StringHashMapUnmanaged(klient.Pod) = .empty;
    for (parsed.items) |pod| try by_key.put(arena, try key(arena, pod), pod);

    var same: usize = 0;
    var changed: usize = 0;
    var missing: usize = 0;
    var different: usize = 0;
    for (from_pb.items) |pod| {
        const other = by_key.get(try key(arena, pod)) orelse {
            missing += 1;
            continue;
        };
        if (!std.mem.eql(u8, pod.metadata.resourceVersion orelse "", other.metadata.resourceVersion orelse "")) {
            changed += 1;
            continue;
        }
        const a = try std.json.Stringify.valueAlloc(arena, pod, .{});
        const b = try std.json.Stringify.valueAlloc(arena, other, .{});
        if (std.mem.eql(u8, a, b)) {
            same += 1;
        } else {
            if (different == 0) reportFirstDifference(a, b);
            different += 1;
        }
    }

    std.debug.print(
        \\protobuf: {d} pods, {d} bytes, decoded in {d} ms
        \\json:     {d} pods, {d} bytes, decoded in {d} ms
        \\identical {d}, changed between fetches {d}, only in protobuf {d}, different {d}
        \\
    , .{
        from_pb.items.len, pb_body.len,   pb_ms,
        parsed.items.len,  json_body.len, json_ms,
        same,              changed,       missing,
        different,
    });
    if (different != 0) return error.ParityMismatch;
}

fn key(arena: std.mem.Allocator, pod: klient.Pod) ![]const u8 {
    return std.fmt.allocPrint(arena, "{s}/{s}", .{ pod.metadata.namespace orelse "", pod.metadata.name });
}

/// Prints only the JSON key path around the first differing byte, never values.
fn reportFirstDifference(a: []const u8, b: []const u8) void {
    const at = std.mem.indexOfDiff(u8, a, b) orelse return;
    const start = std.mem.lastIndexOfScalar(u8, a[0..at], ',') orelse 0;
    const colon = std.mem.indexOfScalarPos(u8, a, start, ':') orelse at;
    std.debug.print("first difference at byte {d}, near key {s}\n", .{ at, a[start..@min(colon, start + 64)] });
}

fn readFile(arena: std.mem.Allocator, io: std.Io, path: []const u8) ![]u8 {
    const file = try std.Io.Dir.cwd().openFile(io, path, .{});
    defer file.close(io);
    var buffer: [64 * 1024]u8 = undefined;
    var reader = file.readerStreaming(io, &buffer);
    return reader.interface.allocRemaining(arena, .unlimited);
}
