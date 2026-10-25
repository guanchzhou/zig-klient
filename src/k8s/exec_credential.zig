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
    var cmd_args = std.ArrayListUnmanaged([]const u8).empty;
    defer cmd_args.deinit(allocator);

    try cmd_args.append(allocator, config.command);

    if (config.args) |args| {
        for (args) |arg| {
            try cmd_args.append(allocator, arg);
        }
    }

    // Zig 0.16: std.process.Child.init was removed. Use std.process.spawn.
    //
    // NOTE: config.env (kubeconfig-scoped plugin env vars) is intentionally not
    // applied yet — the child inherits the parent environment only. The k8s spec
    // ADDS these to the parent env, but SpawnOptions.environ_map *replaces* the env,
    // and Zig 0.16 exposes no public accessor for the live process environ to seed a
    // merged Map from a library context. Replacing the env with only config.env would
    // drop PATH/HOME and break the plugins, so we inherit until a parent-env accessor
    // is available. Plugins that need extra env can be invoked with it pre-set.
    //
    // stdin is closed: an interactive plugin must not block on the caller's terminal.
    // stderr is piped and drained concurrently with stdout, as std.process.run does —
    // a pipe nobody drains deadlocks once the plugin writes more than the pipe buffer
    // (~64 KiB, easily reached by `aws eks get-token` warnings). Only its tail is kept,
    // for the failure log.
    var child = try std.process.spawn(io, .{
        .argv = cmd_args.items,
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
        if (stderr_tail.len > 0) log.warn("credential plugin stderr: {s}", .{stderr_tail});
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

/// Common exec credential plugin configurations
/// AWS EKS credential plugin (aws-iam-authenticator or aws eks get-token)
pub fn awsEksConfig(allocator: std.mem.Allocator, cluster_name: []const u8) !ExecConfig {
    var args = std.ArrayListUnmanaged([]const u8).empty;
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
    var args = std.ArrayListUnmanaged([]const u8).empty;
    try args.append(allocator, "get-token");
    try args.append(allocator, "--server-id");
    try args.append(allocator, server_id);
    try args.append(allocator, "--login");
    try args.append(allocator, "azurecli");

    var envs = std.ArrayListUnmanaged(EnvVar).empty;
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
    var args = std.ArrayListUnmanaged([]const u8).empty;
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
