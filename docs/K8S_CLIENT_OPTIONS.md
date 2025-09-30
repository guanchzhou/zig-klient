# Kubernetes Client Implementation Options

## Current Status

**Use-after-free bug FIXED** ✅  
- Header now properly duplicates ClusterData strings
- No more garbled symbols (◆◆◆◆)

## Implementation Approaches

### Option 1: Native Zig HTTP Client (Current - Partial)

**Status**: 🟡 Partial - Zig 0.15 `fetch()` API doesn't expose response body yet

**Pros:**
- No external dependencies
- Pure Zig implementation
- Full control over implementation

**Cons:**
- Zig 0.15's HTTP API is still evolving
- `fetch()` doesn't return response body (yet)
- Need to wait for stdlib updates

**Code**: `src/k8s/client.zig`

---

### Option 2: Official Kubernetes C Library (Recommended)

**Status**: ✅ Available at `/Users/andreymaltsev/Development/alphasense/c/`

**Library**: [kubernetes-client/c](https://github.com/kubernetes-client/c)

**Pros:**
- ✅ Official Kubernetes client
- ✅ Full API coverage (all Kubernetes resources)
- ✅ Battle-tested and maintained
- ✅ Proper authentication (tokens, certs, OIDC)
- ✅ Works with kubeconfig files
- ✅ Metrics API support
- ✅ Watch/streaming support
- ✅ WebSocket exec support

**Implementation Steps:**

1. **Build C Library**:
   ```bash
   cd /Users/andreymaltsev/Development/alphasense/c/kubernetes
   mkdir build && cd build
   cmake -DCMAKE_INSTALL_PREFIX=/usr/local ..
   make
   sudo make install
   ```

2. **Create Zig Bindings** (`src/k8s/c_bindings.zig`):
   ```zig
   const c = @cImport({
       @cInclude("config/kube_config.h");
       @cInclude("api/CoreV1API.h");
       @cInclude("include/apiClient.h");
   });
   ```

3. **Update build.zig**:
   ```zig
   exe.linkSystemLibrary("kubernetes");
   exe.linkLibC();
   exe.addIncludePath("/usr/local/include");
   exe.addLibraryPath("/usr/local/lib");
   ```

4. **Implement Client** (see below)

---

### Option 3: kubectl proxy + Simple HTTP (Quickest)

**Status**: 🟢 Can implement immediately with Zig 0.15

**How it works:**
1. User runs `kubectl proxy` (starts HTTP proxy on localhost:8001)
2. c3s connects to `http://localhost:8001` (no auth needed)
3. Use Zig's HTTP client (no TLS complications)

**Pros:**
- ✅ Works with current Zig 0.15
- ✅ No external C dependencies
- ✅ Simple HTTP (no TLS)
- ✅ No auth complications

**Cons:**
- ❌ Requires `kubectl proxy` running
- ❌ Extra manual step for users

**Implementation**:
```zig
// In manager.zig
pub fn connectViaProxy(self: *K8sManager) !void {
    self.client = try K8sClient.init(self.allocator, .{
        .server = "http://localhost:8001",
        .token = null, // No auth needed for proxy
        .namespace = "default",
    });
}
```

---

## Recommended Approach: Use Official C Library

The official Kubernetes C library is the best solution because:

1. **Complete**: Handles all edge cases (auth, TLS, kubeconfig, etc.)
2. **Maintained**: Updated with Kubernetes releases
3. **Proven**: Used in production environments
4. **Metrics**: Full support for `metrics.k8s.io` API

### Implementation with C Library

#### 1. Zig Bindings (`src/k8s/c_client.zig`):

```zig
const std = @import("std");

const c = @cImport({
    @cInclude("config/kube_config.h");
    @cInclude("api/CoreV1API.h");
    @cInclude("include/apiClient.h");
});

pub const K8sClient = struct {
    allocator: std.mem.Allocator,
    api_client: *c.apiClient_t,
    
    pub fn init(allocator: std.mem.Allocator) !K8sClient {
        var base_path: [*c]u8 = null;
        var ssl_config: ?*c.sslConfig_t = null;
        var api_keys: ?*c.list_t = null;
        
        const rc = c.load_kube_config(&base_path, &ssl_config, &api_keys, null);
        if (rc != 0) {
            return error.CannotLoadKubeConfig;
        }
        
        const api_client = c.apiClient_create_with_base_path(base_path, ssl_config, api_keys) orelse {
            c.free_client_config(base_path, ssl_config, api_keys);
            return error.CannotCreateClient;
        };
        
        return K8sClient{
            .allocator = allocator,
            .api_client = api_client,
        };
    }
    
    pub fn deinit(self: *K8sClient) void {
        c.apiClient_free(self.api_client);
        c.apiClient_unsetupGlobalEnv();
    }
    
    pub fn listPods(self: *K8sClient, namespace: []const u8) ![]Pod {
        const ns_z = try self.allocator.dupeZ(u8, namespace);
        defer self.allocator.free(ns_z);
        
        const pod_list = c.CoreV1API_listNamespacedPod(
            self.api_client,
            ns_z.ptr,
            null, null, null, null, null, null, null, null, null, null, null
        ) orelse return error.CannotListPods;
        
        defer c.v1_pod_list_free(pod_list);
        
        // Convert C pod list to Zig pods
        var pods = std.ArrayList(Pod).init(self.allocator);
        // ... iterate and convert ...
        
        return pods.toOwnedSlice();
    }
};
```

#### 2. Build Configuration:

```zig
// build.zig
const exe = b.addExecutable(.{
    .name = "c3s",
    .root_source_file = .{ .path = "src/main.zig" },
    .target = target,
    .optimize = optimize,
});

// Link Kubernetes C library
exe.linkLibC();
exe.linkSystemLibrary("kubernetes");
exe.linkSystemLibrary("curl");
exe.linkSystemLibrary("ssl");
exe.linkSystemLibrary("crypto");
exe.addIncludePath(.{ .path = "/usr/local/include" });
exe.addLibraryPath(.{ .path = "/usr/local/lib" });
```

---

## Real-Time CPU/MEM Metrics

From k9s source code, metrics come from **Metrics Server API** (`metrics.k8s.io/v1beta1`):

### How k9s gets metrics:

```go
// From k9s-patched/internal/client/metrics.go
func (m *MetricsServer) FetchNodesMetrics(ctx context.Context) (*mv1beta1.NodeMetricsList, error) {
    return m.mx.MetricsV1beta1().NodeMetricses().List(ctx, metav1.ListOptions{})
}

func (m *MetricsServer) FetchPodsMetrics(ctx context.Context, ns string) (*mv1beta1.PodMetricsList, error) {
    return m.mx.MetricsV1beta1().PodMetricses(ns).List(ctx, metav1.ListOptions{})
}
```

### API Endpoints:

- **Node Metrics**: `GET /apis/metrics.k8s.io/v1beta1/nodes`
- **Pod Metrics**: `GET /apis/metrics.k8s.io/v1beta1/namespaces/{namespace}/pods`
- **Cluster Metrics**: Aggregate all node metrics

### With C Library:

The generic client API can be used for Metrics Server:

```c
// Using generic API for metrics
generic_client_t* metrics_client = Generic_apiClient_create(
    apiClient, 
    "metrics.k8s.io", 
    "v1beta1", 
    "NodeMetrics"
);
```

---

## Next Steps

1. ✅ **DONE**: Fix use-after-free bug in Header
2. 🟡 **TODO**: Build Kubernetes C library
3. 🟡 **TODO**: Create Zig bindings to C library
4. 🟡 **TODO**: Implement metrics API calls
5. 🟡 **TODO**: Add real-time data refresh (periodic fetch)

---

## Testing

### Quick Test with kubectl proxy:

```bash
# Terminal 1: Start proxy
kubectl proxy

# Terminal 2: Test API
curl http://localhost:8001/api/v1/namespaces
curl http://localhost:8001/apis/metrics.k8s.io/v1beta1/nodes

# Terminal 3: Run c3s
./zig-out/bin/c3s
```

### Full Test with C library:

```bash
# Ensure metrics-server is running in cluster
kubectl top nodes  # Should work

# Run c3s
./zig-out/bin/c3s
# Should show real cluster data with live CPU/MEM
```
