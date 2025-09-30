const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Import klient from parent directory
    const klient_module = b.addModule("klient", .{
        .root_source_file = b.path("../../src/klient.zig"),
        .target = target,
        .optimize = optimize,
    });

    // List of all test files
    const tests = [_][]const u8{
        "test_core_client",
        "test_pods",
        "test_deployments",
        "test_services",
        "test_configmaps",
        "test_secrets",
        "test_namespaces",
        "test_nodes",
        "test_replicasets",
        "test_statefulsets",
        "test_daemonsets",
        "test_jobs",
        "test_cronjobs",
        "test_pvs",
        "test_pvcs",
        "test_connection_pool",
        "test_retry",
        "test_tls",
        "test_kubeconfig",
    };

    // Create build step for each test
    inline for (tests) |test_name| {
        const exe = b.addExecutable(.{
            .name = test_name,
            .root_module = b.createModule(.{
                .root_source_file = b.path(test_name ++ ".zig"),
                .target = target,
                .optimize = optimize,
            }),
        });
        exe.root_module.addImport("klient", klient_module);
        b.installArtifact(exe);

        // Add run step for each test
        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(b.getInstallStep());

        const run_step = b.step("run-" ++ test_name, "Run " ++ test_name);
        run_step.dependOn(&run_cmd.step);
    }

    // Add a step to run all tests
    const run_all_step = b.step("run-all", "Run all tests");
    inline for (tests) |test_name| {
        const exe = b.addExecutable(.{
            .name = test_name,
            .root_module = b.createModule(.{
                .root_source_file = b.path(test_name ++ ".zig"),
                .target = target,
                .optimize = optimize,
            }),
        });
        exe.root_module.addImport("klient", klient_module);
        
        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(b.getInstallStep());
        run_all_step.dependOn(&run_cmd.step);
    }
}
