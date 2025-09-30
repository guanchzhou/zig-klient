const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Import klient from parent directory
    const klient_module = b.addModule("klient", .{
        .root_source_file = b.path("../src/klient.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Test cluster example
    const test_cluster = b.addExecutable(.{
        .name = "test_cluster",
        .root_module = b.createModule(.{
            .root_source_file = b.path("test_cluster.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    test_cluster.root_module.addImport("klient", klient_module);
    
    b.installArtifact(test_cluster);

    // Test proxy example (simpler, no TLS)
    const test_proxy = b.addExecutable(.{
        .name = "test_proxy",
        .root_module = b.createModule(.{
            .root_source_file = b.path("test_proxy.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    test_proxy.root_module.addImport("klient", klient_module);
    
    b.installArtifact(test_proxy);

    // Simple test example (working features only)
    const test_simple = b.addExecutable(.{
        .name = "test_simple",
        .root_module = b.createModule(.{
            .root_source_file = b.path("test_simple.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    test_simple.root_module.addImport("klient", klient_module);
    
    b.installArtifact(test_simple);

    // Comprehensive test for all functions
    const test_all = b.addExecutable(.{
        .name = "test_all_functions",
        .root_module = b.createModule(.{
            .root_source_file = b.path("test_all_functions.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    test_all.root_module.addImport("klient", klient_module);
    
    b.installArtifact(test_all);

    // Run commands
    const run_cluster_cmd = b.addRunArtifact(test_cluster);
    run_cluster_cmd.step.dependOn(b.getInstallStep());

    const run_proxy_cmd = b.addRunArtifact(test_proxy);
    run_proxy_cmd.step.dependOn(b.getInstallStep());

    const run_cluster_step = b.step("run-cluster", "Run the cluster test (requires TLS)");
    run_cluster_step.dependOn(&run_cluster_cmd.step);

    const run_proxy_step = b.step("run-proxy", "Run the proxy test (requires kubectl proxy)");
    run_proxy_step.dependOn(&run_proxy_cmd.step);

    const run_simple_cmd = b.addRunArtifact(test_simple);
    run_simple_cmd.step.dependOn(b.getInstallStep());

    const run_simple_step = b.step("run-simple", "Run the simple working test");
    run_simple_step.dependOn(&run_simple_cmd.step);

    const run_all_cmd = b.addRunArtifact(test_all);
    run_all_cmd.step.dependOn(b.getInstallStep());

    const run_all_step = b.step("run-all", "Run comprehensive test for all functions");
    run_all_step.dependOn(&run_all_cmd.step);

    const run_step = b.step("run", "Run comprehensive test (default)");
    run_step.dependOn(&run_all_cmd.step);
}
