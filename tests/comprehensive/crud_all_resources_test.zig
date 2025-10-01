const std = @import("std");
const klient = @import("klient");
const helpers = @import("test_helpers.zig");

/// Comprehensive CRUD test for all 15 Kubernetes resource types
/// Tests Create, Read, Update, Delete operations for each resource
const TEST_NAMESPACE = "zig-klient-crud-test";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n{'═':<80}\n", .{});
    std.debug.print("  Comprehensive CRUD Test: All 15 Resources\n", .{});
    std.debug.print("{'═':<80}\n\n", .{});

    // Verify context
    try helpers.verifyContext(allocator);

    // Initialize client
    const client = try helpers.initTestClient(allocator);
    defer helpers.deinitTestClient(client, allocator);

    // Create test namespace
    try helpers.createTestNamespace(client, TEST_NAMESPACE);
    defer helpers.deleteTestNamespace(client, TEST_NAMESPACE) catch {};

    var summary = helpers.TestSummary{};

    // Test each resource type
    testPod(allocator, client, &summary) catch |err| {
        std.debug.print("❌ Pod test failed: {s}\n", .{@errorName(err)});
        summary.recordFail();
    };

    testDeployment(allocator, client, &summary) catch |err| {
        std.debug.print("❌ Deployment test failed: {s}\n", .{@errorName(err)});
        summary.recordFail();
    };

    testService(allocator, client, &summary) catch |err| {
        std.debug.print("❌ Service test failed: {s}\n", .{@errorName(err)});
        summary.recordFail();
    };

    testConfigMap(allocator, client, &summary) catch |err| {
        std.debug.print("❌ ConfigMap test failed: {s}\n", .{@errorName(err)});
        summary.recordFail();
    };

    testSecret(allocator, client, &summary) catch |err| {
        std.debug.print("❌ Secret test failed: {s}\n", .{@errorName(err)});
        summary.recordFail();
    };

    testReplicaSet(allocator, client, &summary) catch |err| {
        std.debug.print("❌ ReplicaSet test failed: {s}\n", .{@errorName(err)});
        summary.recordFail();
    };

    testStatefulSet(allocator, client, &summary) catch |err| {
        std.debug.print("❌ StatefulSet test failed: {s}\n", .{@errorName(err)});
        summary.recordFail();
    };

    testDaemonSet(allocator, client, &summary) catch |err| {
        std.debug.print("❌ DaemonSet test failed: {s}\n", .{@errorName(err)});
        summary.recordFail();
    };

    testJob(allocator, client, &summary) catch |err| {
        std.debug.print("❌ Job test failed: {s}\n", .{@errorName(err)});
        summary.recordFail();
    };

    testCronJob(allocator, client, &summary) catch |err| {
        std.debug.print("❌ CronJob test failed: {s}\n", .{@errorName(err)});
        summary.recordFail();
    };

    testPersistentVolumeClaim(allocator, client, &summary) catch |err| {
        std.debug.print("❌ PersistentVolumeClaim test failed: {s}\n", .{@errorName(err)});
        summary.recordFail();
    };

    testIngress(allocator, client, &summary) catch |err| {
        std.debug.print("❌ Ingress test failed: {s}\n", .{@errorName(err)});
        summary.recordFail();
    };

    // Cluster-scoped resources (read-only tests)
    testNodeRead(allocator, client, &summary) catch |err| {
        std.debug.print("❌ Node read test failed: {s}\n", .{@errorName(err)});
        summary.recordFail();
    };

    testNamespaceCRUD(allocator, client, &summary) catch |err| {
        std.debug.print("❌ Namespace CRUD test failed: {s}\n", .{@errorName(err)});
        summary.recordFail();
    };

    // Print summary
    summary.print("CRUD Tests (All Resources)");

    if (summary.failed > 0) {
        std.process.exit(1);
    }
}

