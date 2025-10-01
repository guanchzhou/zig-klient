# WebSocket Operations Setup Guide

## Overview

`zig-klient` includes complete WebSocket API implementations for:
- **Pod exec**: Execute commands in running containers
- **Pod attach**: Attach to running container processes  
- **Port forward**: Forward local ports to pod ports

These features are **optionally enabled** by adding the `websocket.zig` dependency.

---

## Why Optional?

WebSocket operations are:
1. **Not required** for most Kubernetes client use cases (95% of users only need CRUD operations)
2. **External dependency** that adds complexity
3. **Heavier weight** than the core library

By making this optional, `zig-klient` stays lightweight for users who don't need these advanced features.

---

## Prerequisites

Before enabling WebSocket support:

1. **Zig 0.15.1** or newer
2. **Rancher Desktop** or another local Kubernetes cluster (for testing)
3. **kubectl** configured and working
4. **Network access** to your Kubernetes API server

---

## Setup Instructions

### Step 1: Add websocket.zig Dependency

Update your `build.zig.zon`:

```zig
.{
    .name = .myapp,
    .version = "0.1.0",
    .dependencies = .{
        .klient = .{
            .url = "https://github.com/guanchzhou/zig-klient/archive/main.tar.gz",
            .hash = "...", // zig will provide this
        },
        // Add websocket.zig dependency
        .websocket = .{
            .url = "https://github.com/karlseguin/websocket.zig/archive/main.tar.gz",
            .hash = "...", // zig will provide this after first fetch
        },
    },
}
```

### Step 2: Update build.zig

In your `build.zig`, add the websocket module:

```zig
const klient_dep = b.dependency("klient", .{
    .target = target,
    .optimize = optimize,
});

const websocket_dep = b.dependency("websocket", .{
    .target = target,
    .optimize = optimize,
});

exe.root_module.addImport("klient", klient_dep.module("klient"));
exe.root_module.addImport("websocket", websocket_dep.module("websocket"));
```

### Step 3: Fetch Dependencies

```bash
zig build
```

Zig will automatically download and cache the dependencies.

---

## Usage Examples

### Pod Exec

Execute a command in a running container:

```zig
const std = @import("std");
const klient = @import("klient");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize K8s client
    var client = try klient.K8sClient.init(allocator, .{
        .server = "https://127.0.0.1:6443",
        .token = "your-token",
    });
    defer client.deinit();

    // Initialize WebSocket client
    var ws_client = try klient.WebSocketClient.init(
        allocator,
        client.api_server,
        client.token.?,
        null, // ca_cert_data (optional)
    );
    defer ws_client.deinit();

    // Create exec client
    var exec_client = klient.ExecClient.init(allocator, &ws_client);

    // Execute command
    const result = try exec_client.exec("my-pod", "default", .{
        .command = &[_][]const u8{ "ls", "-la", "/app" },
        .stdout = true,
        .stderr = true,
    });
    defer result.deinit();

    // Print output
    std.debug.print("Output:\n{s}\n", .{result.stdout()});
    std.debug.print("Exit code: {d}\n", .{result.exit_code});
}
```

### Pod Attach

Attach to a running container process:

```zig
const std = @import("std");
const klient = @import("klient");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var client = try klient.K8sClient.init(allocator, .{
        .server = "https://127.0.0.1:6443",
        .token = "your-token",
    });
    defer client.deinit();

    var ws_client = try klient.WebSocketClient.init(
        allocator,
        client.api_server,
        client.token.?,
        null,
    );
    defer ws_client.deinit();

    // Create attach client
    var attach_client = klient.AttachClient.init(allocator, &ws_client);

    // Attach to running container
    var session = try attach_client.attach("my-pod", "default", .{
        .stdin = true,
        .stdout = true,
        .tty = true,
    });
    defer session.deinit();

    // Send input
    try session.writeStdin("echo hello from zig\n");

    // Read output
    const msg = try session.read();
    defer msg.deinit(allocator);

    std.debug.print("Output: {s}\n", .{msg.data});
}
```

### Port Forward

Forward local ports to pod ports:

```zig
const std = @import("std");
const klient = @import("klient");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var client = try klient.K8sClient.init(allocator, .{
        .server = "https://127.0.0.1:6443",
        .token = "your-token",
    });
    defer client.deinit();

    var ws_client = try klient.WebSocketClient.init(
        allocator,
        client.api_server,
        client.token.?,
        null,
    );
    defer ws_client.deinit();

    // Create port forwarder
    var forwarder = klient.PortForwarder.init(allocator, &ws_client);

    // Forward ports
    var session = try forwarder.forward("my-pod", "default", .{
        .ports = &[_]klient.PortMapping{
            .{ .local = 8080, .remote = 80 },
            .{ .local = 5432, .remote = 5432 },
        },
    });
    defer session.deinit();

    std.debug.print("Port forwarding active:\n", .{});
    std.debug.print("  localhost:8080 -> pod:80\n", .{});
    std.debug.print("  localhost:5432 -> pod:5432\n", .{});

    // Keep forwarding active
    while (session.isActive()) {
        std.time.sleep(1 * std.time.ns_per_s);
    }
}
```

