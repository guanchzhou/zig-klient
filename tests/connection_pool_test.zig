const std = @import("std");
const klient = @import("klient");

test "ConnectionPool: init and deinit with testing allocator" {
    const allocator = std.testing.allocator;

    var pool = try klient.ConnectionPool.init(allocator, .{
        .server = "https://localhost:6443",
        .max_connections = 5,
        .idle_timeout_ms = 10_000,
    });
    defer pool.deinit();

    const s = pool.stats();
    try std.testing.expectEqual(@as(usize, 0), s.total);
    try std.testing.expectEqual(@as(usize, 0), s.idle);
    try std.testing.expectEqual(@as(usize, 0), s.in_use);
    try std.testing.expectEqual(@as(usize, 5), s.max);
    std.debug.print("✅ ConnectionPool init/deinit test passed\n", .{});
}

test "ConnectionPool: stats utilization calculation" {
    const s = klient.PoolStats{
        .total = 8,
        .idle = 3,
        .in_use = 5,
        .max = 10,
    };
    const util = s.utilization();
    try std.testing.expectApproxEqAbs(@as(f64, 50.0), util, 0.001);
    std.debug.print("✅ PoolStats utilization test passed\n", .{});
}

test "ConnectionPool: utilization is 0 when max is 0" {
    const s = klient.PoolStats{
        .total = 0,
        .idle = 0,
        .in_use = 0,
        .max = 0,
    };
    try std.testing.expectEqual(@as(f64, 0.0), s.utilization());
    std.debug.print("✅ PoolStats zero-max utilization test passed\n", .{});
}

test "ConnectionPool: acquire returns connection" {
    const allocator = std.testing.allocator;

    var pool = try klient.ConnectionPool.init(allocator, .{
        .server = "https://localhost:6443",
        .max_connections = 2,
        .idle_timeout_ms = 30_000,
    });
    defer pool.deinit();

    // Acquire a connection
    const client = try pool.acquire();

    const s1 = pool.stats();
    try std.testing.expectEqual(@as(usize, 1), s1.total);
    try std.testing.expectEqual(@as(usize, 1), s1.in_use);
    try std.testing.expectEqual(@as(usize, 0), s1.idle);

    // Release it back
    pool.release(client);

    const s2 = pool.stats();
    try std.testing.expectEqual(@as(usize, 1), s2.total);
    try std.testing.expectEqual(@as(usize, 0), s2.in_use);
    try std.testing.expectEqual(@as(usize, 1), s2.idle);

    std.debug.print("✅ ConnectionPool acquire/release test passed\n", .{});
}

test "ConnectionPool: respects max connections" {
    const allocator = std.testing.allocator;

    var pool = try klient.ConnectionPool.init(allocator, .{
        .server = "https://localhost:6443",
        .max_connections = 1,
        .idle_timeout_ms = 30_000,
    });
    defer pool.deinit();

    // Acquire 1 connection (max)
    _ = try pool.acquire();

    // Second should fail (pool is full)
    const result = pool.acquire();
    try std.testing.expectError(error.ConnectionPoolExhausted, result);

    const s = pool.stats();
    try std.testing.expectEqual(@as(usize, 1), s.total);
    try std.testing.expectEqual(@as(usize, 1), s.in_use);

    std.debug.print("✅ ConnectionPool max connections test passed\n", .{});
}

test "ConnectionPool: acquire creates connection and stats are accurate" {
    const allocator = std.testing.allocator;

    var pool = try klient.ConnectionPool.init(allocator, .{
        .server = "https://localhost:6443",
        .max_connections = 5,
        .idle_timeout_ms = 30_000,
    });
    defer pool.deinit();

    // Before any acquire
    const s0 = pool.stats();
    try std.testing.expectEqual(@as(usize, 0), s0.total);

    // After acquire
    _ = try pool.acquire();
    const s1 = pool.stats();
    try std.testing.expectEqual(@as(usize, 1), s1.total);
    try std.testing.expectEqual(@as(usize, 1), s1.in_use);

    std.debug.print("✅ ConnectionPool acquire and stats test passed\n", .{});
}

test "PoolManager: init and deinit" {
    const allocator = std.testing.allocator;

    var manager = try klient.PoolManager.init(allocator, .{
        .server = "https://localhost:6443",
        .max_connections = 10,
    });
    defer manager.deinit();

    const s = manager.pool.stats();
    try std.testing.expectEqual(@as(usize, 0), s.total);
    std.debug.print("✅ PoolManager init/deinit test passed\n", .{});
}