/// Generic CRUD test function
fn testCRUD(
    allocator: std.mem.Allocator,
    client: *klient.K8sClient,
    resource_type: []const u8,
    create_manifest: []const u8,
    update_manifest: []const u8,
    api_path: []const u8,
    resource_name: []const u8,
) !void {
    std.debug.print("\n🧪 Testing {s}...\n", .{resource_type});

    // CREATE
    std.debug.print("  1. Creating {s}...\n", .{resource_type});
    const create_response = try client.request(.POST, api_path, create_manifest);
    defer allocator.free(create_response);
    std.debug.print("  ✅ Created\n", .{});

    // Wait a bit for resource to be created
    std.time.sleep(1 * std.time.ns_per_s);

    // GET
    std.debug.print("  2. Getting {s}...\n", .{resource_type});
    const get_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ api_path, resource_name });
    defer allocator.free(get_path);

    const get_response = try client.request(.GET, get_path, null);
    defer allocator.free(get_response);
    std.debug.print("  ✅ Retrieved\n", .{});

    // LIST
    std.debug.print("  3. Listing {s}...\n", .{resource_type});
    const list_response = try client.request(.GET, api_path, null);
    defer allocator.free(list_response);
    std.debug.print("  ✅ Listed\n", .{});

    // UPDATE
    std.debug.print("  4. Updating {s}...\n", .{resource_type});
    const update_response = try client.request(.PUT, get_path, update_manifest);
    defer allocator.free(update_response);
    std.debug.print("  ✅ Updated\n", .{});

    // PATCH
    std.debug.print("  5. Patching {s}...\n", .{resource_type});
    const patch =
        \\{"metadata":{"labels":{"test-patched":"true"}}}
    ;
    const patch_response = try client.request(.PATCH, get_path, patch);
    defer allocator.free(patch_response);
    std.debug.print("  ✅ Patched\n", .{});

    // DELETE
    std.debug.print("  6. Deleting {s}...\n", .{resource_type});
    const delete_response = try client.request(.DELETE, get_path, null);
    defer allocator.free(delete_response);
    std.debug.print("  ✅ Deleted\n", .{});

    std.debug.print("✅ {s} CRUD test passed\n", .{resource_type});
}

fn testPod(allocator: std.mem.Allocator, client: *klient.K8sClient, summary: *helpers.TestSummary) !void {
    const name = "test-pod";
    const create_manifest = try helpers.createTestPodManifest(allocator, name, TEST_NAMESPACE, null);
    defer allocator.free(create_manifest);

    const update_manifest = try helpers.createTestPodManifest(
        allocator,
        name,
        TEST_NAMESPACE,
        "\"app\": \"test\", \"version\": \"v2\"",
    );
    defer allocator.free(update_manifest);

    const api_path = try std.fmt.allocPrint(allocator, "/api/v1/namespaces/{s}/pods", .{TEST_NAMESPACE});
    defer allocator.free(api_path);

    try testCRUD(allocator, client, "Pod", create_manifest, update_manifest, api_path, name);
    summary.recordPass();
}

fn testDeployment(allocator: std.mem.Allocator, client: *klient.K8sClient, summary: *helpers.TestSummary) !void {
    const name = "test-deployment";
    const create_manifest = try helpers.createTestDeploymentManifest(allocator, name, TEST_NAMESPACE, 1);
    defer allocator.free(create_manifest);

    const update_manifest = try helpers.createTestDeploymentManifest(allocator, name, TEST_NAMESPACE, 3);
    defer allocator.free(update_manifest);

    const api_path = try std.fmt.allocPrint(allocator, "/apis/apps/v1/namespaces/{s}/deployments", .{TEST_NAMESPACE});
    defer allocator.free(api_path);

    try testCRUD(allocator, client, "Deployment", create_manifest, update_manifest, api_path, name);
    summary.recordPass();
}

