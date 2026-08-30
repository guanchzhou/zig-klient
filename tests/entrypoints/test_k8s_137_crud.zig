// Live integration test for Kubernetes 1.37 GA kinds.
// Requires a Kubernetes >= 1.37 API server. Exercises list -> create -> get ->
// delete through zig-klient for DeviceTaintRule, ClusterTrustBundle, and
// StorageVersionMigration v1.
//
// PodCertificateRequest is not created here: the apiserver requires a real
// pod/node/service-account UID plus a kubelet-shaped PKCS#10 stub.
//
// Connects via `kubectl proxy` (default http://127.0.0.1:8080). Run first:
//     kubectl proxy --port=8080
const std = @import("std");
const klient = @import("klient");

const NAME = "zig-klient-probe";

// Signer-less ClusterTrustBundle PEM. A real X.509 CA (CN=zig-klient-probe,
// notBefore=2026-08-30, notAfter=2036-08-27). The apiserver rejects placeholder
// PEMs that do not parse as certificates.
const TRUST_BUNDLE =
    \\-----BEGIN CERTIFICATE-----
    \\MIIDJzCCAg+gAwIBAgIUbHUi9o6JnMJALFeF7MTuAIY7y7UwDQYJKoZIhvcNAQEL
    \\BQAwGzEZMBcGA1UEAwwQemlnLWtsaWVudC1wcm9iZTAeFw0yNjA4MzAxMDI5MjZa
    \\Fw0zNjA4MjcxMDI5MjZaMBsxGTAXBgNVBAMMEHppZy1rbGllbnQtcHJvYmUwggEi
    \\MA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQClgRBq3XvzfQuet0nGFSEU07QM
    \\jSjpRxopFkooKhmHjo1ADQTGtLIGBwVKCM/zJ4XITwlLrfOLOt5f3vM/ljXzdl6J
    \\2ELShkLNaDYPLcdSlmC2GwA2iZlmCSD799I2bJrLvjYjBSbekZyLSHto8TDvMRlF
    \\T+b80Er6RoYlEYVs79U0lsmB3/iW2ZHIHIx9IR0kxgpO+OGH3cu6bpTEU4Bn3JlZ
    \\3/zPCJYZZ3ZleUa+lBC+Q6B37Q2RI5CyjSSlBqZFGnDsBOhcEwrpUqcfT3HwcGFw
    \\W0p+zj9SiCI9CjoDfUXESNf6u6734bGskWb5U9afo6Mju4A9/72xFgREa95JAgMB
    \\AAGjYzBhMB0GA1UdDgQWBBQhE/WX9cu24jBtU7eaHrfwvTbEfzAfBgNVHSMEGDAW
    \\gBQhE/WX9cu24jBtU7eaHrfwvTbEfzAPBgNVHRMBAf8EBTADAQH/MA4GA1UdDwEB
    \\/wQEAwIBBjANBgkqhkiG9w0BAQsFAAOCAQEApNtLI76ulatWyVPbq7iEAr0CC9ic
    \\DS73O1dSt4qXHo8LGX7wm43si7M5fm+AACYly1+NgsoMCi8LkM0wr7uoxHD9qka3
    \\U6C+wBYLPm6MVcORhOFado2tixwotD+0LyN3Fd/MLzUvZk6T0SN2VrxN/+r9aTPQ
    \\hZCE67QnIUCKvkqftdUWw9hdTt0QxJ3Q7T3LPSTvae2ej1HQ103JRTXL2AZa6PtQ
    \\Ks15ZMzB76Tp4Uta6FCk2z2YLKpdpEHqYxUKxSzGpMAFAiPw2Jh3qvkdAvflpV0x
    \\Qwq9VUlvAt2c1tnqZ6ASq4rsn7gfrdmpWehf42quv5g/vGzb2FAAo4nyLg==
    \\-----END CERTIFICATE-----
    \\
;

fn dumpErr(kind: []const u8, err: anyerror, api_err: ?klient.K8sClient.ApiError) void {
    if (api_err) |e| {
        std.debug.print("  {s} failed: {s} code={?d} reason={s} message={s}\n", .{
            kind,
            @errorName(err),
            e.code,
            e.reason orelse "(none)",
            e.message orelse "(none)",
        });
    } else {
        std.debug.print("  {s} failed: {s}\n", .{ kind, @errorName(err) });
    }
}

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var threaded = std.Io.Threaded.init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  Test: K8s 1.37 GA kinds CRUD (zig-klient)\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n\n", .{});

    var client = try klient.K8sClient.init(allocator, io, .{
        .server = "http://127.0.0.1:8080",
        .namespace = "default",
    });
    defer client.deinit();
    std.debug.print("🔌 Connected — API server: {s}\n\n", .{client.api_server});

    try roundTripDeviceTaintRule(&client);
    try roundTripClusterTrustBundle(&client);
    try roundTripStorageVersionMigration(&client, allocator);

    std.debug.print("\n═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  ✅ 1.37 GA kinds CRUD round-trip succeeded\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
}

