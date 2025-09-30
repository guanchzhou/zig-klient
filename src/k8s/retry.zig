const std = @import("std");

/// Retry configuration for HTTP requests
pub const RetryConfig = struct {
    /// Maximum number of retry attempts (0 = no retries)
    max_attempts: u32 = 3,
    
    /// Initial backoff duration in milliseconds
    initial_backoff_ms: u64 = 100,
    
    /// Maximum backoff duration in milliseconds
    max_backoff_ms: u64 = 30_000, // 30 seconds
    
    /// Backoff multiplier for exponential backoff
    backoff_multiplier: f64 = 2.0,
    
    /// Add random jitter to backoff (0.0 - 1.0)
    jitter_factor: f64 = 0.1,
    
    /// Which HTTP status codes should trigger retries
    retryable_status_codes: []const u16 = &[_]u16{
        408, // Request Timeout
        429, // Too Many Requests
        500, // Internal Server Error
        502, // Bad Gateway
        503, // Service Unavailable
        504, // Gateway Timeout
    },
    
    /// Maximum total retry time in milliseconds
    max_retry_time_ms: u64 = 60_000, // 1 minute
};

/// Retry context tracking current attempt
pub const RetryContext = struct {
    config: RetryConfig,
    current_attempt: u32 = 0,
    total_time_ms: u64 = 0,
    random: std.Random,
    
    pub fn init(config: RetryConfig) RetryContext {
        var prng = std.Random.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
        return .{
            .config = config,
            .random = prng.random(),
        };
    }
    
    /// Check if we should retry based on attempt count and total time
    pub fn shouldRetry(self: *RetryContext, status_code: ?u16) bool {
        // Don't retry if we've exhausted attempts
        if (self.current_attempt >= self.config.max_attempts) {
            return false;
        }
        
        // Don't retry if we've exceeded max retry time
        if (self.total_time_ms >= self.config.max_retry_time_ms) {
            return false;
        }
        
        // If status code provided, check if it's retryable
        if (status_code) |code| {
            var is_retryable = false;
            for (self.config.retryable_status_codes) |retryable_code| {
                if (code == retryable_code) {
                    is_retryable = true;
                    break;
                }
            }
            if (!is_retryable) {
                return false;
            }
        }
        
        return true;
    }
    
    /// Calculate backoff duration for current attempt with exponential backoff and jitter
    pub fn getBackoffDuration(self: *RetryContext) u64 {
        if (self.current_attempt == 0) {
            return 0; // No backoff for first attempt
        }
        
        // Calculate exponential backoff: initial * (multiplier ^ (attempt - 1))
        const attempt_f: f64 = @floatFromInt(self.current_attempt - 1);
        const backoff_f: f64 = @floatFromInt(self.config.initial_backoff_ms);
        const multiplier_pow = std.math.pow(f64, self.config.backoff_multiplier, attempt_f);
        var backoff_duration = backoff_f * multiplier_pow;
        
        // Cap at max backoff
        const max_backoff_f: f64 = @floatFromInt(self.config.max_backoff_ms);
        if (backoff_duration > max_backoff_f) {
            backoff_duration = max_backoff_f;
        }
        
        // Add random jitter: backoff * (1 + random(-jitter, +jitter))
        const jitter_range = backoff_duration * self.config.jitter_factor;
        const jitter = (self.random.float(f64) * 2.0 - 1.0) * jitter_range;
        backoff_duration += jitter;
        
        // Ensure non-negative
        if (backoff_duration < 0) {
            backoff_duration = 0;
        }
        
        return @intFromFloat(backoff_duration);
    }
    
    /// Sleep for the backoff duration
    pub fn backoff(self: *RetryContext) !void {
        const duration_ms = self.getBackoffDuration();
        if (duration_ms == 0) return;
        
        // Sleep for the calculated duration
        std.time.sleep(duration_ms * std.time.ns_per_ms);
        self.total_time_ms += duration_ms;
    }
    
    /// Increment attempt counter
    pub fn nextAttempt(self: *RetryContext) void {
        self.current_attempt += 1;
    }
    
    /// Reset retry context for a new operation
    pub fn reset(self: *RetryContext) void {
        self.current_attempt = 0;
        self.total_time_ms = 0;
    }
};

/// Retry a function with exponential backoff
pub fn retryWithBackoff(
    comptime T: type,
    config: RetryConfig,
    operation: anytype,
) !T {
    var ctx = RetryContext.init(config);
    
    while (true) {
        // Try the operation
        const result = operation() catch |err| {
            // Check if we should retry
            if (!ctx.shouldRetry(null)) {
                return err; // No more retries, return error
            }
            
            // Backoff before retry
            ctx.nextAttempt();
            try ctx.backoff();
            continue;
        };
        
        // Success!
        return result;
    }
}

/// Default retry configuration for production use
pub const defaultConfig = RetryConfig{
    .max_attempts = 3,
    .initial_backoff_ms = 100,
    .max_backoff_ms = 30_000,
    .backoff_multiplier = 2.0,
    .jitter_factor = 0.1,
    .max_retry_time_ms = 60_000,
};

/// Aggressive retry configuration for critical operations
pub const aggressiveConfig = RetryConfig{
    .max_attempts = 5,
    .initial_backoff_ms = 50,
    .max_backoff_ms = 10_000,
    .backoff_multiplier = 1.5,
    .jitter_factor = 0.2,
    .max_retry_time_ms = 120_000,
};

/// Conservative retry configuration for non-critical operations
pub const conservativeConfig = RetryConfig{
    .max_attempts = 2,
    .initial_backoff_ms = 200,
    .max_backoff_ms = 5_000,
    .backoff_multiplier = 2.0,
    .jitter_factor = 0.05,
    .max_retry_time_ms = 30_000,
};
