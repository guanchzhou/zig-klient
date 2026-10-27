//! Kubernetes Protobuf (`application/vnd.kubernetes.protobuf`) decoding into
//! the same structs the JSON path fills.
//!
//! A body is `k8s\x00` followed by a `runtime.Unknown` envelope whose `raw`
//! field holds the object (or list) message. `ListDecoder` reads a list body
//! from a `std.Io.Reader` and returns each item as soon as its bytes have
//! arrived; `decode` turns one encoded message into a struct.
//!
//! Field numbers come from per-type tables (`protobuf_schema.zig`). The
//! Kubernetes encoder writes every non-pointer field, including empty strings,
//! zero numbers and zero timestamps, where the JSON encoder omits them; the
//! tables mark which fields follow that `omitempty` rule so both formats give
//! the same struct.

const std = @import("std");
const Allocator = std.mem.Allocator;
const schema = @import("protobuf_schema.zig");
/// Upstream message tables; `generated.roots` pairs each supported zig-klient
/// type name with its message.
pub const generated = @import("protobuf_generated.zig");

pub const magic = "k8s\x00";
pub const content_type = "application/vnd.kubernetes.protobuf";
pub const default_max_object_size: usize = 4 << 20;

/// Whether `decode` and `ListDecoder` can produce `T`.
pub fn supports(comptime T: type) bool {
    return schema.lookup(T) != null;
}

/// Whether a `Content-Type` header value names the Kubernetes Protobuf
/// encoding, ignoring parameters and case.
pub fn isContentType(value: []const u8) bool {
    const end = std.mem.indexOfScalar(u8, value, ';') orelse value.len;
    const media_type = std.mem.trim(u8, value[0..end], " \t");
    return std.ascii.eqlIgnoreCase(media_type, content_type);
}

pub const Error = error{
    /// The body does not start with `k8s\x00`.
    BadMagic,
    /// The body ended inside a field.
    Truncated,
    /// A length or varint does not fit the bytes around it.
    Malformed,
    /// Groups (wire types 3 and 4) are not used by Kubernetes.
    UnsupportedWireType,
    /// A known field arrived with a different wire type than its table says.
    WireTypeMismatch,
    /// A struct field without a default was not present.
    MissingField,
    /// The envelope has no `raw` field.
    MissingRaw,
    /// The envelope names a content encoding (none is defined upstream).
    UnsupportedContentEncoding,
    /// A timestamp before 1970 or past year 9999.
    InvalidTime,
    /// One item, or the list metadata, is larger than `max_object_size`.
    ObjectTooLarge,
    OutOfMemory,
};

pub const WireType = enum(u3) {
    varint = 0,
    fixed64 = 1,
    len = 2,
    start_group = 3,
    end_group = 4,
    fixed32 = 5,
    _,
};

pub const Tag = struct {
    number: u32,
    wire: WireType,
};

// ---------------------------------------------------------------------------
// Field tables

/// An upstream message, as generated into `protobuf_generated.zig`.
pub const Message = struct {
    fields: []const MessageField,
};

pub const FieldType = enum {
    string,
    /// Base64 in JSON.
    bytes,
    bool,
    int32,
    int64,
    double,
    message,
    /// `metav1.Time`: RFC 3339 in UTC, whole seconds; zero is null.
    time,
    /// `metav1.MicroTime`: RFC 3339 in UTC with microseconds; zero is null.
    micro_time,
    /// `resource.Quantity`: its canonical string.
    quantity,
    /// `intstr.IntOrString`: a JSON number or string.
    int_or_string,
    /// `runtime.RawExtension` or `metav1.FieldsV1`: JSON bytes, kept as JSON.
    raw_json,
    /// A named `[]string` map value: a message repeating field 1.
    string_list,
};

pub const MessageField = struct {
    number: u32,
    /// JSON name; empty for an embedded message.
    json: []const u8,
    type: FieldType,
    message: ?*const Message = null,
    repeated: bool = false,
    /// `map<string, type>`.
    map: bool = false,
    /// A Go embedded struct whose fields belong to the outer JSON object.
    embedded: bool = false,
    /// The Go field is a value with `omitempty`, so its zero value means
    /// "unset", as in JSON. False for pointer fields, whose presence is
    /// encoded, and for fields without `omitempty`, whose JSON keeps the zero
    /// value.
    omit_zero: bool = true,
};

