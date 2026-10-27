//! Protobuf decoder tests. The fixtures are written by the upstream Kubernetes
//! encoders (tools/protobuf-gen): each `.pb` body must decode into the
//! same structs as the `.json` body next to it.

const std = @import("std");
const klient = @import("klient");
const pb = klient.protobuf;
const testing = std.testing;

const pod_list_pb = @embedFile("fixtures/protobuf/pod_list.pb");
const pod_list_json = @embedFile("fixtures/protobuf/pod_list.json");
const page_pb = @embedFile("fixtures/protobuf/pod_list_page.pb");
const page_json = @embedFile("fixtures/protobuf/pod_list_page.json");
const empty_pb = @embedFile("fixtures/protobuf/pod_list_empty.pb");
const empty_json = @embedFile("fixtures/protobuf/pod_list_empty.json");

const Decoded = struct {
    arena: std.heap.ArenaAllocator,
    items: []klient.Pod,
    meta: pb.ListMeta,

    fn deinit(self: *Decoded) void {
        self.arena.deinit();
    }
};

fn decodeAll(reader: *std.Io.Reader, options: pb.ListOptions) !Decoded {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    errdefer arena.deinit();
    var decoder = try pb.ListDecoder(klient.Pod).init(testing.allocator, reader, options);
    defer decoder.deinit();
    var items: std.ArrayList(klient.Pod) = .empty;
    while (try decoder.next(arena.allocator())) |pod| try items.append(arena.allocator(), pod);
    const meta = decoder.listMeta();
    const copied: pb.ListMeta = .{
        .resource_version = if (meta.resource_version) |v| try arena.allocator().dupe(u8, v) else null,
        .continue_token = if (meta.continue_token) |v| try arena.allocator().dupe(u8, v) else null,
        .remaining_item_count = meta.remaining_item_count,
    };
    return .{ .arena = arena, .items = items.items, .meta = copied };
}

fn decodeBody(body: []const u8) !Decoded {
    var reader: std.Io.Reader = .fixed(body);
    return decodeAll(&reader, .{});
}

const JsonList = struct {
    metadata: struct {
        resourceVersion: ?[]const u8 = null,
        @"continue": ?[]const u8 = null,
        remainingItemCount: ?i64 = null,
    },
    items: ?[]klient.Pod = null,
};

