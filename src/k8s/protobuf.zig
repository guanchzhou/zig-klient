const std = @import("std");

/// Protobuf wire types
pub const WireType = enum(u3) {
    varint = 0,
    fixed64 = 1,
    length_delimited = 2,
    start_group = 3, // deprecated
    end_group = 4, // deprecated
    fixed32 = 5,
};

/// Encode a varint (variable-length integer)
pub fn encodeVarint(writer: anytype, value: u64) !void {
    var v = value;
    while (v >= 0x80) {
        try writer.writeByte(@intCast((v & 0x7F) | 0x80));
        v >>= 7;
    }
    try writer.writeByte(@intCast(v & 0x7F));
}

/// Decode a varint from a reader
pub fn decodeVarint(reader: anytype) !u64 {
    var result: u64 = 0;
    var shift: u6 = 0;
    
    while (true) {
        const byte = try reader.readByte();
        result |= @as(u64, byte & 0x7F) << shift;
        
        if ((byte & 0x80) == 0) {
            break;
        }
        
        shift += 7;
        if (shift >= 64) {
            return error.VarintOverflow;
        }
    }
    
    return result;
}

/// Encode a signed varint using zigzag encoding
pub fn encodeSignedVarint(writer: anytype, value: i64) !void {
    const unsigned = zigzagEncode(value);
    try encodeVarint(writer, unsigned);
}

/// Decode a signed varint using zigzag decoding
pub fn decodeSignedVarint(reader: anytype) !i64 {
    const unsigned = try decodeVarint(reader);
    return zigzagDecode(unsigned);
}

/// Zigzag encode a signed integer
fn zigzagEncode(value: i64) u64 {
    const shifted = @as(u64, @bitCast(value)) << 1;
    const sign = @as(u64, @bitCast(value >> 63));
    return shifted ^ sign;
}

/// Zigzag decode a signed integer
fn zigzagDecode(value: u64) i64 {
    const result = (value >> 1) ^ (~(value & 1) +% 1);
    return @bitCast(result);
}

/// Encode a field tag (field number + wire type)
pub fn encodeTag(writer: anytype, field_number: u32, wire_type: WireType) !void {
    const tag = (@as(u64, field_number) << 3) | @intFromEnum(wire_type);
    try encodeVarint(writer, tag);
}

/// Decode a field tag
pub fn decodeTag(reader: anytype) !struct { field_number: u32, wire_type: WireType } {
    const tag = try decodeVarint(reader);
    return .{
        .field_number = @intCast(tag >> 3),
        .wire_type = @enumFromInt(@as(u3, @intCast(tag & 0x7))),
    };
}

/// Encode a length-delimited field (string, bytes, embedded message)
pub fn encodeLengthDelimited(writer: anytype, field_number: u32, data: []const u8) !void {
    try encodeTag(writer, field_number, .length_delimited);
    try encodeVarint(writer, data.len);
    try writer.writeAll(data);
}

/// Decode a length-delimited field
pub fn decodeLengthDelimited(reader: anytype, allocator: std.mem.Allocator) ![]u8 {
    const length = try decodeVarint(reader);
    const data = try allocator.alloc(u8, @intCast(length));
    const bytes_read = try reader.readAll(data);
    if (bytes_read != length) {
        allocator.free(data);
        return error.UnexpectedEof;
    }
    return data;
}

/// Encode a string field
pub fn encodeString(writer: anytype, field_number: u32, value: []const u8) !void {
    try encodeLengthDelimited(writer, field_number, value);
}

/// Encode a boolean field
pub fn encodeBool(writer: anytype, field_number: u32, value: bool) !void {
    try encodeTag(writer, field_number, .varint);
    try encodeVarint(writer, if (value) 1 else 0);
}

/// Decode a boolean field
pub fn decodeBool(reader: anytype) !bool {
    const value = try decodeVarint(reader);
    return value != 0;
}

/// Encode an int32 field
pub fn encodeInt32(writer: anytype, field_number: u32, value: i32) !void {
    try encodeTag(writer, field_number, .varint);
    try encodeSignedVarint(writer, value);
}

