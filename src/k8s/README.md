# Kubernetes Client Module

Native Zig implementation of a Kubernetes API client for c3s.

## Overview

This module provides a lightweight Kubernetes client that:
- Reads kubeconfig files (`~/.kube/config`)
- Authenticates with Kubernetes API servers (token, cert-based)
- Fetches cluster information and resources
- Falls back to fixtures when cluster is unavailable

## Architecture

```
k8s/
├── client.zig         # HTTP REST API client for K8s
├── kubeconfig.zig     # Kubeconfig parser (YAML)
├── manager.zig        # High-level K8s operations manager
├── index.zig          # Module exports
└── README.md          # This file
```

## Components

### K8sClient (`client.zig`)
Low-level HTTP client that communicates with the Kubernetes API server.

**Features:**
- REST API calls (GET, POST, DELETE)
- Bearer token authentication
- JSON response parsing
- Pod listing (namespace-scoped and cluster-wide)
- Cluster version and metrics

**Usage:**
```zig
const config = KubeConfig{
    .server = "https://kubernetes.default.svc",
    .token = "eyJhbGciOi...",
    .namespace = "default",
};

var client = try K8sClient.init(allocator, config);
defer client.deinit();

const pods = try client.listPods();
defer allocator.free(pods);
```

### KubeconfigParser (`kubeconfig.zig`)
Parses `~/.kube/config` files to extract cluster configuration.

**Features:**
- YAML parsing (simple implementation)
- Supports multiple clusters, contexts, and users
- Reads current-context
- Handles token and cert-based auth

**Usage:**
```zig
var parser = KubeconfigParser.init(allocator);
var kubeconfig = try parser.load();
defer kubeconfig.deinit(allocator);

const context = kubeconfig.getCurrentContext().?;
const cluster = kubeconfig.getCluster(context.cluster).?;
```

**Kubeconfig Structure:**
```yaml
current-context: my-context
clusters:
- name: my-cluster
  server: https://api.example.com
contexts:
- name: my-context
  cluster: my-cluster
  user: my-user
  namespace: default
users:
- name: my-user
  token: eyJhbGci...
  # OR
  client-certificate: /path/to/cert
  client-key: /path/to/key
```

### K8sManager (`manager.zig`)
High-level interface that coordinates kubeconfig parsing and API client.

**Features:**
- Automatic kubeconfig loading
- Cluster connection management
- Fallback to fixtures when disconnected
- Unified API for cluster data and pods

**Usage:**
```zig
var manager = K8sManager.init(allocator);
defer manager.deinit();

// Connect to cluster (non-fatal if fails)
manager.connect() catch |err| {
    std.log.warn("K8s connection failed: {}", .{err});
};

// Get pods (returns fixtures if not connected)
const pods = try manager.getPods();
defer allocator.free(pods);

// Get cluster info (returns fixtures if not connected)
const info = try manager.getClusterInfo();
defer info.deinit(allocator);
```

## Integration with c3s

### Application Initialization
The K8s manager is initialized in `app.zig`:

```zig
// Initialize Kubernetes manager
var k8s_manager = k8s.K8sManager.init(allocator);

// Try to connect (non-fatal)
k8s_manager.connect() catch |err| {
    Logger.warn("Failed to connect to Kubernetes: {}. Using fixtures.", .{err});
};

// Get cluster data for header
const cluster_data = try k8s_manager.getClusterInfo();
defer cluster_data.deinit(allocator);

var header = try Header.initWithData(allocator, theme, cluster_data);
```

### Pod Data Loading
Pods are loaded from K8s in `pods_view.zig`:

```zig
if (k8s_manager.isConnected()) {
    const k8s_pods = try k8s_manager.getPods();
    defer allocator.free(k8s_pods);
    
    try app.pods_view.loadPodsFromK8s(k8s_pods);
    Logger.info("Loaded {d} pods from Kubernetes cluster", .{k8s_pods.len});
}
```

## Data Structures