fn testService(allocator: std.mem.Allocator, client: *klient.K8sClient, summary: *helpers.TestSummary) !void {
    const name = "test-service";
    const create_manifest = try std.fmt.allocPrint(allocator,
        \\{{
        \\  "apiVersion": "v1",
        \\  "kind": "Service",
        \\  "metadata": {{
        \\    "name": "{s}",
        \\    "namespace": "{s}"
        \\  }},
        \\  "spec": {{
        \\    "selector": {{ "app": "test" }},
        \\    "ports": [{{ "port": 80, "targetPort": 8080 }}]
        \\  }}
        \\}}
    , .{ name, TEST_NAMESPACE });
    defer allocator.free(create_manifest);

    const update_manifest = try std.fmt.allocPrint(allocator,
        \\{{
        \\  "apiVersion": "v1",
        \\  "kind": "Service",
        \\  "metadata": {{
        \\    "name": "{s}",
        \\    "namespace": "{s}"
        \\  }},
        \\  "spec": {{
        \\    "selector": {{ "app": "test" }},
        \\    "ports": [{{ "port": 80, "targetPort": 9090 }}]
        \\  }}
        \\}}
    , .{ name, TEST_NAMESPACE });
    defer allocator.free(update_manifest);

    const api_path = try std.fmt.allocPrint(allocator, "/api/v1/namespaces/{s}/services", .{TEST_NAMESPACE});
    defer allocator.free(api_path);

    try testCRUD(allocator, client, "Service", create_manifest, update_manifest, api_path, name);
    summary.recordPass();
}

fn testConfigMap(allocator: std.mem.Allocator, client: *klient.K8sClient, summary: *helpers.TestSummary) !void {
    const name = "test-configmap";
    const create_manifest = try helpers.createTestConfigMapManifest(allocator, name, TEST_NAMESPACE);
    defer allocator.free(create_manifest);

    const update_manifest = try std.fmt.allocPrint(allocator,
        \\{{
        \\  "apiVersion": "v1",
        \\  "kind": "ConfigMap",
        \\  "metadata": {{
        \\    "name": "{s}",
        \\    "namespace": "{s}"
        \\  }},
        \\  "data": {{
        \\    "key1": "updated-value1",
        \\    "key3": "value3"
        \\  }}
        \\}}
    , .{ name, TEST_NAMESPACE });
    defer allocator.free(update_manifest);

    const api_path = try std.fmt.allocPrint(allocator, "/api/v1/namespaces/{s}/configmaps", .{TEST_NAMESPACE});
    defer allocator.free(api_path);

    try testCRUD(allocator, client, "ConfigMap", create_manifest, update_manifest, api_path, name);
    summary.recordPass();
}

fn testSecret(allocator: std.mem.Allocator, client: *klient.K8sClient, summary: *helpers.TestSummary) !void {
    const name = "test-secret";

    // Base64 encode values
    const create_manifest = try std.fmt.allocPrint(allocator,
        \\{{
        \\  "apiVersion": "v1",
        \\  "kind": "Secret",
        \\  "metadata": {{
        \\    "name": "{s}",
        \\    "namespace": "{s}"
        \\  }},
        \\  "type": "Opaque",
        \\  "data": {{
        \\    "username": "YWRtaW4=",
        \\    "password": "cGFzc3dvcmQ="
        \\  }}
        \\}}
    , .{ name, TEST_NAMESPACE });
    defer allocator.free(create_manifest);

    const update_manifest = try std.fmt.allocPrint(allocator,
        \\{{
        \\  "apiVersion": "v1",
        \\  "kind": "Secret",
        \\  "metadata": {{
        \\    "name": "{s}",
        \\    "namespace": "{s}"
        \\  }},
        \\  "type": "Opaque",
        \\  "data": {{
        \\    "username": "YWRtaW4=",
        \\    "password": "bmV3cGFzc3dvcmQ="
        \\  }}
        \\}}
    , .{ name, TEST_NAMESPACE });
    defer allocator.free(update_manifest);

    const api_path = try std.fmt.allocPrint(allocator, "/api/v1/namespaces/{s}/secrets", .{TEST_NAMESPACE});
    defer allocator.free(api_path);

    try testCRUD(allocator, client, "Secret", create_manifest, update_manifest, api_path, name);
    summary.recordPass();
}