/// One proto field of a message, mapped to a field of the Zig struct.
pub const Field = struct {
    number: u32,
    /// Zig struct field this proto field fills. Unused for `.embedded`.
    name: []const u8 = "",
    kind: Kind = .auto,
    omit_zero: bool = true,
    /// Table of the nested message, for struct-typed Zig fields.
    message: ?[]const Field = null,
};

pub const Kind = union(enum) {
    /// Derived from the Zig field type: strings, bool, i32, i64, nested
    /// structs (with `message`), and slices of those.
    auto,
    time,
    micro_time,
    quantity,
    /// Bytes, as the base64 string JSON carries.
    base64,
    /// Any value kept as `std.json.Value`, decoded by walking its message at
    /// run time. Maps and repeated fields collect into one object or array.
    json: *const MessageField,
    /// A Go embedded struct: a nested message whose fields belong to this
    /// struct, as in the flattened JSON.
    embedded: []const Field,
};

// ---------------------------------------------------------------------------
// Wire reader over a complete message

pub const Wire = struct {
    bytes: []const u8,
    pos: usize = 0,

    pub fn atEnd(self: *const Wire) bool {
        return self.pos >= self.bytes.len;
    }

    pub fn varint(self: *Wire) Error!u64 {
        var result: u64 = 0;
        var shift: u7 = 0;
        while (true) {
            if (self.pos >= self.bytes.len) return error.Truncated;
            const byte = self.bytes[self.pos];
            self.pos += 1;
            if (shift == 63 and byte > 1) return error.Malformed;
            result |= @as(u64, byte & 0x7f) << @intCast(shift);
            if (byte & 0x80 == 0) return result;
            shift += 7;
            if (shift > 63) return error.Malformed;
        }
    }

    pub fn tag(self: *Wire) Error!Tag {
        return tagFromKey(try self.varint());
    }

    pub fn lenPrefixed(self: *Wire) Error![]const u8 {
        const len = try self.varint();
        if (len > self.bytes.len - self.pos) return error.Truncated;
        const start = self.pos;
        self.pos += @intCast(len);
        return self.bytes[start..self.pos];
    }

    pub fn skip(self: *Wire, wire: WireType) Error!void {
        switch (wire) {
            .varint => _ = try self.varint(),
            .fixed64 => try self.advance(8),
            .fixed32 => try self.advance(4),
            .len => _ = try self.lenPrefixed(),
            else => return error.UnsupportedWireType,
        }
    }

    fn advance(self: *Wire, n: usize) Error!void {
        if (n > self.bytes.len - self.pos) return error.Truncated;
        self.pos += n;
    }
};

fn tagFromKey(key: u64) Error!Tag {
    const number = key >> 3;
    if (number == 0 or number > std.math.maxInt(u29)) return error.Malformed;
    const wire: WireType = @fromBackingInt(@intCast(@as(u3, @truncate(key))));
    return .{ .number = @intCast(number), .wire = wire };
}

fn expectWire(actual: WireType, expected: WireType) Error!void {
    if (actual != expected) return error.WireTypeMismatch;
}

// ---------------------------------------------------------------------------
// Message decoding

/// Decodes one encoded message of type `T`. Strings and slices are allocated
/// from `arena`; nothing points into `bytes` afterwards.
pub fn decode(comptime T: type, arena: Allocator, bytes: []const u8) Error!T {
    return decodeMessage(T, schema.of(T), arena, bytes);
}

fn decodeMessage(comptime T: type, comptime fields: []const Field, arena: Allocator, bytes: []const u8) Error!T {
    const info = @typeInfo(T).@"struct";
    var out: T = undefined;
    var seen: std.StaticBitSet(info.field_names.len) = .empty;
    inline for (info.field_names, info.field_types, info.field_attrs, 0..) |name, F, attrs, i| {
        if (attrs.defaultValue(F)) |default| {
            @field(out, name) = default;
            seen.set(i);
        }
    }
    try decodeFields(T, fields, arena, bytes, &out, &seen);
    if (seen.count() != info.field_names.len) return error.MissingField;
    return out;
}