### Pod
```zig
pub const Pod = struct {
    name: []const u8,
    namespace: []const u8,
    ready: []const u8,        // e.g., "1/1"
    status: []const u8,       // e.g., "Running"
    restarts: u32,
    age: []const u8,          // e.g., "2d"
    node: []const u8,         // node name
    ip: []const u8,           // pod IP
    cpu_usage: []const u8,    // TODO: from metrics API
    mem_usage: []const u8,    // TODO: from metrics API
};
```

### ClusterData
```zig
pub const ClusterData = struct {
    context: []const u8,
    cluster: []const u8,
    user: []const u8,
    k8s_version: []const u8,  // e.g., "v1.29.2"
    cpu_usage: u8,            // percentage
    mem_usage: u8,            // percentage
};
```

## Supported Features

✅ **Implemented:**
- Kubeconfig parsing
- Bearer token authentication
- Pod listing (namespace and cluster-wide)
- Cluster version retrieval
- Fallback to fixtures

⏳ **TODO:**
- Cert-based authentication (TLS)
- Kubernetes Metrics API integration (real CPU/MEM)
- Age calculation from ISO8601 timestamps
- Watch API for real-time updates
- Resource management (DELETE, PATCH)
- Other resources (Deployments, Services, etc.)

## Error Handling

The K8s client implements graceful degradation:

1. **Connection Failure**: Falls back to fixtures
2. **Authentication Error**: Logs warning, uses fixtures
3. **API Error**: Returns specific error codes
4. **Parse Error**: Validates JSON, returns errors

**Example:**
```zig
manager.connect() catch |err| {
    // Non-fatal: app continues with fixtures
    Logger.warn("K8s connection failed: {}", .{err});
};

const pods = try manager.getPods();
// Returns fixtures if not connected
// Returns real data if connected
```

## Limitations

1. **Simple YAML Parser**: Uses basic string parsing, not a full YAML library
2. **No TLS Support**: Cert-based auth not yet implemented
3. **No Metrics API**: CPU/MEM usage shows "n/a" (uses placeholder values)
4. **No Watch API**: No real-time updates yet
5. **Limited Resources**: Only pods and basic cluster info

## Future Enhancements

### Phase 1: Full Authentication
- Implement TLS cert-based auth
- Support for exec-based auth (e.g., AWS IAM)
- Refresh token handling

### Phase 2: Metrics API
- Integrate with Kubernetes Metrics Server
- Real CPU and memory usage
- Historical metrics

### Phase 3: Real-time Updates
- Watch API implementation
- Websocket support for streaming
- Automatic pod list refresh

### Phase 4: Resource Management
- CRUD operations for all resources
- Deployments, Services, ConfigMaps
- Jobs, CronJobs, StatefulSets
- RBAC resources

### Phase 5: Advanced Features
- Multi-cluster support
- Context switching UI
- Namespace filtering
- Resource search and filtering

## Testing

### Unit Tests
```bash
# Test K8s client
zig test src/k8s/client.zig

# Test kubeconfig parser
zig test src/k8s/kubeconfig.zig

# Test manager
zig test src/k8s/manager.zig
```

### Integration Testing
The K8s client can be tested with:
1. **Real cluster**: Set up kubeconfig
2. **Minikube**: Local development cluster
3. **Kind**: Kubernetes in Docker
4. **Fixtures**: Built-in test data

## Security Considerations

1. **Token Storage**: Tokens are read from kubeconfig, not hardcoded
2. **TLS Verification**: TODO - implement cert verification
3. **API Server**: Always use HTTPS (validated in kubeconfig)
4. **Secrets**: Never log sensitive data (tokens, certs)

## References

- [Kubernetes API Docs](https://kubernetes.io/docs/reference/using-api/)
- [Kubeconfig Spec](https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/)
- [REST API Reference](https://kubernetes.io/docs/reference/kubernetes-api/)
- [Metrics API](https://kubernetes.io/docs/tasks/debug/debug-cluster/resource-metrics-pipeline/)