fn testReplicaSet(allocator: std.mem.Allocator, client: *klient.K8sClient, summary: *helpers.TestSummary) !void {
    const name = "test-replicaset";
    const create_manifest = try std.fmt.allocPrint(allocator,
        \\{{
        \\  "apiVersion": "apps/v1",
        \\  "kind": "ReplicaSet",
        \\  "metadata": {{
        \\    "name": "{s}",
        \\    "namespace": "{s}"
        \\  }},
        \\  "spec": {{
        \\    "replicas": 1,
        \\    "selector": {{ "matchLabels": {{ "app": "{s}" }} }},
        \\    "template": {{
        \\      "metadata": {{ "labels": {{ "app": "{s}" }} }},
        \\      "spec": {{
        \\        "containers": [{{
        \\          "name": "nginx",
        \\          "image": "nginx:alpine"
        \\        }}]
        \\      }}
        \\    }}
        \\  }}
        \\}}
    , .{ name, TEST_NAMESPACE, name, name });
    defer allocator.free(create_manifest);

    const update_manifest = try std.fmt.allocPrint(allocator,
        \\{{
        \\  "apiVersion": "apps/v1",
        \\  "kind": "ReplicaSet",
        \\  "metadata": {{
        \\    "name": "{s}",
        \\    "namespace": "{s}"
        \\  }},
        \\  "spec": {{
        \\    "replicas": 2,
        \\    "selector": {{ "matchLabels": {{ "app": "{s}" }} }},
        \\    "template": {{
        \\      "metadata": {{ "labels": {{ "app": "{s}" }} }},
        \\      "spec": {{
        \\        "containers": [{{
        \\          "name": "nginx",
        \\          "image": "nginx:alpine"
        \\        }}]
        \\      }}
        \\    }}
        \\  }}
        \\}}
    , .{ name, TEST_NAMESPACE, name, name });
    defer allocator.free(update_manifest);

    const api_path = try std.fmt.allocPrint(allocator, "/apis/apps/v1/namespaces/{s}/replicasets", .{TEST_NAMESPACE});
    defer allocator.free(api_path);

    try testCRUD(allocator, client, "ReplicaSet", create_manifest, update_manifest, api_path, name);
    summary.recordPass();
}

fn testStatefulSet(allocator: std.mem.Allocator, client: *klient.K8sClient, summary: *helpers.TestSummary) !void {
    const name = "test-statefulset";
    const create_manifest = try std.fmt.allocPrint(allocator,
        \\{{
        \\  "apiVersion": "apps/v1",
        \\  "kind": "StatefulSet",
        \\  "metadata": {{
        \\    "name": "{s}",
        \\    "namespace": "{s}"
        \\  }},
        \\  "spec": {{
        \\    "serviceName": "{s}",
        \\    "replicas": 1,
        \\    "selector": {{ "matchLabels": {{ "app": "{s}" }} }},
        \\    "template": {{
        \\      "metadata": {{ "labels": {{ "app": "{s}" }} }},
        \\      "spec": {{
        \\        "containers": [{{
        \\          "name": "nginx",
        \\          "image": "nginx:alpine"
        \\        }}]
        \\      }}
        \\    }}
        \\  }}
        \\}}
    , .{ name, TEST_NAMESPACE, name, name, name });
    defer allocator.free(create_manifest);

    const update_manifest = try std.fmt.allocPrint(allocator,
        \\{{
        \\  "apiVersion": "apps/v1",
        \\  "kind": "StatefulSet",
        \\  "metadata": {{
        \\    "name": "{s}",
        \\    "namespace": "{s}"
        \\  }},
        \\  "spec": {{
        \\    "serviceName": "{s}",
        \\    "replicas": 2,
        \\    "selector": {{ "matchLabels": {{ "app": "{s}" }} }},
        \\    "template": {{
        \\      "metadata": {{ "labels": {{ "app": "{s}" }} }},
        \\      "spec": {{
        \\        "containers": [{{
        \\          "name": "nginx",
        \\          "image": "nginx:alpine"
        \\        }}]
        \\      }}
        \\    }}
        \\  }}
        \\}}
    , .{ name, TEST_NAMESPACE, name, name, name });
    defer allocator.free(update_manifest);

    const api_path = try std.fmt.allocPrint(allocator, "/apis/apps/v1/namespaces/{s}/statefulsets", .{TEST_NAMESPACE});
    defer allocator.free(api_path);

    try testCRUD(allocator, client, "StatefulSet", create_manifest, update_manifest, api_path, name);
    summary.recordPass();
}

