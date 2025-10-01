const std = @import("std");
const retry_mod = @import("retry.zig");
const tls_mod = @import("tls.zig");
const protobuf_k8s = @import("protobuf_k8s.zig");

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
    
    pub const Config = struct {
        server: []const u8,
        token: ?[]const u8 = null,
        namespace: ?[]const u8 = null,
        retry_config: ?retry_mod.RetryConfig = null,
        tls_config: ?tls_mod.TlsConfig = null,
    };
    
    pub fn init(allocator: std.mem.Allocator, config: Config) !K8sClient {
        const http_client = std.http.Client{ .allocator = allocator };
        
        return K8sClient{
            .allocator = allocator,
            .api_server = try allocator.dupe(u8, config.server),
            .token = if (config.token) |t| try allocator.dupe(u8, t) else null,
            .namespace = try allocator.dupe(u8, config.namespace orelse "default"),
            .http_client = http_client,
            .retry_config = config.retry_config orelse retry_mod.defaultConfig,
            .tls_config = config.tls_config,
        };
    }
    
    pub fn deinit(self: *K8sClient) void {
        self.allocator.free(self.api_server);
        if (self.token) |t| self.allocator.free(t);
        self.allocator.free(self.namespace);
        self.http_client.deinit();
    }
    
    /// List all pods in the current namespace
    pub fn listPods(self: *K8sClient) ![]Pod {
        const path = try std.fmt.allocPrint(
            self.allocator,
            "/api/v1/namespaces/{s}/pods",
            .{self.namespace}
        );
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
        const parsed_version = try std.json.parseFromSlice(
            std.json.Value,
            self.allocator,
            version_response,
            .{}
        );
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
    
    /// HTTP methods enum for type safety
    pub const Method = enum {
        GET,
        POST,
        PUT,
        DELETE,
        PATCH,
    };
    
    /// Make HTTP request to Kubernetes API with automatic retries
    pub fn request(self: *K8sClient, method: Method, path: []const u8, body: ?[]const u8) ![]u8 {
        return self.requestWithContentType(method, path, body, "application/json");
    }
    
    /// Make HTTP request with retries (use this for production code)
    pub fn requestWithRetry(self: *K8sClient, method: Method, path: []const u8, body: ?[]const u8) ![]u8 {
        var retry_ctx = retry_mod.RetryContext.init(self.retry_config);
        
        while (true) {
            const result = self.request(method, path, body) catch |err| {
                // Check if we should retry
                if (!retry_ctx.shouldRetry(null)) {
                    return err; // No more retries
                }
                
                // Backoff before retry
                retry_ctx.nextAttempt();
                try retry_ctx.backoff();
                continue;
            };
            
            // Success!
            return result;
        }
    }
    
    /// Make HTTP request with custom Content-Type
    pub fn requestWithContentType(
        self: *K8sClient,
        method: Method,
        path: []const u8,
        body: ?[]const u8,
        content_type: []const u8,
    ) ![]u8 {
        const url = try std.fmt.allocPrint(
            self.allocator,
            "{s}{s}",
            .{ self.api_server, path }
        );
        defer self.allocator.free(url);
        
        const uri = try std.Uri.parse(url);
        
        const http_method: std.http.Method = switch (method) {
            .GET => .GET,
            .POST => .POST,
            .PUT => .PUT,
            .DELETE => .DELETE,
            .PATCH => .PATCH,
        };
        
        // Build headers with authorization
        var header_buffer: [1024]u8 = undefined;
        var content_type_buffer: [256]u8 = undefined;
        var headers = std.http.Client.Request.Headers{};
        
        if (self.token) |token| {
            const auth_value = try std.fmt.bufPrint(&header_buffer, "Bearer {s}", .{token});
            headers.authorization = .{ .override = auth_value };
        }
        
        if (body != null) {
            const ct_value = try std.fmt.bufPrint(&content_type_buffer, "{s}", .{content_type});
            headers.content_type = .{ .override = ct_value };
        }
        
        // Make request to Kubernetes API
        var req = try self.http_client.request(http_method, uri, .{
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
            // Try to read error body
            var error_buffer = try std.ArrayList(u8).initCapacity(self.allocator, 0);
            defer error_buffer.deinit(self.allocator);
            
            var transfer_buffer: [4096]u8 = undefined;
            const reader = response.reader(&transfer_buffer);
            const max_size: std.io.Limit = @enumFromInt(1 * 1024 * 1024); // 1 MB
            reader.appendRemaining(self.allocator, &error_buffer, max_size) catch {};
            
            // Log error details if possible
            // In library mode, just return error
            return error.K8sApiError;
        }
        
        // Read response body
        var body_buffer = try std.ArrayList(u8).initCapacity(self.allocator, 0);
        errdefer body_buffer.deinit(self.allocator);
        
        var transfer_buffer: [4096]u8 = undefined;
        const reader = response.reader(&transfer_buffer);
        
        const max_size: std.io.Limit = @enumFromInt(10 * 1024 * 1024); // 10 MB
        reader.appendRemaining(self.allocator, &body_buffer, max_size) catch |err| switch (err) {
            error.ReadFailed => return response.bodyErr().?,
            else => |e| return e,
        };
        
        return try body_buffer.toOwnedSlice(self.allocator);
    }

    /// Make HTTP request with Protobuf serialization
    /// Returns raw Protobuf-encoded response data
    pub fn requestWithProtobuf(
        self: *K8sClient,
        method: Method,
        path: []const u8,
        body: ?[]const u8,
    ) ![]u8 {
        const url = try std.fmt.allocPrint(
            self.allocator,
            "{s}{s}",
            .{ self.api_server, path }
        );
        defer self.allocator.free(url);
        
        const uri = try std.Uri.parse(url);
        
        const http_method: std.http.Method = switch (method) {
            .GET => .GET,
            .POST => .POST,
            .PUT => .PUT,
            .DELETE => .DELETE,
            .PATCH => .PATCH,
        };
        
        // Build headers with Protobuf Content-Type and authorization
        var header_buffer: [1024]u8 = undefined;
        var content_type_buffer: [256]u8 = undefined;
        var accept_buffer: [256]u8 = undefined;
        var headers = std.http.Client.Request.Headers{};
        
        if (self.token) |token| {
            const auth_value = try std.fmt.bufPrint(&header_buffer, "Bearer {s}", .{token});
            headers.authorization = .{ .override = auth_value };
        }
        
        // Set Protobuf Content-Type for request body
        if (body != null) {
            const ct_value = try std.fmt.bufPrint(&content_type_buffer, "{s}", .{protobuf_k8s.K8S_CONTENT_TYPE_WITH_CHARSET});
            headers.content_type = .{ .override = ct_value };
        }
        
        // Set Protobuf Accept header for response
        const accept_value = try std.fmt.bufPrint(&accept_buffer, "{s}", .{protobuf_k8s.K8S_CONTENT_TYPE});
        _ = accept_value; // TODO: Add Accept header support to std.http.Client.Request.Headers
        
        // Make request to Kubernetes API
        var req = try self.http_client.request(http_method, uri, .{
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
            return error.K8sApiError;
        }
        
        // Read response body (Protobuf-encoded)
        var body_buffer = try std.ArrayList(u8).initCapacity(self.allocator, 0);
        errdefer body_buffer.deinit(self.allocator);
        
        var transfer_buffer: [4096]u8 = undefined;
        const reader = response.reader(&transfer_buffer);
        
        const max_size: std.io.Limit = @enumFromInt(10 * 1024 * 1024); // 10 MB
        reader.appendRemaining(self.allocator, &body_buffer, max_size) catch |err| switch (err) {
            error.ReadFailed => return response.bodyErr().?,
            else => |e| return e,
        };
        
        return try body_buffer.toOwnedSlice(self.allocator);
    }
    
    /// Old method signature for backwards compatibility
    fn requestOld(self: *K8sClient, method_str: []const u8, path: []const u8, body: ?[]const u8) ![]u8 {
        const method: Method = if (std.mem.eql(u8, method_str, "GET"))
            .GET
        else if (std.mem.eql(u8, method_str, "POST"))
            .POST
        else if (std.mem.eql(u8, method_str, "PUT"))
            .PUT
        else if (std.mem.eql(u8, method_str, "DELETE"))
            .DELETE
        else if (std.mem.eql(u8, method_str, "PATCH"))
            .PATCH
        else
            .GET;
        
        return self.request(method, path, body);
    }
    
    /// Parse pod list from JSON response
    fn parsePodList(self: *K8sClient, json: []const u8) ![]Pod {
        const parsed = try std.json.parseFromSlice(
            std.json.Value,
            self.allocator,
            json,
            .{}
        );
        defer parsed.deinit();
        
        const items = parsed.value.object.get("items").?.array;
        var pods = try std.ArrayList(Pod).initCapacity(self.allocator, 0);
        
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
        const parsed = try std.json.parseFromSlice(
            std.json.Value,
            self.allocator,
            json,
            .{}
        );
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
    
    /// Calculate age from timestamp
    fn calculateAge(self: *K8sClient, timestamp: []const u8) ![]const u8 {
        _ = self;
        _ = timestamp;
        // TODO: Implement proper age calculation from ISO8601 timestamp
        // For now, return placeholder
        return "n/a";
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
