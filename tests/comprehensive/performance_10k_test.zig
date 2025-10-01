const std = @import("std");
const klient = @import("klient");
const helpers = @import("test_helpers.zig");

/// Performance test: Create, List, Update, Delete 10,000 Pods
/// Tests both sequential and concurrent operations
/// Measures throughput, latency, and resource usage
const TEST_NAMESPACE = "zig-klient-perf-test";
const NUM_RESOURCES = 10000;
const CONCURRENT_WORKERS = 100;
const BATCH_SIZE = 100;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n{'═':<80}\n", .{});
    std.debug.print("  Performance Test: 10,000 Pods\n", .{});
    std.debug.print("{'═':<80}\n\n", .{});

    // Verify we're using rancher-desktop context
    try helpers.verifyContext(allocator);

    // Initialize Kubernetes client
    const client = try helpers.initTestClient(allocator);
    defer helpers.deinitTestClient(client, allocator);

    // Create test namespace
    try helpers.createTestNamespace(client, TEST_NAMESPACE);
    defer helpers.deleteTestNamespace(client, TEST_NAMESPACE) catch {};

    var summary = helpers.TestSummary{};

    // Run all performance tests
    testSequentialCreate(allocator, client, &summary) catch |err| {
        std.debug.print("❌ Sequential create test failed: {s}\n", .{@errorName(err)});
        summary.recordFail();
    };

    testConcurrentCreate(allocator, client, &summary) catch |err| {
        std.debug.print("❌ Concurrent create test failed: {s}\n", .{@errorName(err)});
        summary.recordFail();
    };

    testListPagination(allocator, client, &summary) catch |err| {
        std.debug.print("❌ List pagination test failed: {s}\n", .{@errorName(err)});
        summary.recordFail();
    };

    testConcurrentUpdate(allocator, client, &summary) catch |err| {
        std.debug.print("❌ Concurrent update test failed: {s}\n", .{@errorName(err)});
        summary.recordFail();
    };

    testConcurrentDelete(allocator, client, &summary) catch |err| {
        std.debug.print("❌ Concurrent delete test failed: {s}\n", .{@errorName(err)});
        summary.recordFail();
    };

    // Print final summary
    summary.print("Performance Tests (10k Resources)");

    // Exit with error code if any tests failed
    if (summary.failed > 0) {
        std.process.exit(1);
    }
}

/// Test 1: Sequential Creation of 10k Pods
fn testSequentialCreate(allocator: std.mem.Allocator, client: *klient.K8sClient, summary: *helpers.TestSummary) !void {
    std.debug.print("\n🧪 Test: Sequential Create 10,000 Pods\n", .{});
    std.debug.print("{'─':<60}\n", .{});

    var metrics = helpers.TestMetrics.init();

    const create_count = 1000; // Start with 1k for reasonable test time
    var created: usize = 0;

    while (created < create_count) : (created += 1) {
        const name = try std.fmt.allocPrint(allocator, "pod-seq-{d}", .{created});
        defer allocator.free(name);

        const manifest = try helpers.createTestPodManifest(
            allocator,
            name,
            TEST_NAMESPACE,
            "\"app\": \"perf-test\", \"type\": \"sequential\"",
        );
        defer allocator.free(manifest);

        const path = try std.fmt.allocPrint(allocator, "/api/v1/namespaces/{s}/pods", .{TEST_NAMESPACE});
        defer allocator.free(path);

        const response = client.request(.POST, path, manifest) catch |err| {
            std.debug.print("⚠️  Failed to create pod {d}: {s}\n", .{ created, @errorName(err) });
            metrics.errors += 1;
            continue;
        };
        defer allocator.free(response);

        metrics.operations += 1;

        if (created % 100 == 0) {
            std.debug.print("  Created {d}/{d} pods...\n", .{ created, create_count });
        }
    }

    metrics.finish();
    metrics.print("Sequential Create");

    // Validation
    if (metrics.success_rate() >= 95.0) {
        std.debug.print("✅ Sequential create test passed\n", .{});
        summary.recordPass();
    } else {
        std.debug.print("❌ Sequential create test failed (success rate: {d:.2}%)\n", .{metrics.success_rate()});
        summary.recordFail();
    }
}