fn testDaemonSet(allocator: std.mem.Allocator, client: *klient.K8sClient, summary: *helpers.TestSummary) !void {
    const name = "test-daemonset";
    const create_manifest = try std.fmt.allocPrint(allocator,
        \\{{
        \\  "apiVersion": "apps/v1",
        \\  "kind": "DaemonSet",
        \\  "metadata": {{
        \\    "name": "{s}",
        \\    "namespace": "{s}"
        \\  }},
        \\  "spec": {{
        \\    "selector": {{ "matchLabels": {{ "app": "{s}" }} }},
        \\    "template": {{
        \\      "metadata": {{ "labels": {{ "app": "{s}" }} }},
        \\      "spec": {{
        \\        "containers": [{{
        \\          "name": "nginx",
        \\          "image": "nginx:alpine"
        \\        }}]
        \\      }}
        \\    }}
        \\  }}
        \\}}
    , .{ name, TEST_NAMESPACE, name, name });
    defer allocator.free(create_manifest);

    const update_manifest = try std.fmt.allocPrint(allocator,
        \\{{
        \\  "apiVersion": "apps/v1",
        \\  "kind": "DaemonSet",
        \\  "metadata": {{
        \\    "name": "{s}",
        \\    "namespace": "{s}",
        \\    "labels": {{ "version": "v2" }}
        \\  }},
        \\  "spec": {{
        \\    "selector": {{ "matchLabels": {{ "app": "{s}" }} }},
        \\    "template": {{
        \\      "metadata": {{ "labels": {{ "app": "{s}" }} }},
        \\      "spec": {{
        \\        "containers": [{{
        \\          "name": "nginx",
        \\          "image": "nginx:alpine"
        \\        }}]
        \\      }}
        \\    }}
        \\  }}
        \\}}
    , .{ name, TEST_NAMESPACE, name, name });
    defer allocator.free(update_manifest);

    const api_path = try std.fmt.allocPrint(allocator, "/apis/apps/v1/namespaces/{s}/daemonsets", .{TEST_NAMESPACE});
    defer allocator.free(api_path);

    try testCRUD(allocator, client, "DaemonSet", create_manifest, update_manifest, api_path, name);
    summary.recordPass();
}

fn testJob(allocator: std.mem.Allocator, client: *klient.K8sClient, summary: *helpers.TestSummary) !void {
    const name = "test-job";
    const create_manifest = try std.fmt.allocPrint(allocator,
        \\{{
        \\  "apiVersion": "batch/v1",
        \\  "kind": "Job",
        \\  "metadata": {{
        \\    "name": "{s}",
        \\    "namespace": "{s}"
        \\  }},
        \\  "spec": {{
        \\    "template": {{
        \\      "spec": {{
        \\        "containers": [{{
        \\          "name": "job",
        \\          "image": "busybox",
        \\          "command": ["echo", "hello"]
        \\        }}],
        \\        "restartPolicy": "Never"
        \\      }}
        \\    }}
        \\  }}
        \\}}
    , .{ name, TEST_NAMESPACE });
    defer allocator.free(create_manifest);

    const update_manifest = try std.fmt.allocPrint(allocator,
        \\{{
        \\  "apiVersion": "batch/v1",
        \\  "kind": "Job",
        \\  "metadata": {{
        \\    "name": "{s}",
        \\    "namespace": "{s}",
        \\    "labels": {{ "version": "v2" }}
        \\  }},
        \\  "spec": {{
        \\    "template": {{
        \\      "spec": {{
        \\        "containers": [{{
        \\          "name": "job",
        \\          "image": "busybox",
        \\          "command": ["echo", "hello"]
        \\        }}],
        \\        "restartPolicy": "Never"
        \\      }}
        \\    }}
        \\  }}
        \\}}
    , .{ name, TEST_NAMESPACE });
    defer allocator.free(update_manifest);

    const api_path = try std.fmt.allocPrint(allocator, "/apis/batch/v1/namespaces/{s}/jobs", .{TEST_NAMESPACE});
    defer allocator.free(api_path);

    try testCRUD(allocator, client, "Job", create_manifest, update_manifest, api_path, name);
    summary.recordPass();
}

