const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // YAML parsing for kubeconfig (sakakibara/yaml-zig)
    const yaml = b.dependency("yaml", .{
        .target = target,
        .optimize = optimize,
    });

    // Create the zig-klient library module.
    // link_libc is required on Linux: parts of the client use libc-backed std
    // functions (clock_gettime, threads, file I/O). macOS links libc implicitly,
    // so this only matters for portable/CI builds.
    const klient_module = b.addModule("klient", .{
        .root_source_file = b.path("src/klient.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    klient_module.addImport("yaml", yaml.module("yaml"));

    // === Unit Tests (data-driven — each entry generates a test step) ===

    const unit_tests = [_]struct { name: []const u8, source: []const u8, desc: []const u8 }{
        .{ .name = "test-retry", .source = "tests/retry_test.zig", .desc = "Run retry logic tests" },
        .{ .name = "test-advanced", .source = "tests/advanced_features_test.zig", .desc = "Run advanced features tests" },
        .{ .name = "test-kubeconfig", .source = "tests/kubeconfig_yaml_test.zig", .desc = "Run kubeconfig YAML parser tests" },
        .{ .name = "test-incluster", .source = "tests/incluster_config_test.zig", .desc = "Run in-cluster configuration tests" },
        .{ .name = "test-list-options", .source = "tests/list_options_test.zig", .desc = "Run list options tests" },
        .{ .name = "test-delete-options", .source = "tests/delete_options_test.zig", .desc = "Run delete/create/update options tests" },
        .{ .name = "test-serviceaccount", .source = "tests/serviceaccount_test.zig", .desc = "Run ServiceAccount tests" },
        .{ .name = "test-rbac", .source = "tests/rbac_test.zig", .desc = "Run RBAC tests" },
        .{ .name = "test-autoscaling", .source = "tests/autoscaling_test.zig", .desc = "Run auto-scaling and resource management tests" },
        .{ .name = "test-storage", .source = "tests/storage_test.zig", .desc = "Run storage and CSI tests" },
        .{ .name = "test-admission", .source = "tests/admission_test.zig", .desc = "Run admission control and certificate tests" },
        .{ .name = "test-k8s-136-fields", .source = "tests/k8s_136_fields_test.zig", .desc = "Run K8s 1.36 field-level additions (hostUsers, image volume, DRA adminAccess)" },
        .{ .name = "test-k8s-137", .source = "tests/k8s_137_test.zig", .desc = "Run K8s 1.37 GA kinds (DeviceTaintRule, ClusterTrustBundle, PodCertificateRequest, StorageVersionMigration v1)" },
        .{ .name = "test-json-binding", .source = "tests/json_binding_test.zig", .desc = "Run JSON field-binding tests (type/continue reserved-name fields)" },
        .{ .name = "test-fuzz", .source = "tests/fuzz_test.zig", .desc = "Fuzz the kubeconfig YAML parser (add --fuzz for a campaign)" },
        .{ .name = "test-advanced-resources", .source = "tests/advanced_test.zig", .desc = "Run advanced resources tests" },
        .{ .name = "test-websocket", .source = "tests/websocket_test.zig", .desc = "Run WebSocket unit tests" },
        .{ .name = "test-gateway-api", .source = "tests/gateway_api_test.zig", .desc = "Run Gateway API tests (K8s 1.34)" },
        .{ .name = "test-dra", .source = "tests/dra_test.zig", .desc = "Run Dynamic Resource Allocation tests (K8s 1.34)" },
        .{ .name = "test-volume-attributes", .source = "tests/volume_attributes_test.zig", .desc = "Run VolumeAttributesClass tests (K8s 1.34)" },
        .{ .name = "test-protobuf", .source = "tests/protobuf_request_test.zig", .desc = "Run raw Protobuf request tests" },
        .{ .name = "test-protobuf-decode", .source = "tests/protobuf_test.zig", .desc = "Run Protobuf decoder tests against upstream-encoded fixtures" },
        .{ .name = "test-protobuf-types", .source = "tests/protobuf_types_test.zig", .desc = "Decode every generated type's Protobuf fixture and compare it with its JSON" },
        .{ .name = "test-list-policy", .source = "tests/list_policy_test.zig", .desc = "Run list retry policy tests (no network)" },
        .{ .name = "test-registry", .source = "tests/resource_registry_test.zig", .desc = "Run resource registry tests" },
        .{ .name = "test-query", .source = "tests/query_test.zig", .desc = "Run query builder tests" },
        .{ .name = "test-path", .source = "tests/path_test.zig", .desc = "Run path segment and header validation tests" },
        .{ .name = "test-stream-get", .source = "tests/stream_get_test.zig", .desc = "Run streaming GET and local HTTP tests" },
        .{ .name = "test-watch", .source = "tests/watch_test.zig", .desc = "Run watch/informer tests" },
        .{ .name = "test-discovery", .source = "tests/discovery_test.zig", .desc = "Run API discovery tests" },
        .{ .name = "test-auth", .source = "tests/auth_test.zig", .desc = "Run auth and options tests" },
        .{ .name = "test-types-meta", .source = "tests/types_meta_test.zig", .desc = "Run types, CRD, metrics, and retry edge case tests" },
        .{ .name = "test-migration-probe", .source = "tests/migration_probe_test.zig", .desc = "Force-compile entire library surface to catch lazy-compilation gaps" },
    };

    // Tests excluded from default `zig build test` (require a live cluster).
    // Live exec/attach/port-forward are covered by the integration entrypoints
    // below (test-pod-exec, run via kubectl proxy).
    const live_tests = [_]struct { name: []const u8, source: []const u8, desc: []const u8 }{
        .{ .name = "test-websocket-integration", .source = "tests/websocket_integration_test.zig", .desc = "WebSocket exec/attach/port-forward against a live cluster" },
    };

    const test_step = b.step("test", "Run all unit tests");

    inline for (unit_tests) |t| {
        const test_mod = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path(t.source),
                .target = target,
                .optimize = optimize,
                .link_libc = true,
            }),
        });
        test_mod.root_module.addImport("klient", klient_module);

        const run = b.addRunArtifact(test_mod);
        const step = b.step(t.name, t.desc);
        step.dependOn(&run.step);
        test_step.dependOn(&run.step);
    }

    // Declared here so the live tests below can attach their *compilation* to it.
    const build_integration_step = b.step("build-integration-tests", "Build all integration test executables");

    inline for (live_tests) |t| {
        const test_mod = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path(t.source),
                .target = target,
                .optimize = optimize,
                .link_libc = true,
            }),
        });
        test_mod.root_module.addImport("klient", klient_module);

        // Compiled by `build-integration-tests` (which CI runs) so these cannot rot
        // again, but only RUN when their own step is invoked explicitly -- they need a
        // live cluster and will fail anywhere else.
        build_integration_step.dependOn(&b.addInstallArtifact(test_mod, .{}).step);

        const run = b.addRunArtifact(test_mod);
        const step = b.step(t.name, t.desc);
        step.dependOn(&run.step);
    }

    // === Integration Test Entrypoints ===
    // Standalone executables that test zig-klient against a live cluster

    const test_entrypoints = [_]struct { name: []const u8, source: []const u8, desc: []const u8 }{
        .{ .name = "test-simple-connection", .source = "tests/entrypoints/test_simple_connection.zig", .desc = "Simple connection test" },
        .{ .name = "test-list-pods", .source = "tests/entrypoints/test_list_pods.zig", .desc = "List pods in default namespace" },
        .{ .name = "test-create-pod", .source = "tests/entrypoints/test_create_pod.zig", .desc = "Create a test pod" },
        .{ .name = "test-get-pod", .source = "tests/entrypoints/test_get_pod.zig", .desc = "Get pod details" },
        .{ .name = "test-update-pod", .source = "tests/entrypoints/test_update_pod.zig", .desc = "Update pod labels" },
        .{ .name = "test-delete-pod", .source = "tests/entrypoints/test_delete_pod.zig", .desc = "Delete pod and cleanup" },
        .{ .name = "test-watch-pods", .source = "tests/entrypoints/test_watch_pods.zig", .desc = "Watch for pod events" },
        .{ .name = "test-full-integration", .source = "tests/entrypoints/test_full_integration.zig", .desc = "Run all operations end-to-end" },
        .{ .name = "test-via-proxy", .source = "tests/entrypoints/test_via_proxy.zig", .desc = "Integration test via kubectl proxy (no TLS)" },
        .{ .name = "test-mutating-admission-policy", .source = "tests/entrypoints/test_mutating_admission_policy.zig", .desc = "MutatingAdmissionPolicy CRUD (requires K8s >= 1.36)" },
        .{ .name = "test-k8s-137-crud", .source = "tests/entrypoints/test_k8s_137_crud.zig", .desc = "DeviceTaintRule / ClusterTrustBundle / StorageVersionMigration v1 CRUD (requires K8s >= 1.37)" },
        .{ .name = "test-pod-exec", .source = "tests/entrypoints/test_pod_exec.zig", .desc = "Pod exec over WebSocket (requires a running pod + kubectl proxy)" },
        .{ .name = "test-protobuf-parity", .source = "tests/entrypoints/test_protobuf_parity.zig", .desc = "Compare a Protobuf and a JSON Pod list body (-- --protobuf FILE --json FILE)" },
    };

    inline for (test_entrypoints) |entrypoint| {
        const exe_module = b.createModule(.{
            .root_source_file = b.path(entrypoint.source),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        });
        exe_module.addImport("klient", klient_module);

        const exe = b.addExecutable(.{
            .name = entrypoint.name,
            .root_module = exe_module,
        });

        const install_exe = b.addInstallArtifact(exe, .{});
        build_integration_step.dependOn(&install_exe.step);

        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(&install_exe.step);
        run_cmd.addPassthruArgs();

        const run_step = b.step(entrypoint.name, entrypoint.desc);
        run_step.dependOn(&run_cmd.step);
    }

    // === Comprehensive integration tests (require a Kubernetes cluster) ===
    // Built, not run: they need a live cluster, but compiling them in CI is what
    // stops them rotting. This step was previously `_ = b.step(...)` -- a step with
    // no dependencies, so it built nothing and ran nothing, and the 1,649 lines here
    // silently stopped compiling.
    const comprehensive_tests = [_]struct { name: []const u8, source: []const u8 }{
        .{ .name = "comprehensive-crud", .source = "tests/comprehensive/crud_all_resources_test.zig" },
        .{ .name = "comprehensive-perf", .source = "tests/comprehensive/performance_10k_test.zig" },
    };

    const comprehensive_step = b.step("test-comprehensive", "Build comprehensive tests (require rancher-desktop to run)");
    build_integration_step.dependOn(comprehensive_step);

    inline for (comprehensive_tests) |t| {
        const mod = b.createModule(.{
            .root_source_file = b.path(t.source),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        });
        mod.addImport("klient", klient_module);

        const exe = b.addExecutable(.{ .name = t.name, .root_module = mod });
        comprehensive_step.dependOn(&b.addInstallArtifact(exe, .{}).step);
    }

    // === libcurl with HTTP/2 (nghttp2) over mbedTLS, built from pinned sources ===
    const with_h2 = b.option(bool, "h2", "Fetch and build the libcurl/nghttp2/mbedTLS/zlib sources (default: false)") orelse false;
    const c_deps_step = b.step("build-c-deps", "Build static libcurl, nghttp2, mbedTLS and zlib for -Dtarget (needs -Dh2)");
    const list_unit_step = b.step("test-list-client-unit", "Run ListClient loopback tests (needs -Dh2; no cluster)");
    const fixture_step = b.step("test-list-client", "Run ListClient against the scripted HTTP/2 fixture (needs -Dh2 and Python; no cluster)");
    const spike_step = b.step("h2-spike", "One HTTP/2 GET to the current kubeconfig context through libcurl (needs -Dh2; read-only)");
    if (!with_h2) {
        const fail = b.addFail("this step needs -Dh2=true");
        c_deps_step.dependOn(&fail.step);
        spike_step.dependOn(&fail.step);
        list_unit_step.dependOn(&fail.step);
        fixture_step.dependOn(&fail.step);
    } else if (buildLibcurl(b, target, optimize)) |c| {
        c_deps_step.dependOn(&b.addInstallArtifact(c.lib, .{}).step);

        const spike_module = b.createModule(.{
            .root_source_file = b.path("tests/entrypoints/test_h2_spike.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        });
        spike_module.addImport("klient", klient_module);
        spike_module.addImport("curl_c", c.bindings);
        spike_module.linkLibrary(c.lib);

        const list_module = b.addModule("klient-list", .{
            .root_source_file = b.path("src/k8s/list_client.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        });
        list_module.addImport("klient", klient_module);
        list_module.addImport("curl_c", c.bindings);
        list_module.linkLibrary(c.lib);
        spike_module.addImport("klient-list", list_module);

        const spike = b.addExecutable(.{ .name = "test-h2-spike", .root_module = spike_module });
        c_deps_step.dependOn(&b.addInstallArtifact(spike, .{}).step);
        const run_spike = b.addRunArtifact(spike);
        run_spike.addPassthruArgs();
        spike_step.dependOn(&run_spike.step);
        const list_unit = b.addTest(.{ .name = "test-list-client-unit", .root_module = list_module });
        list_unit_step.dependOn(&b.addRunArtifact(list_unit).step);

        const fixture_module = b.createModule(.{
            .root_source_file = b.path("tests/list_client_fixture_test.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        });
        fixture_module.addImport("klient", klient_module);
        fixture_module.addImport("klient-list", list_module);
        fixture_module.linkLibrary(c.lib);
        const run_fixture = b.addRunArtifact(b.addTest(.{ .name = "test-list-client", .root_module = fixture_module }));
        const venv_python = ".zig-cache/fixture-venv/bin/python3";
        const venv_step = b.addSystemCommand(&.{ "python3", "-m", "venv", ".zig-cache/fixture-venv" });
        const pip_step = b.addSystemCommand(&.{ venv_python, "-m", "pip", "install", "--disable-pip-version-check", "h2" });
        pip_step.step.dependOn(&venv_step.step);
        run_fixture.step.dependOn(&pip_step.step);
        run_fixture.setEnvironmentVariable("LIST_FIXTURE_PYTHON", venv_python);
        fixture_step.dependOn(&run_fixture.step);
    }

    // === Protobuf schema and fixtures (needs Go; reads k8s.io/api) ===
    const gen_protobuf_step = b.step("gen-protobuf", "Regenerate src/k8s/protobuf_generated.zig and its fixtures from k8s.io/api (needs Go)");
    const gen_protobuf = b.addSystemCommand(&.{ "go", "run", "." });
    gen_protobuf.setCwd(b.path("tools/protobuf-gen"));
    gen_protobuf.addArg("-schema");
    gen_protobuf.addFileArg(b.path("src/k8s/protobuf_generated.zig"));
    gen_protobuf.addArg("-fixtures");
    gen_protobuf.addDirectoryArg(b.path("tests/fixtures/protobuf"));
    gen_protobuf.has_side_effects = true;
    const fmt_generated = b.addFmt(.{ .paths = b.pathList(&.{"src/k8s/protobuf_generated.zig"}) });
    fmt_generated.step.dependOn(&gen_protobuf.step);
    gen_protobuf_step.dependOn(&fmt_generated.step);

    // === API documentation (zig build docs -> zig-out/docs) ===
    const docs_step = b.step("docs", "Generate API documentation into zig-out/docs");
    const docs_obj = b.addObject(.{ .name = "zig-klient", .root_module = klient_module });
    const install_docs = b.addInstallDirectory(.{
        .source_dir = docs_obj.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });
    docs_step.dependOn(&install_docs.step);
}

const Libcurl = struct {
    lib: *std.Build.Step.Compile,
    bindings: *std.Build.Module,
};

/// Returns null until the lazy C dependencies are fetched; the build runner
/// fetches them and re-runs `build`.
fn buildLibcurl(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) ?Libcurl {
    const curl_dep = b.lazyDependency("curl", .{});
    const nghttp2_dep = b.lazyDependency("nghttp2", .{});
    const mbedtls_dep = b.lazyDependency("mbedtls", .{});
    const zlib_dep = b.lazyDependency("zlib", .{});
    if (curl_dep == null or nghttp2_dep == null or mbedtls_dep == null or zlib_dep == null) return null;

    const curl = @import("libs/curl.zig").create(b, target, optimize, curl_dep.?, "");
    const nghttp2 = @import("libs/nghttp2.zig").create(b, target, optimize, nghttp2_dep.?, "");
    const mbedtls_build = @import("libs/mbedtls.zig");
    const mbedtls = mbedtls_build.create(b, target, optimize, mbedtls_dep.?, "");
    mbedtls_build.addConfig(curl.root_module);
    const zlib = @import("libs/zlib.zig").create(b, target, optimize, zlib_dep.?, "");
    curl.root_module.linkLibrary(nghttp2);
    curl.root_module.linkLibrary(mbedtls);
    curl.root_module.linkLibrary(zlib);

    const translate = b.addTranslateC(.{
        .root_source_file = b.path("libs/curl_c.h"),
        .target = target,
        .optimize = optimize,
    });
    translate.addIncludePath(curl_dep.?.path("include"));
    return .{ .lib = curl, .bindings = translate.createModule() };
}

// Export the module for use as a dependency
pub fn module(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Module {
    return b.addModule("klient", .{
        .root_source_file = b.path("src/klient.zig"),
        .target = target,
        .optimize = optimize,
    });
}
