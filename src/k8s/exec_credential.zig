const std = @import("std");
const log = std.log.scoped(.klient);

/// ExecCredential configuration from kubeconfig
pub const ExecConfig = struct {
    /// Command to execute
    command: []const u8,

    /// Arguments to pass to command
    args: ?[][]const u8 = null,

    /// Environment variables to set
    env: ?[]EnvVar = null,

    /// API version for credential response
    apiVersion: []const u8 = "client.authentication.k8s.io/v1",

    /// Install hint for missing command
    installHint: ?[]const u8 = null,

    /// Provide cluster info to command
    provideClusterInfo: bool = false,
};

pub const EnvVar = struct {
    name: []const u8,
    value: []const u8,
};

/// ExecCredential response from external command
pub const ExecCredential = struct {
    apiVersion: []const u8,
    kind: []const u8 = "ExecCredential",
    status: ?Status = null,
    spec: ?std.json.Value = null,

    pub const Status = struct {
        token: ?[]const u8 = null,
        clientCertificateData: ?[]const u8 = null,
        clientKeyData: ?[]const u8 = null,
        expirationTimestamp: ?[]const u8 = null,
    };
};

/// Execute credential plugin and get authentication token.
///
/// Returns a Parsed(ExecCredential) that owns the backing memory for all
/// string fields. Caller MUST call .deinit() when done.
///
/// Previous implementation returned ExecCredential directly after freeing
/// the parse arena — a use-after-free bug since all string fields pointed
/// into the freed arena.
pub fn executeCredentialPlugin(
    allocator: std.mem.Allocator,
    io: std.Io,
    config: ExecConfig,
) !std.json.Parsed(ExecCredential) {
    // Build command arguments
    var cmd_args = std.ArrayList([]const u8).empty;
    defer cmd_args.deinit(allocator);

    try cmd_args.append(allocator, config.command);

    if (config.args) |args| {
        for (args) |arg| {
            try cmd_args.append(allocator, arg);
        }
    }

    // Merge config.env onto the inherited process environment when specified.
    var merged_env: ?std.process.Environ.Map = null;
    defer if (merged_env) |*m| m.deinit();
    if (config.env) |envs| {
        if (envs.len > 0) {
            var env_map = std.process.Environ.Map.init(allocator);
            errdefer env_map.deinit();

            var i: usize = 0;
            while (std.c.environ[i]) |entry_ptr| : (i += 1) {
                const entry = std.mem.span(entry_ptr);
                const eq = std.mem.indexOfScalar(u8, entry, '=') orelse continue;
                const key = entry[0..eq];
                if (!std.process.Environ.Map.validateKeyForPut(key)) continue;
                try env_map.put(key, entry[eq + 1 ..]);
            }
            for (envs) |ev| {
                if (!std.process.Environ.Map.validateKeyForPut(ev.name)) return error.InvalidEnvVarName;
                try env_map.put(ev.name, ev.value);
            }
            merged_env = env_map;
        }
    }

    // stdin is closed: an interactive plugin must not block on the caller's terminal.
    // stderr is piped and drained concurrently with stdout, as std.process.run does —
    // a pipe nobody drains deadlocks once the plugin writes more than the pipe buffer
    // (~64 KiB, easily reached by `aws eks get-token` warnings). Only its tail is kept,
    // for the failure log.
    var child = try std.process.spawn(io, .{
        .argv = cmd_args.items,
        .environ_map = if (merged_env) |*m| m else null,
        .stdin = .ignore,
        .stdout = .pipe,
        .stderr = .pipe,
    });
    // Kills the plugin if we bail out early (oversized output, read error); after a
    // successful wait() it only releases resources.
    defer child.kill(io);

    var multi_reader_buffer: std.Io.File.MultiReader.Buffer(2) = undefined;
    var multi_reader: std.Io.File.MultiReader = undefined;
    multi_reader.init(allocator, io, multi_reader_buffer.toStreams(), &.{ child.stdout.?, child.stderr.? });
    defer multi_reader.deinit();
    const stdout_reader = multi_reader.reader(0);
    const stderr_reader = multi_reader.reader(1);

    while (multi_reader.fill(64, .none)) |_| {
        if (stdout_reader.bufferedLen() > max_plugin_stdout_bytes) return error.StreamTooLong;
        const stderr_len = stderr_reader.bufferedLen();
        if (stderr_len > max_plugin_stderr_bytes) stderr_reader.toss(stderr_len - max_plugin_stderr_bytes);
    } else |err| switch (err) {
        error.EndOfStream => {},
        else => |e| return e,
    }
    try multi_reader.checkAnyError();

    const term = try child.wait(io);

    if (term != .exited or term.exited != 0) {
        const stderr_tail = std.mem.trim(u8, stderr_reader.buffered(), &std.ascii.whitespace);
        if (stderr_tail.len > 0) {
            var scrubbed_buf: [max_plugin_stderr_bytes]u8 = undefined;
            const scrubbed = scrubSecrets(&scrubbed_buf, stderr_tail);
            log.warn("credential plugin stderr: {s}", .{scrubbed});
        }
        if (config.installHint) |hint| {
            log.warn("credential plugin failed; install hint: {s}", .{hint});
        }
        return error.CredentialPluginFailed;
    }

    // Parse JSON response — caller owns the Parsed arena
    const parsed = try std.json.parseFromSlice(
        ExecCredential,
        allocator,
        stdout_reader.buffered(),
        .{ .ignore_unknown_fields = true, .allocate = .alloc_always },
    );
    errdefer parsed.deinit();

    // The token is sent verbatim as an Authorization header value.
    if (parsed.value.status) |status| {
        if (status.token) |token| {
            for (token) |byte| {
                if (byte < 0x20 or byte == 0x7f) return error.InvalidCredentialToken;
            }
        }
    }
    return parsed;
}

