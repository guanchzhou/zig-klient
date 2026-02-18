const std = @import("std");
const retry_mod = @import("retry.zig");
const tls_mod = @import("tls.zig");

/// Kubernetes API client - standalone library
/// Provides access to Kubernetes cluster resources via REST API
///
/// Note: This library is logging-agnostic. Wrap API calls with your own
/// logging if needed.
pub const K8sClient = struct {
    allocator: std.mem.Allocator,
    api_server: []const u8,
    token: ?[]const u8,
    namespace: []const u8,
    http_client: std.http.Client,
    retry_config: retry_mod.RetryConfig,
    tls_config: ?tls_mod.TlsConfig,
    max_response_size: usize,
    /// Last K8s API error response (populated on K8sApiError)
    last_api_error: ?ApiError = null,
    // Temp CA file path - must be deleted in deinit()
    temp_ca_path: ?[]const u8 = null,

    /// Structured Kubernetes API error (owns its string memory)
    pub const ApiError = struct {
        status: ?[]const u8 = null,
        message: ?[]const u8 = null,
        reason: ?[]const u8 = null,
        code: ?i64 = null,

        /// Free owned string memory
        pub fn deinit(self: *ApiError, allocator: std.mem.Allocator) void {
            if (self.status) |s| allocator.free(s);
            if (self.message) |s| allocator.free(s);
            if (self.reason) |s| allocator.free(s);
            self.* = .{};
        }
    };

    pub const Config = struct {
        server: []const u8,
        token: ?[]const u8 = null,
        namespace: ?[]const u8 = null,
        retry_config: ?retry_mod.RetryConfig = null,
        tls_config: ?tls_mod.TlsConfig = null,
        /// Maximum response body size in bytes (default 16MB)
        max_response_size: usize = 16 * 1024 * 1024,
    };

    pub fn init(allocator: std.mem.Allocator, config: Config) !K8sClient {
        var http_client = std.http.Client{
            .allocator = allocator,
            .read_buffer_size = 16384,
            .write_buffer_size = 16384,
        };

        // Configure custom CA bundle if TLS config provided
        var temp_ca_path: ?[]const u8 = null;

        if (config.tls_config) |tls| {
            // Rescan system certificates — best-effort since some environments
            // don't have system CA bundles (e.g., scratch containers)
            http_client.ca_bundle.rescan(allocator) catch {};
            http_client.next_https_rescan_certs = false;

            if (tls.ca_cert_data) |ca_pem| {
                // Write CA cert PEM data to a temp file for the Certificate.Bundle parser
                const path = try std.fmt.allocPrint(allocator, "/tmp/zig-klient-ca-{d}.pem", .{@as(u64, @intCast(std.time.timestamp()))});
                temp_ca_path = path;

                const file = std.fs.createFileAbsolute(path, .{}) catch |err| {
                    // If we can't create the temp file, TLS with custom CA will fail.
                    // Propagate the error instead of silently degrading.
                    allocator.free(path);
                    return err;
                };
                defer file.close();
                try file.writeAll(ca_pem);

                http_client.ca_bundle.addCertsFromFilePathAbsolute(allocator, path) catch |err| {
                    // CA cert data provided but couldn't be loaded — this is a
                    // configuration error that should not be silently ignored.
                    allocator.free(path);
                    temp_ca_path = null;
                    return err;
                };
            } else if (tls.ca_cert_path) |ca_path| {
                http_client.ca_bundle.addCertsFromFilePathAbsolute(allocator, ca_path) catch |err| {
                    // User explicitly provided a CA cert path that failed to load.
                    return err;
                };
            }
        }

        return K8sClient{
            .allocator = allocator,
            .api_server = try allocator.dupe(u8, config.server),
            .token = if (config.token) |t| try allocator.dupe(u8, t) else null,
            .namespace = try allocator.dupe(u8, config.namespace orelse "default"),
            .http_client = http_client,
            .retry_config = config.retry_config orelse retry_mod.defaultConfig,
            .tls_config = config.tls_config,
            .max_response_size = config.max_response_size,
            .temp_ca_path = temp_ca_path,
        };
    }

    pub fn deinit(self: *K8sClient) void {
        self.clearLastApiError();
        self.allocator.free(self.api_server);
        if (self.token) |t| self.allocator.free(t);
        self.allocator.free(self.namespace);
        self.destroyHttpClient();

        // Clean up temporary CA file if it exists
        if (self.temp_ca_path) |path| {
            std.fs.deleteFileAbsolute(path) catch {};
            self.allocator.free(path);
        }
    }

    /// Free previous API error strings before storing a new one
    fn clearLastApiError(self: *K8sClient) void {
        if (self.last_api_error) |*err| {
            err.deinit(self.allocator);
            self.last_api_error = null;
        }
    }

    fn destroyHttpClient(self: *K8sClient) void {
        // WORKAROUND: Skip http_client.deinit() to avoid BOTH:
        // 1. Integer overflow bug in std.http.Client when calculating buffer sizes
        // 2. Invalid free panic when manually clearing connection pool
        // This causes a small (~200KB) one-time memory leak, but prevents crashes on exit.
        // TODO: Fix properly once Zig stdlib bugs are resolved
        _ = self;
    }

    /// Get cluster version information.
    /// For resource metrics (CPU/memory), use the MetricsClient instead.
    pub fn getClusterInfo(self: *K8sClient) !ClusterInfo {
        const version_response = try self.request(.GET, "/version", null);
        defer self.allocator.free(version_response);

        const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, version_response, .{
            .ignore_unknown_fields = true,
        });
        defer parsed.deinit();

        const git_version = if (parsed.value.object.get("gitVersion")) |v|
            (if (v == .string) v.string else "unknown")
        else
            "unknown";

        const node_count = self.getNodeCount();

        return ClusterInfo{
            .k8s_version = try self.allocator.dupe(u8, git_version),
            .node_count = node_count,
        };
    }

    /// Count cluster nodes (best-effort, returns 0 on failure).
    fn getNodeCount(self: *K8sClient) u32 {
        const nodes_response = self.request(.GET, "/api/v1/nodes", null) catch return 0;
        defer self.allocator.free(nodes_response);

        const parsed = std.json.parseFromSlice(std.json.Value, self.allocator, nodes_response, .{
            .ignore_unknown_fields = true,
        }) catch return 0;
        defer parsed.deinit();

        const items = parsed.value.object.get("items") orelse return 0;
        if (items != .array) return 0;
        return @intCast(items.array.items.len);
    }

    /// HTTP method alias for convenience
    pub const Method = std.http.Method;

    /// Make HTTP request to Kubernetes API with automatic retries
    pub fn request(self: *K8sClient, method: std.http.Method, path: []const u8, body: ?[]const u8) ![]u8 {
        return self.requestWithContentType(method, path, body, "application/json");
    }

    /// Make HTTP request with retries (use this for production code)
    /// Retries on transport errors and retryable HTTP status codes (429, 500, 502, 503, 504)
    pub fn requestWithRetry(self: *K8sClient, method: std.http.Method, path: []const u8, body: ?[]const u8) ![]u8 {
        var retry_ctx = retry_mod.RetryContext.init(self.retry_config);

        while (true) {
            const result = self.request(method, path, body) catch |err| {
                // For K8s API errors, check if the status code is retryable
                const status_code: ?u16 = if (err == error.K8sApiError)
                    if (self.last_api_error) |api_err|
                        if (api_err.code) |code| @intCast(code) else null
                    else
                        null
                else
                    null;

                if (!retry_ctx.shouldRetry(status_code)) {
                    return err;
                }

                retry_ctx.nextAttempt();
                try retry_ctx.backoff();
                continue;
            };

            return result;
        }
    }

    /// Make HTTP request with custom Content-Type
    pub fn requestWithContentType(
        self: *K8sClient,
        method: std.http.Method,
        path: []const u8,
        body: ?[]const u8,
        content_type: []const u8,
    ) ![]u8 {
        // Stack-allocated URL buffer (K8s API URLs are bounded in length)
        var url_buf: [4096]u8 = undefined;
        const url = try std.fmt.bufPrint(&url_buf, "{s}{s}", .{ self.api_server, path });

        const uri = try std.Uri.parse(url);

        // Build headers with authorization
        var header_buffer: [4096]u8 = undefined;
        var headers = std.http.Client.Request.Headers{};

        if (self.token) |token| {
            const auth_value = try std.fmt.bufPrint(&header_buffer, "Bearer {s}", .{token});
            headers.authorization = .{ .override = auth_value };
        }

        if (body != null) {
            headers.content_type = .{ .override = content_type };
        }

        // Make request to Kubernetes API
        var req = try self.http_client.request(method, uri, .{
            .redirect_behavior = @enumFromInt(3),
            .headers = headers,
        });
        defer req.deinit();

        // Send request with or without body
        if (body) |request_body| {
            req.transfer_encoding = .{ .content_length = request_body.len };
            var send_body = try req.sendBody(&.{});
            try send_body.writer.writeAll(request_body);
            try send_body.end();
        } else {
            try req.sendBodiless();
        }

        // Receive response headers
        var redirect_buffer: [2048]u8 = undefined;
        var response = try req.receiveHead(&redirect_buffer);

        // Check response status
        const is_success = @intFromEnum(response.head.status) >= 200 and @intFromEnum(response.head.status) < 300;
        if (!is_success) {
            // Read and parse K8s API error response (with decompression)
            var error_buffer = try std.ArrayList(u8).initCapacity(self.allocator, 4096);
            defer error_buffer.deinit(self.allocator);

            var err_transfer_buffer: [16384]u8 = undefined;
            var err_decompress: std.http.Decompress = undefined;
            var err_decompress_buffer: [32768]u8 = undefined;
            const err_reader = response.readerDecompressing(&err_transfer_buffer, &err_decompress, &err_decompress_buffer);
            err_reader.appendRemaining(self.allocator, &error_buffer, .limited(65536)) catch {};

            // Try to parse structured K8s API error
            self.clearLastApiError();
            if (error_buffer.items.len > 0) {
                const parsed_err = std.json.parseFromSlice(std.json.Value, self.allocator, error_buffer.items, .{
                    .ignore_unknown_fields = true,
                }) catch null;
                if (parsed_err) |pe| {
                    defer pe.deinit();
                    const obj = pe.value.object;
                    // Dupe strings so they survive pe.deinit()
                    self.last_api_error = .{
                        .status = if (obj.get("status")) |v| blk: {
                            if (v == .string) break :blk self.allocator.dupe(u8, v.string) catch null else break :blk null;
                        } else null,
                        .message = if (obj.get("message")) |v| blk: {
                            if (v == .string) break :blk self.allocator.dupe(u8, v.string) catch null else break :blk null;
                        } else null,
                        .reason = if (obj.get("reason")) |v| blk: {
                            if (v == .string) break :blk self.allocator.dupe(u8, v.string) catch null else break :blk null;
                        } else null,
                        .code = if (obj.get("code")) |v| blk: {
                            if (v == .integer) break :blk v.integer else break :blk null;
                        } else null,
                    };
                }
            }

            return error.K8sApiError;
        }

        // Read response body with automatic gzip/deflate decompression
        var body_buffer = try std.ArrayList(u8).initCapacity(self.allocator, 8192);
        errdefer body_buffer.deinit(self.allocator);

        var transfer_buffer: [16384]u8 = undefined;
        var decompress: std.http.Decompress = undefined;
        var decompress_buffer: [32768]u8 = undefined;
        const reader = response.readerDecompressing(&transfer_buffer, &decompress, &decompress_buffer);

        reader.appendRemaining(self.allocator, &body_buffer, .limited(self.max_response_size)) catch |err| switch (err) {
            error.ReadFailed => return response.bodyErr().?,
            else => |e| return e,
        };

        return try body_buffer.toOwnedSlice(self.allocator);
    }

    /// Make HTTP request with Protobuf serialization
    /// Returns raw Protobuf-encoded response data
    pub fn requestWithProtobuf(
        self: *K8sClient,
        method: std.http.Method,
        path: []const u8,
        body: ?[]const u8,
    ) ![]u8 {
        // Stack-allocated URL buffer
        var url_buf: [4096]u8 = undefined;
        const url = try std.fmt.bufPrint(&url_buf, "{s}{s}", .{ self.api_server, path });

        const uri = try std.Uri.parse(url);

        // Build headers with Protobuf Content-Type and authorization
        var header_buffer: [4096]u8 = undefined;
        var headers = std.http.Client.Request.Headers{};

        if (self.token) |token| {
            const auth_value = try std.fmt.bufPrint(&header_buffer, "Bearer {s}", .{token});
            headers.authorization = .{ .override = auth_value };
        }

        // Set Protobuf Content-Type for request body
        if (body != null) {
            headers.content_type = .{ .override = "application/vnd.kubernetes.protobuf;charset=utf-8" };
        }

        // Make request to Kubernetes API with Protobuf Accept header
        var req = try self.http_client.request(method, uri, .{
            .redirect_behavior = @enumFromInt(3),
            .headers = headers,
            .extra_headers = &.{
                .{ .name = "Accept", .value = "application/vnd.kubernetes.protobuf" },
            },
        });
        defer req.deinit();

        // Send request with or without body
        if (body) |request_body| {
            req.transfer_encoding = .{ .content_length = request_body.len };
            var send_body = try req.sendBody(&.{});
            try send_body.writer.writeAll(request_body);
            try send_body.end();
        } else {
            try req.sendBodiless();
        }

        // Receive response headers
        var redirect_buffer: [2048]u8 = undefined;
        var response = try req.receiveHead(&redirect_buffer);

        // Check response status
        const is_success = @intFromEnum(response.head.status) >= 200 and @intFromEnum(response.head.status) < 300;
        if (!is_success) {
            self.clearLastApiError();
            self.last_api_error = .{ .code = @intFromEnum(response.head.status) };
            return error.K8sApiError;
        }

        // Read response body (Protobuf-encoded) with decompression and size limit
        var body_buffer = try std.ArrayList(u8).initCapacity(self.allocator, 8192);
        errdefer body_buffer.deinit(self.allocator);

        var transfer_buffer: [16384]u8 = undefined;
        var decompress: std.http.Decompress = undefined;
        var decompress_buffer: [32768]u8 = undefined;
        const reader = response.readerDecompressing(&transfer_buffer, &decompress, &decompress_buffer);

        reader.appendRemaining(self.allocator, &body_buffer, .limited(self.max_response_size)) catch |err| switch (err) {
            error.ReadFailed => return response.bodyErr().?,
            else => |e| return e,
        };

        return try body_buffer.toOwnedSlice(self.allocator);
    }

};

/// Cluster information
pub const ClusterInfo = struct {
    k8s_version: []const u8,
    node_count: u32,
};

/// Kubeconfig structure
pub const KubeConfig = struct {
    server: []const u8,
    token: ?[]const u8 = null,
    namespace: ?[]const u8 = null,
    cert_path: ?[]const u8 = null,
    key_path: ?[]const u8 = null,
};
