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

    // ServiceAccount tests
    const serviceaccount_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/serviceaccount_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    serviceaccount_tests.root_module.addImport("klient", klient_module);

    const run_serviceaccount_tests = b.addRunArtifact(serviceaccount_tests);
    const serviceaccount_test_step = b.step("test-serviceaccount", "Run ServiceAccount tests");
    serviceaccount_test_step.dependOn(&run_serviceaccount_tests.step);

    // RBAC tests (Role, RoleBinding, ClusterRole, ClusterRoleBinding)
    const rbac_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/rbac_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    rbac_tests.root_module.addImport("klient", klient_module);

    const run_rbac_tests = b.addRunArtifact(rbac_tests);
    const rbac_test_step = b.step("test-rbac", "Run RBAC tests (Role, RoleBinding, ClusterRole, ClusterRoleBinding)");
    rbac_test_step.dependOn(&run_rbac_tests.step);

    // Auto-scaling and resource management tests
    const autoscaling_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/autoscaling_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    autoscaling_tests.root_module.addImport("klient", klient_module);

    const run_autoscaling_tests = b.addRunArtifact(autoscaling_tests);
    const autoscaling_test_step = b.step("test-autoscaling", "Run auto-scaling and resource management tests");
    autoscaling_test_step.dependOn(&run_autoscaling_tests.step);

    // Storage and CSI tests
    const storage_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/storage_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    storage_tests.root_module.addImport("klient", klient_module);

    const run_storage_tests = b.addRunArtifact(storage_tests);
    const storage_test_step = b.step("test-storage", "Run storage and CSI tests");
    storage_test_step.dependOn(&run_storage_tests.step);

    // Admission control and certificate tests
    const admission_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/admission_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    admission_tests.root_module.addImport("klient", klient_module);

    const run_admission_tests = b.addRunArtifact(admission_tests);
    const admission_test_step = b.step("test-admission", "Run admission control and certificate tests");
    admission_test_step.dependOn(&run_admission_tests.step);

    // Advanced resources tests (APIService, FlowSchema, RuntimeClass, etc.)
    const advanced_resources_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/advanced_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    advanced_resources_tests.root_module.addImport("klient", klient_module);

    const run_advanced_resources_tests = b.addRunArtifact(advanced_resources_tests);
    const advanced_resources_test_step = b.step("test-advanced-resources", "Run advanced resources tests");
    advanced_resources_test_step.dependOn(&run_advanced_resources_tests.step);

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

    // WebSocket live tests (requires rancher-desktop)
    const websocket_live_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/websocket_live_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    websocket_live_tests.root_module.addImport("klient", klient_module);

    const run_websocket_live_tests = b.addRunArtifact(websocket_live_tests);
    const websocket_live_test_step = b.step("test-websocket-live", "Run WebSocket live tests against Rancher Desktop");
    websocket_live_test_step.dependOn(&run_websocket_live_tests.step);

    // Gateway API tests (Kubernetes 1.34)
    const gateway_api_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/gateway_api_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    gateway_api_tests.root_module.addImport("klient", klient_module);

    const run_gateway_api_tests = b.addRunArtifact(gateway_api_tests);
    const gateway_api_test_step = b.step("test-gateway-api", "Run Gateway API tests (K8s 1.34)");
    gateway_api_test_step.dependOn(&run_gateway_api_tests.step);

    // Dynamic Resource Allocation tests (Kubernetes 1.34)
    const dra_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/dra_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    dra_tests.root_module.addImport("klient", klient_module);

    const run_dra_tests = b.addRunArtifact(dra_tests);
    const dra_test_step = b.step("test-dra", "Run Dynamic Resource Allocation tests (K8s 1.34)");
    dra_test_step.dependOn(&run_dra_tests.step);

    // VolumeAttributesClass tests (Kubernetes 1.34)
    const volume_attributes_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/volume_attributes_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    volume_attributes_tests.root_module.addImport("klient", klient_module);

    const run_volume_attributes_tests = b.addRunArtifact(volume_attributes_tests);
    const volume_attributes_test_step = b.step("test-volume-attributes", "Run VolumeAttributesClass tests (K8s 1.34)");
    volume_attributes_test_step.dependOn(&run_volume_attributes_tests.step);

    // Protobuf integration tests
    const protobuf_integration_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/protobuf_integration_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    protobuf_integration_tests.root_module.addImport("klient", klient_module);

    const run_protobuf_integration_tests = b.addRunArtifact(protobuf_integration_tests);
    const protobuf_integration_test_step = b.step("test-protobuf", "Run Protobuf integration tests");
    protobuf_integration_test_step.dependOn(&run_protobuf_integration_tests.step);

    // Run all unit tests
    const test_step = b.step("test", "Run all unit tests");
    test_step.dependOn(&run_retry_tests.step);
    test_step.dependOn(&run_kubeconfig_yaml_tests.step);
    test_step.dependOn(&run_incluster_tests.step);
    test_step.dependOn(&run_list_options_tests.step);
    test_step.dependOn(&run_delete_options_tests.step);
    test_step.dependOn(&run_serviceaccount_tests.step);
    test_step.dependOn(&run_rbac_tests.step);
    test_step.dependOn(&run_autoscaling_tests.step);
    test_step.dependOn(&run_storage_tests.step);
    test_step.dependOn(&run_admission_tests.step);
    test_step.dependOn(&run_advanced_resources_tests.step);
    test_step.dependOn(&run_websocket_tests.step);
    test_step.dependOn(&run_protobuf_integration_tests.step);
    test_step.dependOn(&run_gateway_api_tests.step);
    test_step.dependOn(&run_dra_tests.step);
    test_step.dependOn(&run_volume_attributes_tests.step);

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
        .{ .name = "test-via-proxy", .source = "tests/entrypoints/test_via_proxy.zig", .description = "Integration test via kubectl proxy (no TLS)" },
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
    // These require manual execution against Rancher Desktop:
    //   1. cd tests/comprehensive
    //   2. ./run_all.sh
    // Test files: crud_all_resources_test.zig, performance_10k_test.zig, test_helpers.zig
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