fn decodeFields(
    comptime T: type,
    comptime fields: []const Field,
    arena: Allocator,
    bytes: []const u8,
    out: *T,
    seen: anytype,
) Error!void {
    var counts: [fields.len]usize = @splat(0);
    var wire: Wire = .{ .bytes = bytes };
    while (!wire.atEnd()) {
        const t = try wire.tag();
        inline for (fields, 0..) |field, i| {
            if (comptime isRepeated(T, field)) {
                if (t.number == field.number) counts[i] += 1;
            }
        }
        try wire.skip(t.wire);
    }

    var filled: [fields.len]usize = @splat(0);
    inline for (fields, 0..) |field, i| {
        if (comptime isRepeated(T, field)) {
            if (counts[i] != 0) {
                const Elem = @typeInfo(Unwrapped(@FieldType(T, field.name))).pointer.child;
                @field(out, field.name) = try arena.alloc(Elem, counts[i]);
                seen.set(comptime fieldIndex(T, field.name));
            }
        }
    }

    wire = .{ .bytes = bytes };
    fields: while (!wire.atEnd()) {
        const t = try wire.tag();
        inline for (fields, 0..) |field, i| {
            if (t.number == field.number) {
                switch (field.kind) {
                    .embedded => |inner| {
                        try expectWire(t.wire, .len);
                        try decodeFields(T, inner, arena, try wire.lenPrefixed(), out, seen);
                    },
                    else => {
                        if (comptime isRepeated(T, field)) {
                            const F = @FieldType(T, field.name);
                            const Elem = @typeInfo(Unwrapped(F)).pointer.child;
                            const items = @constCast(if (comptime @typeInfo(F) == .optional) @field(out, field.name).? else @field(out, field.name));
                            const element = comptime blk: {
                                var f = field;
                                f.omit_zero = false;
                                break :blk f;
                            };
                            items[filled[i]] = (try decodeValue(Elem, element, arena, &wire, t.wire)) orelse zeroOf(Elem);
                            filled[i] += 1;
                        } else {
                            try decodeInto(T, field, arena, &wire, t.wire, out);
                        }
                        seen.set(comptime fieldIndex(T, field.name));
                    },
                }
                continue :fields;
            }
        }
        try wire.skip(t.wire);
    }
}

fn decodeInto(
    comptime T: type,
    comptime field: Field,
    arena: Allocator,
    wire: *Wire,
    wire_type: WireType,
    out: *T,
) Error!void {
    const F = @FieldType(T, field.name);
    const optional = @typeInfo(F) == .optional;
    const V = Unwrapped(F);
    if (comptime field.kind == .json and (field.kind.json.map or field.kind.json.repeated)) {
        const current: ?std.json.Value = @field(out, field.name);
        @field(out, field.name) = try collectJson(current, field.kind.json, arena, wire, wire_type);
    } else if (try decodeValue(V, field, arena, wire, wire_type)) |value| {
        @field(out, field.name) = value;
    } else if (comptime optional) {
        @field(out, field.name) = null;
    } else {
        @field(out, field.name) = zeroOf(V);
    }
}

