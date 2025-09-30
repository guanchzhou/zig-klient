const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create the zig-klient library module
    const klient_module = b.addModule("klient", .{
        .root_source_file = b.path("src/klient.zig"),
        .target = target,
        .optimize = optimize,
    });

    // === Tests ===

    // K8s client tests
    const client_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/k8s_client_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    client_tests.root_module.addImport("klient", klient_module);

    const run_client_tests = b.addRunArtifact(client_tests);
    const client_test_step = b.step("test-client", "Run K8s client tests");
    client_test_step.dependOn(&run_client_tests.step);

    // K8s resources tests
    const resources_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/k8s_resources_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    resources_tests.root_module.addImport("klient", klient_module);

    const run_resources_tests = b.addRunArtifact(resources_tests);
    const resources_test_step = b.step("test-resources", "Run K8s resources tests");
    resources_test_step.dependOn(&run_resources_tests.step);

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

    // New resources tests
    const new_resources_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/new_resources_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    new_resources_tests.root_module.addImport("klient", klient_module);

    const run_new_resources_tests = b.addRunArtifact(new_resources_tests);
    const new_resources_test_step = b.step("test-new-resources", "Run new resources tests");
    new_resources_test_step.dependOn(&run_new_resources_tests.step);

    // Advanced features tests
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

    // Run all tests
    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&run_client_tests.step);
    test_step.dependOn(&run_resources_tests.step);
    test_step.dependOn(&run_retry_tests.step);
    test_step.dependOn(&run_new_resources_tests.step);
    test_step.dependOn(&run_advanced_tests.step);
}

// Export the module for use as a dependency
pub fn module(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Module {
    return b.addModule("klient", .{
        .root_source_file = b.path("src/klient.zig"),
        .target = target,
        .optimize = optimize,
    });
}
