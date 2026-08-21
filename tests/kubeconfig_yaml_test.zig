const std = @import("std");
const klient = @import("klient");

test "KubeconfigParser - YAML parsing" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;

    const yaml_config =
        \\apiVersion: v1
        \\kind: Config
        \\current-context: test-context
        \\clusters:
        \\- name: test-cluster
        \\  cluster:
        \\    server: https://kubernetes.example.com:6443
        \\    certificate-authority-data: Y2EtZGF0YQ==
        \\contexts:
        \\- name: test-context
        \\  context:
        \\    cluster: test-cluster
        \\    user: test-user
        \\    namespace: default
        \\users:
        \\- name: test-user
        \\  user:
        \\    token: my-bearer-token
    ;

    // Write to temp file
    var temp_dir = std.testing.tmpDir(.{});
    defer temp_dir.cleanup();

    try temp_dir.dir.writeFile(io, .{ .sub_path = "config", .data = yaml_config });

    // Get temp file path
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const path_len = try temp_dir.dir.realPathFile(io, "config", &path_buf);
    const temp_path = path_buf[0..path_len];

    // Parse kubeconfig
    var parser = klient.KubeconfigParser.init(allocator, io);
    var config = try parser.loadFromPath(temp_path);
    defer config.deinit(allocator);

    // Verify parsed data
    try std.testing.expectEqualStrings("test-context", config.current_context);
    try std.testing.expectEqual(@as(usize, 1), config.clusters.len);
    try std.testing.expectEqual(@as(usize, 1), config.contexts.len);
    try std.testing.expectEqual(@as(usize, 1), config.users.len);

    // Verify cluster
    const cluster = config.clusters[0];
    try std.testing.expectEqualStrings("test-cluster", cluster.name);
    try std.testing.expectEqualStrings("https://kubernetes.example.com:6443", cluster.server);
    try std.testing.expectEqualStrings("Y2EtZGF0YQ==", cluster.certificate_authority_data.?);

    // Verify context
    const context = config.contexts[0];
    try std.testing.expectEqualStrings("test-context", context.name);
    try std.testing.expectEqualStrings("test-cluster", context.cluster);
    try std.testing.expectEqualStrings("test-user", context.user);
    try std.testing.expectEqualStrings("default", context.namespace.?);

    // Verify user
    const user = config.users[0];
    try std.testing.expectEqualStrings("test-user", user.name);
    try std.testing.expectEqualStrings("my-bearer-token", user.token.?);
}

test "KubeconfigParser - Get methods" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;

    const yaml_config =
        \\apiVersion: v1
        \\kind: Config
        \\current-context: prod-context
        \\clusters:
        \\- name: prod-cluster
        \\  cluster:
        \\    server: https://prod.example.com:6443
        \\contexts:
        \\- name: prod-context
        \\  context:
        \\    cluster: prod-cluster
        \\    user: prod-user
        \\users:
        \\- name: prod-user
        \\  user:
        \\    client-certificate-data: Y2VydC1kYXRh
        \\    client-key-data: a2V5LWRhdGE=
    ;

    var temp_dir = std.testing.tmpDir(.{});
    defer temp_dir.cleanup();

    try temp_dir.dir.writeFile(io, .{ .sub_path = "config", .data = yaml_config });

    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const path_len = try temp_dir.dir.realPathFile(io, "config", &path_buf);
    const temp_path = path_buf[0..path_len];

    var parser = klient.KubeconfigParser.init(allocator, io);
    var config = try parser.loadFromPath(temp_path);
    defer config.deinit(allocator);

    // Test getCurrentContext
    const current_ctx = config.getCurrentContext().?;
    try std.testing.expectEqualStrings("prod-context", current_ctx.name);
    try std.testing.expectEqualStrings("prod-cluster", current_ctx.cluster);

    // Test getClusterByName
    const cluster = config.getClusterByName("prod-cluster").?;
    try std.testing.expectEqualStrings("https://prod.example.com:6443", cluster.server);

    // Test getUserByName
    const user = config.getUserByName("prod-user").?;
    try std.testing.expectEqualStrings("Y2VydC1kYXRh", user.client_certificate_data.?);
    try std.testing.expectEqualStrings("a2V5LWRhdGE=", user.client_key_data.?);
}

// --- Baseline coverage added 2026-08-21 -------------------------------------
// These pin the observable behaviour of the hand-written YAML walkers in
// src/k8s/kubeconfig_yaml.zig so a parser swap can be proven equivalent.
// Gaps they close: certificate-authority (path form), insecure-skip-tls-verify
// (bool), client-certificate/client-key (path forms), username/password,
// the whole exec block, multi-entry lists, and getContextByName.

