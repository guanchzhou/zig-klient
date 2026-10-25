const std = @import("std");
const Io = std.Io;

/// Load custom CA certificate PEM data into an `std.http.Client`'s trust bundle.
///
/// The PEM is parsed in memory; nothing touches the filesystem. Returns
/// `error.NoCertificatesFound` when `ca_pem` holds no PEM certificate block, since
/// a CA that silently adds nothing would leave the client trusting nobody.
pub fn addCaCertData(
    client: *std.http.Client,
    allocator: std.mem.Allocator,
    io: Io,
    now: Io.Timestamp,
    ca_pem: []const u8,
) !void {
    _ = io;
    try addCertsFromPem(&client.ca_bundle, allocator, ca_pem, now.toSeconds());
}

/// In-memory counterpart of `Certificate.Bundle.addCertsFromFile`: decode every
/// `CERTIFICATE` PEM block in `pem` and add it to `bundle`. Expired certificates and
/// ones with unrecognized object IDs are skipped, as the std loader does.
pub fn addCertsFromPem(
    bundle: *std.crypto.Certificate.Bundle,
    allocator: std.mem.Allocator,
    pem: []const u8,
    now_sec: i64,
) !void {
    const begin_marker = "-----BEGIN CERTIFICATE-----";
    const end_marker = "-----END CERTIFICATE-----";
    const base64 = std.base64.standard.decoderWithIgnore(" \t\r\n");

    var found = false;
    var start_index: usize = 0;
    while (std.mem.findPos(u8, pem, start_index, begin_marker)) |begin_marker_start| {
        const cert_start = begin_marker_start + begin_marker.len;
        const cert_end = std.mem.findPos(u8, pem, cert_start, end_marker) orelse
            return error.MissingEndCertificateMarker;
        start_index = cert_end + end_marker.len;

        const encoded_cert = std.mem.trim(u8, pem[cert_start..cert_end], " \t\r\n");
        const decoded_upper_bound = base64.calcSizeUpperBound(encoded_cert.len);
        // Bundle indexes certificates with u32 offsets.
        const decoded_start = std.math.cast(u32, bundle.bytes.items.len) orelse
            return error.CertificateAuthorityBundleTooBig;
        _ = std.math.cast(u32, bundle.bytes.items.len + decoded_upper_bound) orelse
            return error.CertificateAuthorityBundleTooBig;

        try bundle.bytes.ensureUnusedCapacity(allocator, decoded_upper_bound);
        const decoded_len = try base64.decode(bundle.bytes.unusedCapacitySlice(), encoded_cert);
        bundle.bytes.items.len += decoded_len;
        try bundle.parseCert(allocator, decoded_start, now_sec);
        found = true;
    }
    if (!found) return error.NoCertificatesFound;
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
