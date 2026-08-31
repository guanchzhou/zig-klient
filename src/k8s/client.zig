const std = @import("std");
const log = std.log.scoped(.klient);
const retry_mod = @import("retry.zig");
const tls_mod = @import("tls.zig");

/// Controls one callback-scoped streaming GET request.
pub const StreamGetOptions = struct {
    /// Advertise supported compression and transparently decode the response.
    accept_compression: bool = true,
    /// Reject response headers larger than this value (maximum 64 KiB).
    max_header_bytes: usize = 64 << 10,
    /// When set, replace or append an explicit Kubernetes `pretty` query value.
    pretty: ?bool = null,
};

/// Response metadata copied before a streaming callback starts reading the body.
///
/// `content_type` is valid only for the duration of the callback.
pub const StreamResponseMeta = struct {
    status: std.http.Status,
    retry_after_seconds: ?u32,
    content_type: ?[]const u8,
};

const stream_header_capacity = 64 << 10;
const max_redirect_bytes = 8 << 10;
const max_request_url_bytes = 16 << 10;

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
    /// `std/crypto/tls/Client.zig`; ziglang/zig#19521). Re-checked on
    /// 0.17.0-dev.1936+5a625d5f3 — still absent. A Kubernetes API server sends one
    /// whenever it is started with `--client-ca-file` — the default for every
    /// distribution. The handshake then aborts with `TlsUnexpectedMessage`, which
    /// surfaces here masked.
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
            .read_buffer_size = stream_header_capacity,
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
    /// Parse a Kubernetes `Status` error body.
    ///
    /// `fallback_code` is the HTTP status and is used whenever the body omits a
    /// usable `code`. That default matters: a null code is indistinguishable from a
    /// transport failure to `retry.shouldRetry`, which treats it as retryable — so a
    /// `Status` without `code` previously made a 404 or 403 burn the entire retry
    /// budget with backoff.
    fn parseStatusJson(self: *K8sClient, body: []const u8, fallback_code: i64) ?ApiError {
        if (body.len == 0) return null;
        const parsed = std.json.parseFromSlice(std.json.Value, self.allocator, body, .{
            .ignore_unknown_fields = true,
        }) catch return null;
        defer parsed.deinit();
        if (parsed.value != .object) return null;
        const obj = parsed.value.object;
        const code: i64 = if (obj.get("code")) |v|
            (if (v == .integer) v.integer else fallback_code)
        else
            fallback_code;
        return .{
            .status = self.dupStatusField(obj, "status"),
            .message = self.dupStatusField(obj, "message"),
            .reason = self.dupStatusField(obj, "reason"),
            .code = code,
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
    /// `err_out` is caller-owned storage holding the detail of the most recent
    /// request made through it, or null. On `error.K8sApiError` it receives an
    /// `ApiError` whose strings were allocated with this client's allocator; the
    /// caller must `deinit` it with that allocator. It is set to null on success and
    /// on transport-level failures, which never produce a `Status`.
    ///
    /// A sink may be reused across calls: each request frees what the previous one
    /// left there. Copy anything you need to outlive the next request through it.
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
        // The sink describes THIS request. Release whatever a previous one left in
        // it: overwriting without freeing leaks the old status/message/reason, and
        // leaving it in place lets a later success — or a transport failure, which
        // never writes here — be read as carrying the earlier call's Status.
        if (err_out) |out| {
            if (out.*) |*prev| prev.deinit(self.allocator);
            out.* = null;
        }

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

    const ScopedRequestOptions = struct {
        accept_compression: bool = true,
        max_header_bytes: usize = stream_header_capacity,
        pretty: ?bool = null,
    };

    const BufferedResponseContext = struct {
        client: *K8sClient,
        err_out: ?*?ApiError,
        result: ?[]u8 = null,
    };

    fn requestUrl(self: *K8sClient, path: []const u8, pretty: ?bool) ![]u8 {
        const base_len = std.math.add(usize, self.api_server.len, path.len) catch
            return error.RequestUrlTooLong;
        if (pretty == null) {
            if (base_len > max_request_url_bytes) return error.RequestUrlTooLong;
            return std.fmt.allocPrint(self.allocator, "{s}{s}", .{ self.api_server, path });
        }

        const fragment_start = std.mem.findScalar(u8, path, '#') orelse path.len;
        const before_fragment = path[0..fragment_start];
        const fragment = path[fragment_start..];
        const query_start = std.mem.findScalar(u8, before_fragment, '?');
        const path_part = if (query_start) |index| before_fragment[0..index] else before_fragment;
        const query = if (query_start) |index| before_fragment[index + 1 ..] else null;

        var url: std.ArrayList(u8) = .empty;
        errdefer url.deinit(self.allocator);
        try url.appendSlice(self.allocator, self.api_server);
        try url.appendSlice(self.allocator, path_part);
        try url.append(self.allocator, '?');

        var wrote_parameter = false;
        var wrote_pretty = false;
        if (query) |query_string| {
            var parameters = std.mem.splitScalar(u8, query_string, '&');
            while (parameters.next()) |parameter| {
                if (parameter.len == 0) continue;
                const name_end = std.mem.findScalar(u8, parameter, '=') orelse parameter.len;
                const is_pretty = std.mem.eql(u8, parameter[0..name_end], "pretty");
                if (is_pretty and wrote_pretty) continue;

                if (wrote_parameter) try url.append(self.allocator, '&');
                if (is_pretty) {
                    try url.appendSlice(self.allocator, if (pretty.?) "pretty=true" else "pretty=false");
                    wrote_pretty = true;
                } else {
                    try url.appendSlice(self.allocator, parameter);
                }
                wrote_parameter = true;
            }
        }
        if (!wrote_pretty) {
            if (wrote_parameter) try url.append(self.allocator, '&');
            try url.appendSlice(self.allocator, if (pretty.?) "pretty=true" else "pretty=false");
        }
        try url.appendSlice(self.allocator, fragment);

        if (url.items.len > max_request_url_bytes) return error.RequestUrlTooLong;
        return url.toOwnedSlice(self.allocator);
    }

    fn resolveRedirect(self: *K8sClient, base_url: []const u8, location: []const u8) ![]u8 {
        if (location.len > max_redirect_bytes) return error.HttpRedirectLocationOversize;
        const capacity = std.math.add(usize, location.len, base_url.len + 1) catch
            return error.HttpRedirectLocationOversize;
        const scratch = try self.allocator.alloc(u8, capacity);
        defer self.allocator.free(scratch);
        @memcpy(scratch[0..location.len], location);

        const base_uri = try std.Uri.parse(base_url);
        var remaining = scratch;
        const resolved = try base_uri.resolveInPlace(location.len, &remaining);
        const next_url = try std.fmt.allocPrint(self.allocator, "{f}", .{resolved});
        errdefer self.allocator.free(next_url);
        if (next_url.len > max_request_url_bytes) return error.HttpRedirectLocationOversize;
        return next_url;
    }

    fn effectivePort(uri: std.Uri) ?u16 {
        if (uri.port) |port| return port;
        if (std.ascii.eqlIgnoreCase(uri.scheme, "http")) return 80;
        if (std.ascii.eqlIgnoreCase(uri.scheme, "https")) return 443;
        return null;
    }

    fn sameOrigin(base_url: []const u8, candidate_url: []const u8) !bool {
        const base_uri = try std.Uri.parse(base_url);
        const candidate_uri = try std.Uri.parse(candidate_url);
        if (!std.ascii.eqlIgnoreCase(base_uri.scheme, candidate_uri.scheme)) return false;
        if (effectivePort(base_uri) != effectivePort(candidate_uri)) return false;

        var base_host_buffer: [std.Io.net.HostName.max_len]u8 = undefined;
        var candidate_host_buffer: [std.Io.net.HostName.max_len]u8 = undefined;
        const base_host = try base_uri.getHost(&base_host_buffer);
        const candidate_host = try candidate_uri.getHost(&candidate_host_buffer);
        return std.ascii.eqlIgnoreCase(base_host.bytes, candidate_host.bytes);
    }

    fn retryAfterSeconds(head: std.http.Client.Response.Head) ?u32 {
        var headers = head.iterateHeaders();
        while (headers.next()) |header| {
            if (!std.ascii.eqlIgnoreCase(header.name, "retry-after")) continue;
            return std.fmt.parseInt(u32, header.value, 10) catch null;
        }
        return null;
    }

    fn requestScoped(
        self: *K8sClient,
        io: std.Io,
        method: std.http.Method,
        path: []const u8,
        body: ?[]const u8,
        format: WireFormat,
        options: ScopedRequestOptions,
        context: anytype,
        callback: anytype,
    ) !void {
        if (io.userdata != self.io.userdata or io.vtable != self.io.vtable)
            return error.IoMismatch;
        if (options.max_header_bytes == 0 or options.max_header_bytes > stream_header_capacity)
            return error.InvalidHeaderLimit;

        var current_url = try self.requestUrl(path, options.pretty);
        defer self.allocator.free(current_url);
        var current_method = method;
        var current_body = body;
        var redirects_remaining: u16 = 3;

        while (true) {
            var next_url: ?[]u8 = null;
            {
                const uri = try std.Uri.parse(current_url);
                var header_buffer: [4096]u8 = undefined;
                var headers = std.http.Client.Request.Headers{
                    .authorization = .omit,
                };
                if (current_body != null) {
                    headers.content_type = .{ .override = format.content_type };
                }

                var accept_header: [1]std.http.Header = undefined;
                var extra_headers: []const std.http.Header = &.{};
                if (format.accept) |accept| {
                    accept_header[0] = .{ .name = "Accept", .value = accept };
                    extra_headers = accept_header[0..1];
                }

                if (self.token) |token| {
                    if (try sameOrigin(self.api_server, current_url)) {
                        const auth_value = try std.fmt.bufPrint(&header_buffer, "Bearer {s}", .{token});
                        headers.authorization = .{ .override = auth_value };
                    }
                }

                var req = self.http_client.request(current_method, uri, .{
                    .redirect_behavior = .unhandled,
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

                if (!options.accept_compression) {
                    req.accept_encoding = @splat(false);
                    req.accept_encoding[@intFromEnum(std.http.ContentEncoding.identity)] = true;
                    req.headers.accept_encoding = .{ .override = "identity" };
                }

                if (current_body) |request_body| {
                    req.transfer_encoding = .{ .content_length = request_body.len };
                    var body_buffer: [8192]u8 = undefined;
                    var send_body = try req.sendBody(&body_buffer);
                    try send_body.writer.writeAll(request_body);
                    try send_body.end();
                } else {
                    try req.sendBodiless();
                }

                var response = req.receiveHead(&.{}) catch |err| {
                    if (err == error.ReadFailed) {
                        if (req.connection) |connection|
                            return connection.getReadError().?;
                    }
                    return err;
                };
                if (response.head.bytes.len > options.max_header_bytes)
                    return error.HttpHeadersOversize;

                if (response.head.status.class() == .redirect) {
                    if (redirects_remaining == 0) return error.TooManyHttpRedirects;
                    const location = response.head.location orelse
                        return error.HttpRedirectLocationMissing;

                    const changes_to_get = response.head.status == .see_other or
                        ((response.head.status == .moved_permanently or
                            response.head.status == .found) and current_method == .POST);
                    if (!changes_to_get and current_body != null)
                        return error.RedirectRequiresResend;

                    next_url = try self.resolveRedirect(current_url, location);
                    redirects_remaining -= 1;
                    if (changes_to_get) {
                        current_method = .GET;
                        current_body = null;
                    }
                } else {
                    const status = response.head.status;
                    const retry_after_seconds = retryAfterSeconds(response.head);
                    const content_type_copy: ?[]u8 = if (response.head.content_type) |content_type|
                        try self.allocator.dupe(u8, content_type)
                    else
                        null;
                    defer if (content_type_copy) |content_type|
                        self.allocator.free(content_type);

                    var transfer_buffer: [16384]u8 = undefined;
                    var decompress: std.http.Decompress = undefined;
                    var decompress_buffer: [std.compress.flate.max_window_len]u8 = undefined;
                    const reader = response.readerDecompressing(
                        &transfer_buffer,
                        &decompress,
                        &decompress_buffer,
                    );
                    callback(context, StreamResponseMeta{
                        .status = status,
                        .retry_after_seconds = retry_after_seconds,
                        .content_type = content_type_copy,
                    }, reader) catch |err| {
                        if (err == error.ReadFailed) {
                            if (response.bodyErr()) |body_err| return body_err;
                            switch (decompress) {
                                .flate => |flate| {
                                    if (flate.err) |decompress_err| {
                                        if (decompress_err != error.ReadFailed) return decompress_err;
                                    }
                                },
                                .zstd, .none => {},
                            }
                            if (req.connection) |connection| {
                                if (connection.stream_reader.err) |read_err| return read_err;
                            }
                        }
                        return err;
                    };
                    return;
                }
            }

            self.allocator.free(current_url);
            current_url = next_url.?;
        }
    }

    fn collectBufferedResponse(
        context: *BufferedResponseContext,
        meta: StreamResponseMeta,
        reader: *std.Io.Reader,
    ) anyerror!void {
        const self = context.client;
        if (meta.status.class() != .success) {
            const http_code: i64 = @intFromEnum(meta.status);
            if (context.err_out) |out| out.* = ApiError{ .code = http_code };

            var error_buffer = try std.ArrayList(u8).initCapacity(self.allocator, 4096);
            defer error_buffer.deinit(self.allocator);
            reader.appendRemaining(self.allocator, &error_buffer, .limited(65536)) catch |err| switch (err) {
                error.StreamTooLong => {},
                error.OutOfMemory => return error.OutOfMemory,
                else => {},
            };

            if (context.err_out) |out| {
                if (self.parseStatusJson(error_buffer.items, http_code)) |detail| out.* = detail;
            }
            return error.K8sApiError;
        }

        var body_buffer = try std.ArrayList(u8).initCapacity(self.allocator, 8192);
        defer body_buffer.deinit(self.allocator);
        try reader.appendRemaining(
            self.allocator,
            &body_buffer,
            .limited(self.max_response_size),
        );
        context.result = try body_buffer.toOwnedSlice(self.allocator);
    }

    /// Stream a GET response through a callback while its HTTP resources are alive.
    ///
    /// The callback must consume any body bytes it needs before returning. Redirects
    /// are followed up to three times, and bearer credentials are sent only when the
    /// resolved URL has the same scheme, host, and effective port as `api_server`.
    pub fn streamGet(
        self: *K8sClient,
        io: std.Io,
        path: []const u8,
        options: StreamGetOptions,
        context: anytype,
        callback: anytype,
    ) !void {
        return self.requestScoped(
            io,
            .GET,
            path,
            null,
            .json,
            .{
                .accept_compression = options.accept_compression,
                .max_header_bytes = options.max_header_bytes,
                .pretty = options.pretty,
            },
            context,
            callback,
        );
    }

    /// A single HTTP attempt with no retry. The retry wrappers call this.
    fn sendOnce(
        self: *K8sClient,
        method: std.http.Method,
        path: []const u8,
        body: ?[]const u8,
        format: WireFormat,
        err_out: ?*?ApiError,
    ) ![]u8 {
        var context: BufferedResponseContext = .{
            .client = self,
            .err_out = err_out,
        };
        try self.requestScoped(
            self.io,
            method,
            path,
            body,
            format,
            .{},
            &context,
            collectBufferedResponse,
        );
        return context.result.?;
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