---

## Testing Against Rancher Desktop

### Setup Test Environment

1. **Start Rancher Desktop**
   ```bash
   # Verify it's running
   kubectl cluster-info
   ```

2. **Create Test Namespace**
   ```bash
   kubectl create namespace zig-klient-test
   ```

3. **Deploy Test Pod**
   ```bash
   kubectl run test-pod \
     --image=busybox:latest \
     --namespace=zig-klient-test \
     --command -- sh -c "while true; do sleep 3600; done"
   ```

4. **Wait for Pod to be Ready**
   ```bash
   kubectl wait --for=condition=Ready pod/test-pod -n zig-klient-test --timeout=60s
   ```

### Run Integration Tests

```bash
cd zig-klient/

# Run WebSocket integration tests
zig build test-websocket-integration

# Or run manually
zig test tests/websocket_integration_test.zig \
  --dep klient \
  -Mklient=src/klient.zig
```

### Cleanup

```bash
kubectl delete namespace zig-klient-test
```

---

## Troubleshooting

### Connection Refused

**Error**: `Connection refused when connecting to WebSocket`

**Solution**:
- Verify kubectl can connect: `kubectl get pods`
- Check API server URL is correct
- Ensure token has proper permissions

### Certificate Errors

**Error**: `TLS certificate verification failed`

**Solution**:
- For testing: Disable cert verification (development only!)
- For production: Provide correct CA certificate
  ```zig
  const ca_cert_data = try std.fs.cwd().readFileAlloc(
      allocator,
      "/path/to/ca.crt",
      10 * 1024 * 1024,
  );
  defer allocator.free(ca_cert_data);
  ```

### Pod Not Found

**Error**: `Pod "xyz" not found`

**Solution**:
- Check pod exists: `kubectl get pod xyz -n namespace`
- Verify namespace is correct
- Ensure pod is in Running state

### Command Execution Fails

**Error**: `Command execution failed`

**Solution**:
- Test with kubectl first: `kubectl exec pod-name -- command`
- Check command exists in container
- Verify pod has necessary permissions

---

## Performance Considerations

### Connection Pooling

WebSocket connections are expensive to create. Reuse connections when possible:

```zig
// Good: Reuse WebSocket client
var ws_client = try klient.WebSocketClient.init(...);
defer ws_client.deinit();

for (pods) |pod| {
    var exec_client = klient.ExecClient.init(allocator, &ws_client);
    // Execute commands...
}
```

### Timeout Configuration

Set appropriate timeouts for your use case:

```zig
const result = try exec_client.exec(pod_name, namespace, .{
    .command = &[_][]const u8{ "long-running-command" },
    .timeout_seconds = 300, // 5 minutes
});
```

### Memory Management

Always clean up resources:

```zig
const result = try exec_client.exec(...);
defer result.deinit(); // IMPORTANT: Always call deinit()

// Use result...
```

---

## Security Best Practices

1. **Use RBAC**: Grant minimal permissions for exec/attach operations
2. **Audit Logs**: Enable audit logging for exec/attach events
3. **Network Policies**: Restrict which pods can be accessed
4. **TLS**: Always use TLS in production (never skip certificate verification)
5. **Token Rotation**: Regularly rotate service account tokens

---

## Kubernetes RBAC Permissions

WebSocket operations require specific RBAC permissions:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-exec-role
  namespace: default
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
- apiGroups: [""]
  resources: ["pods/exec"]
  verbs: ["create"]
- apiGroups: [""]
  resources: ["pods/attach"]
  verbs: ["create"]
- apiGroups: [""]
  resources: ["pods/portforward"]
  verbs: ["create"]
```

Apply with:
```bash
kubectl apply -f rbac.yaml
```

---

## Additional Resources

- [WebSocket.zig Repository](https://github.com/karlseguin/websocket.zig)
- [Kubernetes Pod Exec API](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.34/#pod-v1-core)
- [Kubernetes SPDY Protocol](https://github.com/kubernetes/kubernetes/blob/master/staging/src/k8s.io/apimachinery/pkg/util/httpstream/spdy/roundtripper.go)

---

## Status

**Current Implementation Status**:
- ✅ API interfaces complete
- ✅ Pod exec implementation
- ✅ Pod attach implementation
- ✅ Port forward implementation
- ✅ Integration test framework
- ⏳ Requires `websocket.zig` dependency to be added
- ⏳ Live cluster testing pending dependency

**Last Updated**: January 2025

