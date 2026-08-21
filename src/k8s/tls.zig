const std = @import("std");
const Io = std.Io;

/// Load custom CA certificate PEM data into an `std.http.Client`'s trust bundle.
///
/// SECURITY: the Certificate.Bundle parser only reads from a file, so the PEM is
/// staged in a temp file using an UNPREDICTABLE random name + exclusive (O_EXCL)
/// creation, and deleted immediately after the bundle copies the certs in. This
/// prevents a local attacker on a shared /tmp from winning a symlink/TOCTOU race
/// to inject their own CA (which would enable MITM of the API session).
pub fn addCaCertData(
    client: *std.http.Client,
    allocator: std.mem.Allocator,
    io: Io,
    now: Io.Timestamp,
    ca_pem: []const u8,
) !void {
    var rand_bytes: [16]u8 = undefined;
    try io.randomSecure(&rand_bytes);
    const rand_hex = std.fmt.bytesToHex(rand_bytes, .lower);
    const path = try std.fmt.allocPrint(allocator, "/tmp/zig-klient-ca-{s}.pem", .{&rand_hex});
    defer allocator.free(path);

    {
        const file = try Io.Dir.createFileAbsolute(io, path, .{ .exclusive = true });
        defer file.close(io);
        var write_buf: [4096]u8 = undefined;
        var file_writer = file.writer(io, &write_buf);
        try file_writer.interface.writeAll(ca_pem);
        try file_writer.flush();
    }

    const load_result = client.ca_bundle.addCertsFromFilePathAbsolute(allocator, io, now, path);
    Io.Dir.deleteFileAbsolute(io, path) catch {};
    try load_result;
}

/// TLS configuration for custom CA certificates and mTLS authentication
pub const TlsConfig = struct {
    client_cert_data: ?[]const u8 = null,
    client_key_data: ?[]const u8 = null,
    ca_cert_data: ?[]const u8 = null,
    client_cert_path: ?[]const u8 = null,
    client_key_path: ?[]const u8 = null,
    ca_cert_path: ?[]const u8 = null,
    insecure_skip_verify: bool = false,
    server_name: ?[]const u8 = null,
};

/// Decode base64-encoded certificate data from kubeconfig
pub fn decodeBase64Cert(allocator: std.mem.Allocator, base64_data: []const u8) ![]u8 {
    const decoder = std.base64.standard.Decoder;
    const max_size = try decoder.calcSizeForSlice(base64_data);

    var decoded = try allocator.alloc(u8, max_size);
    errdefer allocator.free(decoded);

    try decoder.decode(decoded, base64_data);
    const actual_size = decoder.calcSizeForSlice(base64_data) catch max_size;
    return allocator.realloc(decoded, actual_size) catch decoded[0..actual_size];
}
