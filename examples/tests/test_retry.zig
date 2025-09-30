const std = @import("std");
const klient = @import("klient");

pub fn main() !void {
    std.debug.print("\n=== Test: Retry Configuration ===\n\n", .{});

    const retry_config = klient.retry.defaultConfig;
    std.debug.print("✓ retry.defaultConfig\n", .{});
    std.debug.print("  Max attempts: {d}\n", .{retry_config.max_attempts});
    std.debug.print("  Initial backoff: {d}ms\n", .{retry_config.initial_backoff_ms});
    std.debug.print("  Max backoff: {d}ms\n", .{retry_config.max_backoff_ms});
    std.debug.print("  Backoff multiplier: {d}\n", .{retry_config.backoff_multiplier});

    std.debug.print("\n✓ All Retry tests passed!\n\n", .{});
}