fn roundTripDeviceTaintRule(client: *klient.K8sClient) !void {
    std.debug.print("— DeviceTaintRule (resource.k8s.io/v1) —\n", .{});
    var api_err: ?klient.K8sClient.ApiError = null;
    defer if (api_err) |*e| e.deinit(client.allocator);

    var rules = klient.DeviceTaintRules.init(client);
    rules.client.error_sink = &api_err;

    {
        const list = rules.client.list(null) catch |err| {
            dumpErr("list", err, api_err);
            return err;
        };
        defer list.deinit();
        std.debug.print("  list: {} existing\n", .{list.value.items.len});
    }

    const rule = klient.DeviceTaintRule{
        .apiVersion = "resource.k8s.io/v1",
        .kind = "DeviceTaintRule",
        .metadata = .{ .name = NAME },
        .spec = .{
            .deviceSelector = .{ .driver = "zig-klient.example.com", .pool = null, .device = null },
            .taint = .{ .key = "zig-klient.example.com/probe", .value = "test", .effect = "NoSchedule" },
        },
    };
    {
        const created = rules.client.create(rule, null) catch |err| {
            dumpErr("create", err, api_err);
            return err;
        };
        defer created.deinit();
        std.debug.print("  create: {s}\n", .{created.value.metadata.name});
    }

    {
        const got = rules.client.get(NAME, null) catch |err| {
            dumpErr("get", err, api_err);
            return err;
        };
        defer got.deinit();
        const effect = got.value.spec.?.taint.effect;
        std.debug.print("  get: {s} (taint.effect={s})\n", .{ got.value.metadata.name, effect });
        if (!std.mem.eql(u8, effect, "NoSchedule")) return error.RoundTripFieldMismatch;
    }

    rules.client.delete(NAME, null) catch |err| {
        dumpErr("delete", err, api_err);
        return err;
    };
    std.debug.print("  delete: {s}\n", .{NAME});
}

fn roundTripClusterTrustBundle(client: *klient.K8sClient) !void {
    std.debug.print("— ClusterTrustBundle (certificates.k8s.io/v1) —\n", .{});
    var api_err: ?klient.K8sClient.ApiError = null;
    defer if (api_err) |*e| e.deinit(client.allocator);

    var bundles = klient.ClusterTrustBundles.init(client);
    bundles.client.error_sink = &api_err;

    {
        const list = bundles.client.list(null) catch |err| {
            dumpErr("list", err, api_err);
            return err;
        };
        defer list.deinit();
        std.debug.print("  list: {} existing\n", .{list.value.items.len});
    }

    const bundle = klient.ClusterTrustBundle{
        .apiVersion = "certificates.k8s.io/v1",
        .kind = "ClusterTrustBundle",
        .metadata = .{ .name = NAME },
        .spec = .{
            .signerName = null,
            .trustBundle = TRUST_BUNDLE,
        },
    };
    {
        const created = bundles.client.create(bundle, null) catch |err| {
            dumpErr("create", err, api_err);
            return err;
        };
        defer created.deinit();
        std.debug.print("  create: {s}\n", .{created.value.metadata.name});
    }

    {
        const got = bundles.client.get(NAME, null) catch |err| {
            dumpErr("get", err, api_err);
            return err;
        };
        defer got.deinit();
        const pem = got.value.spec.?.trustBundle;
        std.debug.print("  get: {s} (trustBundle {d} bytes)\n", .{ got.value.metadata.name, pem.len });
        if (!std.mem.startsWith(u8, pem, "-----BEGIN CERTIFICATE-----")) return error.RoundTripFieldMismatch;
    }

    bundles.client.delete(NAME, null) catch |err| {
        dumpErr("delete", err, api_err);
        return err;
    };
    std.debug.print("  delete: {s}\n", .{NAME});
}

fn roundTripStorageVersionMigration(client: *klient.K8sClient, allocator: std.mem.Allocator) !void {
    std.debug.print("— StorageVersionMigration (storagemigration.k8s.io/v1) —\n", .{});
    var api_err: ?klient.K8sClient.ApiError = null;
    defer if (api_err) |*e| e.deinit(client.allocator);

    var migrations = klient.StorageVersionMigrations.init(client);
    migrations.client.error_sink = &api_err;

    {
        const list = migrations.client.list(null) catch |err| {
            dumpErr("list", err, api_err);
            return err;
        };
        defer list.deinit();
        std.debug.print("  list: {} existing\n", .{list.value.items.len});
    }

    // v1 GroupResource is group+resource only — `version` is a strict-decoding error.
    var resource = try std.json.parseFromSlice(std.json.Value, allocator,
        \\{"group":"","resource":"configmaps"}
    , .{});
    defer resource.deinit();

    const migration = klient.StorageVersionMigration{
        .apiVersion = "storagemigration.k8s.io/v1",
        .kind = "StorageVersionMigration",
        .metadata = .{ .name = NAME },
        .spec = .{ .resource = resource.value },
    };
    {
        const created = migrations.client.create(migration, null) catch |err| {
            dumpErr("create", err, api_err);
            return err;
        };
        defer created.deinit();
        std.debug.print("  create: {s}\n", .{created.value.metadata.name});
    }

    {
        const got = migrations.client.get(NAME, null) catch |err| {
            dumpErr("get", err, api_err);
            return err;
        };
        defer got.deinit();
        const plural = got.value.spec.?.resource.object.get("resource").?.string;
        std.debug.print("  get: {s} (resource={s})\n", .{ got.value.metadata.name, plural });
        if (!std.mem.eql(u8, plural, "configmaps")) return error.RoundTripFieldMismatch;
    }

    migrations.client.delete(NAME, null) catch |err| {
        dumpErr("delete", err, api_err);
        return err;
    };
    std.debug.print("  delete: {s}\n", .{NAME});
}
