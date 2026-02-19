const std = @import("std");

/// Connection pool for HTTP connections to Kubernetes API
pub const ConnectionPool = struct {
    allocator: std.mem.Allocator,
    server: []const u8,
    max_connections: usize,
    idle_timeout_ms: u64,
    connections: std.ArrayList(PooledConnection),
    mutex: std.Thread.Mutex,
    
    const Self = @This();
    
    pub const Config = struct {
        server: []const u8,
        max_connections: usize = 10,
        idle_timeout_ms: u64 = 30_000, // 30 seconds
    };
    
    pub fn init(allocator: std.mem.Allocator, config: Config) !Self {
        return Self{
            .allocator = allocator,
            .server = try allocator.dupe(u8, config.server),
            .max_connections = config.max_connections,
            .idle_timeout_ms = config.idle_timeout_ms,
            .connections = try std.ArrayList(PooledConnection).initCapacity(allocator, 0),
            .mutex = .{},
        };
    }
    
    pub fn deinit(self: *Self) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        
        for (self.connections.items) |*conn| {
            conn.deinit();
        }
        self.connections.deinit(self.allocator);
        self.allocator.free(self.server);
    }
    
    /// Get a connection from the pool (or create new one)
    pub fn acquire(self: *Self) !*std.http.Client {
        self.mutex.lock();
        defer self.mutex.unlock();
        
        const now = std.time.milliTimestamp();
        
        // Try to find an idle connection
        for (self.connections.items, 0..) |*conn, i| {
            if (conn.state == .idle) {
                // Check if connection is still fresh (saturate to 0 on clock skew)
                const idle_time: u64 = @intCast(@max(0, now - conn.last_used));
                if (idle_time > self.idle_timeout_ms) {
                    // Connection expired, remove it
                    _ = self.connections.swapRemove(i);
                    conn.deinit();
                    continue;
                }
                
                // Reuse connection
                conn.state = .in_use;
                conn.last_used = now;
                return &conn.client;
            }
        }
        
        // No idle connections, create new one if under limit
        if (self.connections.items.len < self.max_connections) {
            var new_conn = try PooledConnection.init(self.allocator, self.server);
            new_conn.state = .in_use;
            new_conn.last_used = now;
            
            try self.connections.append(self.allocator, new_conn);
            return &self.connections.items[self.connections.items.len - 1].client;
        }
        
        // Pool is full, wait or error
        return error.ConnectionPoolExhausted;
    }
    
    /// Release a connection back to the pool
    pub fn release(self: *Self, client: *std.http.Client) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        
        for (self.connections.items) |*conn| {
            if (&conn.client == client) {
                conn.state = .idle;
                conn.last_used = std.time.milliTimestamp();
                return;
            }
        }
    }
    
    /// Remove expired connections
    pub fn cleanup(self: *Self) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        
        const now = std.time.milliTimestamp();
        var i: usize = 0;
        
        while (i < self.connections.items.len) {
            const conn = &self.connections.items[i];
            if (conn.state == .idle) {
                const idle_time: u64 = @intCast(@max(0, now - conn.last_used));
                if (idle_time > self.idle_timeout_ms) {
                    var removed = self.connections.swapRemove(i);
                    removed.deinit();
                    continue; // Don't increment i
                }
            }
            i += 1;
        }
    }
    
    /// Get pool statistics
    pub fn stats(self: *Self) PoolStats {
        self.mutex.lock();
        defer self.mutex.unlock();
        
        var idle_count: usize = 0;
        var in_use_count: usize = 0;
        
        for (self.connections.items) |conn| {
            switch (conn.state) {
                .idle => idle_count += 1,
                .in_use => in_use_count += 1,
            }
        }
        
        return PoolStats{
            .total = self.connections.items.len,
            .idle = idle_count,
            .in_use = in_use_count,
            .max = self.max_connections,
        };
    }
};

/// A pooled HTTP connection
const PooledConnection = struct {
    client: std.http.Client,
    state: State,
    last_used: i64,
    server: []const u8,
    
    const State = enum {
        idle,
        in_use,
    };
    
    fn init(allocator: std.mem.Allocator, server: []const u8) !PooledConnection {
        return PooledConnection{
            .client = std.http.Client{ .allocator = allocator },
            .state = .idle,
            .last_used = std.time.milliTimestamp(),
            .server = try allocator.dupe(u8, server),
        };
    }
    
    fn deinit(self: *PooledConnection) void {
        // WORKAROUND (Zig 0.15.x): Skip http_client.deinit() to avoid
        // integer overflow / invalid free panics in std.http.Client.
        // Same workaround as K8sClient.destroyHttpClient().
        // self.client.deinit();
        self.client.allocator.free(self.server);
    }
};

/// Pool statistics
pub const PoolStats = struct {
    total: usize,
    idle: usize,
    in_use: usize,
    max: usize,
    
    pub fn utilization(self: PoolStats) f64 {
        if (self.max == 0) return 0.0;
        const used_f: f64 = @floatFromInt(self.in_use);
        const max_f: f64 = @floatFromInt(self.max);
        return (used_f / max_f) * 100.0;
    }
};

/// Connection pool manager with automatic cleanup
pub const PoolManager = struct {
    pool: ConnectionPool,
    cleanup_thread: ?std.Thread = null,
    running: std.atomic.Value(bool),
    
    const Self = @This();
    
    pub fn init(allocator: std.mem.Allocator, config: ConnectionPool.Config) !Self {
        return Self{
            .pool = try ConnectionPool.init(allocator, config),
            .running = std.atomic.Value(bool).init(true),
        };
    }
    
    pub fn deinit(self: *Self) void {
        self.running.store(false, .seq_cst);
        if (self.cleanup_thread) |thread| {
            thread.join();
        }
        self.pool.deinit();
    }
    
    /// Start automatic cleanup thread
    pub fn startCleanup(self: *Self, interval_ms: u64) !void {
        self.cleanup_thread = try std.Thread.spawn(.{}, cleanupLoop, .{ self, interval_ms });
    }
    
    fn cleanupLoop(self: *Self, interval_ms: u64) void {
        while (self.running.load(.seq_cst)) {
            std.time.sleep(interval_ms * std.time.ns_per_ms);
            self.pool.cleanup();
        }
    }
};
