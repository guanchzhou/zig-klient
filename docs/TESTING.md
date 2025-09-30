# Testing Guide

## Test Structure

The `zig-klient` library has two types of tests:

### 1. Unit Tests (`tests/`)

Located in `tests/`, these test isolated functionality without requiring a Kubernetes cluster:

- **`retry_test.zig`** - Tests retry logic, exponential backoff, jitter, and preset configurations
- **`advanced_features_test.zig`** - Tests TLS configuration, connection pooling, and CRD API path construction

Run unit tests:
```bash
zig build test
```

Run specific test suites:
```bash
zig build test-retry      # Retry logic tests
zig build test-advanced   # Advanced features tests
```

### 2. Integration Tests (`examples/tests/`)

Located in `examples/tests/`, these test against a **real Kubernetes cluster**:

**Core Functionality:**
- `test_core_client.zig` - K8sClient initialization and cluster info
- `test_kubeconfig.zig` - Kubeconfig parsing
- `test_connection_pool.zig` - Connection pool management
- `test_retry.zig` - Retry configuration
- `test_tls.zig` - TLS configuration

**Resource Clients (14 total):**
- `test_pods.zig` - Pods client
- `test_deployments.zig` - Deployments client
- `test_services.zig` - Services client
- `test_configmaps.zig` - ConfigMaps client
- `test_secrets.zig` - Secrets client
- `test_namespaces.zig` - Namespaces client
- `test_nodes.zig` - Nodes client
- `test_replicasets.zig` - ReplicaSets client
- `test_statefulsets.zig` - StatefulSets client
- `test_daemonsets.zig` - DaemonSets client
- `test_jobs.zig` - Jobs client
- `test_cronjobs.zig` - CronJobs client
- `test_pvs.zig` - PersistentVolumes client
- `test_pvcs.zig` - PersistentVolumeClaims client

Run all integration tests:
```bash
cd examples/tests
./run_all_tests.sh
```

Run individual integration tests:
```bash
cd examples/tests
zig build
./zig-out/bin/test_pods
./zig-out/bin/test_deployments
# ... etc
```

## Prerequisites for Integration Tests

1. **Running Kubernetes cluster** (e.g., Rancher Desktop, minikube, kind)
2. **kubectl proxy** running for non-TLS testing:
   ```bash
   kubectl proxy --port=8080 &
   ```
3. **Test resources** created in cluster:
   ```bash
   kubectl apply -f examples/tests/test-resources.yaml
   ```

## Test Results

See `docs/INTEGRATION_TESTS.md` for the latest integration test results.

## Coverage

- **Unit Tests**: Isolated functionality (retry, TLS, CRD, connection pool)
- **Integration Tests**: All 19 functions verified against live cluster (100% pass rate)

## Cleanup

Remove test resources from cluster:
```bash
kubectl delete namespace klient-test
```
