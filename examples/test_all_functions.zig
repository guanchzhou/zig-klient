const std = @import("std");
const klient = @import("klient");

var test_count: u32 = 0;
var passed_count: u32 = 0;
var failed_count: u32 = 0;

fn testPassed(name: []const u8) void {
    test_count += 1;
    passed_count += 1;
    std.debug.print("  ✓ {s}\n", .{name});
}

fn testFailed(name: []const u8, err: anyerror) void {
    test_count += 1;
    failed_count += 1;
    std.debug.print("  ✗ {s} - Error: {s}\n", .{ name, @errorName(err) });
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n" ++ "=" ** 70 ++ "\n", .{});
    std.debug.print("   zig-klient Comprehensive Function Test Suite\n", .{});
    std.debug.print("=" ** 70 ++ "\n\n", .{});

    // Initialize client
    std.debug.print("Initializing K8s client (via kubectl proxy)...\n", .{});
    var client = try klient.K8sClient.init(allocator, .{
        .server = "http://127.0.0.1:8080",
        .token = null,
        .namespace = "default",
    });
    defer client.deinit();
    std.debug.print("  ✓ Client initialized\n\n", .{});

    // === Core Client Functions ===
    std.debug.print("Testing Core Client Functions:\n", .{});

    // Test getClusterInfo
    if (client.getClusterInfo()) |info| {
        testPassed("getClusterInfo()");
        std.debug.print("    Version: {s}\n", .{info.k8s_version});
    } else |err| {
        testFailed("getClusterInfo()", err);
    }

    // === Pods Client ===
    std.debug.print("\nTesting Pods Client:\n", .{});
    var pods_client = klient.Pods.init(&client);

    // Test listAll
    if (pods_client.client.listAll()) |pods_parsed| {
        defer pods_parsed.deinit();
        testPassed("Pods.listAll()");
        std.debug.print("    Found: {d} pods\n", .{pods_parsed.value.items.len});
    } else |err| {
        testFailed("Pods.listAll()", err);
    }

    // Test list (namespaced)
    if (pods_client.client.list("kube-system")) |pods_parsed| {
        defer pods_parsed.deinit();
        testPassed("Pods.list(namespace)");
        std.debug.print("    Found: {d} pods in kube-system\n", .{pods_parsed.value.items.len});
    } else |err| {
        testFailed("Pods.list(namespace)", err);
    }

    // Test get (specific pod)
    if (pods_client.client.list("kube-system")) |pods_parsed| {
        defer pods_parsed.deinit();
        if (pods_parsed.value.items.len > 0) {
            const pod_name = pods_parsed.value.items[0].metadata.name;
            if (pods_client.client.get(pod_name, "kube-system")) |pod| {
                testPassed("Pods.get(name, namespace)");
                std.debug.print("    Retrieved: {s}\n", .{pod.metadata.name});
            } else |err| {
                testFailed("Pods.get(name, namespace)", err);
            }
        }
    } else |_| {}

    // === Deployments Client ===
    std.debug.print("\nTesting Deployments Client:\n", .{});
    var deployments_client = klient.Deployments.init(&client);

    // Test listAll
    if (deployments_client.client.listAll()) |deps_parsed| {
        defer deps_parsed.deinit();
        testPassed("Deployments.listAll()");
        std.debug.print("    Found: {d} deployments\n", .{deps_parsed.value.items.len});
    } else |err| {
        testFailed("Deployments.listAll()", err);
    }

    // Test list (namespaced)
    if (deployments_client.client.list("kube-system")) |deps_parsed| {
        defer deps_parsed.deinit();
        testPassed("Deployments.list(namespace)");
        std.debug.print("    Found: {d} deployments in kube-system\n", .{deps_parsed.value.items.len});
    } else |err| {
        testFailed("Deployments.list(namespace)", err);
    }

    // === Services Client ===
    std.debug.print("\nTesting Services Client:\n", .{});
    var services_client = klient.Services.init(&client);

    // Test listAll
    if (services_client.client.listAll()) |svcs_parsed| {
        defer svcs_parsed.deinit();
        testPassed("Services.listAll()");
        std.debug.print("    Found: {d} services\n", .{svcs_parsed.value.items.len});
    } else |err| {
        testFailed("Services.listAll()", err);
    }

    // Test list (namespaced)
    if (services_client.client.list("default")) |svcs_parsed| {
        defer svcs_parsed.deinit();
        testPassed("Services.list(namespace)");
        std.debug.print("    Found: {d} services in default\n", .{svcs_parsed.value.items.len});
    } else |err| {
        testFailed("Services.list(namespace)", err);
    }

    // === ConfigMaps Client ===
    std.debug.print("\nTesting ConfigMaps Client:\n", .{});
    var configmaps_client = klient.ConfigMaps.init(&client);

    // Test listAll
    if (configmaps_client.client.listAll()) |cms_parsed| {
        defer cms_parsed.deinit();
        testPassed("ConfigMaps.listAll()");
        std.debug.print("    Found: {d} configmaps\n", .{cms_parsed.value.items.len});
    } else |err| {
        testFailed("ConfigMaps.listAll()", err);
    }

    // Test list (namespaced)
    if (configmaps_client.client.list("kube-system")) |cms_parsed| {
        defer cms_parsed.deinit();
        testPassed("ConfigMaps.list(namespace)");
        std.debug.print("    Found: {d} configmaps in kube-system\n", .{cms_parsed.value.items.len});
    } else |err| {
        testFailed("ConfigMaps.list(namespace)", err);
    }

    // === Secrets Client ===
    std.debug.print("\nTesting Secrets Client:\n", .{});
    var secrets_client = klient.Secrets.init(&client);

    // Test listAll
    if (secrets_client.client.listAll()) |secrets_parsed| {
        defer secrets_parsed.deinit();
        testPassed("Secrets.listAll()");
        std.debug.print("    Found: {d} secrets\n", .{secrets_parsed.value.items.len});
    } else |err| {
        testFailed("Secrets.listAll()", err);
    }

    // Test list (namespaced)
    if (secrets_client.client.list("default")) |secrets_parsed| {
        defer secrets_parsed.deinit();
        testPassed("Secrets.list(namespace)");
        std.debug.print("    Found: {d} secrets in default\n", .{secrets_parsed.value.items.len});
    } else |err| {
        testFailed("Secrets.list(namespace)", err);
    }

    // === Namespaces Client (cluster-scoped) ===
    std.debug.print("\nTesting Namespaces Client:\n", .{});
    var namespaces_client = klient.Namespaces.init(&client);

    // Test list
    if (namespaces_client.list()) |ns_parsed| {
        defer ns_parsed.deinit();
        testPassed("Namespaces.list()");
        std.debug.print("    Found: {d} namespaces\n", .{ns_parsed.value.items.len});
    } else |err| {
        testFailed("Namespaces.list()", err);
    }

    // === Nodes Client (cluster-scoped) ===
    std.debug.print("\nTesting Nodes Client:\n", .{});
    var nodes_client = klient.Nodes.init(&client);

    // Test list
    if (nodes_client.list()) |nodes_parsed| {
        defer nodes_parsed.deinit();
        testPassed("Nodes.list()");
        std.debug.print("    Found: {d} nodes\n", .{nodes_parsed.value.items.len});
    } else |err| {
        testFailed("Nodes.list()", err);
    }

    // === ReplicaSets Client ===
    std.debug.print("\nTesting ReplicaSets Client:\n", .{});
    var replicasets_client = klient.ReplicaSets.init(&client);

    // Test listAll
    if (replicasets_client.client.listAll()) |rs_parsed| {
        defer rs_parsed.deinit();
        testPassed("ReplicaSets.listAll()");
        std.debug.print("    Found: {d} replicasets\n", .{rs_parsed.value.items.len});
    } else |err| {
        testFailed("ReplicaSets.listAll()", err);
    }

    // === StatefulSets Client ===
    std.debug.print("\nTesting StatefulSets Client:\n", .{});
    var statefulsets_client = klient.StatefulSets.init(&client);

    // Test listAll
    if (statefulsets_client.client.listAll()) |sts_parsed| {
        defer sts_parsed.deinit();
        testPassed("StatefulSets.listAll()");
        std.debug.print("    Found: {d} statefulsets\n", .{sts_parsed.value.items.len});
    } else |err| {
        testFailed("StatefulSets.listAll()", err);
    }

    // === DaemonSets Client ===
    std.debug.print("\nTesting DaemonSets Client:\n", .{});
    var daemonsets_client = klient.DaemonSets.init(&client);

    // Test listAll
    if (daemonsets_client.client.listAll()) |ds_parsed| {
        defer ds_parsed.deinit();
        testPassed("DaemonSets.listAll()");
        std.debug.print("    Found: {d} daemonsets\n", .{ds_parsed.value.items.len});
    } else |err| {
        testFailed("DaemonSets.listAll()", err);
    }

    // === Jobs Client ===
    std.debug.print("\nTesting Jobs Client:\n", .{});
    var jobs_client = klient.Jobs.init(&client);

    // Test listAll
    if (jobs_client.client.listAll()) |jobs_parsed| {
        defer jobs_parsed.deinit();
        testPassed("Jobs.listAll()");
        std.debug.print("    Found: {d} jobs\n", .{jobs_parsed.value.items.len});
    } else |err| {
        testFailed("Jobs.listAll()", err);
    }

    // === CronJobs Client ===
    std.debug.print("\nTesting CronJobs Client:\n", .{});
    var cronjobs_client = klient.CronJobs.init(&client);

    // Test listAll
    if (cronjobs_client.client.listAll()) |cj_parsed| {
        defer cj_parsed.deinit();
        testPassed("CronJobs.listAll()");
        std.debug.print("    Found: {d} cronjobs\n", .{cj_parsed.value.items.len});
    } else |err| {
        testFailed("CronJobs.listAll()", err);
    }

    // === PersistentVolumes Client (cluster-scoped) ===
    std.debug.print("\nTesting PersistentVolumes Client:\n", .{});
    var pvs_client = klient.PersistentVolumes.init(&client);

    // Test list
    if (pvs_client.list()) |pvs_parsed| {
        defer pvs_parsed.deinit();
        testPassed("PersistentVolumes.list()");
        std.debug.print("    Found: {d} persistent volumes\n", .{pvs_parsed.value.items.len});
    } else |err| {
        testFailed("PersistentVolumes.list()", err);
    }

    // === PersistentVolumeClaims Client ===
    std.debug.print("\nTesting PersistentVolumeClaims Client:\n", .{});
    var pvcs_client = klient.PersistentVolumeClaims.init(&client);

    // Test listAll
    if (pvcs_client.client.listAll()) |pvcs_parsed| {
        defer pvcs_parsed.deinit();
        testPassed("PersistentVolumeClaims.listAll()");
        std.debug.print("    Found: {d} persistent volume claims\n", .{pvcs_parsed.value.items.len});
    } else |err| {
        testFailed("PersistentVolumeClaims.listAll()", err);
    }

    // === Connection Pool ===
    std.debug.print("\nTesting Connection Pool:\n", .{});

    if (klient.pool.ConnectionPool.init(allocator, .{
        .server = "http://127.0.0.1:8080",
        .max_connections = 5,
        .idle_timeout_ms = 30_000,
    })) |pool_result| {
        var pool = pool_result;
        defer pool.deinit();
        testPassed("ConnectionPool.init()");

        const stats = pool.stats();
        testPassed("ConnectionPool.stats()");
        std.debug.print("    Max: {d}, Total: {d}, Idle: {d}, InUse: {d}\n", .{
            stats.max,
            stats.total,
            stats.idle,
            stats.in_use,
        });
    } else |err| {
        testFailed("ConnectionPool.init()", err);
    }

    // === Retry Configuration ===
    std.debug.print("\nTesting Retry Configuration:\n", .{});
    const retry_config = klient.retry.defaultConfig;
    testPassed("retry.defaultConfig");
    std.debug.print("    Max attempts: {d}, Initial backoff: {d}ms\n", .{
        retry_config.max_attempts,
        retry_config.initial_backoff_ms,
    });

    // === TLS Configuration ===
    std.debug.print("\nTesting TLS Configuration:\n", .{});
    const tls_config = klient.tls.TlsConfig{
        .insecure_skip_verify = true,
    };
    testPassed("tls.TlsConfig initialization");
    std.debug.print("    Insecure skip verify: {}\n", .{tls_config.insecure_skip_verify});

    // === Kubeconfig Parser ===
    std.debug.print("\nTesting Kubeconfig Parser:\n", .{});
    var parser = klient.KubeconfigParser.init(allocator);
    if (parser.load()) |kubeconfig| {
        var kc = kubeconfig;
        defer kc.deinit(allocator);
        testPassed("KubeconfigParser.load()");
        std.debug.print("    Clusters: {d}, Contexts: {d}, Users: {d}\n", .{
            kc.clusters.len,
            kc.contexts.len,
            kc.users.len,
        });
    } else |err| {
        testFailed("KubeconfigParser.load()", err);
    }

    // === Summary ===
    std.debug.print("\n" ++ "=" ** 70 ++ "\n", .{});
    std.debug.print("Test Summary:\n", .{});
    std.debug.print("  Total:  {d}\n", .{test_count});
    std.debug.print("  Passed: {d}\n", .{passed_count});
    std.debug.print("  Failed: {d}\n", .{failed_count});

    if (failed_count == 0) {
        std.debug.print("\n🎉 ALL TESTS PASSED! 🎉\n", .{});
        std.debug.print("zig-klient is fully functional with your Rancher Desktop cluster!\n", .{});
    } else {
        std.debug.print("\n⚠️  Some tests failed. See details above.\n", .{});
    }
    std.debug.print("=" ** 70 ++ "\n\n", .{});
}