/// Decodes one value of Zig type `V`. Null means "unset": a zero value under
/// `omit_zero`, or a zero timestamp.
fn decodeValue(comptime V: type, comptime field: Field, arena: Allocator, wire: *Wire, wire_type: WireType) Error!?V {
    switch (field.kind) {
        .time, .micro_time => {
            comptime assertString(V, field);
            try expectWire(wire_type, .len);
            return decodeTime(arena, try wire.lenPrefixed(), field.kind == .micro_time);
        },
        .quantity => {
            comptime assertString(V, field);
            try expectWire(wire_type, .len);
            return try decodeQuantity(arena, try wire.lenPrefixed());
        },
        .base64 => {
            comptime assertString(V, field);
            try expectWire(wire_type, .len);
            const bytes = try wire.lenPrefixed();
            if (field.omit_zero and bytes.len == 0) return null;
            return try encodeBase64(arena, bytes);
        },
        .json => |message_field| {
            if (V != std.json.Value) @compileError(field.name ++ ": .json needs a std.json.Value field");
            return decodeJsonValue(message_field, field.omit_zero, arena, wire, wire_type);
        },
        .auto => {},
        else => @compileError(field.name ++ ": unsupported kind for this position"),
    }

    if (V == []const u8) {
        try expectWire(wire_type, .len);
        const bytes = try wire.lenPrefixed();
        if (field.omit_zero and bytes.len == 0) return null;
        return try arena.dupe(u8, bytes);
    }
    switch (@typeInfo(V)) {
        .bool => {
            try expectWire(wire_type, .varint);
            const value = try wire.varint() != 0;
            if (field.omit_zero and !value) return null;
            return value;
        },
        .int => |info| {
            try expectWire(wire_type, .varint);
            const raw = try wire.varint();
            const value: V = switch (info.bits) {
                32 => @bitCast(@as(u32, @truncate(raw))),
                64 => @bitCast(raw),
                else => @compileError(field.name ++ ": only i32 and i64 are supported"),
            };
            if (field.omit_zero and value == 0) return null;
            return value;
        },
        .@"struct" => {
            if (V == std.json.Value) @compileError(field.name ++ ": std.json.Value needs an explicit kind");
            const fields = field.message orelse @compileError(field.name ++ ": struct field without a message table");
            try expectWire(wire_type, .len);
            return try decodeMessage(V, fields, arena, try wire.lenPrefixed());
        },
        else => @compileError(field.name ++ ": unsupported field type " ++ @typeName(V)),
    }
}

fn zeroOf(comptime V: type) V {
    if (V == []const u8) return "";
    if (V == std.json.Value) return .null;
    return switch (@typeInfo(V)) {
        .bool => false,
        .int => 0,
        else => unreachable,
    };
}

fn quantityString(bytes: []const u8) Error![]const u8 {
    var result: []const u8 = "";
    var wire: Wire = .{ .bytes = bytes };
    while (!wire.atEnd()) {
        const t = try wire.tag();
        if (t.number == 1) {
            try expectWire(t.wire, .len);
            result = try wire.lenPrefixed();
        } else try wire.skip(t.wire);
    }
    return result;
}

fn decodeQuantity(arena: Allocator, bytes: []const u8) Error![]const u8 {
    return arena.dupe(u8, try quantityString(bytes));
}

fn decodeTime(arena: Allocator, bytes: []const u8, micro: bool) Error!?[]const u8 {
    var seconds: i64 = 0;
    var nanos: i32 = 0;
    var wire: Wire = .{ .bytes = bytes };
    while (!wire.atEnd()) {
        const t = try wire.tag();
        switch (t.number) {
            1 => {
                try expectWire(t.wire, .varint);
                seconds = @bitCast(try wire.varint());
            },
            2 => {
                try expectWire(t.wire, .varint);
                nanos = @bitCast(@as(u32, @truncate(try wire.varint())));
            },
            else => try wire.skip(t.wire),
        }
    }
    if (seconds == 0 and nanos == 0) return null;
    return try formatTime(arena, seconds, nanos, micro);
}

const max_unix_seconds: i64 = 253402300799; // 9999-12-31T23:59:59Z

pub fn formatTime(arena: Allocator, seconds: i64, nanos: i32, micro: bool) Error![]const u8 {
    if (seconds < 0 or seconds > max_unix_seconds or nanos < 0 or nanos >= std.time.ns_per_s)
        return error.InvalidTime;
    const epoch: std.time.epoch.EpochSeconds = .{ .secs = @intCast(seconds) };
    const year_day = epoch.getEpochDay().calculateYearDay();
    const month_day = year_day.calculateMonthDay();
    const day_seconds = epoch.getDaySeconds();
    const date = .{
        year_day.year,
        month_day.month.numeric(),
        @as(u8, month_day.day_index) + 1,
        day_seconds.getHoursIntoDay(),
        day_seconds.getMinutesIntoHour(),
        day_seconds.getSecondsIntoMinute(),
    };
    if (micro) {
        return std.fmt.allocPrint(arena, "{d:0>4}-{d:0>2}-{d:0>2}T{d:0>2}:{d:0>2}:{d:0>2}.{d:0>6}Z", date ++ .{@as(u32, @intCast(@divTrunc(nanos, 1000)))});
    }
    return std.fmt.allocPrint(arena, "{d:0>4}-{d:0>2}-{d:0>2}T{d:0>2}:{d:0>2}:{d:0>2}Z", date);
}

