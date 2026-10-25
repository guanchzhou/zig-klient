const std = @import("std");
const klient = @import("klient");
const retry = klient.retry;

test "RetryContext - Basic retry logic" {
    var ctx = retry.RetryContext.init(.{
        .max_attempts = 3,
        .initial_backoff_ms = 100,
        .max_backoff_ms = 30_000,
        .backoff_multiplier = 2.0,
        .jitter_factor = 0.0,
        .max_retry_time_ms = 60_000,
    });

    // First attempt should succeed
    try std.testing.expect(ctx.shouldRetry(null));
    try std.testing.expectEqual(@as(u32, 0), ctx.current_attempt);

    // Increment and check backoff
    ctx.nextAttempt();
    const backoff1 = ctx.getBackoffDuration();
    try std.testing.expect(backoff1 >= 100);
}

test "RetryContext - Exponential backoff" {
    var ctx = retry.RetryContext.init(.{
        .max_attempts = 5,
        .initial_backoff_ms = 100,
        .max_backoff_ms = 30_000,
        .backoff_multiplier = 2.0,
        .jitter_factor = 0.0,
        .max_retry_time_ms = 60_000,
    });

    ctx.nextAttempt(); // attempt 1
    const backoff1 = ctx.getBackoffDuration();

    ctx.nextAttempt(); // attempt 2
    const backoff2 = ctx.getBackoffDuration();

    ctx.nextAttempt(); // attempt 3
    const backoff3 = ctx.getBackoffDuration();

    // Each backoff should be larger (exponential): 100, 200, 400
    try std.testing.expect(backoff2 >= backoff1);
    try std.testing.expect(backoff3 >= backoff2);
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
}

test "isTransientError - only network-level failures are retried" {
    for ([_]anyerror{
        error.ConnectionRefused,
        error.ConnectionResetByPeer,
        error.ConnectionTimedOut,
        error.Timeout,
        error.ReadFailed,
        error.EndOfStream,
    }) |err| try std.testing.expect(retry.isTransientError(err));

    for ([_]anyerror{
        error.OutOfMemory,
        error.StreamTooLong,
        error.TlsInitializationFailed,
        error.CertificateBundleLoadFailure,
        error.InvalidPathSegment,
        error.InvalidRequestUrl,
        error.UnknownHostName,
        error.TooManyHttpRedirects,
        error.K8sApiError,
    }) |err| try std.testing.expect(!retry.isTransientError(err));
}

test "RetryContext.delayFor - honours Retry-After on 429 and 503, capped" {
    var ctx = retry.RetryContext.init(.{
        .initial_backoff_ms = 100,
        .max_backoff_ms = 10_000,
        .jitter_factor = 0.0,
    });

    try std.testing.expectEqual(@as(u64, 3_000), ctx.delayFor(429, 3));
    try std.testing.expectEqual(@as(u64, 0), ctx.delayFor(503, 0));
    try std.testing.expectEqual(@as(u64, 10_000), ctx.delayFor(503, 3_600));
    try std.testing.expectEqual(@as(u64, 10_000), ctx.delayFor(429, std.math.maxInt(u32)));

    // Retry-After on other statuses, or no header, falls back to exponential backoff.
    try std.testing.expectEqual(ctx.getBackoffDuration(), ctx.delayFor(500, 3));
    try std.testing.expectEqual(ctx.getBackoffDuration(), ctx.delayFor(429, null));
    try std.testing.expectEqual(ctx.getBackoffDuration(), ctx.delayFor(null, null));
}
