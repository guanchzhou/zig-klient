const std = @import("std");
const log = std.log.scoped(.klient);
const retry_mod = @import("retry.zig");
const tls_mod = @import("tls.zig");

/// Kubernetes API client - standalone library
/// Provides access to Kubernetes cluster resources via REST API
///
/// Note: This library is logging-agnostic. Wrap API calls with your own
/// logging if needed.
///
/// Thread-safety: a `K8sClient` may be shared across threads. It holds no per-request
/// mutable state, and the underlying `std.http.Client` opens and pools connections
/// under a mutex ("Connections are opened in a thread-safe manner"). Sharing one
/// client therefore shares one connection pool.
///
/// Error detail is returned, not stored: pass storage to `requestCapturing`, or set
/// `ResourceClient.error_sink`. (A previous `last_api_error` field on this struct made
/// the client un-shareable and handed out strings that the next request freed.)
pub const K8sClient = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    api_server: []const u8,
    token: ?[]const u8,
    namespace: []const u8,
    http_client: std.http.Client,
    retry_config: retry_mod.RetryConfig,
    tls_config: ?tls_mod.TlsConfig,
    max_response_size: usize,

    /// Structured Kubernetes API error. The strings are allocated with the client's
    /// allocator but owned by whoever captured it — call `deinit` with that same
    /// allocator. Capture one by passing storage to a `*Capturing` request variant
    /// or by setting `ResourceClient.error_sink`.
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

    /// Zig 0.16's `std.crypto.tls.Client` implements none of these, and
    /// `std.http.Client` exposes no hook to supply them. Previously they were
    /// accepted and silently dropped, so a caller configuring client-certificate
    /// auth got an unauthenticated connection and, later, an opaque
    /// `error.TlsInitializationFailed`. Fail at construction with a reason instead.
    ///
    /// Note this is not why HTTPS fails against a cluster — see `tlsUnsupportedHint`.
    fn rejectUnsupportedTlsOptions(tls: tls_mod.TlsConfig) !void {
        if (tls.client_cert_data != null or tls.client_cert_path != null or
            tls.client_key_data != null or tls.client_key_path != null)
        {
            log.warn(
                "client-certificate auth is not supported: Zig {s} std.crypto.tls has no " ++
                    "client-certificate support. Authenticate with a bearer token, or reach the " ++
                    "API through `kubectl proxy` (see connectWithFallback).",
                .{@import("builtin").zig_version_string},
            );
            return error.ClientCertificatesUnsupported;
        }
        if (tls.insecure_skip_verify) {
            log.warn(
                "insecure_skip_verify is not supported: std.http.Client does not expose TLS " ++
                    "verification settings. Supply the cluster CA via ca_cert_data/ca_cert_path.",
                .{},
            );
            return error.InsecureSkipVerifyUnsupported;
        }
        if (tls.server_name != null) {
            log.warn(
                "server_name (SNI override) is not supported: std.http.Client derives SNI from " ++
                    "the request URL. Point `server` at the name the certificate carries.",
                .{},
            );
            return error.TlsServerNameUnsupported;
        }
    }

    /// Explains `error.TlsInitializationFailed`, which `std.http.Client` returns for
    /// every handshake failure with the cause discarded.
    ///
    /// The usual cause is not a bad CA: Zig 0.16's TLS client has no handling for the
    /// `certificate_request` handshake message (it appears nowhere in
    /// `std/crypto/tls/Client.zig`), and a Kubernetes API server sends one whenever it
    /// is started with `--client-ca-file` — the default for every distribution. The
    /// handshake then aborts with `TlsUnexpectedMessage`, which surfaces here masked.
    fn tlsUnsupportedHint(self: *K8sClient, path: []const u8) void {
        if (!std.mem.startsWith(u8, self.api_server, "https://")) return;
        log.err(
            "TLS handshake with {s} failed while requesting {s}. Zig {s} cannot complete a " ++
                "handshake with an API server that requests client certificates, which is the " ++
                "default. Run `kubectl proxy` and point `server` at http://127.0.0.1:8001, or " ++
                "use connectWithFallback().",
            .{ self.api_server, path, @import("builtin").zig_version_string },
        );
    }

    pub fn init(allocator: std.mem.Allocator, io: std.Io, config: Config) !K8sClient {
        // Validate before allocating anything: the CA bundle rescan below owns heap
        // memory, so bailing out after it would leak the whole system trust store.
        if (config.tls_config) |tls| try rejectUnsupportedTlsOptions(tls);

        var http_client = std.http.Client{
            .allocator = allocator,
            .io = io,
        };
        // Every failure path past this point must release the bundle.
        errdefer http_client.deinit();

        // Force an upfront certificate rescan so the first HTTPS request
        // doesn't silently fail on platforms with non-standard CA paths (macOS).
        const now = std.Io.Timestamp.now(io, .real);
        http_client.ca_bundle.rescan(allocator, io, now) catch {};
        http_client.now = now;

        // Configure custom CA bundle if TLS config provided
        if (config.tls_config) |tls| {
            if (tls.ca_cert_data) |ca_pem| {
                // Hardened staging (random name + O_EXCL + immediate delete) lives in
                // tls.addCaCertData; see there for the symlink/TOCTOU rationale.
                try tls_mod.addCaCertData(&http_client, allocator, io, now, ca_pem);
            } else if (tls.ca_cert_path) |ca_path| {
                http_client.ca_bundle.addCertsFromFilePathAbsolute(allocator, io, now, ca_path) catch |err| {
                    // User explicitly provided a CA cert path that failed to load.
                    return err;
                };
            }
        }

        return K8sClient{
            .allocator = allocator,
            .io = io,
            .api_server = try allocator.dupe(u8, config.server),
            .token = if (config.token) |t| try allocator.dupe(u8, t) else null,
            .namespace = try allocator.dupe(u8, config.namespace orelse "default"),
            .http_client = http_client,
            .retry_config = config.retry_config orelse retry_mod.defaultConfig,
            .tls_config = config.tls_config,
            .max_response_size = config.max_response_size,
        };
    }

    pub fn deinit(self: *K8sClient) void {
        self.allocator.free(self.api_server);
        if (self.token) |t| self.allocator.free(t);
        self.allocator.free(self.namespace);
        self.destroyHttpClient();
    }

    fn dupStatusField(self: *K8sClient, obj: std.json.ObjectMap, key: []const u8) ?[]const u8 {
        const v = obj.get(key) orelse return null;
        if (v != .string) return null;
        return self.allocator.dupe(u8, v.string) catch null;
    }

    /// Best-effort parse of a Kubernetes `Status` error body. Returns null when the
    /// body is empty or is not a JSON object (a protobuf error body, or the HTML a
    /// load balancer serves) — the caller then falls back to the HTTP status code.
    /// Strings are duped so they outlive the temporary parse.
    fn parseStatusJson(self: *K8sClient, body: []const u8) ?ApiError {
        if (body.len == 0) return null;
        const parsed = std.json.parseFromSlice(std.json.Value, self.allocator, body, .{
            .ignore_unknown_fields = true,
        }) catch return null;
        defer parsed.deinit();
        if (parsed.value != .object) return null;
        const obj = parsed.value.object;
        return .{
            .status = self.dupStatusField(obj, "status"),
            .message = self.dupStatusField(obj, "message"),
            .reason = self.dupStatusField(obj, "reason"),
            .code = if (obj.get("code")) |v| (if (v == .integer) v.integer else null) else null,
        };
    }

    fn destroyHttpClient(self: *K8sClient) void {
        self.http_client.deinit();
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

    /// Count cluster nodes (best-effort). Returns null when the count could not be
    /// determined (request/parse failure or unexpected shape) — distinct from a real
    /// empty cluster (0).
    ///
    /// Asks for a single item and reads `metadata.remainingItemCount` rather than
    /// downloading every Node. A Node object is several KB (status.images alone
    /// often dominates it), so the full list costs O(cluster) bytes and parse time
    /// to produce one integer.
    fn getNodeCount(self: *K8sClient) ?u32 {
        // `limit` forces a paginated (etcd-backed) list, which is what makes the
        // API server populate remainingItemCount. Do NOT add resourceVersion=0
        // here: a watch-cache read returns the full list and omits the count.
        const nodes_response = self.request(.GET, "/api/v1/nodes?limit=1", null) catch return null;
        defer self.allocator.free(nodes_response);

        const Page = struct {
            metadata: struct { remainingItemCount: ?i64 = null } = .{},
            items: []struct {} = &.{},
        };
        const parsed = std.json.parseFromSlice(Page, self.allocator, nodes_response, .{
            .ignore_unknown_fields = true,
        }) catch return null;
        defer parsed.deinit();

        // remainingItemCount is absent on the last (or only) page.
        const remaining = parsed.value.metadata.remainingItemCount orelse 0;
        if (remaining < 0) return null;
        return std.math.cast(u32, @as(i64, @intCast(parsed.value.items.len)) + remaining);
    }

    /// HTTP method alias for convenience
    pub const Method = std.http.Method;

    /// Make a request to the Kubernetes API. Idempotent methods (GET/PUT/DELETE/
    /// PATCH/HEAD) are retried automatically per `retry_config` on transport errors
    /// and retryable status codes (429/5xx); POST (create) is sent ONCE to avoid
    /// duplicating a non-idempotent write. Use requestWithRetry to force retries.
    pub fn request(self: *K8sClient, method: std.http.Method, path: []const u8, body: ?[]const u8) ![]u8 {
        return self.requestWithContentType(method, path, body, "application/json");
    }

    /// Like `request`, but captures the Kubernetes `Status` detail of a failure.
    ///
    /// `err_out` is caller-owned storage: on `error.K8sApiError` it receives an
    /// `ApiError` whose strings were allocated with this client's allocator, and the
    /// caller must `deinit` it with that allocator. It is left untouched on success
    /// and on transport-level failures.
    ///
    /// This replaces the old `client.last_api_error` field. That was mutable state on
    /// the shared client, which made `K8sClient` un-shareable across threads even
    /// though `std.http.Client` underneath is thread-safe, and its strings were freed
    /// by the following request.
    pub fn requestCapturing(
        self: *K8sClient,
        method: std.http.Method,
        path: []const u8,
        body: ?[]const u8,
        err_out: *?ApiError,
    ) ![]u8 {
        return self.sendWithRetry(method, path, body, .json, false, err_out);
    }

    /// `requestWithContentType` with the same error capture as `requestCapturing`.
    /// This is what `ResourceClient.error_sink` routes through.
    pub fn requestCapturingWithContentType(
        self: *K8sClient,
        method: std.http.Method,
        path: []const u8,
        body: ?[]const u8,
        content_type: []const u8,
        err_out: *?ApiError,
    ) ![]u8 {
        return self.sendWithRetry(method, path, body, .{ .content_type = content_type }, false, err_out);
    }

    /// `requestWithProtobuf` with the same error capture as `requestCapturing`.
    pub fn requestWithProtobufCapturing(
        self: *K8sClient,
        method: std.http.Method,
        path: []const u8,
        body: ?[]const u8,
        err_out: *?ApiError,
    ) ![]u8 {
        return self.sendWithRetry(method, path, body, .protobuf, false, err_out);
    }

    /// Whether a duplicate of this method has no additional observable effect, so
    /// it is safe to retry. POST/CONNECT are not.
    fn isIdempotent(method: std.http.Method) bool {
        return switch (method) {
            .GET, .HEAD, .PUT, .DELETE, .OPTIONS, .TRACE, .PATCH => true,
            else => false,
        };
    }

    /// Shared retry loop. Retries when `force` is set or the method is idempotent;
    /// otherwise performs a single attempt.
    fn sendWithRetry(
        self: *K8sClient,
        method: std.http.Method,
        path: []const u8,
        body: ?[]const u8,
        format: WireFormat,
        force: bool,
        err_out: ?*?ApiError,
    ) ![]u8 {
        if (!force and !isIdempotent(method)) {
            return self.sendOnce(method, path, body, format, err_out);
        }

        var retry_ctx = retry_mod.RetryContext.init(self.retry_config);
        while (true) {
            // The retry decision needs the status code even when the caller does not
            // want the detail, so always capture locally and hand over at the end.
            var attempt_err: ?ApiError = null;
            const result = self.sendOnce(method, path, body, format, &attempt_err) catch |err| {
                // A failed TLS handshake is deterministic — the CA, the URL and the
                // peer's capabilities do not change between attempts. Retrying only
                // burns the backoff budget and repeats the diagnostic N times.
                if (err == error.TlsInitializationFailed) {
                    if (attempt_err) |*e| e.deinit(self.allocator);
                    return err;
                }

                const status_code: ?u16 = if (attempt_err) |api_err|
                    if (api_err.code) |code| std.math.cast(u16, code) else null
                else
                    null;

                if (!retry_ctx.shouldRetry(status_code)) {
                    // Last attempt: give the detail to the caller, or drop it.
                    if (err_out) |out| {
                        out.* = attempt_err;
                    } else if (attempt_err) |*e| {
                        e.deinit(self.allocator);
                    }
                    return err;
                }

                // Another attempt follows; this attempt's detail is superseded.
                if (attempt_err) |*e| e.deinit(self.allocator);

                retry_ctx.nextAttempt();
                try retry_ctx.backoff();
                continue;
            };
            return result;
        }
    }

    /// Force retries regardless of method idempotency. Use only when a duplicate
    /// write is known to be safe (e.g. a POST guarded by a server-side dedup).
    pub fn requestWithRetry(self: *K8sClient, method: std.http.Method, path: []const u8, body: ?[]const u8) ![]u8 {
        return self.sendWithRetry(method, path, body, .json, true, null);
    }

    /// Make HTTP request with custom Content-Type (idempotent methods auto-retry).
    pub fn requestWithContentType(
        self: *K8sClient,
        method: std.http.Method,
        path: []const u8,
        body: ?[]const u8,
        content_type: []const u8,
    ) ![]u8 {
        return self.sendWithRetry(method, path, body, .{ .content_type = content_type }, false, null);
    }

    /// Wire format for one attempt. The JSON and Protobuf paths differ only in these
    /// two headers; everything else — auth, redirects, status handling, decompression,
    /// size limiting — is identical and lives in `sendOnce`.
    pub const WireFormat = struct {
        content_type: []const u8,
        /// Sent as `Accept`. Null leaves the server to its default (JSON).
        accept: ?[]const u8 = null,

        pub const json: WireFormat = .{ .content_type = "application/json" };
        pub const protobuf: WireFormat = .{
            .content_type = "application/vnd.kubernetes.protobuf;charset=utf-8",
            .accept = "application/vnd.kubernetes.protobuf",
        };
    };

    /// A single HTTP attempt with no retry. The retry wrappers call this.
    fn sendOnce(
        self: *K8sClient,
        method: std.http.Method,
        path: []const u8,
        body: ?[]const u8,
        format: WireFormat,
        err_out: ?*?ApiError,
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
            headers.content_type = .{ .override = format.content_type };
        }

        // Stack-local, so it outlives `req`, which is torn down before we return.
        var accept_header: [1]std.http.Header = undefined;
        var extra_headers: []const std.http.Header = &.{};
        if (format.accept) |accept| {
            accept_header[0] = .{ .name = "Accept", .value = accept };
            extra_headers = accept_header[0..1];
        }

        // Make request to Kubernetes API
        var req = self.http_client.request(method, uri, .{
            .redirect_behavior = @enumFromInt(3),
            .headers = headers,
            .extra_headers = extra_headers,
        }) catch |err| {
            if (err == error.TlsInitializationFailed) {
                self.tlsUnsupportedHint(path);
            } else {
                log.warn("HTTP request init failed for {s}: {}", .{ path, err });
            }
            return err;
        };
        defer req.deinit();

        // Send request with or without body
        if (body) |request_body| {
            req.transfer_encoding = .{ .content_length = request_body.len };
            var body_buf: [8192]u8 = undefined;
            var send_body = req.sendBody(&body_buf) catch |err| {
                log.warn("HTTP sendBody failed for {s}: {}", .{ path, err });
                return err;
            };
            try send_body.writer.writeAll(request_body);
            try send_body.end();
        } else {
            req.sendBodiless() catch |err| {
                log.warn("HTTP sendBodiless failed for {s}: {}", .{ path, err });
                return err;
            };
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

            if (err_out) |out| {
                // Not every error body is a Kubernetes Status: a load balancer or
                // ingress in front of the API server answers with HTML, and a
                // protobuf request may get a protobuf body. Fall back to the status
                // code so the caller always learns something.
                out.* = self.parseStatusJson(error_buffer.items) orelse
                    ApiError{ .code = @intFromEnum(response.head.status) };
            }
            return error.K8sApiError;
        }

        // Read response body with automatic gzip/deflate decompression
        var body_buffer = try std.ArrayList(u8).initCapacity(self.allocator, 8192);
        errdefer body_buffer.deinit(self.allocator);

        var transfer_buffer: [16384]u8 = undefined;
        var decompress: std.http.Decompress = undefined;
        var decompress_buffer: [std.compress.flate.max_window_len]u8 = undefined;
        const reader = response.readerDecompressing(&transfer_buffer, &decompress, &decompress_buffer);

        reader.appendRemaining(self.allocator, &body_buffer, .limited(self.max_response_size)) catch |err| switch (err) {
            error.ReadFailed => return response.bodyErr().?,
            else => |e| return e,
        };

        return try body_buffer.toOwnedSlice(self.allocator);
    }

    /// Make a request using Kubernetes' Protobuf wire format.
    /// Returns the raw Protobuf-encoded response body.
    ///
    /// Goes through the same retry policy as `request`: idempotent methods are
    /// retried, POST is sent once. Previously this path had its own copy of the
    /// send/receive logic with no retries at all, and the two copies had drifted.
    pub fn requestWithProtobuf(
        self: *K8sClient,
        method: std.http.Method,
        path: []const u8,
        body: ?[]const u8,
    ) ![]u8 {
        return self.sendWithRetry(method, path, body, .protobuf, false, null);
    }
};

/// Cluster information
pub const ClusterInfo = struct {
    k8s_version: []const u8,
    /// null when the node count couldn't be determined (vs 0 = empty cluster).
    node_count: ?u32,

    /// getClusterInfo() dupes `k8s_version`, so the caller owns it and must free.
    pub fn deinit(self: ClusterInfo, allocator: std.mem.Allocator) void {
        allocator.free(self.k8s_version);
    }
};

/// Kubeconfig structure
pub const KubeConfig = struct {
    server: []const u8,
    token: ?[]const u8 = null,
    namespace: ?[]const u8 = null,
    cert_path: ?[]const u8 = null,
    key_path: ?[]const u8 = null,
};