// ---------------------------------------------------------------------------
// Messages kept as JSON, decoded by walking their generated table

/// Adds one wire occurrence of a map or repeated field to `current`, the
/// object or array collected so far.
fn collectJson(
    current: ?std.json.Value,
    field: *const MessageField,
    arena: Allocator,
    wire: *Wire,
    wire_type: WireType,
) Error!std.json.Value {
    if (field.map) {
        var object: std.json.ObjectMap = if (current) |value| switch (value) {
            .object => |o| o,
            else => .empty,
        } else .empty;
        try expectWire(wire_type, .len);
        try putMapEntry(&object, field, arena, try wire.lenPrefixed());
        return .{ .object = object };
    }
    var array: std.json.Array = if (current) |value| switch (value) {
        .array => |a| a,
        else => .init(arena),
    } else .init(arena);
    try array.append((try decodeJsonValue(field, false, arena, wire, wire_type)) orelse .null);
    return .{ .array = array };
}

/// Decodes one encoded `message` into the JSON object the API server would
/// send for it, without type meta.
pub fn decodeJson(message: *const Message, arena: Allocator, bytes: []const u8) Error!std.json.Value {
    return .{ .object = try decodeJsonObject(message, arena, bytes) };
}

fn decodeJsonObject(message: *const Message, arena: Allocator, bytes: []const u8) Error!std.json.ObjectMap {
    var object: std.json.ObjectMap = .empty;
    try decodeJsonFields(message, arena, bytes, &object);
    return object;
}

fn decodeJsonFields(message: *const Message, arena: Allocator, bytes: []const u8, object: *std.json.ObjectMap) Error!void {
    var wire: Wire = .{ .bytes = bytes };
    while (!wire.atEnd()) {
        const t = try wire.tag();
        const field = findField(message, t.number) orelse {
            try wire.skip(t.wire);
            continue;
        };
        if (field.embedded) {
            try expectWire(t.wire, .len);
            try decodeJsonFields(field.message.?, arena, try wire.lenPrefixed(), object);
        } else if (field.map or field.repeated) {
            const slot = try object.getOrPut(arena, field.json);
            slot.value_ptr.* = try collectJson(if (slot.found_existing) slot.value_ptr.* else null, field, arena, &wire, t.wire);
        } else if (try decodeJsonValue(field, field.omit_zero, arena, &wire, t.wire)) |value| {
            try object.put(arena, field.json, value);
        }
    }
}

fn findField(message: *const Message, number: u32) ?*const MessageField {
    for (message.fields) |*field| {
        if (field.number == number) return field;
    }
    return null;
}

fn putMapEntry(object: *std.json.ObjectMap, field: *const MessageField, arena: Allocator, bytes: []const u8) Error!void {
    var key: []const u8 = "";
    var value: ?std.json.Value = null;
    var wire: Wire = .{ .bytes = bytes };
    while (!wire.atEnd()) {
        const t = try wire.tag();
        switch (t.number) {
            1 => {
                try expectWire(t.wire, .len);
                key = try wire.lenPrefixed();
            },
            2 => value = try decodeJsonValue(field, false, arena, &wire, t.wire),
            else => try wire.skip(t.wire),
        }
    }
    try object.put(arena, try arena.dupe(u8, key), value orelse try zeroJson(field, arena));
}

/// The JSON of a map value whose entry left the value out.
fn zeroJson(field: *const MessageField, arena: Allocator) Error!std.json.Value {
    var empty: Wire = .{ .bytes = "" };
    return switch (field.type) {
        .string, .bytes => .{ .string = "" },
        .bool => .{ .bool = false },
        .int32, .int64 => .{ .integer = 0 },
        .double => .{ .float = 0 },
        .quantity => .{ .string = "0" },
        .string_list => .{ .array = .init(arena) },
        .message => .{ .object = .empty },
        else => (try decodeJsonValue(field, false, arena, &empty, .len)) orelse .null,
    };
}

