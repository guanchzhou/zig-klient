const std = @import("std");
const protobuf = @import("protobuf.zig");
const types = @import("types.zig");

/// Kubernetes API version for Protobuf
pub const K8S_API_VERSION = "v1";
pub const K8S_CONTENT_TYPE = "application/vnd.kubernetes.protobuf";
pub const K8S_CONTENT_TYPE_WITH_CHARSET = "application/vnd.kubernetes.protobuf;charset=utf-8";

/// Field numbers for Kubernetes common metadata
pub const FieldNumbers = struct {
    // TypeMeta fields
    pub const api_version = 1;
    pub const kind = 2;
    
    // ObjectMeta fields (starting from 10 to avoid conflicts)
    pub const metadata_name = 10;
    pub const metadata_namespace = 11;
    pub const metadata_uid = 12;
    pub const metadata_resource_version = 13;
    pub const metadata_labels = 14;
    pub const metadata_annotations = 15;
    pub const metadata_creation_timestamp = 16;
    pub const metadata_deletion_timestamp = 17;
    
    // Spec field
    pub const spec = 20;
    
    // Status field
    pub const status = 30;
    
    // List metadata
    pub const list_metadata = 40;
    pub const list_items = 41;
};

/// Encode Kubernetes TypeMeta
pub fn encodeTypeMeta(encoder: *protobuf.MessageEncoder, api_version: ?[]const u8, kind: ?[]const u8) !void {
    if (api_version) |av| {
        try protobuf.encodeString(encoder.writer(), FieldNumbers.api_version, av);
    }
    if (kind) |k| {
        try protobuf.encodeString(encoder.writer(), FieldNumbers.kind, k);
    }
}

/// Decode Kubernetes TypeMeta
pub fn decodeTypeMeta(decoder: *protobuf.MessageDecoder, allocator: std.mem.Allocator) !struct {
    api_version: ?[]const u8,
    kind: ?[]const u8,
} {
    var api_version: ?[]const u8 = null;
    var kind: ?[]const u8 = null;

    while (!decoder.isAtEnd()) {
        const tag = try protobuf.decodeTag(decoder.reader());
        
        switch (tag.field_number) {
            FieldNumbers.api_version => {
                api_version = try protobuf.decodeLengthDelimited(decoder.reader(), allocator);
            },
            FieldNumbers.kind => {
                kind = try protobuf.decodeLengthDelimited(decoder.reader(), allocator);
            },
            else => {
                try protobuf.skipField(decoder.reader(), tag.wire_type, allocator);
            },
        }
    }

    return .{
        .api_version = api_version,
        .kind = kind,
    };
}

/// Encode Kubernetes ObjectMeta (simplified version)
pub fn encodeObjectMeta(encoder: *protobuf.MessageEncoder, metadata: types.ObjectMeta) !void {
    if (metadata.name) |name| {
        try protobuf.encodeString(encoder.writer(), FieldNumbers.metadata_name, name);
    }
    if (metadata.namespace) |namespace| {
        try protobuf.encodeString(encoder.writer(), FieldNumbers.metadata_namespace, namespace);
    }
    if (metadata.uid) |uid| {
        try protobuf.encodeString(encoder.writer(), FieldNumbers.metadata_uid, uid);
    }
    if (metadata.resourceVersion) |rv| {
        try protobuf.encodeString(encoder.writer(), FieldNumbers.metadata_resource_version, rv);
    }
    // Note: labels and annotations require map encoding (more complex, would be added next)
}

/// Encode a generic Kubernetes resource to Protobuf
pub fn encodeResource(
    comptime T: type,
    allocator: std.mem.Allocator,
    resource: T,
) ![]u8 {
    var encoder = try protobuf.MessageEncoder.init(allocator);
    errdefer encoder.deinit(allocator);

    // Encode TypeMeta
    const resource_info = @typeInfo(T);
    if (resource_info == .@"struct") {
        if (@hasField(T, "apiVersion")) {
            if (@field(resource, "apiVersion")) |api_version| {
                try protobuf.encodeString(encoder.writer(), FieldNumbers.api_version, api_version);
            }
        }
        if (@hasField(T, "kind")) {
            if (@field(resource, "kind")) |kind| {
                try protobuf.encodeString(encoder.writer(), FieldNumbers.kind, kind);
            }
        }

        // Encode ObjectMeta
        if (@hasField(T, "metadata")) {
            const metadata = @field(resource, "metadata");
            
            // Create embedded message for metadata
            var metadata_encoder = try protobuf.MessageEncoder.init(allocator);
            defer metadata_encoder.deinit(allocator);
            
            try encodeObjectMeta(&metadata_encoder, metadata);
            const metadata_bytes = metadata_encoder.getSlice();
            
            // Encode metadata as length-delimited field
            try protobuf.encodeLengthDelimited(encoder.writer(), 3, metadata_bytes);
        }

        // Note: Spec encoding would require type-specific logic for each resource type
        // This is a simplified implementation demonstrating the approach
    }

    return try encoder.toOwnedSlice(allocator);
}