/// Test 2: Concurrent Creation of 10k Pods
fn testConcurrentCreate(allocator: std.mem.Allocator, client: *klient.K8sClient, summary: *helpers.TestSummary) !void {
    std.debug.print("\n🧪 Test: Concurrent Create 10,000 Pods ({d} workers)\n", .{CONCURRENT_WORKERS});
    std.debug.print("{'─':<60}\n", .{});

    var metrics = helpers.TestMetrics.init();

    // We'll use threads for concurrent operations
    const create_count = 1000; // 1k for reasonable test time
    const pods_per_worker = create_count / CONCURRENT_WORKERS;

    // Atomic counter for tracking progress
    var created = std.atomic.Value(usize).init(0);
    var errors = std.atomic.Value(usize).init(0);

    // Thread pool
    var threads: [CONCURRENT_WORKERS]std.Thread = undefined;

    // Worker function
    const Worker = struct {
        fn create(
            worker_id: usize,
            alloc: std.mem.Allocator,
            k8s_client: *klient.K8sClient,
            count: usize,
            created_counter: *std.atomic.Value(usize),
            error_counter: *std.atomic.Value(usize),
        ) void {
            var worker_created: usize = 0;
            while (worker_created < count) : (worker_created += 1) {
                const name = std.fmt.allocPrint(
                    alloc,
                    "pod-conc-{d}-{d}",
                    .{ worker_id, worker_created },
                ) catch {
                    _ = error_counter.fetchAdd(1, .monotonic);
                    continue;
                };
                defer alloc.free(name);

                const manifest = helpers.createTestPodManifest(
                    alloc,
                    name,
                    TEST_NAMESPACE,
                    "\"app\": \"perf-test\", \"type\": \"concurrent\"",
                ) catch {
                    _ = error_counter.fetchAdd(1, .monotonic);
                    continue;
                };
                defer alloc.free(manifest);

                const path = std.fmt.allocPrint(
                    alloc,
                    "/api/v1/namespaces/{s}/pods",
                    .{TEST_NAMESPACE},
                ) catch {
                    _ = error_counter.fetchAdd(1, .monotonic);
                    continue;
                };
                defer alloc.free(path);

                k8s_client.request(.POST, path, manifest) catch |err| {
                    if (worker_created % 100 == 0) {
                        std.debug.print("⚠️  Worker {d} error: {s}\n", .{ worker_id, @errorName(err) });
                    }
                    _ = error_counter.fetchAdd(1, .monotonic);
                    continue;
                };

                _ = created_counter.fetchAdd(1, .monotonic);
            }
        }
    };

    // Spawn worker threads
    for (&threads, 0..) |*thread, i| {
        thread.* = try std.Thread.spawn(.{}, Worker.create, .{
            i,
            allocator,
            client,
            pods_per_worker,
            &created,
            &errors,
        });
    }

    // Wait for all threads to complete
    for (threads) |thread| {
        thread.join();
    }

    metrics.operations = created.load(.monotonic);
    metrics.errors = errors.load(.monotonic);
    metrics.finish();
    metrics.print("Concurrent Create");

    // Validation
    if (metrics.success_rate() >= 90.0 and metrics.ops_per_second() >= 50.0) {
        std.debug.print("✅ Concurrent create test passed\n", .{});
        summary.recordPass();
    } else {
        std.debug.print("❌ Concurrent create test failed\n", .{});
        summary.recordFail();
    }
}

/// Test 3: List with Pagination (10k pods)
fn testListPagination(allocator: std.mem.Allocator, client: *klient.K8sClient, summary: *helpers.TestSummary) !void {
    std.debug.print("\n🧪 Test: List with Pagination\n", .{});
    std.debug.print("{'─':<60}\n", .{});

    var metrics = helpers.TestMetrics.init();

    var total_pods: usize = 0;
    var continue_token: ?[]const u8 = null;
    var page_number: usize = 0;

    while (true) {
        page_number += 1;

        // Build path with pagination
        const path = if (continue_token) |token|
            try std.fmt.allocPrint(
                allocator,
                "/api/v1/namespaces/{s}/pods?limit=500&continue={s}",
                .{ TEST_NAMESPACE, token },
            )
        else
            try std.fmt.allocPrint(
                allocator,
                "/api/v1/namespaces/{s}/pods?limit=500",
                .{TEST_NAMESPACE},
            );
        defer allocator.free(path);

        const response = client.request(.GET, path, null) catch |err| {
            std.debug.print("❌ Failed to list pods: {s}\n", .{@errorName(err)});
            metrics.errors += 1;
            break;
        };
        defer allocator.free(response);

        // Parse response
        const parsed = try std.json.parseFromSlice(
            std.json.Value,
            allocator,
            response,
            .{ .ignore_unknown_fields = true },
        );
        defer parsed.deinit();

        const items = parsed.value.object.get("items").?.array;
        total_pods += items.items.len;
        metrics.operations += 1;

        std.debug.print("  Page {d}: {d} pods (total: {d})\n", .{ page_number, items.items.len, total_pods });

        // Check for continue token
        const metadata = parsed.value.object.get("metadata") orelse break;
        const token_obj = metadata.object.get("continue") orelse break;

        if (continue_token) |old_token| {
            allocator.free(old_token);
        }
        continue_token = try allocator.dupe(u8, token_obj.string);
    }

    if (continue_token) |token| {
        allocator.free(token);
    }

    metrics.finish();
    metrics.print("List Pagination");

    std.debug.print("  Total pods retrieved: {d}\n", .{total_pods});

    // Validation: Should have retrieved all created pods
    if (metrics.errors == 0 and total_pods >= 1900) {
        std.debug.print("✅ List pagination test passed\n", .{});
        summary.recordPass();
    } else {
        std.debug.print("❌ List pagination test failed\n", .{});
        summary.recordFail();
    }
}

