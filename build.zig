const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Add zig-yaml dependency
    const yaml = b.dependency("yaml", .{
        .target = target,
        .optimize = optimize,
    });

    // Add zig-protobuf dependency
    const protobuf_dep = b.dependency("protobuf", .{
        .target = target,
        .optimize = optimize,
    });

    // Create the zig-klient library module
    const klient_module = b.addModule("klient", .{
        .root_source_file = b.path("src/klient.zig"),
        .target = target,
        .optimize = optimize,
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
        .{ .name = "test-advanced-resources", .source = "tests/advanced_test.zig", .desc = "Run advanced resources tests" },
        .{ .name = "test-websocket", .source = "tests/websocket_test.zig", .desc = "Run WebSocket unit tests" },
        .{ .name = "test-gateway-api", .source = "tests/gateway_api_test.zig", .desc = "Run Gateway API tests (K8s 1.34)" },
        .{ .name = "test-dra", .source = "tests/dra_test.zig", .desc = "Run Dynamic Resource Allocation tests (K8s 1.34)" },
        .{ .name = "test-volume-attributes", .source = "tests/volume_attributes_test.zig", .desc = "Run VolumeAttributesClass tests (K8s 1.34)" },
        .{ .name = "test-protobuf", .source = "tests/protobuf_integration_test.zig", .desc = "Run Protobuf integration tests" },
    };

    // Tests excluded from default `zig build test` (require live cluster)
    const live_tests = [_]struct { name: []const u8, source: []const u8, desc: []const u8 }{
        .{ .name = "test-websocket-live", .source = "tests/websocket_live_test.zig", .desc = "Run WebSocket live tests against Rancher Desktop" },
    };

    const test_step = b.step("test", "Run all unit tests");

    inline for (unit_tests) |t| {
        const test_mod = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path(t.source),
                .target = target,
                .optimize = optimize,
            }),
        });
        test_mod.root_module.addImport("klient", klient_module);

        const run = b.addRunArtifact(test_mod);
        const step = b.step(t.name, t.desc);
        step.dependOn(&run.step);
        test_step.dependOn(&run.step);
    }

    inline for (live_tests) |t| {
        const test_mod = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path(t.source),
                .target = target,
                .optimize = optimize,
            }),
        });
        test_mod.root_module.addImport("klient", klient_module);

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
    };

    const build_integration_step = b.step("build-integration-tests", "Build all integration test executables");

    inline for (test_entrypoints) |entrypoint| {
        const exe_module = b.createModule(.{
            .root_source_file = b.path(entrypoint.source),
            .target = target,
            .optimize = optimize,
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

    // Comprehensive integration tests (require Kubernetes cluster)
    // These require manual execution against Rancher Desktop:
    //   1. cd tests/comprehensive
    //   2. ./run_all.sh
    _ = b.step("test-comprehensive", "Build comprehensive tests (requires rancher-desktop)");
}

// Export the module for use as a dependency
pub fn module(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Module {
    return b.addModule("klient", .{
        .root_source_file = b.path("src/klient.zig"),
        .target = target,
        .optimize = optimize,
    });
}
