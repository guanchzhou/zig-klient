const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Add zig-yaml dependency
    const yaml = b.dependency("yaml", .{
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

    // === Unit Tests ===
    // Note: Comprehensive integration tests are in examples/tests/
    //       These unit tests focus on isolated functionality

    // Retry logic tests
    const retry_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/retry_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    retry_tests.root_module.addImport("klient", klient_module);

    const run_retry_tests = b.addRunArtifact(retry_tests);
    const retry_test_step = b.step("test-retry", "Run retry logic tests");
    retry_test_step.dependOn(&run_retry_tests.step);

    // Advanced features tests (TLS, Connection Pool, CRD)
    const advanced_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/advanced_features_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    advanced_tests.root_module.addImport("klient", klient_module);

    const run_advanced_tests = b.addRunArtifact(advanced_tests);
    const advanced_test_step = b.step("test-advanced", "Run advanced features tests");
    advanced_test_step.dependOn(&run_advanced_tests.step);

    // Kubeconfig YAML tests
    const kubeconfig_yaml_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/kubeconfig_yaml_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    kubeconfig_yaml_tests.root_module.addImport("klient", klient_module);

    const run_kubeconfig_yaml_tests = b.addRunArtifact(kubeconfig_yaml_tests);
    const kubeconfig_yaml_test_step = b.step("test-kubeconfig", "Run kubeconfig YAML parser tests");
    kubeconfig_yaml_test_step.dependOn(&run_kubeconfig_yaml_tests.step);

    // In-cluster config tests
    const incluster_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/incluster_config_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    incluster_tests.root_module.addImport("klient", klient_module);

    const run_incluster_tests = b.addRunArtifact(incluster_tests);
    const incluster_test_step = b.step("test-incluster", "Run in-cluster configuration tests");
    incluster_test_step.dependOn(&run_incluster_tests.step);

    // List options tests
    const list_options_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/list_options_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    list_options_tests.root_module.addImport("klient", klient_module);

    const run_list_options_tests = b.addRunArtifact(list_options_tests);
    const list_options_test_step = b.step("test-list-options", "Run list options tests");
    list_options_test_step.dependOn(&run_list_options_tests.step);

    // Delete options tests
    const delete_options_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/delete_options_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    delete_options_tests.root_module.addImport("klient", klient_module);

    const run_delete_options_tests = b.addRunArtifact(delete_options_tests);
    const delete_options_test_step = b.step("test-delete-options", "Run delete/create/update options tests");
    delete_options_test_step.dependOn(&run_delete_options_tests.step);

    // WebSocket tests
    const websocket_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/websocket_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    websocket_tests.root_module.addImport("klient", klient_module);

    const run_websocket_tests = b.addRunArtifact(websocket_tests);
    const websocket_test_step = b.step("test-websocket", "Run WebSocket unit tests");
    websocket_test_step.dependOn(&run_websocket_tests.step);

    // WebSocket integration tests (requires rancher-desktop)
    const websocket_integration_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/websocket_integration_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    websocket_integration_tests.root_module.addImport("klient", klient_module);

    const run_websocket_integration_tests = b.addRunArtifact(websocket_integration_tests);
    const websocket_integration_test_step = b.step("test-websocket-integration", "Run WebSocket integration tests (requires rancher-desktop)");
    websocket_integration_test_step.dependOn(&run_websocket_integration_tests.step);

    // Run all unit tests
    const test_step = b.step("test", "Run all unit tests");
    test_step.dependOn(&run_retry_tests.step);
    test_step.dependOn(&run_advanced_tests.step);
    test_step.dependOn(&run_kubeconfig_yaml_tests.step);
    test_step.dependOn(&run_incluster_tests.step);
    test_step.dependOn(&run_list_options_tests.step);
    test_step.dependOn(&run_delete_options_tests.step);
    test_step.dependOn(&run_websocket_tests.step);

    // === Integration Test Entrypoints ===
    // These are standalone executables that test zig-klient against a live cluster

    // Helper function to create test entrypoint
    const TestEntrypoint = struct {
        name: []const u8,
        source: []const u8,
        description: []const u8,
    };

    const test_entrypoints = [_]TestEntrypoint{
        .{ .name = "test-simple-connection", .source = "tests/entrypoints/test_simple_connection.zig", .description = "Simple connection test" },
        .{ .name = "test-list-pods", .source = "tests/entrypoints/test_list_pods.zig", .description = "List pods in default namespace" },
        .{ .name = "test-create-pod", .source = "tests/entrypoints/test_create_pod.zig", .description = "Create a test pod" },
        .{ .name = "test-get-pod", .source = "tests/entrypoints/test_get_pod.zig", .description = "Get pod details" },
        .{ .name = "test-update-pod", .source = "tests/entrypoints/test_update_pod.zig", .description = "Update pod labels" },
        .{ .name = "test-delete-pod", .source = "tests/entrypoints/test_delete_pod.zig", .description = "Delete pod and cleanup" },
        .{ .name = "test-watch-pods", .source = "tests/entrypoints/test_watch_pods.zig", .description = "Watch for pod events" },
        .{ .name = "test-full-integration", .source = "tests/entrypoints/test_full_integration.zig", .description = "Run all operations end-to-end" },
    };

    // Build all test entrypoints
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

        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(&install_exe.step);

        const run_step = b.step(entrypoint.name, entrypoint.description);
        run_step.dependOn(&run_cmd.step);
    }

    // Build all integration tests at once
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
    }

    // Comprehensive integration tests (require Kubernetes cluster)
    // These are built as separate executables to run against live cluster
    const comprehensive_step = b.step("test-comprehensive", "Build comprehensive tests (requires rancher-desktop)");

    // Note: Comprehensive tests require manual execution against Rancher Desktop
    // Build targets commented out due to zig-yaml compatibility issues with Zig 0.15.1
    // To run comprehensive tests:
    // 1. cd tests/comprehensive
    // 2. ./run_all.sh
    //
    // The test files are ready and documented in:
    // - tests/comprehensive/crud_all_resources_test.zig
    // - tests/comprehensive/performance_10k_test.zig
    // - tests/comprehensive/test_helpers.zig
    _ = comprehensive_step; // Suppress unused variable warning
}

// Export the module for use as a dependency
pub fn module(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Module {
    return b.addModule("klient", .{
        .root_source_file = b.path("src/klient.zig"),
        .target = target,
        .optimize = optimize,
    });
}