/// Parse `src` as a kubeconfig via a temp file. The returned Kubeconfig owns
/// all its memory (every field is duped), so the temp dir can go away first.
fn parseConfig(allocator: std.mem.Allocator, src: []const u8) !klient.Kubeconfig {
    const io = std.testing.io;
    var temp_dir = std.testing.tmpDir(.{});
    defer temp_dir.cleanup();

    try temp_dir.dir.writeFile(io, .{ .sub_path = "config", .data = src });
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const path_len = try temp_dir.dir.realPathFile(io, "config", &path_buf);

    var parser = klient.KubeconfigParser.init(allocator, io);
    return parser.loadFromPath(path_buf[0..path_len]);
}

test "kubeconfig - all cluster fields incl. CA path and insecure bool" {
    const allocator = std.testing.allocator;
    var config = try parseConfig(allocator,
        \\apiVersion: v1
        \\kind: Config
        \\current-context: c
        \\clusters:
        \\- name: full
        \\  cluster:
        \\    server: https://a.example.com:6443
        \\    certificate-authority: /etc/ssl/ca.crt
        \\    insecure-skip-tls-verify: true
        \\- name: insecure-false
        \\  cluster:
        \\    server: https://b.example.com:6443
        \\    insecure-skip-tls-verify: false
        \\- name: bare
        \\  cluster:
        \\    server: https://c.example.com:6443
        \\contexts:
        \\- name: c
        \\  context:
        \\    cluster: full
        \\    user: u
        \\users:
        \\- name: u
        \\  user:
        \\    token: t
    );
    defer config.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 3), config.clusters.len);

    const full = config.getClusterByName("full").?;
    try std.testing.expectEqualStrings("/etc/ssl/ca.crt", full.certificate_authority.?);
    // CA path and CA data are distinct fields; only one was set here.
    try std.testing.expect(full.certificate_authority_data == null);

    // Regression guard: insecure-skip-tls-verify used to be silently dropped.
    // The old hand-written parseCluster accepted only a `.boolean` Value, but
    // zig-yaml never produced one when parsing (it built `.boolean` solely on
    // the stringify path), so `true` arrived as a scalar and hit `else => {}`.
    // Typed decoding resolves it. Must stay non-null.
    try std.testing.expectEqual(true, full.insecure_skip_tls_verify.?);

    // false must round-trip as false, not as null-because-falsy.
    const ins_false = config.getClusterByName("insecure-false").?;
    try std.testing.expectEqual(false, ins_false.insecure_skip_tls_verify.?);

    // Absent optionals stay null.
    const bare = config.getClusterByName("bare").?;
    try std.testing.expect(bare.certificate_authority == null);
    try std.testing.expect(bare.insecure_skip_tls_verify == null);
}

test "kubeconfig - all user auth field shapes" {
    const allocator = std.testing.allocator;
    var config = try parseConfig(allocator,
        \\apiVersion: v1
        \\kind: Config
        \\current-context: c
        \\clusters:
        \\- name: cl
        \\  cluster:
        \\    server: https://a.example.com:6443
        \\contexts:
        \\- name: c
        \\  context:
        \\    cluster: cl
        \\    user: certs
        \\users:
        \\- name: certs
        \\  user:
        \\    client-certificate: /home/me/.certs/client.crt
        \\    client-key: /home/me/.certs/client.key
        \\- name: basic
        \\  user:
        \\    username: admin
        \\    password: s3cr3t
        \\- name: bare
        \\  user:
        \\    token: only-a-token
    );
    defer config.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 3), config.users.len);

    // Path forms are separate fields from the *-data forms.
    const certs = config.getUserByName("certs").?;
    try std.testing.expectEqualStrings("/home/me/.certs/client.crt", certs.client_certificate.?);
    try std.testing.expectEqualStrings("/home/me/.certs/client.key", certs.client_key.?);
    try std.testing.expect(certs.client_certificate_data == null);
    try std.testing.expect(certs.client_key_data == null);

    const basic = config.getUserByName("basic").?;
    try std.testing.expectEqualStrings("admin", basic.username.?);
    try std.testing.expectEqualStrings("s3cr3t", basic.password.?);

    const bare = config.getUserByName("bare").?;
    try std.testing.expectEqualStrings("only-a-token", bare.token.?);
    try std.testing.expect(bare.username == null);
    try std.testing.expect(bare.exec == null);
}

