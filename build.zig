const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // YAML parsing for kubeconfig (sakakibara/yaml-zig)
    const yaml = b.dependency("yaml", .{
        .target = target,
        .optimize = optimize,
    });

    // Add zig-protobuf dependency
    const protobuf_dep = b.dependency("protobuf", .{
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
    klient_module.addImport("protobuf", protobuf_dep.module("protobuf"));

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
        .{ .name = "test-protobuf", .source = "tests/protobuf_integration_test.zig", .desc = "Run Protobuf integration tests" },
        .{ .name = "test-registry", .source = "tests/resource_registry_test.zig", .desc = "Run resource registry tests" },
        .{ .name = "test-query", .source = "tests/query_test.zig", .desc = "Run query builder tests" },
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

// Export the module for use as a dependency
pub fn module(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Module {
    return b.addModule("klient", .{
        .root_source_file = b.path("src/klient.zig"),
        .target = target,
        .optimize = optimize,
    });
}
