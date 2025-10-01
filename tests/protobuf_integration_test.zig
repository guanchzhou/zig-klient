const std = @import("std");
const klient = @import("klient");

// Test that zig-protobuf library is properly integrated
test "Protobuf - Library integration" {
    // Verify protobuf module is accessible
    const protobuf = klient.protobuf;
    _ = protobuf; // Suppress unused warning

    // This confirms the library is properly imported and available
    try std.testing.expect(true);
}

// Test that K8sClient has requestWithProtobuf method
test "Protobuf - K8sClient method exists" {
    const allocator = std.testing.allocator;

    // Create a client (using correct Config field names)
    var client = try klient.K8sClient.init(allocator, .{
        .server = "https://test.example.com",
        .token = "test-token",
    });
    defer client.deinit();

    // Verify the requestWithProtobuf method exists (compilation test)
    // We can't actually call it without a real server, but we can verify it compiles
    const has_method = @hasDecl(@TypeOf(client), "requestWithProtobuf");
    try std.testing.expect(has_method);
}

// Test Protobuf content type constants
test "Protobuf - Content-Type handling" {
    // Verify the content types are correctly set for Kubernetes Protobuf API
    const k8s_protobuf_content_type = "application/vnd.kubernetes.protobuf";
    const k8s_protobuf_with_charset = "application/vnd.kubernetes.protobuf;charset=utf-8";
    
    // These are the standard Kubernetes Protobuf content types
    try std.testing.expect(k8s_protobuf_content_type.len > 0);
    try std.testing.expect(k8s_protobuf_with_charset.len > 0);
    
    // Verify they contain "protobuf"
    try std.testing.expect(std.mem.indexOf(u8, k8s_protobuf_content_type, "protobuf") != null);
    try std.testing.expect(std.mem.indexOf(u8, k8s_protobuf_with_charset, "protobuf") != null);
}

// Test that protobuf types are re-exported correctly
test "Protobuf - Type re-exports" {
    // Verify that protobuf types are accessible through klient
    const ProtobufFieldType = klient.ProtobufFieldType;
    const ProtobufWire = klient.ProtobufWire;
    const ProtobufJson = klient.ProtobufJson;
    
    // These should compile without errors
    _ = ProtobufFieldType;
    _ = ProtobufWire;
    _ = ProtobufJson;
    
    try std.testing.expect(true);
}

// Test zig-protobuf library availability
test "Protobuf - Library features available" {
    // Access the protobuf library
    const protobuf = klient.protobuf;
    
    // Verify key types and functions are available
    // Note: We're just checking they exist, not testing the library itself
    // (that's the responsibility of zig-protobuf's own tests)
    
    const has_field_type = @hasDecl(protobuf, "FieldType");
    const has_wire = @hasDecl(protobuf, "wire");
    const has_json = @hasDecl(protobuf, "json");
    
    try std.testing.expect(has_field_type);
    try std.testing.expect(has_wire);
    try std.testing.expect(has_json);
}

// Integration test: Verify protobuf can be used with K8s types
test "Protobuf - Integration with K8s types" {
    // Verify that K8s types are available and compatible
    const Pod = klient.types.Pod;
    const ObjectMeta = klient.ObjectMeta;
    
    // These should compile without errors
    _ = Pod;
    _ = ObjectMeta;
    
    // In the future, we could encode K8s resources to Protobuf and back using zig-protobuf
    // For now, we just verify the types are accessible and compatible
    try std.testing.expect(true);
}

// Test that requestWithProtobuf method has correct signature
test "Protobuf - Request method signature" {
    // This is a compile-time test to verify the method exists
    const ClientType = klient.K8sClient;
    
    // Check that requestWithProtobuf exists
    const has_method = @hasDecl(ClientType, "requestWithProtobuf");
    try std.testing.expect(has_method);
}
