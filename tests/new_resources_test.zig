const std = @import("std");
const klient = @import("klient");
const types = klient.types;

test "StatefulSet - Structure" {
    var containers = [_]types.Container{
        .{
            .name = "nginx",
            .image = "nginx:latest",
        },
    };
    
    const statefulset = types.StatefulSet{
        .apiVersion = "apps/v1",
        .kind = "StatefulSet",
        .metadata = .{
            .name = "web",
            .namespace = "default",
        },
        .spec = .{
            .replicas = 3,
            .serviceName = "nginx",
            .selector = .{ .matchLabels = null },
            .template = .{
                .spec = .{
                    .containers = &containers,
                },
            },
        },
    };
    
    try std.testing.expectEqualStrings("StatefulSet", statefulset.kind);
    try std.testing.expectEqualStrings("web", statefulset.metadata.name);
    try std.testing.expectEqual(3, statefulset.spec.?.replicas.?);
    try std.testing.expectEqualStrings("nginx", statefulset.spec.?.serviceName);
    
    std.debug.print("✅ StatefulSet structure test passed\n", .{});
}

test "DaemonSet - Structure" {
    var containers = [_]types.Container{
        .{
            .name = "fluentd",
            .image = "fluentd:latest",
        },
    };
    
    const daemonset = types.DaemonSet{
        .apiVersion = "apps/v1",
        .kind = "DaemonSet",
        .metadata = .{
            .name = "fluentd",
            .namespace = "kube-system",
        },
        .spec = .{
            .selector = .{ .matchLabels = null },
            .template = .{
                .spec = .{
                    .containers = &containers,
                },
            },
        },
    };
    
    try std.testing.expectEqualStrings("DaemonSet", daemonset.kind);
    try std.testing.expectEqualStrings("fluentd", daemonset.metadata.name);
    try std.testing.expectEqualStrings("kube-system", daemonset.metadata.namespace.?);
    
    std.debug.print("✅ DaemonSet structure test passed\n", .{});
}

test "Job - Structure" {
    var command_args = [_][]const u8{ "perl", "-Mbignum=bpi", "-wle", "print bpi(2000)" };
    var containers = [_]types.Container{
        .{
            .name = "pi",
            .image = "perl:5.34.0",
            .command = @as(?[][]const u8, &command_args),
        },
    };
    
    const job = types.Job{
        .apiVersion = "batch/v1",
        .kind = "Job",
        .metadata = .{
            .name = "pi",
        },
        .spec = .{
            .template = .{
                .spec = .{
                    .containers = &containers,
                    .restartPolicy = "Never",
                },
            },
            .completions = 1,
            .parallelism = 1,
            .backoffLimit = 4,
        },
    };
    
    try std.testing.expectEqualStrings("Job", job.kind);
    try std.testing.expectEqualStrings("pi", job.metadata.name);
    try std.testing.expectEqual(1, job.spec.?.completions.?);
    try std.testing.expectEqual(4, job.spec.?.backoffLimit.?);
    
    std.debug.print("✅ Job structure test passed\n", .{});
}

test "CronJob - Structure" {
    var command_args = [_][]const u8{ "/bin/sh", "-c", "date; echo Hello from Kubernetes" };
    var containers = [_]types.Container{
        .{
            .name = "hello",
            .image = "busybox:1.28",
            .command = @as(?[][]const u8, &command_args),
        },
    };
    
    const cronjob = types.CronJob{
        .apiVersion = "batch/v1",
        .kind = "CronJob",
        .metadata = .{
            .name = "hello",
        },
        .spec = .{
            .schedule = "*/1 * * * *",
            .jobTemplate = .{
                .spec = .{
                    .template = .{
                        .spec = .{
                            .containers = &containers,
                            .restartPolicy = "OnFailure",
                        },
                    },
                },
            },
            .successfulJobsHistoryLimit = 3,
            .failedJobsHistoryLimit = 1,
        },
    };
    
    try std.testing.expectEqualStrings("CronJob", cronjob.kind);
    try std.testing.expectEqualStrings("hello", cronjob.metadata.name);
    try std.testing.expectEqualStrings("*/1 * * * *", cronjob.spec.?.schedule);
    try std.testing.expectEqual(3, cronjob.spec.?.successfulJobsHistoryLimit.?);
    
    std.debug.print("✅ CronJob structure test passed\n", .{});
}

test "ReplicaSet - Structure" {
    var containers = [_]types.Container{
        .{
            .name = "nginx",
            .image = "nginx:1.14.2",
        },
    };
    
    const replicaset = types.ReplicaSet{
        .apiVersion = "apps/v1",
        .kind = "ReplicaSet",
        .metadata = .{
            .name = "frontend",
        },
        .spec = .{
            .replicas = 3,
            .selector = .{ .matchLabels = null },
            .template = .{
                .spec = .{
                    .containers = &containers,
                },
            },
        },
    };
    
    try std.testing.expectEqualStrings("ReplicaSet", replicaset.kind);
    try std.testing.expectEqualStrings("frontend", replicaset.metadata.name);
    try std.testing.expectEqual(3, replicaset.spec.?.replicas.?);
    
    std.debug.print("✅ ReplicaSet structure test passed\n", .{});
}

test "PersistentVolumeClaim - Structure" {
    var access_modes = [_][]const u8{"ReadWriteOnce"};
    const pvc = types.PersistentVolumeClaim{
        .apiVersion = "v1",
        .kind = "PersistentVolumeClaim",
        .metadata = .{
            .name = "myclaim",
        },
        .spec = .{
            .accessModes = @as(?[][]const u8, &access_modes),
            .storageClassName = "standard",
        },
    };
    
    try std.testing.expectEqualStrings("PersistentVolumeClaim", pvc.kind);
    try std.testing.expectEqualStrings("myclaim", pvc.metadata.name);
    try std.testing.expectEqualStrings("standard", pvc.spec.?.storageClassName.?);
    
    std.debug.print("✅ PersistentVolumeClaim structure test passed\n", .{});
}
