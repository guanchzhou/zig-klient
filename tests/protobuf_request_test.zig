const std = @import("std");
const klient = @import("klient");

test "K8sClient exposes raw Protobuf requests" {
    var client = try klient.K8sClient.init(std.testing.allocator, std.testing.io, .{
        .server = "https://test.example.com",
        .token = "test-token",
    });
    defer client.deinit();

    try std.testing.expect(@hasDecl(@TypeOf(client), "requestWithProtobuf"));
}

test "Kubernetes Protobuf content types are distinct" {
    const content_type = "application/vnd.kubernetes.protobuf";
    const content_type_with_charset = "application/vnd.kubernetes.protobuf;charset=utf-8";

    try std.testing.expect(!std.mem.eql(u8, content_type, content_type_with_charset));
    try std.testing.expect(std.mem.indexOf(u8, content_type, "protobuf") != null);
    try std.testing.expect(std.mem.indexOf(u8, content_type_with_charset, "protobuf") != null);
}