fn testCronJob(allocator: std.mem.Allocator, client: *klient.K8sClient, summary: *helpers.TestSummary) !void {
    const name = "test-cronjob";
    const create_manifest = try std.fmt.allocPrint(allocator,
        \\{{
        \\  "apiVersion": "batch/v1",
        \\  "kind": "CronJob",
        \\  "metadata": {{
        \\    "name": "{s}",
        \\    "namespace": "{s}"
        \\  }},
        \\  "spec": {{
        \\    "schedule": "0 0 * * *",
        \\    "jobTemplate": {{
        \\      "spec": {{
        \\        "template": {{
        \\          "spec": {{
        \\            "containers": [{{
        \\              "name": "job",
        \\              "image": "busybox",
        \\              "command": ["echo", "hello"]
        \\            }}],
        \\            "restartPolicy": "OnFailure"
        \\          }}
        \\        }}
        \\      }}
        \\    }}
        \\  }}
        \\}}
    , .{ name, TEST_NAMESPACE });
    defer allocator.free(create_manifest);

    const update_manifest = try std.fmt.allocPrint(allocator,
        \\{{
        \\  "apiVersion": "batch/v1",
        \\  "kind": "CronJob",
        \\  "metadata": {{
        \\    "name": "{s}",
        \\    "namespace": "{s}"
        \\  }},
        \\  "spec": {{
        \\    "schedule": "0 12 * * *",
        \\    "jobTemplate": {{
        \\      "spec": {{
        \\        "template": {{
        \\          "spec": {{
        \\            "containers": [{{
        \\              "name": "job",
        \\              "image": "busybox",
        \\              "command": ["echo", "hello"]
        \\            }}],
        \\            "restartPolicy": "OnFailure"
        \\          }}
        \\        }}
        \\      }}
        \\    }}
        \\  }}
        \\}}
    , .{ name, TEST_NAMESPACE });
    defer allocator.free(update_manifest);

    const api_path = try std.fmt.allocPrint(allocator, "/apis/batch/v1/namespaces/{s}/cronjobs", .{TEST_NAMESPACE});
    defer allocator.free(api_path);

    try testCRUD(allocator, client, "CronJob", create_manifest, update_manifest, api_path, name);
    summary.recordPass();
}

fn testPersistentVolumeClaim(allocator: std.mem.Allocator, client: *klient.K8sClient, summary: *helpers.TestSummary) !void {
    const name = "test-pvc";
    const create_manifest = try std.fmt.allocPrint(allocator,
        \\{{
        \\  "apiVersion": "v1",
        \\  "kind": "PersistentVolumeClaim",
        \\  "metadata": {{
        \\    "name": "{s}",
        \\    "namespace": "{s}"
        \\  }},
        \\  "spec": {{
        \\    "accessModes": ["ReadWriteOnce"],
        \\    "resources": {{
        \\      "requests": {{ "storage": "1Gi" }}
        \\    }}
        \\  }}
        \\}}
    , .{ name, TEST_NAMESPACE });
    defer allocator.free(create_manifest);

    const update_manifest = try std.fmt.allocPrint(allocator,
        \\{{
        \\  "apiVersion": "v1",
        \\  "kind": "PersistentVolumeClaim",
        \\  "metadata": {{
        \\    "name": "{s}",
        \\    "namespace": "{s}",
        \\    "labels": {{ "version": "v2" }}
        \\  }},
        \\  "spec": {{
        \\    "accessModes": ["ReadWriteOnce"],
        \\    "resources": {{
        \\      "requests": {{ "storage": "1Gi" }}
        \\    }}
        \\  }}
        \\}}
    , .{ name, TEST_NAMESPACE });
    defer allocator.free(update_manifest);

    const api_path = try std.fmt.allocPrint(allocator, "/api/v1/namespaces/{s}/persistentvolumeclaims", .{TEST_NAMESPACE});
    defer allocator.free(api_path);

    try testCRUD(allocator, client, "PersistentVolumeClaim", create_manifest, update_manifest, api_path, name);
    summary.recordPass();
}