/// One value of `field`, ignoring `repeated` and `map`. Null means "unset":
/// a zero value under `omit_zero`, a zero timestamp, or empty raw JSON.
fn decodeJsonValue(field: *const MessageField, omit_zero: bool, arena: Allocator, wire: *Wire, wire_type: WireType) Error!?std.json.Value {
    switch (field.type) {
        .bool => {
            try expectWire(wire_type, .varint);
            const value = try wire.varint() != 0;
            if (omit_zero and !value) return null;
            return .{ .bool = value };
        },
        .int32, .int64 => {
            try expectWire(wire_type, .varint);
            const raw = try wire.varint();
            const value: i64 = if (field.type == .int32) @as(i32, @bitCast(@as(u32, @truncate(raw)))) else @bitCast(raw);
            if (omit_zero and value == 0) return null;
            return .{ .integer = value };
        },
        .double => {
            try expectWire(wire_type, .fixed64);
            const start = wire.pos;
            try wire.skip(.fixed64);
            const value: f64 = @bitCast(std.mem.readInt(u64, wire.bytes[start..][0..8], .little));
            if (omit_zero and value == 0) return null;
            return .{ .float = value };
        },
        else => {},
    }
    try expectWire(wire_type, .len);
    const bytes = try wire.lenPrefixed();
    switch (field.type) {
        .string => {
            if (omit_zero and bytes.len == 0) return null;
            return .{ .string = try arena.dupe(u8, bytes) };
        },
        .bytes => {
            if (omit_zero and bytes.len == 0) return null;
            return .{ .string = try encodeBase64(arena, bytes) };
        },
        .message => {
            const object = try decodeJsonObject(field.message.?, arena, bytes);
            if (omit_zero and object.count() == 0) return null;
            return .{ .object = object };
        },
        .time, .micro_time => {
            const text = try decodeTime(arena, bytes, field.type == .micro_time) orelse return null;
            return .{ .string = text };
        },
        .quantity => return .{ .string = try decodeQuantity(arena, bytes) },
        .int_or_string => return try decodeIntOrString(arena, bytes),
        .raw_json => return try decodeRawJson(arena, bytes),
        .string_list => {
            var array: std.json.Array = .init(arena);
            var inner: Wire = .{ .bytes = bytes };
            while (!inner.atEnd()) {
                const t = try inner.tag();
                if (t.number != 1) {
                    try inner.skip(t.wire);
                    continue;
                }
                try expectWire(t.wire, .len);
                try array.append(.{ .string = try arena.dupe(u8, try inner.lenPrefixed()) });
            }
            return .{ .array = array };
        },
        .bool, .int32, .int64, .double => unreachable,
    }
}

fn encodeBase64(arena: Allocator, bytes: []const u8) Error![]const u8 {
    const encoder = std.base64.standard.Encoder;
    return encoder.encode(try arena.alloc(u8, encoder.calcSize(bytes.len)), bytes);
}

fn decodeIntOrString(arena: Allocator, bytes: []const u8) Error!std.json.Value {
    var is_string = false;
    var int_value: i32 = 0;
    var string_value: []const u8 = "";
    var wire: Wire = .{ .bytes = bytes };
    while (!wire.atEnd()) {
        const t = try wire.tag();
        switch (t.number) {
            1 => {
                try expectWire(t.wire, .varint);
                is_string = try wire.varint() == 1;
            },
            2 => {
                try expectWire(t.wire, .varint);
                int_value = @bitCast(@as(u32, @truncate(try wire.varint())));
            },
            3 => {
                try expectWire(t.wire, .len);
                string_value = try wire.lenPrefixed();
            },
            else => try wire.skip(t.wire),
        }
    }
    if (is_string) return .{ .string = try arena.dupe(u8, string_value) };
    return .{ .integer = int_value };
}

/// `runtime.RawExtension` and `metav1.FieldsV1` both carry JSON in field 1.
fn decodeRawJson(arena: Allocator, bytes: []const u8) Error!?std.json.Value {
    var raw: []const u8 = "";
    var wire: Wire = .{ .bytes = bytes };
    while (!wire.atEnd()) {
        const t = try wire.tag();
        if (t.number == 1) {
            try expectWire(t.wire, .len);
            raw = try wire.lenPrefixed();
        } else try wire.skip(t.wire);
    }
    if (raw.len == 0) return null;
    return std.json.parseFromSliceLeaky(std.json.Value, arena, raw, .{ .allocate = .alloc_always }) catch |err| switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        else => error.Malformed,
    };
}