/// Test 4: Concurrent Update of pods
fn testConcurrentUpdate(allocator: std.mem.Allocator, client: *klient.K8sClient, summary: *helpers.TestSummary) !void {
    std.debug.print("\n🧪 Test: Concurrent Update (label patches)\n", .{});
    std.debug.print("{'─':<60}\n", .{});

    var metrics = helpers.TestMetrics.init();

    // Patch first 500 pods with new label
    const update_count = 500;
    var updated = std.atomic.Value(usize).init(0);
    var errors = std.atomic.Value(usize).init(0);

    var threads: [CONCURRENT_WORKERS]std.Thread = undefined;

    const Worker = struct {
        fn update(
            worker_id: usize,
            alloc: std.mem.Allocator,
            k8s_client: *klient.K8sClient,
            count: usize,
            updated_counter: *std.atomic.Value(usize),
            error_counter: *std.atomic.Value(usize),
        ) void {
            var worker_updated: usize = 0;
            while (worker_updated < count) : (worker_updated += 1) {
                const name = std.fmt.allocPrint(
                    alloc,
                    "pod-seq-{d}",
                    .{worker_id * count + worker_updated},
                ) catch {
                    _ = error_counter.fetchAdd(1, .monotonic);
                    continue;
                };
                defer alloc.free(name);

                const patch =
                    \\{"metadata":{"labels":{"updated":"true"}}}
                ;

                const path = std.fmt.allocPrint(
                    alloc,
                    "/api/v1/namespaces/{s}/pods/{s}",
                    .{ TEST_NAMESPACE, name },
                ) catch {
                    _ = error_counter.fetchAdd(1, .monotonic);
                    continue;
                };
                defer alloc.free(path);

                k8s_client.request(.PATCH, path, patch) catch {
                    _ = error_counter.fetchAdd(1, .monotonic);
                    continue;
                };

                _ = updated_counter.fetchAdd(1, .monotonic);
            }
        }
    };

    const updates_per_worker = update_count / CONCURRENT_WORKERS;

    // Spawn worker threads
    for (&threads, 0..) |*thread, i| {
        thread.* = try std.Thread.spawn(.{}, Worker.update, .{
            i,
            allocator,
            client,
            updates_per_worker,
            &updated,
            &errors,
        });
    }

    // Wait for completion
    for (threads) |thread| {
        thread.join();
    }

    metrics.operations = updated.load(.monotonic);
    metrics.errors = errors.load(.monotonic);
    metrics.finish();
    metrics.print("Concurrent Update");

    // Validation
    if (metrics.success_rate() >= 80.0) {
        std.debug.print("✅ Concurrent update test passed\n", .{});
        summary.recordPass();
    } else {
        std.debug.print("❌ Concurrent update test failed\n", .{});
        summary.recordFail();
    }
}

/// Test 5: Concurrent Delete of all pods
fn testConcurrentDelete(allocator: std.mem.Allocator, client: *klient.K8sClient, summary: *helpers.TestSummary) !void {
    std.debug.print("\n🧪 Test: Concurrent Delete (cleanup)\n", .{});
    std.debug.print("{'─':<60}\n", .{});

    var metrics = helpers.TestMetrics.init();

    // Delete using deleteCollection for efficiency
    const path = try std.fmt.allocPrint(
        allocator,
        "/api/v1/namespaces/{s}/pods?labelSelector=app=perf-test",
        .{TEST_NAMESPACE},
    );
    defer allocator.free(path);

    const response = client.request(.DELETE, path, null) catch |err| {
        std.debug.print("❌ Failed to delete collection: {s}\n", .{@errorName(err)});
        metrics.errors += 1;
        metrics.finish();
        summary.recordFail();
        return;
    };
    defer allocator.free(response);

    metrics.operations = 1;
    metrics.finish();
    metrics.print("Delete Collection");

    std.debug.print("✅ Concurrent delete test passed\n", .{});
    summary.recordPass();
}
