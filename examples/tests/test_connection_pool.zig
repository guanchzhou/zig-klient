const std = @import("std");
const klient = @import("klient");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== Test: Connection Pool ===\n\n", .{});

    var pool = try klient.pool.ConnectionPool.init(allocator, .{
        .server = "http://127.0.0.1:8080",
        .max_connections = 5,
        .idle_timeout_ms = 30_000,
    });
    defer pool.deinit();

    std.debug.print("✓ ConnectionPool.init()\n", .{});

    const stats = pool.stats();
    std.debug.print("✓ ConnectionPool.stats()\n", .{});
    std.debug.print("  Max: {d}, Total: {d}, Idle: {d}, InUse: {d}\n", .{
        stats.max,
        stats.total,
        stats.idle,
        stats.in_use,
    });

    std.debug.print("\n✓ All Connection Pool tests passed!\n\n", .{});
}
