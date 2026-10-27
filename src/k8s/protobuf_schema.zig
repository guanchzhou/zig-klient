//! Field tables for the structs `protobuf.decode` fills, projected at compile
//! time from the generated upstream messages (`protobuf_generated.zig`).
//!
//! A Zig field matches the proto field with the same JSON name, looked up
//! through embedded messages the way JSON flattens them. A Zig field with no
//! proto field is a compile error naming both.

const std = @import("std");
const pb = @import("protobuf.zig");
const Field = pb.Field;
const Message = pb.Message;
const MessageField = pb.MessageField;
const generated = @import("protobuf_generated.zig");
const types = @import("types.zig");

pub fn of(comptime T: type) []const Field {
    return lookup(T) orelse @compileError("no Protobuf table for " ++ @typeName(T));
}

pub fn lookup(comptime T: type) ?[]const Field {
    return comptime if (rootMessage(T)) |message| project(T, message) else null;
}

fn rootMessage(comptime T: type) ?*const Message {
    inline for (generated.roots) |root| {
        if (@field(types, root[0]) == T) return root[1];
    }
    return null;
}

/// Struct fields that never have a proto field: object messages do not carry
/// their own type meta, and JSON list items omit it too.
const type_meta_fields = [_][]const u8{ "apiVersion", "kind" };

/// The generic resource wrapper has a `status`; kinds without one upstream
/// leave it at its default, as their JSON does.
fn isWrapperStatus(comptime T: type, comptime name: []const u8) bool {
    if (!std.mem.eql(u8, name, "status")) return false;
    const index = std.meta.fieldIndex(T, name).?;
    return @typeInfo(T).@"struct".field_attrs[index].defaultValue(@FieldType(T, name)) != null;
}

fn project(comptime T: type, comptime message: *const Message) []const Field {
    @setEvalBranchQuota(200_000);
    comptime {
        for (@typeInfo(T).@"struct".field_names) |name| {
            if (isTypeMeta(name)) continue;
            if (hasJsonName(message, name)) continue;
            if (!isWrapperStatus(T, name))
                @compileError(@typeName(T) ++ "." ++ name ++ " has no Protobuf field in its upstream message");
        }
        const fields = projectFields(T, message);
        return &fields;
    }
}

fn projectFields(comptime T: type, comptime message: *const Message) [countProjected(T, message)]Field {
    var out: [countProjected(T, message)]Field = undefined;
    var i: usize = 0;
    for (message.fields) |*field| {
        if (field.embedded) {
            if (countProjected(T, field.message.?) == 0) continue;
            const inner = projectFields(T, field.message.?);
            out[i] = .{ .number = field.number, .kind = .{ .embedded = &inner } };
            i += 1;
        } else if (@hasField(T, field.json)) {
            out[i] = projectField(T, field);
            i += 1;
        }
    }
    return out;
}

fn countProjected(comptime T: type, comptime message: *const Message) usize {
    var n: usize = 0;
    for (message.fields) |field| {
        if (field.embedded) {
            if (countProjected(T, field.message.?) != 0) n += 1;
        } else if (@hasField(T, field.json)) n += 1;
    }
    return n;
}

fn projectField(comptime T: type, comptime field: *const MessageField) Field {
    const name = field.json;
    const where = @typeName(T) ++ "." ++ name;
    const F = Unwrapped(@FieldType(T, name));
    const base: Field = .{ .number = field.number, .name = name, .omit_zero = field.omit_zero };

    if (F == std.json.Value) return withKind(base, .{ .json = field });
    if (field.map) @compileError(where ++ ": a map needs a std.json.Value field");

    const Elem = if (field.repeated) blk: {
        if (F == []const u8 or @typeInfo(F) != .pointer or @typeInfo(F).pointer.size != .slice)
            @compileError(where ++ ": a repeated field needs a slice");
        break :blk @typeInfo(F).pointer.child;
    } else F;
    if (Elem == std.json.Value) return withKind(base, .{ .json = field });

    switch (field.type) {
        .string => expect(Elem == []const u8, where, "[]const u8"),
        .bool => expect(Elem == bool, where, "bool"),
        .int32 => expect(Elem == i32, where, "i32"),
        .int64 => expect(Elem == i64, where, "i64"),
        .time, .micro_time, .quantity, .bytes => {
            expect(Elem == []const u8, where, "[]const u8");
            return withKind(base, switch (field.type) {
                .time => .time,
                .micro_time => .micro_time,
                .bytes => .base64,
                else => .quantity,
            });
        },
        .message => {
            expect(@typeInfo(Elem) == .@"struct", where, "struct or std.json.Value");
            var nested = base;
            nested.message = project(Elem, field.message.?);
            return nested;
        },
        else => @compileError(where ++ ": ." ++ @tagName(field.type) ++ " needs a std.json.Value field"),
    }
    return base;
}

fn withKind(base: Field, kind: pb.Kind) Field {
    var field = base;
    field.kind = kind;
    return field;
}

fn expect(comptime ok: bool, comptime where: []const u8, comptime want: []const u8) void {
    if (!ok) @compileError(where ++ ": the Protobuf field needs a " ++ want ++ " Zig field");
}

fn hasJsonName(comptime message: *const Message, comptime name: []const u8) bool {
    for (message.fields) |field| {
        if (field.embedded) {
            if (hasJsonName(field.message.?, name)) return true;
        } else if (std.mem.eql(u8, field.json, name)) return true;
    }
    return false;
}

fn isTypeMeta(comptime name: []const u8) bool {
    for (type_meta_fields) |meta_name| {
        if (std.mem.eql(u8, meta_name, name)) return true;
    }
    return false;
}

fn Unwrapped(comptime F: type) type {
    return switch (@typeInfo(F)) {
        .optional => |o| o.child,
        else => F,
    };
}
