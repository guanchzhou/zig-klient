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
            // Rescan system certificates first so we have the standard CA bundle
            http_client.ca_bundle.rescan(allocator) catch {};
            http_client.next_https_rescan_certs = false;

            if (tls.ca_cert_data) |ca_pem| {
                // Write CA cert PEM data to a temp file for the Certificate.Bundle parser
                const path = try std.fmt.allocPrint(allocator, "/tmp/zig-klient-ca-{d}.pem", .{@as(u64, @intCast(std.time.timestamp()))});
                temp_ca_path = path;

                const file = std.fs.createFileAbsolute(path, .{}) catch {
                    allocator.free(path);
                    temp_ca_path = null;
                    return K8sClient{
                        .allocator = allocator,
                        .api_server = try allocator.dupe(u8, config.server),
                        .token = if (config.token) |t| try allocator.dupe(u8, t) else null,
                        .namespace = try allocator.dupe(u8, config.namespace orelse "default"),
                        .http_client = http_client,
                        .retry_config = config.retry_config orelse retry_mod.defaultConfig,
                        .tls_config = config.tls_config,
                        .max_response_size = config.max_response_size,
                        .temp_ca_path = null,
                    };
                };
                file.writeAll(ca_pem) catch {};
                file.close();

                http_client.ca_bundle.addCertsFromFilePathAbsolute(allocator, path) catch {};
            } else if (tls.ca_cert_path) |ca_path| {
                http_client.ca_bundle.addCertsFromFilePathAbsolute(allocator, ca_path) catch {};
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

    /// List all pods in the current namespace
    pub fn listPods(self: *K8sClient) ![]Pod {
        const path = try std.fmt.allocPrint(self.allocator, "/api/v1/namespaces/{s}/pods", .{self.namespace});
        defer self.allocator.free(path);

        const response = try self.request(.GET, path, null);
        defer self.allocator.free(response);

        return try self.parsePodList(response);
    }

    /// List all pods across all namespaces
    pub fn listAllPods(self: *K8sClient) ![]Pod {
        const path = "/api/v1/pods";
        const response = try self.request(.GET, path, null);
        defer self.allocator.free(response);

        return try self.parsePodList(response);
    }

    /// Get cluster information
    pub fn getClusterInfo(self: *K8sClient) !ClusterInfo {
        const version_path = "/version";
        const version_response = try self.request(.GET, version_path, null);
        defer self.allocator.free(version_response);

        // Parse version info
        const parsed_version = try std.json.parseFromSlice(std.json.Value, self.allocator, version_response, .{});
        defer parsed_version.deinit();

        const version_obj = parsed_version.value.object;
        const git_version = version_obj.get("gitVersion").?.string;

        // Get node info for CPU/memory
        const nodes_path = "/api/v1/nodes";
        const nodes_response = try self.request(.GET, nodes_path, null);
        defer self.allocator.free(nodes_response);

        const node_metrics = try self.parseNodeMetrics(nodes_response);

        return ClusterInfo{
            .k8s_version = try self.allocator.dupe(u8, git_version),
            .cpu_usage = node_metrics.cpu_usage,
            .mem_usage = node_metrics.mem_usage,
        };
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
            err_reader.appendRemaining(self.allocator, &error_buffer, .{ .max = 65536 }) catch {};

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

        reader.appendRemaining(self.allocator, &body_buffer, .{ .max = self.max_response_size }) catch |err| switch (err) {
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

        reader.appendRemaining(self.allocator, &body_buffer, .{ .max = self.max_response_size }) catch |err| switch (err) {
            error.ReadFailed => return response.bodyErr().?,
            else => |e| return e,
        };

        return try body_buffer.toOwnedSlice(self.allocator);
    }

    /// Parse pod list from JSON response
    fn parsePodList(self: *K8sClient, json: []const u8) ![]Pod {
        const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, json, .{});
        defer parsed.deinit();

        const items = parsed.value.object.get("items").?.array;
        var pods = try std.ArrayList(Pod).initCapacity(self.allocator, items.items.len);

        for (items.items) |item| {
            const metadata = item.object.get("metadata").?.object;
            const spec = item.object.get("spec").?.object;
            const status = item.object.get("status").?.object;

            const name = metadata.get("name").?.string;
            const namespace = metadata.get("namespace").?.string;
            const creation_timestamp = metadata.get("creationTimestamp").?.string;

            const phase = status.get("phase").?.string;
            const container_statuses = status.get("containerStatuses");

            var ready_count: u32 = 0;
            var total_count: u32 = 0;
            var restart_count: u32 = 0;

            if (container_statuses) |cs| {
                total_count = @intCast(cs.array.items.len);
                for (cs.array.items) |container| {
                    if (container.object.get("ready").?.bool) {
                        ready_count += 1;
                    }
                    restart_count += @intCast(container.object.get("restartCount").?.integer);
                }
            }

            const ready_str = try std.fmt.allocPrint(self.allocator, "{d}/{d}", .{ ready_count, total_count });
            const age_str = try self.calculateAge(creation_timestamp);

            // Get node and IP
            const node_name = if (spec.get("nodeName")) |n| n.string else "n/a";
            const pod_ip = if (status.get("podIP")) |ip| ip.string else "n/a";

            try pods.append(self.allocator, Pod{
                .name = try self.allocator.dupe(u8, name),
                .namespace = try self.allocator.dupe(u8, namespace),
                .ready = ready_str,
                .status = try self.allocator.dupe(u8, phase),
                .restarts = restart_count,
                .age = age_str,
                .node = try self.allocator.dupe(u8, node_name),
                .ip = try self.allocator.dupe(u8, pod_ip),
                .cpu_usage = "n/a", // TODO: Get from metrics API
                .mem_usage = "n/a", // TODO: Get from metrics API
            });
        }

        return try pods.toOwnedSlice(self.allocator);
    }

    /// Parse node metrics from JSON response
    fn parseNodeMetrics(self: *K8sClient, json: []const u8) !struct { cpu_usage: u8, mem_usage: u8 } {
        const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, json, .{});
        defer parsed.deinit();

        const items = parsed.value.object.get("items").?.array;

        // Simple calculation: average across all nodes
        var total_cpu: u64 = 0;
        var total_mem: u64 = 0;
        var node_count: u32 = 0;

        for (items.items) |item| {
            const status = item.object.get("status").?.object;
            if (status.get("allocatable")) |_| {
                node_count += 1;
                // For now, return mock values
                // TODO: Implement proper metrics API parsing
                total_cpu += 50;
                total_mem += 60;
            }
        }

        if (node_count == 0) {
            return .{ .cpu_usage = 0, .mem_usage = 0 };
        }

        return .{
            .cpu_usage = @intCast(total_cpu / node_count),
            .mem_usage = @intCast(total_mem / node_count),
        };
    }

    /// Calculate age from ISO 8601 timestamp (e.g., "2024-01-15T10:30:00Z")
    fn calculateAge(self: *K8sClient, timestamp: []const u8) ![]const u8 {
        // Parse ISO 8601: YYYY-MM-DDThh:mm:ssZ
        if (timestamp.len < 19) return try self.allocator.dupe(u8, "n/a");

        const year = std.fmt.parseInt(i32, timestamp[0..4], 10) catch return try self.allocator.dupe(u8, "n/a");
        const month = std.fmt.parseInt(u4, timestamp[5..7], 10) catch return try self.allocator.dupe(u8, "n/a");
        const day = std.fmt.parseInt(u5, timestamp[8..10], 10) catch return try self.allocator.dupe(u8, "n/a");
        const hour = std.fmt.parseInt(u5, timestamp[11..13], 10) catch return try self.allocator.dupe(u8, "n/a");
        const minute = std.fmt.parseInt(u6, timestamp[14..16], 10) catch return try self.allocator.dupe(u8, "n/a");
        const second = std.fmt.parseInt(u6, timestamp[17..19], 10) catch return try self.allocator.dupe(u8, "n/a");

        const epoch_day = std.time.epoch.EpochDay.fromYearMonthDay(.{
            .year = year,
            .month = @enumFromInt(month),
            .day = day,
        });
        const created_sec: i64 = epoch_day.toSecs() + @as(i64, hour) * 3600 + @as(i64, minute) * 60 + @as(i64, second);
        const now_sec = std.time.timestamp();
        const diff = now_sec - created_sec;

        if (diff < 0) return try self.allocator.dupe(u8, "0s");

        const udiff: u64 = @intCast(diff);
        if (udiff < 60) {
            return try std.fmt.allocPrint(self.allocator, "{d}s", .{udiff});
        } else if (udiff < 3600) {
            return try std.fmt.allocPrint(self.allocator, "{d}m", .{udiff / 60});
        } else if (udiff < 86400) {
            return try std.fmt.allocPrint(self.allocator, "{d}h", .{udiff / 3600});
        } else {
            return try std.fmt.allocPrint(self.allocator, "{d}d", .{udiff / 86400});
        }
    }
};

/// Pod information from Kubernetes API
pub const Pod = struct {
    name: []const u8,
    namespace: []const u8,
    ready: []const u8,
    status: []const u8,
    restarts: u32,
    age: []const u8,
    node: []const u8,
    ip: []const u8,
    cpu_usage: []const u8,
    mem_usage: []const u8,
};

/// Cluster information
pub const ClusterInfo = struct {
    k8s_version: []const u8,
    cpu_usage: u8,
    mem_usage: u8,
};

/// Kubeconfig structure
pub const KubeConfig = struct {
    server: []const u8,
    token: ?[]const u8 = null,
    namespace: ?[]const u8 = null,
    cert_path: ?[]const u8 = null,
    key_path: ?[]const u8 = null,
};
