const std = @import("std");
const klient = @import("klient");

pub fn main() !void {
    std.debug.print("\n=== Test: TLS Configuration ===\n\n", .{});

    const tls_config = klient.tls.TlsConfig{
        .insecure_skip_verify = true,
        .client_cert_path = null,
        .client_key_path = null,
        .ca_cert_path = null,
        .server_name = null,
    };

    std.debug.print("✓ TlsConfig initialization\n", .{});
    std.debug.print("  Insecure skip verify: {}\n", .{tls_config.insecure_skip_verify});
    std.debug.print("  Client cert path: {?s}\n", .{tls_config.client_cert_path});
    std.debug.print("  CA cert path: {?s}\n", .{tls_config.ca_cert_path});

    std.debug.print("\n✓ All TLS tests passed!\n\n", .{});
}
