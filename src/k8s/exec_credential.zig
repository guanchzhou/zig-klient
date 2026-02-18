const std = @import("std");

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
    config: ExecConfig,
) !std.json.Parsed(ExecCredential) {
    // Build command arguments
    var cmd_args = std.ArrayListUnmanaged([]const u8){};
    defer cmd_args.deinit(allocator);

    try cmd_args.append(allocator, config.command);

    if (config.args) |args| {
        for (args) |arg| {
            try cmd_args.append(allocator, arg);
        }
    }

    // Execute command
    var child = std.process.Child.init(cmd_args.items, allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    try child.spawn();

    // Read stdout
    const stdout = try child.stdout.?.readToEndAlloc(allocator, 10 * 1024 * 1024);
    defer allocator.free(stdout);

    // Wait for completion
    const term = try child.wait();

    if (term != .Exited or term.Exited != 0) {
        if (config.installHint) |hint| {
            std.debug.print("Credential plugin failed. Install hint: {s}\n", .{hint});
        }
        return error.CredentialPluginFailed;
    }

    // Parse JSON response — caller owns the Parsed arena
    return std.json.parseFromSlice(
        ExecCredential,
        allocator,
        stdout,
        .{ .ignore_unknown_fields = true, .allocate = .alloc_always },
    );
}

/// Common exec credential plugin configurations

/// AWS EKS credential plugin (aws-iam-authenticator or aws eks get-token)
pub fn awsEksConfig(allocator: std.mem.Allocator, cluster_name: []const u8) !ExecConfig {
    var args = std.ArrayListUnmanaged([]const u8){};
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
    var args = std.ArrayListUnmanaged([]const u8){};
    try args.append(allocator, "get-token");
    try args.append(allocator, "--server-id");
    try args.append(allocator, server_id);
    try args.append(allocator, "--login");
    try args.append(allocator, "azurecli");

    var envs = std.ArrayListUnmanaged(EnvVar){};
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
    var args = std.ArrayListUnmanaged([]const u8){};
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
