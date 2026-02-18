const std = @import("std");

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

/// Load TLS configuration from files
pub fn loadFromFiles(
    allocator: std.mem.Allocator,
    cert_path: ?[]const u8,
    key_path: ?[]const u8,
    ca_path: ?[]const u8,
) !TlsConfig {
    var config = TlsConfig{};
    errdefer {
        if (config.client_cert_data) |d| allocator.free(d);
        if (config.client_cert_path) |p| allocator.free(p);
        if (config.client_key_data) |d| allocator.free(d);
        if (config.client_key_path) |p| allocator.free(p);
        if (config.ca_cert_data) |d| allocator.free(d);
        if (config.ca_cert_path) |p| allocator.free(p);
    }

    // Load client certificate
    if (cert_path) |path| {
        const cert_file = try std.fs.cwd().openFile(path, .{});
        defer cert_file.close();

        config.client_cert_data = try cert_file.readToEndAlloc(allocator, 1024 * 1024);
        config.client_cert_path = try allocator.dupe(u8, path);
    }

    // Load client key
    if (key_path) |path| {
        const key_file = try std.fs.cwd().openFile(path, .{});
        defer key_file.close();

        config.client_key_data = try key_file.readToEndAlloc(allocator, 1024 * 1024);
        config.client_key_path = try allocator.dupe(u8, path);
    }

    // Load CA certificate
    if (ca_path) |path| {
        const ca_file = try std.fs.cwd().openFile(path, .{});
        defer ca_file.close();

        config.ca_cert_data = try ca_file.readToEndAlloc(allocator, 1024 * 1024);
        config.ca_cert_path = try allocator.dupe(u8, path);
    }

    return config;
}

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

/// Parse PEM certificate to extract useful information
pub const CertInfo = struct {
    subject: []const u8,
    issuer: []const u8,
    not_before: []const u8,
    not_after: []const u8,

    pub fn deinit(self: *CertInfo, allocator: std.mem.Allocator) void {
        allocator.free(self.subject);
        allocator.free(self.issuer);
        allocator.free(self.not_before);
        allocator.free(self.not_after);
    }
};

/// Validate that cert and key match (basic validation)
pub fn validateCertKeyPair(cert_data: []const u8, key_data: []const u8) !void {
    // Basic validation: check that both are PEM format
    if (!std.mem.startsWith(u8, cert_data, "-----BEGIN CERTIFICATE-----")) {
        return error.InvalidCertificate;
    }

    if (!std.mem.startsWith(u8, key_data, "-----BEGIN") or
        !std.mem.containsAtLeast(u8, key_data, 1, "PRIVATE KEY"))
    {
        return error.InvalidPrivateKey;
    }

    // Note: Full cryptographic validation would require OpenSSL/BoringSSL
    // For now, we do basic format checks
}

/// TLS bundle containing all necessary data for mTLS
pub const TlsBundle = struct {
    cert_data: []const u8,
    key_data: []const u8,
    ca_data: ?[]const u8 = null,

    pub fn deinit(self: *TlsBundle, allocator: std.mem.Allocator) void {
        allocator.free(self.cert_data);
        allocator.free(self.key_data);
        if (self.ca_data) |ca| allocator.free(ca);
    }
};

/// Create TLS bundle from config
pub fn createBundle(allocator: std.mem.Allocator, config: TlsConfig) !TlsBundle {
    var bundle: TlsBundle = undefined;

    // Get certificate data
    if (config.client_cert_data) |data| {
        bundle.cert_data = try allocator.dupe(u8, data);
    } else if (config.client_cert_path) |path| {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();
        bundle.cert_data = try file.readToEndAlloc(allocator, 1024 * 1024);
    } else {
        return error.NoCertificateData;
    }
    errdefer allocator.free(bundle.cert_data);

    // Get key data
    if (config.client_key_data) |data| {
        bundle.key_data = try allocator.dupe(u8, data);
    } else if (config.client_key_path) |path| {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();
        bundle.key_data = try file.readToEndAlloc(allocator, 1024 * 1024);
    } else {
        allocator.free(bundle.cert_data);
        return error.NoKeyData;
    }
    errdefer allocator.free(bundle.key_data);

    // Validate cert/key pair
    try validateCertKeyPair(bundle.cert_data, bundle.key_data);

    // Get CA data (optional)
    if (config.ca_cert_data) |data| {
        bundle.ca_data = try allocator.dupe(u8, data);
    } else if (config.ca_cert_path) |path| {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();
        bundle.ca_data = try file.readToEndAlloc(allocator, 1024 * 1024);
    }

    return bundle;
}