/// Decode an int32 field
pub fn decodeInt32(reader: anytype) !i32 {
    const value = try decodeSignedVarint(reader);
    return @intCast(value);
}

/// Encode an int64 field
pub fn encodeInt64(writer: anytype, field_number: u32, value: i64) !void {
    try encodeTag(writer, field_number, .varint);
    try encodeSignedVarint(writer, value);
}

/// Decode an int64 field
pub fn decodeInt64(reader: anytype) !i64 {
    return try decodeSignedVarint(reader);
}

/// Encode a uint32 field
pub fn encodeUint32(writer: anytype, field_number: u32, value: u32) !void {
    try encodeTag(writer, field_number, .varint);
    try encodeVarint(writer, value);
}

/// Decode a uint32 field
pub fn decodeUint32(reader: anytype) !u32 {
    const value = try decodeVarint(reader);
    return @intCast(value);
}

/// Encode a uint64 field
pub fn encodeUint64(writer: anytype, field_number: u32, value: u64) !void {
    try encodeTag(writer, field_number, .varint);
    try encodeVarint(writer, value);
}

/// Decode a uint64 field
pub fn decodeUint64(reader: anytype) !u64 {
    return try decodeVarint(reader);
}

/// Encode a fixed32 field
pub fn encodeFixed32(writer: anytype, field_number: u32, value: u32) !void {
    try encodeTag(writer, field_number, .fixed32);
    try writer.writeInt(u32, value, .little);
}

/// Decode a fixed32 field
pub fn decodeFixed32(reader: anytype) !u32 {
    return try reader.readInt(u32, .little);
}

/// Encode a fixed64 field
pub fn encodeFixed64(writer: anytype, field_number: u32, value: u64) !void {
    try encodeTag(writer, field_number, .fixed64);
    try writer.writeInt(u64, value, .little);
}

/// Decode a fixed64 field
pub fn decodeFixed64(reader: anytype) !u64 {
    return try reader.readInt(u64, .little);
}

/// Skip a field based on its wire type
pub fn skipField(reader: anytype, wire_type: WireType, allocator: std.mem.Allocator) !void {
    switch (wire_type) {
        .varint => _ = try decodeVarint(reader),
        .fixed64 => _ = try reader.readInt(u64, .little),
        .length_delimited => {
            const length = try decodeVarint(reader);
            try reader.skipBytes(@intCast(length), .{});
        },
        .fixed32 => _ = try reader.readInt(u32, .little),
        .start_group, .end_group => return error.DeprecatedGroupWireType,
    }
    _ = allocator; // Unused but kept for future compatibility
}

/// Protobuf message encoder
pub const MessageEncoder = struct {
    buffer: std.ArrayList(u8),

    pub fn init(allocator: std.mem.Allocator) !MessageEncoder {
        return MessageEncoder{
            .buffer = try std.ArrayList(u8).initCapacity(allocator, 1024),
        };
    }

    pub fn deinit(self: *MessageEncoder, allocator: std.mem.Allocator) void {
        self.buffer.deinit(allocator);
    }

    pub fn writer(self: *MessageEncoder) std.ArrayList(u8).Writer {
        return self.buffer.writer();
    }

    pub fn toOwnedSlice(self: *MessageEncoder, allocator: std.mem.Allocator) ![]u8 {
        return try self.buffer.toOwnedSlice(allocator);
    }

    pub fn getSlice(self: *MessageEncoder) []const u8 {
        return self.buffer.items;
    }
};

/// Protobuf message decoder
pub const MessageDecoder = struct {
    stream: std.io.FixedBufferStream([]const u8),

    pub fn init(data: []const u8) MessageDecoder {
        return MessageDecoder{
            .stream = std.io.fixedBufferStream(data),
        };
    }

    pub fn reader(self: *MessageDecoder) @TypeOf(self.stream.reader()) {
        return self.stream.reader();
    }

    pub fn isAtEnd(self: *MessageDecoder) bool {
        return self.stream.pos >= self.stream.buffer.len;
    }
};