fn testIngress(allocator: std.mem.Allocator, client: *klient.K8sClient, summary: *helpers.TestSummary) !void {
    const name = "test-ingress";
    const create_manifest = try std.fmt.allocPrint(allocator,
        \\{{
        \\  "apiVersion": "networking.k8s.io/v1",
        \\  "kind": "Ingress",
        \\  "metadata": {{
        \\    "name": "{s}",
        \\    "namespace": "{s}"
        \\  }},
        \\  "spec": {{
        \\    "rules": [{{
        \\      "host": "example.com",
        \\      "http": {{
        \\        "paths": [{{
        \\          "path": "/",
        \\          "pathType": "Prefix",
        \\          "backend": {{
        \\            "service": {{
        \\              "name": "test-service",
        \\              "port": {{ "number": 80 }}
        \\            }}
        \\          }}
        \\        }}]
        \\      }}
        \\    }}]
        \\  }}
        \\}}
    , .{ name, TEST_NAMESPACE });
    defer allocator.free(create_manifest);

    const update_manifest = try std.fmt.allocPrint(allocator,
        \\{{
        \\  "apiVersion": "networking.k8s.io/v1",
        \\  "kind": "Ingress",
        \\  "metadata": {{
        \\    "name": "{s}",
        \\    "namespace": "{s}",
        \\    "labels": {{ "version": "v2" }}
        \\  }},
        \\  "spec": {{
        \\    "rules": [{{
        \\      "host": "example.com",
        \\      "http": {{
        \\        "paths": [{{
        \\          "path": "/",
        \\          "pathType": "Prefix",
        \\          "backend": {{
        \\            "service": {{
        \\              "name": "test-service",
        \\              "port": {{ "number": 80 }}
        \\            }}
        \\          }}
        \\        }}]
        \\      }}
        \\    }}]
        \\  }}
        \\}}
    , .{ name, TEST_NAMESPACE });
    defer allocator.free(update_manifest);

    const api_path = try std.fmt.allocPrint(allocator, "/apis/networking.k8s.io/v1/namespaces/{s}/ingresses", .{TEST_NAMESPACE});
    defer allocator.free(api_path);

    try testCRUD(allocator, client, "Ingress", create_manifest, update_manifest, api_path, name);
    summary.recordPass();
}

fn testNodeRead(allocator: std.mem.Allocator, client: *klient.K8sClient, summary: *helpers.TestSummary) !void {
    std.debug.print("\n🧪 Testing Node (read-only)...\n", .{});

    // LIST
    std.debug.print("  1. Listing Nodes...\n", .{});
    const list_response = try client.request(.GET, "/api/v1/nodes", null);
    defer allocator.free(list_response);
    std.debug.print("  ✅ Listed\n", .{});

    // Parse to get first node name
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, list_response, .{});
    defer parsed.deinit();

    const items = parsed.value.object.get("items").?.array;
    if (items.items.len == 0) {
        std.debug.print("  ⚠️  No nodes found, skipping read test\n", .{});
        summary.recordSkip();
        return;
    }

    const node_name = items.items[0].object.get("metadata").?.object.get("name").?.string;

    // GET
    std.debug.print("  2. Getting Node {s}...\n", .{node_name});
    const get_path = try std.fmt.allocPrint(allocator, "/api/v1/nodes/{s}", .{node_name});
    defer allocator.free(get_path);

    const get_response = try client.request(.GET, get_path, null);
    defer allocator.free(get_response);
    std.debug.print("  ✅ Retrieved\n", .{});

    std.debug.print("✅ Node read test passed\n", .{});
    summary.recordPass();
}

fn testNamespaceCRUD(allocator: std.mem.Allocator, client: *klient.K8sClient, summary: *helpers.TestSummary) !void {
    const name = "test-namespace-crud";
    const create_manifest = try std.fmt.allocPrint(allocator,
        \\{{
        \\  "apiVersion": "v1",
        \\  "kind": "Namespace",
        \\  "metadata": {{
        \\    "name": "{s}"
        \\  }}
        \\}}
    , .{name});
    defer allocator.free(create_manifest);

    const update_manifest = try std.fmt.allocPrint(allocator,
        \\{{
        \\  "apiVersion": "v1",
        \\  "kind": "Namespace",
        \\  "metadata": {{
        \\    "name": "{s}",
        \\    "labels": {{ "test": "updated" }}
        \\  }}
        \\}}
    , .{name});
    defer allocator.free(update_manifest);

    try testCRUD(allocator, client, "Namespace", create_manifest, update_manifest, "/api/v1/namespaces", name);
    summary.recordPass();
}