const max_plugin_stdout_bytes = 10 * 1024 * 1024;
const max_plugin_stderr_bytes = 4 * 1024;

/// Copy `input` into `out`, redacting raw bearer tokens, JWTs, and common
/// token fields so credential plugin stderr logs never leak secrets.
pub fn scrubSecrets(out: []u8, input: []const u8) []const u8 {
    var w: usize = 0;
    var i: usize = 0;
    while (i < input.len and w < out.len) {
        // Redact "Bearer <token>" (case-insensitive)
        if (i + 7 <= input.len and std.ascii.eqlIgnoreCase(input[i .. i + 7], "bearer ")) {
            w += copySlice(out[w..], input[i .. i + 7]);
            i += 7;
            while (i < input.len and (input[i] == ' ' or input[i] == '\t')) : (i += 1) {
                w += copySlice(out[w..], input[i .. i + 1]);
            }
            const start = i;
            while (i < input.len and !isTokenDelimiter(input[i])) : (i += 1) {}
            if (i > start) w += copySlice(out[w..], "[REDACTED]");
            continue;
        }
        // Redact JSON `"token":"..."` / `"access_token":"..."` / `"id_token":"..."`
        if (matchJsonTokenField(input, i)) |m| {
            w += copySlice(out[w..], input[i..m.value_start]);
            w += copySlice(out[w..], "[REDACTED]");
            i = m.value_end;
            continue;
        }
        // Redact `token=<value>` / `access_token=<value>` / `id_token=<value>`
        if (matchKvTokenField(input, i)) |m| {
            w += copySlice(out[w..], input[i..m.value_start]);
            w += copySlice(out[w..], "[REDACTED]");
            i = m.value_end;
            continue;
        }
        // Redact JWTs (`eyJ<b64>.<b64>.<b64>`)
        if (i + 4 <= input.len and std.mem.startsWith(u8, input[i..], "eyJ")) {
            if (matchJwtEnd(input, i)) |end| {
                w += copySlice(out[w..], "[REDACTED]");
                i = end;
                continue;
            }
        }
        out[w] = input[i];
        w += 1;
        i += 1;
    }
    return out[0..w];
}

const TokenSpan = struct { value_start: usize, value_end: usize };

fn copySlice(dst: []u8, src: []const u8) usize {
    const n = @min(dst.len, src.len);
    @memcpy(dst[0..n], src[0..n]);
    return n;
}

fn isTokenDelimiter(b: u8) bool {
    return b <= 0x20 or b == 0x7f or b == '"' or b == '\'' or b == ',' or b == ';' or b == ')' or b == ']' or b == '}';
}

fn isIdentChar(b: u8) bool {
    return std.ascii.isAlphanumeric(b) or b == '_' or b == '-';
}

fn isJwtChar(b: u8) bool {
    return std.ascii.isAlphanumeric(b) or b == '-' or b == '_' or b == '+' or b == '/' or b == '=';
}

fn matchJwtEnd(input: []const u8, start: usize) ?usize {
    var i = start;
    var dots: usize = 0;
    var seg_len: usize = 0;
    while (i < input.len) : (i += 1) {
        const b = input[i];
        if (b == '.') {
            if (seg_len < 4) return null;
            dots += 1;
            seg_len = 0;
            if (dots > 2) return null;
        } else if (isJwtChar(b)) {
            seg_len += 1;
        } else {
            break;
        }
    }
    if (dots == 2 and i - start >= 20) return i;
    return null;
}