test "kubeconfig - exec credential plugin block" {
    const allocator = std.testing.allocator;
    var config = try parseConfig(allocator,
        \\apiVersion: v1
        \\kind: Config
        \\current-context: c
        \\clusters:
        \\- name: cl
        \\  cluster:
        \\    server: https://a.example.com:6443
        \\contexts:
        \\- name: c
        \\  context:
        \\    cluster: cl
        \\    user: eks
        \\users:
        \\- name: eks
        \\  user:
        \\    exec:
        \\      apiVersion: client.authentication.k8s.io/v1beta1
        \\      command: aws
        \\      args:
        \\      - --region
        \\      - eu-north-1
        \\      - eks
        \\      - get-token
        \\- name: noargs
        \\  user:
        \\    exec:
        \\      command: echo
    );
    defer config.deinit(allocator);

    const eks = config.getUserByName("eks").?;
    const exec = eks.exec.?;
    try std.testing.expectEqualStrings("aws", exec.command.?);
    // NOTE: exec.apiVersion is camelCase in kubeconfig while sibling keys are
    // kebab-case; it maps onto the snake_case field api_version.
    try std.testing.expectEqualStrings("client.authentication.k8s.io/v1beta1", exec.api_version.?);

    const args = exec.args.?;
    try std.testing.expectEqual(@as(usize, 4), args.len);
    try std.testing.expectEqualStrings("--region", args[0]);
    try std.testing.expectEqualStrings("eu-north-1", args[1]);
    try std.testing.expectEqualStrings("eks", args[2]);
    try std.testing.expectEqualStrings("get-token", args[3]);

    // An exec block with no args must yield exec != null, args == null.
    const noargs = config.getUserByName("noargs").?;
    try std.testing.expectEqualStrings("echo", noargs.exec.?.command.?);
    try std.testing.expect(noargs.exec.?.args == null);
}

test "kubeconfig - multiple contexts and lookup accessors" {
    const allocator = std.testing.allocator;
    var config = try parseConfig(allocator,
        \\apiVersion: v1
        \\kind: Config
        \\current-context: staging
        \\clusters:
        \\- name: prod-cluster
        \\  cluster:
        \\    server: https://prod.example.com:6443
        \\- name: staging-cluster
        \\  cluster:
        \\    server: https://staging.example.com:6443
        \\contexts:
        \\- name: prod
        \\  context:
        \\    cluster: prod-cluster
        \\    user: prod-user
        \\    namespace: production
        \\- name: staging
        \\  context:
        \\    cluster: staging-cluster
        \\    user: staging-user
        \\users:
        \\- name: prod-user
        \\  user:
        \\    token: prod-token
        \\- name: staging-user
        \\  user:
        \\    token: staging-token
    );
    defer config.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 2), config.clusters.len);
    try std.testing.expectEqual(@as(usize, 2), config.contexts.len);
    try std.testing.expectEqual(@as(usize, 2), config.users.len);

    // current-context selects the second entry, not just the first.
    const current = config.getCurrentContext().?;
    try std.testing.expectEqualStrings("staging", current.name);
    try std.testing.expectEqualStrings("staging-cluster", current.cluster);
    try std.testing.expect(current.namespace == null);

    const prod = config.getContextByName("prod").?;
    try std.testing.expectEqualStrings("production", prod.namespace.?);
    try std.testing.expectEqualStrings("prod-user", prod.user);

    try std.testing.expect(config.getContextByName("nope") == null);
    try std.testing.expect(config.getClusterByName("nope") == null);
    try std.testing.expect(config.getUserByName("nope") == null);
}

test "kubeconfig - parses the developer's real ~/.kube/config" {
    // Skipped when there is no kubeconfig (CI), so this is safe to keep.
    // Real configs carry many keys we do not model (preferences, extensions,
    // proxy-url, tls-server-name, exec.env, interactiveMode...) -- the case a
    // synthetic fixture cannot cover. Only "no config present" is skipped; a
    // genuine parse failure still fails the test.
    const allocator = std.testing.allocator;
    const io = std.testing.io;

    var parser = klient.KubeconfigParser.init(allocator, io);
    var config = parser.load() catch |err| switch (err) {
        error.FileNotFound, error.HomeNotFound, error.AccessDenied => return error.SkipZigTest,
        else => return err,
    };
    defer config.deinit(allocator);

    try std.testing.expect(config.contexts.len > 0);

    // current-context may legitimately be "" (this developer's config is), in
    // which case it resolves to null. Only a NON-empty current-context is
    // required to name a real context.
    if (config.current_context.len > 0) {
        const current = config.getCurrentContext() orelse return error.CurrentContextUnresolved;
        try std.testing.expect(config.getClusterByName(current.cluster) != null);
        try std.testing.expect(config.getUserByName(current.user) != null);
    }

    // Every entry must be structurally complete: non-empty names, non-empty
    // server URLs, and every context pointing at a cluster and user that exist.
    for (config.clusters) |c| {
        try std.testing.expect(c.name.len > 0);
        try std.testing.expect(c.server.len > 0);
    }
    for (config.contexts) |c| {
        try std.testing.expect(c.name.len > 0);
        try std.testing.expect(config.getClusterByName(c.cluster) != null);
        try std.testing.expect(config.getUserByName(c.user) != null);
    }
}