// Tests
test "Protobuf - varint encoding/decoding" {
    const allocator = std.testing.allocator;
    
    var encoder = try MessageEncoder.init(allocator);
    defer encoder.deinit(allocator);

    // Test various varint values
    const test_values = [_]u64{ 0, 1, 127, 128, 255, 256, 65535, 65536, 0xFFFFFFFF, 0xFFFFFFFFFFFFFFFF };
    
    for (test_values) |value| {
        try encodeVarint(encoder.writer(), value);
    }

    const encoded = encoder.getSlice();
    var decoder = MessageDecoder.init(encoded);

    for (test_values) |expected| {
        const decoded = try decodeVarint(decoder.reader());
        try std.testing.expectEqual(expected, decoded);
    }
}

test "Protobuf - signed varint encoding/decoding" {
    const allocator = std.testing.allocator;
    
    var encoder = try MessageEncoder.init(allocator);
    defer encoder.deinit(allocator);

    const test_values = [_]i64{ -1, 0, 1, -100, 100, -65536, 65536, std.math.minInt(i64), std.math.maxInt(i64) };
    
    for (test_values) |value| {
        try encodeSignedVarint(encoder.writer(), value);
    }

    const encoded = encoder.getSlice();
    var decoder = MessageDecoder.init(encoded);

    for (test_values) |expected| {
        const decoded = try decodeSignedVarint(decoder.reader());
        try std.testing.expectEqual(expected, decoded);
    }
}

test "Protobuf - tag encoding/decoding" {
    const allocator = std.testing.allocator;
    
    var encoder = try MessageEncoder.init(allocator);
    defer encoder.deinit(allocator);

    try encodeTag(encoder.writer(), 1, .varint);
    try encodeTag(encoder.writer(), 2, .length_delimited);
    try encodeTag(encoder.writer(), 15, .fixed64);

    const encoded = encoder.getSlice();
    var decoder = MessageDecoder.init(encoded);

    {
        const tag1 = try decodeTag(decoder.reader());
        try std.testing.expectEqual(@as(u32, 1), tag1.field_number);
        try std.testing.expectEqual(WireType.varint, tag1.wire_type);
    }

    {
        const tag2 = try decodeTag(decoder.reader());
        try std.testing.expectEqual(@as(u32, 2), tag2.field_number);
        try std.testing.expectEqual(WireType.length_delimited, tag2.wire_type);
    }

    {
        const tag3 = try decodeTag(decoder.reader());
        try std.testing.expectEqual(@as(u32, 15), tag3.field_number);
        try std.testing.expectEqual(WireType.fixed64, tag3.wire_type);
    }
}

test "Protobuf - string encoding/decoding" {
    const allocator = std.testing.allocator;
    
    var encoder = try MessageEncoder.init(allocator);
    defer encoder.deinit(allocator);

    const test_string = "Hello, Kubernetes!";
    try encodeString(encoder.writer(), 1, test_string);

    const encoded = encoder.getSlice();
    var decoder = MessageDecoder.init(encoded);

    const tag = try decodeTag(decoder.reader());
    try std.testing.expectEqual(@as(u32, 1), tag.field_number);
    try std.testing.expectEqual(WireType.length_delimited, tag.wire_type);

    const decoded_string = try decodeLengthDelimited(decoder.reader(), allocator);
    defer allocator.free(decoded_string);

    try std.testing.expectEqualStrings(test_string, decoded_string);
}

test "Protobuf - boolean encoding/decoding" {
    const allocator = std.testing.allocator;
    
    var encoder = try MessageEncoder.init(allocator);
    defer encoder.deinit(allocator);

    try encodeBool(encoder.writer(), 1, true);
    try encodeBool(encoder.writer(), 2, false);

    const encoded = encoder.getSlice();
    var decoder = MessageDecoder.init(encoded);

    {
        const tag1 = try decodeTag(decoder.reader());
        try std.testing.expectEqual(@as(u32, 1), tag1.field_number);
        const value1 = try decodeBool(decoder.reader());
        try std.testing.expectEqual(true, value1);
    }

    {
        const tag2 = try decodeTag(decoder.reader());
        try std.testing.expectEqual(@as(u32, 2), tag2.field_number);
        const value2 = try decodeBool(decoder.reader());
        try std.testing.expectEqual(false, value2);
    }
}