// ---------------------------------------------------------------------------
// Comptime table checks

fn Unwrapped(comptime F: type) type {
    return switch (@typeInfo(F)) {
        .optional => |o| o.child,
        else => F,
    };
}

fn isRepeated(comptime T: type, comptime field: Field) bool {
    if (field.kind != .auto and field.kind != .json) return false;
    const V = Unwrapped(@FieldType(T, field.name));
    if (V == []const u8) return false;
    return @typeInfo(V) == .pointer and @typeInfo(V).pointer.size == .slice;
}

fn fieldIndex(comptime T: type, comptime name: []const u8) usize {
    for (@typeInfo(T).@"struct".field_names, 0..) |field_name, i| {
        if (std.mem.eql(u8, field_name, name)) return i;
    }
    @compileError(@typeName(T) ++ " has no field " ++ name);
}

fn assertString(comptime V: type, comptime field: Field) void {
    if (V != []const u8) @compileError(field.name ++ ": this kind needs a []const u8 field");
}

// ---------------------------------------------------------------------------
// Streaming list decoding

pub const ListMeta = struct {
    resource_version: ?[]const u8 = null,
    continue_token: ?[]const u8 = null,
    remaining_item_count: ?i64 = null,
};

pub const ListOptions = struct {
    max_object_size: usize = default_max_object_size,
};

/// Errors from `ListDecoder`: decode errors plus `error.ReadFailed` from the
/// underlying reader, which the caller can inspect for the transport cause.
pub const ListError = Error || error{ReadFailed};

const raw_field = 2;
const content_encoding_field = 3;
const list_meta_field = 1;
const list_items_field = 2;
const max_envelope_field: usize = 64 << 10;