fn matchJsonTokenField(input: []const u8, start: usize) ?TokenSpan {
    const keys = [_][]const u8{ "\"token\"", "\"access_token\"", "\"id_token\"", "\"refresh_token\"" };
    for (keys) |key| {
        if (start + key.len >= input.len) continue;
        if (!std.ascii.eqlIgnoreCase(input[start .. start + key.len], key)) continue;
        var i = start + key.len;
        while (i < input.len and (input[i] == ' ' or input[i] == '\t')) : (i += 1) {}
        if (i >= input.len or input[i] != ':') continue;
        i += 1;
        while (i < input.len and (input[i] == ' ' or input[i] == '\t')) : (i += 1) {}
        if (i >= input.len or input[i] != '"') continue;
        i += 1;
        const val_start = i;
        while (i < input.len and input[i] != '"') : (i += 1) {
            if (input[i] == '\\' and i + 1 < input.len) i += 1;
        }
        if (i > val_start) return .{ .value_start = val_start, .value_end = i };
    }
    return null;
}

fn matchKvTokenField(input: []const u8, start: usize) ?TokenSpan {
    if (start > 0 and isIdentChar(input[start - 1])) return null;
    const keys = [_][]const u8{ "token=", "access_token=", "id_token=", "refresh_token=" };
    for (keys) |key| {
        if (start + key.len >= input.len) continue;
        if (!std.ascii.eqlIgnoreCase(input[start .. start + key.len], key)) continue;
        const val_start = start + key.len;
        var i = val_start;
        while (i < input.len and !isTokenDelimiter(input[i])) : (i += 1) {}
        if (i > val_start) return .{ .value_start = val_start, .value_end = i };
    }
    return null;
}

/// Common exec credential plugin configurations
/// AWS EKS credential plugin (aws-iam-authenticator or aws eks get-token)
pub fn awsEksConfig(allocator: std.mem.Allocator, cluster_name: []const u8) !ExecConfig {
    var args = std.ArrayList([]const u8).empty;
    try args.append(allocator, "eks");
    try args.append(allocator, "get-token");
    try args.append(allocator, "--cluster-name");
    try args.append(allocator, cluster_name);

    return ExecConfig{
        .command = "aws",
        .args = try args.toOwnedSlice(allocator),
        .apiVersion = "client.authentication.k8s.io/v1beta1",
        .installHint = "Install AWS CLI: https://aws.amazon.com/cli/",
    };
}

/// GCP GKE credential plugin (gke-gcloud-auth-plugin or gcloud)
pub fn gcpGkeConfig(allocator: std.mem.Allocator) !ExecConfig {
    _ = allocator;
    return ExecConfig{
        .command = "gke-gcloud-auth-plugin",
        .args = null,
        .apiVersion = "client.authentication.k8s.io/v1beta1",
        .installHint = "Install gke-gcloud-auth-plugin: https://cloud.google.com/kubernetes-engine/docs/how-to/cluster-access-for-kubectl#install_plugin",
    };
}

/// Azure AKS credential plugin (kubelogin)
pub fn azureAksConfig(allocator: std.mem.Allocator, server_id: []const u8) !ExecConfig {
    var args = std.ArrayList([]const u8).empty;
    try args.append(allocator, "get-token");
    try args.append(allocator, "--server-id");
    try args.append(allocator, server_id);
    try args.append(allocator, "--login");
    try args.append(allocator, "azurecli");

    var envs = std.ArrayList(EnvVar).empty;
    try envs.append(allocator, .{
        .name = "AAD_SERVICE_PRINCIPAL_CLIENT_ID",
        .value = "",
    });

    return ExecConfig{
        .command = "kubelogin",
        .args = try args.toOwnedSlice(allocator),
        .env = try envs.toOwnedSlice(allocator),
        .apiVersion = "client.authentication.k8s.io/v1beta1",
        .installHint = "Install kubelogin: https://azure.github.io/kubelogin/",
    };
}

/// Generic OIDC credential plugin
pub fn oidcConfig(
    allocator: std.mem.Allocator,
    issuer_url: []const u8,
    client_id: []const u8,
) !ExecConfig {
    var args = std.ArrayList([]const u8).empty;
    try args.append(allocator, "oidc-login");
    try args.append(allocator, "get-token");
    try args.append(allocator, "--oidc-issuer-url");
    try args.append(allocator, issuer_url);
    try args.append(allocator, "--oidc-client-id");
    try args.append(allocator, client_id);

    return ExecConfig{
        .command = "kubectl",
        .args = try args.toOwnedSlice(allocator),
        .apiVersion = "client.authentication.k8s.io/v1beta1",
        .installHint = "Install kubectl oidc-login plugin",
    };
}