fn expectSameAsJson(decoded: Decoded, json_body: []const u8) !void {
    const parsed = try std.json.parseFromSlice(JsonList, testing.allocator, json_body, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    const json_items = parsed.value.items orelse &.{};
    try testing.expectEqual(json_items.len, decoded.items.len);
    for (json_items, decoded.items) |from_json, from_pb| {
        const want = try std.json.Stringify.valueAlloc(testing.allocator, from_json, .{});
        defer testing.allocator.free(want);
        const got = try std.json.Stringify.valueAlloc(testing.allocator, from_pb, .{});
        defer testing.allocator.free(got);
        try testing.expectEqualStrings(want, got);
    }
    const meta = parsed.value.metadata;
    try expectOptionalString(meta.resourceVersion, decoded.meta.resource_version);
    try expectOptionalString(meta.@"continue", decoded.meta.continue_token);
    try testing.expectEqual(meta.remainingItemCount, decoded.meta.remaining_item_count);
}

fn expectOptionalString(want: ?[]const u8, got: ?[]const u8) !void {
    if (want) |w| {
        try testing.expectEqualStrings(w, got orelse return error.TestExpectedEqual);
    } else try testing.expectEqual(@as(?[]const u8, null), got);
}

test "Pod list decodes into the same structs as its JSON body" {
    var decoded = try decodeBody(pod_list_pb);
    defer decoded.deinit();
    try testing.expectEqual(@as(usize, 2), decoded.items.len);
    try expectSameAsJson(decoded, pod_list_json);

    const rich = decoded.items[0];
    try testing.expectEqualStrings("web-7d9f8c6b5-x2k4p", rich.metadata.name);
    try testing.expectEqualStrings("2026-10-26T12:00:00Z", rich.metadata.creationTimestamp.?);
    try testing.expectEqualStrings("web", rich.metadata.labels.?.object.get("app").?.string);
    try testing.expectEqual(false, rich.spec.?.hostUsers.?);
    try testing.expectEqualStrings("500m", rich.spec.?.containers.?[0].resources.?.limits.?.object.get("cpu").?.string);
    try testing.expectEqualStrings("Memory", rich.spec.?.volumes.?[3].emptyDir.?.object.get("medium").?.string);
    try testing.expectEqual(@as(i32, 137), rich.status.?.containerStatuses.?[0].lastState.?.terminated.?.exitCode);
}

test "paged and empty lists carry their list metadata" {
    var page = try decodeBody(page_pb);
    defer page.deinit();
    try expectSameAsJson(page, page_json);
    try testing.expectEqual(@as(?i64, 3), page.meta.remaining_item_count);

    var empty = try decodeBody(empty_pb);
    defer empty.deinit();
    try testing.expectEqual(@as(usize, 0), empty.items.len);
    try expectSameAsJson(empty, empty_json);
}

test "a body delivered one byte at a time decodes the same" {
    var buffer: [8]u8 = undefined;
    var source = std.testing.Reader.init(&buffer, &.{.{ .buffer = pod_list_pb }});
    source.artificial_limit = .limited(1);
    var decoded = try decodeAll(&source.interface, .{});
    defer decoded.deinit();
    try expectSameAsJson(decoded, pod_list_json);
}

test "items are returned before the rest of the body arrives" {
    const second_item_start = try itemOffset(pod_list_pb, 1);
    var reader: std.Io.Reader = .fixed(pod_list_pb[0 .. second_item_start + 3]);
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var decoder = try pb.ListDecoder(klient.Pod).init(testing.allocator, &reader, .{});
    defer decoder.deinit();
    const first = (try decoder.next(arena.allocator())).?;
    try testing.expectEqualStrings("web-7d9f8c6b5-x2k4p", first.metadata.name);
    try testing.expectError(error.Truncated, decoder.next(arena.allocator()));
}

test "every body cut inside the list is an error" {
    // Past the list, the envelope only has optional trailing fields, so a
    // cut there can still be a complete message.
    const list_end = try rawEnd(pod_list_pb);
    for (0..pod_list_pb.len) |n| {
        var reader: std.Io.Reader = .fixed(pod_list_pb[0..n]);
        if (decodeAll(&reader, .{})) |decoded| {
            var d = decoded;
            d.deinit();
            if (n >= list_end) continue;
            std.debug.print("prefix of {d} bytes decoded\n", .{n});
            return error.TestUnexpectedResult;
        } else |err| switch (err) {
            error.BadMagic, error.Truncated, error.Malformed, error.MissingRaw => {},
            else => return err,
        }
    }
}

test "a JSON body or a wrong prefix is a magic mismatch" {
    var json_reader: std.Io.Reader = .fixed(pod_list_json);
    try testing.expectError(error.BadMagic, pb.ListDecoder(klient.Pod).init(testing.allocator, &json_reader, .{}));
    var short: std.Io.Reader = .fixed("k8s");
    try testing.expectError(error.BadMagic, pb.ListDecoder(klient.Pod).init(testing.allocator, &short, .{}));
}

test "an item larger than max_object_size is rejected" {
    var reader: std.Io.Reader = .fixed(pod_list_pb);
    try testing.expectError(error.ObjectTooLarge, decodeAll(&reader, .{ .max_object_size = 256 }));
}

test "unknown fields of every wire type are skipped" {
    const item = try itemBytes(pod_list_pb, 1);
    const extra = [_]u8{
        0xa0, 0x38, 0x2a, // field 900, varint
        0xa9, 0x38, 1, 2, 3, 4, 5, 6, 7, 8, // field 901, fixed64
        0xb2, 0x38, 0x03, 'a', 'b', 'c', // field 902, length-delimited
        0xbd, 0x38, 1, 2, 3, 4, // field 903, fixed32
    };
    const with_extra = try std.mem.concat(testing.allocator, u8, &.{ item, &extra });
    defer testing.allocator.free(with_extra);

    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const plain = try pb.decode(klient.Pod, arena.allocator(), item);
    const extended = try pb.decode(klient.Pod, arena.allocator(), with_extra);
    const want = try std.json.Stringify.valueAlloc(arena.allocator(), plain, .{});
    const got = try std.json.Stringify.valueAlloc(arena.allocator(), extended, .{});
    try testing.expectEqualStrings(want, got);
}

test "groups, wire type mismatches and missing required fields are errors" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const metadata = [_]u8{ 0x0a, 0x03, 0x0a, 0x01, 'p' };
    try testing.expectError(error.UnsupportedWireType, pb.decode(klient.Pod, a, &metadata ++ [_]u8{0x2b}));
    try testing.expectError(error.WireTypeMismatch, pb.decode(klient.Pod, a, &.{ 0x08, 0x01 }));
    try testing.expectError(error.MissingField, pb.decode(klient.Pod, a, &.{}));
    const pod = try pb.decode(klient.Pod, a, &metadata);
    try testing.expectEqualStrings("p", pod.metadata.name);
}