/// Decode a generic Kubernetes resource from Protobuf
pub fn decodeResource(
    comptime T: type,
    allocator: std.mem.Allocator,
    data: []const u8,
) !T {
    var decoder = protobuf.MessageDecoder.init(data);
    
    // This is a simplified decoder demonstrating the approach
    // Full implementation would need to handle all fields of each resource type
    
    var api_version: ?[]const u8 = null;
    var kind: ?[]const u8 = null;
    var metadata: ?types.ObjectMeta = null;

    while (!decoder.isAtEnd()) {
        const tag = try protobuf.decodeTag(decoder.reader());
        
        switch (tag.field_number) {
            FieldNumbers.api_version => {
                api_version = try protobuf.decodeLengthDelimited(decoder.reader(), allocator);
            },
            FieldNumbers.kind => {
                kind = try protobuf.decodeLengthDelimited(decoder.reader(), allocator);
            },
            3 => { // metadata field
                // Decode embedded metadata message
                const metadata_bytes = try protobuf.decodeLengthDelimited(decoder.reader(), allocator);
                defer allocator.free(metadata_bytes);
                
                // Parse metadata (simplified)
                metadata = types.ObjectMeta{
                    .name = null,
                    .namespace = null,
                    .uid = null,
                    .resourceVersion = null,
                    .labels = null,
                    .annotations = null,
                };
            },
            else => {
                try protobuf.skipField(decoder.reader(), tag.wire_type, allocator);
            },
        }
    }

    // Construct resource (simplified - would need full field mapping)
    // Full implementation would construct the actual resource from decoded fields
    // For now, return a zero-initialized value with the decoded metadata
    var result = std.mem.zeroes(T);
    
    // Set decoded values if the type has these fields
    const type_info = @typeInfo(T);
    if (type_info == .@"struct") {
        if (@hasField(T, "apiVersion") and api_version != null) {
            @field(result, "apiVersion") = api_version;
        }
        if (@hasField(T, "kind") and kind != null) {
            @field(result, "kind") = kind;
        }
        if (@hasField(T, "metadata") and metadata != null) {
            @field(result, "metadata") = metadata.?;
        }
    }
    
    return result;
}

/// Add Protobuf Content-Type headers to HTTP request
pub fn addProtobufHeaders(headers: *std.http.Headers) !void {
    try headers.append("Accept", K8S_CONTENT_TYPE);
    try headers.append("Content-Type", K8S_CONTENT_TYPE_WITH_CHARSET);
}

/// Check if response uses Protobuf encoding
pub fn isProtobufResponse(content_type: []const u8) bool {
    return std.mem.indexOf(u8, content_type, "protobuf") != null;
}

// Tests
test "Protobuf K8s - TypeMeta encoding/decoding" {
    const allocator = std.testing.allocator;
    
    var encoder = try protobuf.MessageEncoder.init(allocator);
    defer encoder.deinit(allocator);

    try encodeTypeMeta(&encoder, "v1", "Pod");

    const encoded = encoder.getSlice();
    var decoder = protobuf.MessageDecoder.init(encoded);

    const decoded = try decodeTypeMeta(&decoder, allocator);
    defer {
        if (decoded.api_version) |av| allocator.free(av);
        if (decoded.kind) |k| allocator.free(k);
    }

    try std.testing.expectEqualStrings("v1", decoded.api_version.?);
    try std.testing.expectEqualStrings("Pod", decoded.kind.?);
}

test "Protobuf K8s - ObjectMeta encoding" {
    const allocator = std.testing.allocator;
    
    var encoder = try protobuf.MessageEncoder.init(allocator);
    defer encoder.deinit(allocator);

    const metadata = types.ObjectMeta{
        .name = "test-pod",
        .namespace = "default",
        .uid = "12345",
        .resourceVersion = "100",
        .labels = null,
        .annotations = null,
    };

    try encodeObjectMeta(&encoder, metadata);

    const encoded = encoder.getSlice();
    try std.testing.expect(encoded.len > 0);
}

test "Protobuf K8s - Content-Type detection" {
    try std.testing.expect(isProtobufResponse("application/vnd.kubernetes.protobuf"));
    try std.testing.expect(isProtobufResponse("application/vnd.kubernetes.protobuf;charset=utf-8"));
    try std.testing.expect(!isProtobufResponse("application/json"));
}