/// Reads a Protobuf list body (`k8s\x00` + `runtime.Unknown` around a
/// `<Kind>List`) and returns its items one at a time. Each item is read in
/// full before it is decoded, so at most one item (`max_object_size`) is
/// buffered; the list itself is never held in memory.
pub fn ListDecoder(comptime T: type) type {
    return struct {
        const Self = @This();

        gpa: Allocator,
        reader: *std.Io.Reader,
        options: ListOptions,
        buffer: std.ArrayList(u8) = .empty,
        raw_left: u64 = 0,
        meta: ListMeta = .{},
        meta_arena: std.heap.ArenaAllocator,
        finished: bool = false,

        /// Reads the magic prefix and the envelope up to the start of the list.
        pub fn init(gpa: Allocator, reader: *std.Io.Reader, options: ListOptions) ListError!Self {
            var self: Self = .{
                .gpa = gpa,
                .reader = reader,
                .options = options,
                .meta_arena = .init(gpa),
            };
            errdefer self.deinit();

            var prefix: [magic.len]u8 = undefined;
            reader.readSliceAll(&prefix) catch |err| return switch (err) {
                error.EndOfStream => error.BadMagic,
                error.ReadFailed => error.ReadFailed,
            };
            if (!std.mem.eql(u8, &prefix, magic)) return error.BadMagic;

            while (true) {
                const t = (try self.envelopeTag()) orelse return error.MissingRaw;
                if (t.number == raw_field) {
                    try expectWire(t.wire, .len);
                    self.raw_left = try self.streamVarint(null);
                    return self;
                }
                try self.envelopeField(t);
            }
        }

        pub fn deinit(self: *Self) void {
            self.buffer.deinit(self.gpa);
            self.meta_arena.deinit();
            self.* = undefined;
        }

        /// The next item, decoded into `arena`, or null after the last one.
        /// List metadata is available from `listMeta` once this returns null.
        pub fn next(self: *Self, arena: Allocator) ListError!?T {
            while (self.raw_left != 0) {
                const t = try tagFromKey(try self.streamVarint(&self.raw_left));
                switch (t.number) {
                    list_items_field => {
                        try expectWire(t.wire, .len);
                        return try decode(T, arena, try self.block(&self.raw_left));
                    },
                    list_meta_field => {
                        try expectWire(t.wire, .len);
                        self.meta = try decodeListMeta(self.meta_arena.allocator(), try self.block(&self.raw_left));
                    },
                    else => try self.skipStream(t.wire, &self.raw_left),
                }
            }
            if (!self.finished) {
                while (try self.envelopeTag()) |t| {
                    if (t.number == raw_field) return error.Malformed;
                    try self.envelopeField(t);
                }
                self.finished = true;
            }
            return null;
        }

        pub fn listMeta(self: *const Self) ListMeta {
            return self.meta;
        }

        /// Null at a clean end of the body (between envelope fields).
        fn envelopeTag(self: *Self) ListError!?Tag {
            _ = self.reader.peekByte() catch |err| return switch (err) {
                error.EndOfStream => null,
                error.ReadFailed => error.ReadFailed,
            };
            return try tagFromKey(try self.streamVarint(null));
        }

        fn envelopeField(self: *Self, t: Tag) ListError!void {
            if (t.number == content_encoding_field) {
                try expectWire(t.wire, .len);
                const len = try self.streamVarint(null);
                if (len != 0) return error.UnsupportedContentEncoding;
                return;
            }
            if (t.wire == .len) {
                const len = try self.streamVarint(null);
                if (len > max_envelope_field) return error.Malformed;
                try self.discard(len);
                return;
            }
            try self.skipStream(t.wire, null);
        }

        fn block(self: *Self, budget: *u64) ListError![]const u8 {
            const len = try self.streamVarint(budget);
            if (len > budget.*) return error.Malformed;
            if (len > self.options.max_object_size) return error.ObjectTooLarge;
            const n: usize = @intCast(len);
            try self.buffer.resize(self.gpa, n);
            self.reader.readSliceAll(self.buffer.items) catch |err| return mapRead(err);
            budget.* -= len;
            return self.buffer.items;
        }

        fn skipStream(self: *Self, wire: WireType, budget: ?*u64) ListError!void {
            const n: u64 = switch (wire) {
                .varint => {
                    _ = try self.streamVarint(budget);
                    return;
                },
                .fixed64 => 8,
                .fixed32 => 4,
                .len => try self.streamVarint(budget),
                else => return error.UnsupportedWireType,
            };
            if (budget) |left| {
                if (n > left.*) return error.Malformed;
                left.* -= n;
            }
            try self.discard(n);
        }

        fn discard(self: *Self, n: u64) ListError!void {
            self.reader.discardAll64(n) catch |err| return mapRead(err);
        }

        fn streamVarint(self: *Self, budget: ?*u64) ListError!u64 {
            var result: u64 = 0;
            var shift: u7 = 0;
            while (true) {
                if (budget) |left| {
                    if (left.* == 0) return error.Malformed;
                    left.* -= 1;
                }
                const byte = self.reader.takeByte() catch |err| return mapRead(err);
                if (shift == 63 and byte > 1) return error.Malformed;
                result |= @as(u64, byte & 0x7f) << @intCast(shift);
                if (byte & 0x80 == 0) return result;
                shift += 7;
                if (shift > 63) return error.Malformed;
            }
        }
    };
}

fn mapRead(err: std.Io.Reader.Error) ListError {
    return switch (err) {
        error.EndOfStream => error.Truncated,
        error.ReadFailed => error.ReadFailed,
    };
}

fn decodeListMeta(arena: Allocator, bytes: []const u8) Error!ListMeta {
    var meta: ListMeta = .{};
    var wire: Wire = .{ .bytes = bytes };
    while (!wire.atEnd()) {
        const t = try wire.tag();
        switch (t.number) {
            2, 3 => {
                try expectWire(t.wire, .len);
                const value = try wire.lenPrefixed();
                const copy: ?[]const u8 = if (value.len == 0) null else try arena.dupe(u8, value);
                if (t.number == 2) meta.resource_version = copy else meta.continue_token = copy;
            },
            4 => {
                try expectWire(t.wire, .varint);
                meta.remaining_item_count = @bitCast(try wire.varint());
            },
            else => try wire.skip(t.wire),
        }
    }
    return meta;
}
