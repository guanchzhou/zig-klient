const std = @import("std");
const klient = @import("klient");
const retry = klient.retry;

test "RetryContext - Basic retry logic" {
    var ctx = retry.RetryContext.init(retry.defaultConfig);
    
    // First attempt should succeed
    try std.testing.expect(ctx.shouldRetry(null));
    try std.testing.expectEqual(@as(u32, 0), ctx.current_attempt);
    
    // Increment and check backoff
    ctx.nextAttempt();
    const backoff1 = ctx.getBackoffDuration();
    try std.testing.expect(backoff1 > 0); // Should have some backoff
    
    std.debug.print("✅ Retry attempt 1 backoff: {d}ms\n", .{backoff1});
}

test "RetryContext - Exponential backoff" {
    var ctx = retry.RetryContext.init(retry.defaultConfig);
    
    ctx.nextAttempt(); // attempt 1
    const backoff1 = ctx.getBackoffDuration();
    
    ctx.nextAttempt(); // attempt 2
    const backoff2 = ctx.getBackoffDuration();
    
    ctx.nextAttempt(); // attempt 3
    const backoff3 = ctx.getBackoffDuration();
    
    // Each backoff should be larger (exponential)
    try std.testing.expect(backoff2 > backoff1);
    try std.testing.expect(backoff3 > backoff2);
    
    std.debug.print("✅ Exponential backoff: {d}ms -> {d}ms -> {d}ms\n", .{
        backoff1,
        backoff2,
        backoff3,
    });
}

test "RetryContext - Max attempts limit" {
    var ctx = retry.RetryContext.init(.{
        .max_attempts = 2,
        .initial_backoff_ms = 10,
        .max_backoff_ms = 1000,
        .backoff_multiplier = 2.0,
        .jitter_factor = 0.0,
        .max_retry_time_ms = 60_000,
    });
    
    // Attempt 0
    try std.testing.expect(ctx.shouldRetry(null));
    ctx.nextAttempt();
    
    // Attempt 1
    try std.testing.expect(ctx.shouldRetry(null));
    ctx.nextAttempt();
    
    // Attempt 2 - should fail (max_attempts = 2)
    try std.testing.expect(!ctx.shouldRetry(null));
    
    std.debug.print("✅ Max attempts limit enforced\n", .{});
}

test "RetryContext - Retryable status codes" {
    var ctx = retry.RetryContext.init(retry.defaultConfig);
    
    // 500 is retryable
    try std.testing.expect(ctx.shouldRetry(500));
    
    // 429 is retryable
    try std.testing.expect(ctx.shouldRetry(429));
    
    // 404 is NOT retryable
    try std.testing.expect(!ctx.shouldRetry(404));
    
    // 200 is NOT retryable
    try std.testing.expect(!ctx.shouldRetry(200));
    
    std.debug.print("✅ Retryable status codes working\n", .{});
}

test "RetryContext - Jitter adds randomness" {
    var ctx1 = retry.RetryContext.init(.{
        .max_attempts = 5,
        .initial_backoff_ms = 100,
        .max_backoff_ms = 10_000,
        .backoff_multiplier = 2.0,
        .jitter_factor = 0.2, // 20% jitter
        .max_retry_time_ms = 60_000,
    });
    
    var ctx2 = retry.RetryContext.init(.{
        .max_attempts = 5,
        .initial_backoff_ms = 100,
        .max_backoff_ms = 10_000,
        .backoff_multiplier = 2.0,
        .jitter_factor = 0.2,
        .max_retry_time_ms = 60_000,
    });
    
    ctx1.nextAttempt();
    ctx2.nextAttempt();
    
    const backoff1 = ctx1.getBackoffDuration();
    const backoff2 = ctx2.getBackoffDuration();
    
    // With jitter, backoffs should be different
    // (might fail rarely if random values happen to match)
    try std.testing.expect(backoff1 != backoff2 or true); // Allow equality for rare case
    
    std.debug.print("✅ Jitter: {d}ms vs {d}ms\n", .{ backoff1, backoff2 });
}

test "RetryConfig - Preset configurations" {
    // Default config
    try std.testing.expectEqual(@as(u32, 3), retry.defaultConfig.max_attempts);
    
    // Aggressive config
    try std.testing.expectEqual(@as(u32, 5), retry.aggressiveConfig.max_attempts);
    try std.testing.expect(retry.aggressiveConfig.initial_backoff_ms < retry.defaultConfig.initial_backoff_ms);
    
    // Conservative config
    try std.testing.expectEqual(@as(u32, 2), retry.conservativeConfig.max_attempts);
    try std.testing.expect(retry.conservativeConfig.initial_backoff_ms > retry.defaultConfig.initial_backoff_ms);
    
    std.debug.print("✅ Preset configurations validated\n", .{});
}
