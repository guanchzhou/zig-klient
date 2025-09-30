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

    // Run all unit tests
    const test_step = b.step("test", "Run all unit tests");
    test_step.dependOn(&run_retry_tests.step);
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