test "varint edge cases" {
    var ok: pb.Wire = .{ .bytes = &.{ 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x01 } };
    try testing.expectEqual(std.math.maxInt(u64), try ok.varint());
    var overflow: pb.Wire = .{ .bytes = &.{ 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x02 } };
    try testing.expectError(error.Malformed, overflow.varint());
    var short: pb.Wire = .{ .bytes = &.{0x80} };
    try testing.expectError(error.Truncated, short.varint());
}

test "formatTime matches metav1 RFC 3339 output" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    try testing.expectEqualStrings("2026-10-26T12:00:00Z", try pb.formatTime(a, 1793016000, 123456789, false));
    try testing.expectEqualStrings("2026-10-26T12:00:00.123456Z", try pb.formatTime(a, 1793016000, 123456789, true));
    try testing.expectEqualStrings("2000-02-29T23:59:59Z", try pb.formatTime(a, 951868799, 0, false));
    try testing.expectError(error.InvalidTime, pb.formatTime(a, -1, 0, false));
}

test "content type and table support checks" {
    try testing.expect(pb.isContentType("application/vnd.kubernetes.protobuf"));
    try testing.expect(pb.isContentType("Application/VND.Kubernetes.Protobuf; charset=utf-8"));
    try testing.expect(!pb.isContentType("application/json"));
    try testing.expect(!pb.isContentType("application/vnd.kubernetes.protobuf.extra"));
    try testing.expect(pb.supports(klient.Pod));
    try testing.expect(pb.supports(klient.Service));
    try testing.expect(!pb.supports(klient.Gateway));
}

/// Bytes of item `index` inside a list body, found with the wire reader.
fn itemBytes(body: []const u8, index: usize) ![]const u8 {
    const start = try itemOffset(body, index);
    var wire: pb.Wire = .{ .bytes = body, .pos = start };
    _ = try wire.tag();
    return wire.lenPrefixed();
}

fn rawField(body: []const u8) ![]const u8 {
    var envelope: pb.Wire = .{ .bytes = body, .pos = pb.magic.len };
    while (!envelope.atEnd()) {
        const t = try envelope.tag();
        if (t.number == 2) return envelope.lenPrefixed();
        try envelope.skip(t.wire);
    }
    return error.MissingRaw;
}

fn rawEnd(body: []const u8) !usize {
    const raw = try rawField(body);
    return @intFromPtr(raw.ptr) - @intFromPtr(body.ptr) + raw.len;
}

fn itemOffset(body: []const u8, index: usize) !usize {
    const raw = try rawField(body);
    const raw_start = @intFromPtr(raw.ptr) - @intFromPtr(body.ptr);

    var list: pb.Wire = .{ .bytes = raw };
    var seen: usize = 0;
    while (!list.atEnd()) {
        const at = list.pos;
        const t = try list.tag();
        if (t.number == 2) {
            if (seen == index) return raw_start + at;
            seen += 1;
        }
        try list.skip(t.wire);
    }
    return error.ItemNotFound;
}
