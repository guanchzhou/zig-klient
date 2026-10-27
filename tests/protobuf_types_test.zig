//! For every type in the generated tables, a randomly filled upstream list
//! (tools/protobuf-gen) must decode from Protobuf into the same struct as its
//! JSON body, and each item must decode into the same JSON object the server
//! sends. Object key order and absent-versus-null members are not compared.

const std = @import("std");
const klient = @import("klient");
const pb = klient.protobuf;
const testing = std.testing;

test "every generated type decodes like its JSON body" {
    inline for (pb.generated.roots) |root| {
        checkType(root[0], @field(klient.types, root[0]), root[1]) catch |err| {
            std.debug.print("type {s}\n", .{root[0]});
            return err;
        };
    }
}

fn checkType(comptime name: []const u8, comptime T: type, message: *const pb.Message) !void {
    const pb_body = @embedFile("fixtures/protobuf/types/" ++ name ++ ".pb");
    const json_body = @embedFile("fixtures/protobuf/types/" ++ name ++ ".json");

    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const json_items = (try std.json.parseFromSliceLeaky(struct { items: []std.json.Value }, arena, json_body, .{
        .ignore_unknown_fields = true,
    })).items;
    const typed_items = (try std.json.parseFromSliceLeaky(struct { items: []T }, arena, json_body, .{
        .ignore_unknown_fields = true,
    })).items;

    var reader: std.Io.Reader = .fixed(pb_body);
    var decoder = try pb.ListDecoder(T).init(testing.allocator, &reader, .{});
    defer decoder.deinit();
    var index: usize = 0;
    while (try decoder.next(arena)) |item| : (index += 1) {
        try testing.expect(index < typed_items.len);
        try expectSameJson(arena, try toValue(arena, typed_items[index]), try toValue(arena, item), "typed");
    }
    try testing.expectEqual(typed_items.len, index);

    for (json_items, 0..) |want, i| {
        const got = try pb.decodeJson(message, arena, try itemBytes(pb_body, i));
        var expected = want;
        _ = expected.object.orderedRemove("apiVersion");
        _ = expected.object.orderedRemove("kind");
        try expectSameJson(arena, expected, got, "json");
    }
}

fn toValue(arena: std.mem.Allocator, value: anytype) !std.json.Value {
    const text = try std.json.Stringify.valueAlloc(arena, value, .{});
    return std.json.parseFromSliceLeaky(std.json.Value, arena, text, .{});
}

fn expectSameJson(arena: std.mem.Allocator, want: std.json.Value, got: std.json.Value, path: []const u8) !void {
    if (sameJson(arena, want, got, path)) |mismatch| {
        std.debug.print("mismatch at {s}\n  want: {f}\n  got:  {f}\n", .{
            mismatch.path,
            std.json.fmt(mismatch.want, .{}),
            std.json.fmt(mismatch.got, .{}),
        });
        return error.TestExpectedEqual;
    }
}

const Mismatch = struct { path: []const u8, want: std.json.Value, got: std.json.Value };

fn sameJson(arena: std.mem.Allocator, want: std.json.Value, got: std.json.Value, path: []const u8) ?Mismatch {
    const bad: Mismatch = .{ .path = path, .want = want, .got = got };
    switch (want) {
        .object => |w| {
            if (got != .object) return bad;
            const g = got.object;
            for (w.keys(), w.values()) |key, value| {
                const sub = std.fmt.allocPrint(arena, "{s}.{s}", .{ path, key }) catch return bad;
                const other = g.get(key) orelse {
                    if (value == .null) continue;
                    return .{ .path = sub, .want = value, .got = .null };
                };
                if (sameJson(arena, value, other, sub)) |m| return m;
            }
            for (g.keys(), g.values()) |key, value| {
                if (value != .null and !w.contains(key))
                    return .{ .path = std.fmt.allocPrint(arena, "{s}.{s}", .{ path, key }) catch path, .want = .null, .got = value };
            }
            return null;
        },
        .array => |w| {
            if (got != .array or got.array.items.len != w.items.len) return bad;
            for (w.items, got.array.items, 0..) |a, b, i| {
                const sub = std.fmt.allocPrint(arena, "{s}[{d}]", .{ path, i }) catch return bad;
                if (sameJson(arena, a, b, sub)) |m| return m;
            }
            return null;
        },
        .string => |w| return if (got == .string and std.mem.eql(u8, w, got.string)) null else bad,
        .integer, .float, .number_string => return if (sameNumber(want, got)) null else bad,
        .bool => |w| return if (got == .bool and got.bool == w) null else bad,
        .null => return if (got == .null) null else bad,
    }
}

fn sameNumber(a: std.json.Value, b: std.json.Value) bool {
    return asFloat(a) == asFloat(b) and asFloat(a) != null;
}

fn asFloat(v: std.json.Value) ?f64 {
    return switch (v) {
        .integer => |i| @floatFromInt(i),
        .float => |f| f,
        .number_string => |s| std.fmt.parseFloat(f64, s) catch null,
        else => null,
    };
}

/// Bytes of item `index` inside a list body.
fn itemBytes(body: []const u8, index: usize) ![]const u8 {
    var envelope: pb.Wire = .{ .bytes = body, .pos = pb.magic.len };
    const raw = while (!envelope.atEnd()) {
        const t = try envelope.tag();
        if (t.number == 2) break try envelope.lenPrefixed();
        try envelope.skip(t.wire);
    } else return error.MissingRaw;
    var list: pb.Wire = .{ .bytes = raw };
    var seen: usize = 0;
    while (!list.atEnd()) {
        const t = try list.tag();
        if (t.number == 2) {
            const item = try list.lenPrefixed();
            if (seen == index) return item;
            seen += 1;
        } else try list.skip(t.wire);
    }
    return error.ItemNotFound;
}
