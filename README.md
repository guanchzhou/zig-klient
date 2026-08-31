# zig-klient

A Kubernetes client library for **Zig** — 73 resource types across 19 API groups with full CRUD, current through **Kubernetes 1.37**. Native WebSocket support for Pod `exec`/`attach`/`port-forward`, and Protobuf serialization via [zig-protobuf](https://github.com/Arwalk/zig-protobuf).

|              |                                                                                       |
| ------------ | ------------------------------------------------------------------------------------- |
| **Build**    | Zig 0.16.0                                                                             |
| **Coverage** | 73 resource types / 19 API groups, current through K8s 1.37                            |
| **Tested**   | Live CRUD on **K8s 1.37.0** (`DeviceTaintRule`, `ClusterTrustBundle`, `StorageVersionMigration` v1) and on **1.36.1** (`MutatingAdmissionPolicy`), both via `kubectl proxy` |
| **Deps**     | [yaml-zig](https://github.com/sakakibara/yaml-zig), [zig-protobuf](https://github.com/Arwalk/zig-protobuf) |
| **License**  | MIT                                                                                    |

**Contents:** [Features](#features) · [Installation](#installation) · [Quick Start](#quick-start) · [Resource Operations](#resource-operations) · [Testing](#testing) · [Architecture](#architecture) · [Requirements](#requirements) · [Roadmap](#roadmap)

> **Connecting & TLS — read this first.** Direct HTTPS does not work against a normal
> Kubernetes API server. `std.crypto.tls.Client` has no handling for the
> `certificate_request` handshake message ([ziglang/zig#19521](https://github.com/ziglang/zig/issues/19521)),
> re-checked on Zig **0.16.0** and **0.17.0-dev.1936**. An API server sends one whenever
> it is started with `--client-ca-file` — the default for every distribution, managed or
> not. The handshake aborts with `TlsUnexpectedMessage`, which `std.http.Client` reports
> as `error.TlsInitializationFailed`. This is not caused by self-signed certificates and
> supplying a CA does not avoid it.
>
> **Connect through `kubectl proxy`**, which is what the integration tests do:
>
> ```bash
> kubectl proxy --port=8001 &
> ```
> ```zig
> var client = try klient.K8sClient.init(allocator, io, .{ .server = "http://127.0.0.1:8001" });
> ```
>
> or call `connectWithFallback()` to find a running proxy automatically.
>
> Custom CA certificates (`tls_config.ca_cert_data` / `ca_cert_path`) are wired into the
> trust store and work as documented — they simply are not sufficient on their own.
> Client certificates, `insecure_skip_verify` and `server_name` cannot be honoured at
> all; passing them now fails fast from `K8sClient.init` rather than being ignored.

## Features

### Resource Coverage (73 Resources Across 19 API Groups)

**Core API (v1)** - 17 resources  
Pod, Service, ConfigMap, Secret, Namespace, Node, PersistentVolume, PersistentVolumeClaim, ServiceAccount, Endpoints, Event, ReplicationController, PodTemplate, ResourceQuota, LimitRange, Binding, ComponentStatus

**Workloads (apps/v1)** - 5 resources  
Deployment, ReplicaSet, StatefulSet, DaemonSet, ControllerRevision

**Batch (batch/v1)** - 2 resources  
Job, CronJob

**Networking (networking.k8s.io/v1)** - 5 resources  
Ingress, IngressClass, NetworkPolicy, IPAddress, ServiceCIDR

**Discovery (discovery.k8s.io/v1)** - 1 resource  
EndpointSlice

**Gateway API (gateway.networking.k8s.io/v1, v1beta1)** - 10 resources  
GatewayClass, Gateway, HTTPRoute, GRPCRoute, TCPRoute, TLSRoute, UDPRoute, BackendTLSPolicy, ListenerSet, ReferenceGrant

> `ReferenceGrant` stays on `v1beta1` — that is still the storage version in Gateway API v1.6.1.

**RBAC (rbac.authorization.k8s.io/v1)** - 4 resources  
Role, RoleBinding, ClusterRole, ClusterRoleBinding

**Storage (storage.k8s.io/v1)** - 6 resources  
StorageClass, VolumeAttachment, CSIDriver, CSINode, CSIStorageCapacity, VolumeAttributesClass

**Dynamic Resource Allocation (resource.k8s.io/v1)** - 5 resources  
ResourceClaim, ResourceClaimTemplate, ResourceSlice, DeviceClass, DeviceTaintRule

> `DeviceTaintRule` graduated to GA in Kubernetes 1.37.

**Policy (policy/v1)** - 1 resource  
PodDisruptionBudget

**Auto-scaling (autoscaling/v2)** - 1 resource  
HorizontalPodAutoscaler

**Scheduling (scheduling.k8s.io/v1)** - 1 resource  
PriorityClass

**Coordination (coordination.k8s.io/v1)** - 1 resource  
Lease

**Certificates (certificates.k8s.io/v1)** - 3 resources  
CertificateSigningRequest, ClusterTrustBundle, PodCertificateRequest

> `ClusterTrustBundle` and `PodCertificateRequest` graduated to GA in Kubernetes 1.37. The v1 `PodCertificateRequest` schema drops `PKIXPublicKey` and `ProofOfPossession`.

**Admission Control (admissionregistration.k8s.io/v1)** - 6 resources  
ValidatingWebhookConfiguration, MutatingWebhookConfiguration, ValidatingAdmissionPolicy, ValidatingAdmissionPolicyBinding, MutatingAdmissionPolicy, MutatingAdmissionPolicyBinding

> `MutatingAdmissionPolicy` and `MutatingAdmissionPolicyBinding` graduated to GA in Kubernetes 1.36.

**API Registration (apiregistration.k8s.io/v1)** - 1 resource  
APIService

**Flow Control (flowcontrol.apiserver.k8s.io/v1)** - 2 resources  
FlowSchema, PriorityLevelConfiguration

**Node (node.k8s.io/v1)** - 1 resource  
RuntimeClass

**Storage Migration (storagemigration.k8s.io/v1)** - 1 resource  
StorageVersionMigration

> `StorageVersionMigration` bumped to `v1` in Kubernetes 1.37 (`v1beta1` is deprecated, removal targeted 1.40).

### Core Capabilities
- **73 Resource Types**: Kubernetes resource types across 19 API groups, current through K8s 1.37
- **Full CRUD Operations**: Create, Read, Update, Delete, Patch on all resources
- **Advanced Delete**: Grace period, propagation policy, preconditions, delete collection
- **Advanced Create/Update**: Field manager, field validation, dry-run support
- **WebSocket Operations**: Pod exec, attach, port-forward
- **Gateway API**: GatewayClass, Gateway, HTTPRoute, GRPCRoute, ReferenceGrant
- **Dynamic Resource Allocation**: ResourceClaim, DeviceClass, ResourceSlice, DeviceTaintRule
- **Generic Resource Client**: Type-safe operations with `ResourceClient<T>` pattern
- **JSON Serialization**: Built-in support for Kubernetes JSON API
- **Cluster-Scoped Resources**: 32 cluster-scoped resources (namespacing handled automatically by the registry)

### Authentication
- **Bearer token** — static token or in-cluster service-account token
- **mTLS** — *not supported on Zig 0.16* (`std.crypto.tls` cannot present a client
  certificate); `K8sClient.init` rejects client-cert options rather than ignoring them
- **Exec credential plugins** — AWS EKS, GCP GKE, Azure AKS, generic OIDC
- **In-cluster config** — automatic service-account detection inside a pod
- Kubeconfig is parsed natively (YAML; no `kubectl` required). HTTP basic auth
  (username/password) is **not** supported — it was removed from Kubernetes in 1.19+.

### Operational Features (k9s-inspired)
- **Enhanced Pod Logs**: Container selection, previous container, tail lines, timestamps, sinceSeconds
- **Rollout Restart**: Deployments, StatefulSets, DaemonSets rolling restart
- **Image Update**: Set container image on deployments (`setImage`)
- **Pod Eviction**: Graceful eviction via Eviction API
- **Node Cordon/Uncordon**: Mark nodes as schedulable/unschedulable
- **Metrics Server API**: CPU/memory metrics for pods and nodes. Default pin is
  `metrics.k8s.io/v1beta1`. Kubernetes 1.37 defines `v1`, but metrics-server still
  registers only v1beta1 (`kubernetes-sigs/metrics-server#1786`, PR #1855 still a
  draft as of 2026-08-30). `MetricsClient.initFromDiscovery` uses v1 only when this
  cluster's `/apis` prefers it.
- **RBAC CanI**: SelfSubjectAccessReview permission checks

### Advanced Features
- **Retry Logic**: Exponential backoff with jitter, status-code-aware retries (429, 500, 502, 503, 504)
- **Watch API**: Real-time resource updates with streaming support
- **Informers**: Local list-then-watch cache with automatic relist on `410 Gone`
- **CRD Support**: Dynamic client for Custom Resource Definitions
- **Predefined CRDs**: Cert-Manager, Istio, Prometheus, Argo, Knative
- **In-Cluster Config**: Automatic service account detection and configuration
- **Field/Label Selectors**: Advanced filtering and search capabilities
- **Pagination**: Efficient handling of large result sets
- **Server-Side Apply**: Declarative resource management with field ownership
- **Structured API Errors**: K8s `Status` responses parsed into status/message/reason/code,
  returned into caller-owned storage (see [Error detail](#error-detail))
- **Shareable client**: one `K8sClient` — and so one connection pool — may be used
  from several threads
- **Response Size Limits**: Configurable max response size (default 16MB) to prevent OOM

### Quality
- Comprehensive unit suite (`zig build test`) plus live integration entrypoints; the
  migration probe force-compiles the whole public API surface
- Memory safe with explicit allocator management
- Type safe with Zig's compile-time type system
- Two dependencies: yaml-zig (YAML parsing) and zig-protobuf (Protocol Buffers)
- Live CRUD verified against Kubernetes 1.37.0 (kindest/node) and 1.36.1 (Rancher Desktop) via `kubectl proxy`

## Installation

### As a Zig Package

Add to your `build.zig.zon`:

```zig
.{
    .name = .myapp,
    .version = "0.1.0",
    .dependencies = .{
        .klient = .{
            .url = "https://github.com/guanchzhou/zig-klient/archive/main.tar.gz",
            .hash = "...", // zig will provide this
        },
    },
}
```

In your `build.zig`:

```zig
const klient_dep = b.dependency("klient", .{
    .target = target,
    .optimize = optimize,
});

exe.root_module.addImport("klient", klient_dep.module("klient"));
```

### Manual Integration

Copy the `src/` directory into your project and import as a module.

## Quick Start

### Basic Usage

```zig
const std = @import("std");
const klient = @import("klient");

pub fn main() !void {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Zig 0.16 threads all I/O through std.Io.
    var threaded = std.Io.Threaded.init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    // Initialize client (note the io parameter)
    var client = try klient.K8sClient.init(allocator, io, .{
        .server = "https://kubernetes.default.svc",
        .token = "your-bearer-token",
    });
    defer client.deinit();

    // List all pods
    var pods = klient.Pods.init(&client);
    const pod_list = try pods.client.listAll();
    defer pod_list.deinit();
    
    for (pod_list.value.items) |pod| {
        std.debug.print("Pod: {s}\n", .{pod.metadata.name});
    }
}
```

> The snippets below assume `allocator`, `io`, and (where used) `client` from the
> setup above.

### Error detail

A failed API call returns `error.K8sApiError`. The Kubernetes `Status` behind it goes
into storage you provide, and you own what lands there:

```zig
var api_err: ?klient.K8sClient.ApiError = null;
defer if (api_err) |*e| e.deinit(allocator);

_ = client.requestCapturing(.GET, "/api/v1/namespaces/default/pods/nope", null, &api_err) catch {
    if (api_err) |e| std.debug.print("{?d} {s}\n", .{ e.code, e.message orelse "" });
    // -> 404 pods "nope" not found
};
```

For the typed resource methods, set `error_sink` on the `ResourceClient`:

```zig
var api_err: ?klient.K8sClient.ApiError = null;
defer if (api_err) |*e| e.deinit(allocator);

var pods = klient.Pods.init(&client);
pods.client.error_sink = &api_err;

_ = pods.client.get("nope", "default") catch {
    if (api_err) |e| std.debug.print("{?d}\n", .{e.code});
};
```

If the error body is not a `Status` — the HTML a load balancer serves, or a protobuf
body — the HTTP status code is reported instead, so a failure always carries something.

The sink holds the detail of the **most recent** call made through it, or null. Each
call frees whatever the previous one left there, so it is safe to reuse across many
calls, and a success clears it rather than leaving a stale error to be misread as the
cause of a later transport failure. Copy anything you need to outlive the next call.

> **Replaces `client.last_api_error`.** That field was mutable state on the client: it
> made `K8sClient` unsafe to share even though `std.http.Client` beneath it is
> thread-safe, its strings were freed by the following request, and it survived across
> calls so a transport failure could be misreported with a previous call's `Status`.
> A `ResourceClient` is a value, so `error_sink` lives at the call site — several
> threads can drive one client through their own sinks. See
> `tests/entrypoints/test_error_capture.zig`.

### With a Custom CA

```zig
var client = try klient.K8sClient.init(allocator, io, .{
    .server = "https://kubernetes.example.com",
    .token = service_account_token,
    .tls_config = .{
        .ca_cert_data = ca_cert_pem, // or .ca_cert_path = "/path/to/ca.crt"
    },
});
defer client.deinit();
```

> **mTLS is not available on Zig 0.16.** Setting `client_cert_data`, `client_key_data`,
> `client_cert_path`, `client_key_path`, `insecure_skip_verify` or `server_name` returns
> an error from `init` (`error.ClientCertificatesUnsupported`,
> `error.InsecureSkipVerifyUnsupported`, `error.TlsServerNameUnsupported`) — these were
> previously accepted and silently dropped, which left callers believing they were
> authenticating when they were not.
>
> Note also that a CA alone will not get you a working HTTPS connection to an API
> server — see **Connecting & TLS** at the top.

### With AWS EKS Authentication

```zig
const aws_config = try klient.awsEksConfig(allocator, "my-cluster");
// Returns a std.json.Parsed(ExecCredential) — it owns the token memory.
var cred = try klient.exec_credential.executeCredentialPlugin(allocator, io, aws_config);
defer cred.deinit();

var client = try klient.K8sClient.init(allocator, io, .{
    .server = "https://xxx.eks.amazonaws.com",
    .token = cred.value.status.?.token,
});
defer client.deinit();
```

### With Retry Logic

```zig
var client = try klient.K8sClient.init(allocator, io, .{
    .server = "https://kubernetes.example.com",
    .token = "token",
    .retry_config = klient.aggressiveConfig, // or: defaultConfig, conservativeConfig
});
defer client.deinit();
// Idempotent operations (GET/PUT/DELETE/PATCH) retry automatically on transport
// errors and 429/5xx; POST (create) is sent once.
```

### Using Watch API

```zig
const PodWatcher = klient.Watcher(klient.Pod);
// init(client, api_path, resource, namespace, options)
var watcher = PodWatcher.init(&client, "/api/v1", "pods", "default", .{
    .allow_watch_bookmarks = true,
});

// watch() is callback-driven and blocks, dispatching each event. The callback owns
// the event and must call event.deinit() when done.
const handler = struct {
    fn onEvent(event: *klient.watch.WatchEvent(klient.Pod)) anyerror!void {
        defer event.deinit();
        switch (event.type_) {
            .ADDED => std.debug.print("Pod added: {s}\n", .{event.object.metadata.name}),
            .MODIFIED => std.debug.print("Pod modified: {s}\n", .{event.object.metadata.name}),
            .DELETED => std.debug.print("Pod deleted: {s}\n", .{event.object.metadata.name}),
            else => {},
        }
    }
}.onEvent;

try watcher.watch(handler);
```

### Using Informer Pattern

```zig
const PodInformer = klient.Informer(klient.Pod);
// init(allocator, client, api_path, resource, namespace)
var informer = PodInformer.init(allocator, &client, "/api/v1", "pods", "default");
defer informer.deinit();

// start() does the initial list then watches, blocking until stop() — run it on its
// own thread. It relists automatically on a 410 Gone (expired resourceVersion).
try informer.start();

// From another thread, read the local cache (thread-safe):
if (informer.get("my-pod")) |pod| {
    std.debug.print("Found: {s}\n", .{pod.metadata.name});
}
```

### Custom Resource Definitions

```zig
// Use predefined CRD
var cert_client = klient.DynamicClient.init(&client, klient.CertManagerCertificate);
const certs = try cert_client.list("production");
defer certs.deinit();

// Or define custom CRD
const my_crd = klient.CRDInfo{
    .group = "mycompany.io",
    .version = "v1alpha1",
    .kind = "CustomApp",
    .plural = "customapps",
    .namespaced = true,
};

var custom = klient.DynamicClient.init(&client, my_crd);
const apps = try custom.list("default");
defer apps.deinit();
```

### Advanced Delete Operations

```zig
// Delete with grace period and propagation policy
const delete_opts = klient.DeleteOptions{
    .grace_period_seconds = 30,
    .propagation_policy = klient.PropagationPolicy.foreground.toString(),
    .dry_run = "All", // Test without actually deleting
};

var deployments = klient.Deployments.init(&client);
try deployments.client.deleteWithOptions("my-app", null, delete_opts);

// Delete collection by label selector
const list_opts = klient.ListOptions{
    .label_selector = "app=nginx,env=staging",
};
try deployments.client.deleteCollection(null, list_opts, delete_opts);
```

### Advanced Create/Update Operations

```zig
// Create with field manager and validation
const create_opts = klient.CreateOptions{
    .field_manager = "my-controller",
    .field_validation = klient.FieldValidation.strict.toString(),
    .dry_run = "All", // Dry run to validate
};

var pods = klient.Pods.init(&client);
const pod = try pods.client.createWithOptions(my_pod, null, create_opts);
defer pod.deinit();

// Update with field ownership tracking
const update_opts = klient.UpdateOptions{
    .field_manager = "deployment-controller",
    .field_validation = klient.FieldValidation.warn.toString(),
};

const updated = try deployments.client.updateWithOptions(deployment, null, update_opts);
defer updated.deinit();
```

### List with Filtering and Pagination

```zig
// Filter by field and label selectors
const list_opts = klient.ListOptions{
    .field_selector = "status.phase=Running",
    .label_selector = "app=nginx,tier=frontend",
    .limit = 50,
    .resource_version = "12345",
};

var pods = klient.Pods.init(&client);
const filtered_pods = try pods.client.listWithOptions(null, list_opts);
defer filtered_pods.deinit();

for (filtered_pods.value.items) |pod| {
    std.debug.print("Pod: {s}\n", .{pod.metadata.name});
}

// Handle pagination with continue tokens
if (filtered_pods.value.metadata.@"continue") |continue_token| {
    const next_opts = klient.ListOptions{
        .continue_token = continue_token,
        .limit = 50,
    };
    const next_page = try pods.client.listWithOptions(null, next_opts);
    defer next_page.deinit();
}
```

### In-Cluster Configuration

```zig
// Automatically detect and load in-cluster config
if (klient.isInCluster(io)) {
    var in_cluster = try klient.loadInClusterConfig(io, allocator);
    defer in_cluster.deinit();

    var client = try klient.K8sClient.init(allocator, io, .{
        .server = in_cluster.server,
        .token = in_cluster.token,
        .tls_config = .{
            .ca_cert_data = in_cluster.ca_cert_data,
        },
    });
    defer client.deinit();

    // Now you can use the client from within a pod
    var pods = klient.Pods.init(&client);
    const pod_list = try pods.client.listAll();
    defer pod_list.deinit();
}
```

### Pod Exec (WebSocket)

```zig
// Initialize WebSocket client. init(allocator, io, api_server, token, ca_cert_data).
// The direct TLS path cannot reach a normal API server (see Connecting & TLS), so
// point this at a `kubectl proxy` (http://127.0.0.1:8001) with token/ca null.
var ws_client = try klient.WebSocketClient.init(
    allocator,
    io,
    "https://kubernetes.default.svc",
    bearer_token,
    ca_cert_data,
);
defer ws_client.deinit();

// Execute command in pod
var exec_client = klient.ExecClient.init(allocator, &ws_client);

const result = try exec_client.exec("my-pod", "default", .{
    .command = &[_][]const u8{ "ls", "-la", "/app" },
    .stdout = true,
    .stderr = true,
});
defer result.deinit();

std.debug.print("Output:\n{s}\n", .{result.stdout()});
std.debug.print("Exit code: {d}\n", .{result.exit_code});
```

### Pod Attach (WebSocket)

```zig
// Attach to running container
var attach_client = klient.AttachClient.init(allocator, &ws_client);

var session = try attach_client.attach("my-pod", "default", .{
    .stdin = true,
    .stdout = true,
    .tty = true,
});
defer session.deinit();

// Send command via stdin
try session.writeStdin("echo hello\n");

// Read output
const msg = try session.read();
defer msg.deinit(allocator);

std.debug.print("Output: {s}\n", .{msg.data});

// Detach from container
session.detach();
```

### Port Forward (WebSocket)

```zig
// Forward local ports to pod
var forwarder = klient.PortForwarder.init(allocator, &ws_client);

var forward_session = try forwarder.forward("my-pod", "default", .{
    .ports = &[_]klient.PortMapping{
        .{ .local = 8080, .remote = 80 },
        .{ .local = 5432, .remote = 5432 },
    },
});
defer forward_session.deinit();

// Ports are now forwarded
// Access pod's port 80 via localhost:8080
// Access pod's port 5432 via localhost:5432

// Keep session alive
while (forward_session.isActive()) {
    std.Thread.sleep(1 * std.time.ns_per_s);
}
```

### Field and Label Selectors

```zig
var pods = klient.Pods.init(&client);

// Using field selectors
const options = klient.ListOptions{
    .field_selector = "status.phase=Running,metadata.name=my-pod",
    .limit = 100,
};
const filtered_pods = try pods.client.listWithOptions("default", options);
defer filtered_pods.deinit();

// Using label selector builder
var label_selector = try klient.LabelSelector.init(allocator);
defer label_selector.deinit();

try label_selector.addEquals("app", "nginx");
try label_selector.addIn("env", &[_][]const u8{ "prod", "staging" });
const selector_str = try label_selector.build();
defer allocator.free(selector_str);

const labeled_options = klient.ListOptions{
    .label_selector = selector_str,
};
const labeled_pods = try pods.client.listWithOptions("default", labeled_options);
defer labeled_pods.deinit();
```

### Server-Side Apply

```zig
var deployments = klient.Deployments.init(&client);

const deployment_manifest =
    \\{
    \\  "apiVersion": "apps/v1",
    \\  "kind": "Deployment",
    \\  "metadata": {
    \\    "name": "my-deployment",
    \\    "namespace": "default"
    \\  },
    \\  "spec": {
    \\    "replicas": 3,
    \\    "selector": {
    \\      "matchLabels": {"app": "myapp"}
    \\    },
    \\    "template": {
    \\      "metadata": {"labels": {"app": "myapp"}},
    \\      "spec": {
    \\        "containers": [{
    \\          "name": "nginx",
    \\          "image": "nginx:latest"
    \\        }]
    \\      }
    \\    }
    \\  }
    \\}
;

const apply_options = klient.ApplyOptions{
    .field_manager = "my-controller",
    .force = false,
};

const applied = try deployments.client.apply(
    "my-deployment",
    deployment_manifest,
    "default",
    apply_options,
);
defer applied.deinit();
```

### JSON Patch

```zig
var json_patch = klient.JsonPatch.init(allocator);
defer json_patch.deinit();

try json_patch.replace("/spec/replicas", .{ .integer = 5 });
try json_patch.add("/metadata/labels/version", .{ .string = "v2" });

const patch_json = try json_patch.build();
defer allocator.free(patch_json);

const patched = try deployments.client.patchWithType(
    "my-deployment",
    patch_json,
    "default",
    klient.PatchType.json,
);
defer patched.deinit();
```

## Resource Operations

All resource types support the same operations:

```zig
// Pods
var pods = klient.Pods.init(&client);

// List operations (return std.json.Parsed - caller must call .deinit())
const pod_list = try pods.client.list("namespace");
defer pod_list.deinit();

const all_pods = try pods.client.listAll();
defer all_pods.deinit();

// Get operation (returns Parsed(T) - caller must call .deinit())
const pod = try pods.client.get("pod-name", "namespace");
defer pod.deinit();
std.debug.print("Pod: {s}\n", .{pod.value.metadata.name});

// Create/Update (return Parsed(T) - caller must call .deinit())
const created = try pods.client.create(pod_spec, "namespace");
defer created.deinit();

const updated = try pods.client.update(updated_spec, "namespace");
defer updated.deinit();

// Delete (returns void)
try pods.client.delete("namespace", "pod-name", null);

// Patch (returns Parsed(T) - caller must call .deinit())
const patched = try pods.client.patch("pod-name", patch_json, "namespace");
defer patched.deinit();

// Pod-specific: Get logs
const logs = try pods.logs("pod-name", "namespace");
defer allocator.free(logs);

// Same pattern for: Deployments, Services, ConfigMaps, Secrets, Namespaces, Nodes,
// ReplicaSets, StatefulSets, DaemonSets, Jobs, CronJobs, PVs, PVCs
```

## Testing

### Unit Tests

Run all unit tests (isolated functionality):

```bash
zig build test
```

Run specific test suites:

```bash
zig build test-retry      # Retry logic tests
zig build test-advanced   # TLS + CRD tests
```

### Integration Tests

Integration tests run against a real Kubernetes cluster. Because the direct TLS path
cannot complete a handshake with an API server that requests client certificates (see
**Connecting & TLS**), the entrypoints connect through `kubectl proxy`:

```bash
kubectl proxy --port=8080 &           # expose the API without TLS
zig build test-k8s-137-crud                # K8s 1.37 DeviceTaintRule / ClusterTrustBundle / StorageVersionMigration v1
zig build test-mutating-admission-policy    # K8s 1.36 MutatingAdmissionPolicy CRUD round-trip
zig build test-via-proxy                   # pods/namespaces/nodes + pod CRUD
```

`test-k8s-137-crud` was verified against **Kubernetes 1.37.0** (kindest/node) —
list → create → get → delete all succeed for `DeviceTaintRule`,
`ClusterTrustBundle`, and `StorageVersionMigration` v1. `PodCertificateRequest`
stays on `zig build test-k8s-137` (schema only): creating one needs a real
pod/node/service-account UID and a kubelet-shaped PKCS#10 stub.
`test-mutating-admission-policy` was verified against Rancher Desktop **1.36.1**.
See [docs/TESTING.md](docs/TESTING.md) for the full guide.

## Documentation

- **API reference**: https://guanchzhou.github.io/zig-klient/ (build with `zig build docs`)
- [TESTING.md](docs/TESTING.md) - Testing guide (unit and integration tests)
- [tests/comprehensive/README.md](tests/comprehensive/README.md) - Comprehensive test suite

## Architecture

```
zig-klient/
├── src/
│   ├── klient.zig              # Main library entry point
│   └── k8s/
│       ├── client.zig          # Core HTTP client
│       ├── types.zig           # Resource type re-exports
│       ├── types/              # Per-group type definitions
│       ├── resource_registry.zig  # Comptime kind → API path / plural / scope
│       ├── resources.zig      # Resource operations
│       ├── retry.zig           # Retry logic
│       ├── watch.zig           # Watch API & Informers
│       ├── discovery.zig       # /apis discovery for optional APIs
│       ├── tls.zig             # Custom CA loading (mTLS is not available on Zig 0.16)
│       ├── crd.zig             # CRD support
│       ├── exec_credential.zig # Cloud auth
│       └── kubeconfig_yaml.zig # Native kubeconfig parsing (no kubectl)
├── tests/                      # Unit tests (isolated)
│   ├── entrypoints/            # Live integration tests (via kubectl proxy)
│   └── comprehensive/          # Larger live scenarios
└── docs/                       # Documentation
```

## Feature Parity Status

**Tested against**: Kubernetes 1.37.0 (kindest/node, live CRUD of 1.37 GA kinds) and Rancher Desktop (Kubernetes 1.36.1)

| Feature | Kubernetes 1.37 | zig-klient | Coverage |
|---------|------------------|------------|----------|
| HTTP Operations | All methods | All methods | Yes |
| Typed resource kinds | 73 modeled | 73 | GA kinds through 1.37 |
| API Groups | 19 | 19 | Yes |
| Auth Methods | 5 | 4 | No HTTP basic auth — removed from K8s 1.19+ |
| In-Cluster Config | Yes | Yes | Yes |
| Delete Options | Yes | Yes | Yes |
| Create/Update Options | Yes | Yes | Yes |
| Delete Collection | Yes | Yes | Yes |
| Retry Logic | Basic | Advanced | Yes |
| Watch API | Yes | Yes | Yes |
| Field/Label Selectors | Yes | Yes | Yes |
| Pagination | Yes | Yes | Yes |
| Server-Side Apply | Yes | Yes | Yes |
| WebSocket Support | Yes | Yes (native) | Yes |
| Protobuf Support | Yes | Yes (zig-protobuf) | Yes |
| Gateway API | Yes | Yes (standard channel, 10 kinds) | Yes |
| Dynamic Resource Allocation | Yes | Yes (incl. DeviceTaintRule) | Yes |
| Mutating Admission Policy | Yes (GA 1.36) | Yes | Yes |
| ClusterTrustBundle / PodCertificateRequest | Yes (GA 1.37) | Yes | Yes |
| StorageVersionMigration | v1 | v1 | Yes |
| Metrics API | v1 defined; metrics-server still v1beta1 | v1beta1 default; `initFromDiscovery` if the cluster prefers v1 | Do not hardcode v1 |

**Coverage**: 73 Kubernetes resource types across 19 API groups, current through K8s 1.37. Alpha kinds (`lifecycle.k8s.io/v1alpha1` Eviction/EvictionRequest, `scheduling.k8s.io/v1alpha3` CompositePodGroup) and beta Workload/PodGroup (`scheduling.k8s.io/v1beta1`) are omitted; optional APIs can be reached through `Discovery` + `DynamicClient`.

## Requirements

- Zig **0.16.0** (0.17-dev is blocked on yaml-zig / zig-protobuf; see CHANGELOG)
- kubectl (optional; only for `kubectl proxy` / integration tests)
- Cloud CLI tools (optional, for exec credential plugins):
  - `aws` CLI for EKS
  - `gke-gcloud-auth-plugin` for GKE
  - `kubelogin` for AKS

## Stability

zig-klient is **pre-1.0**, so the API may change between minor versions. Following
SemVer for `0.x`:

- **minor** (`0.2 → 0.3`) may include breaking changes (signatures, removed symbols);
- **patch** (`0.2.1 → 0.2.2`) is backward-compatible bug/security fixes.

The 1.0 line will stabilize the public surface once the resource API and the
streaming/TLS paths have soaked. Each release's breaking changes are called out in
[CHANGELOG.md](CHANGELOG.md). Targets Zig 0.16.0 and Kubernetes through 1.37.

## License

MIT License - see [LICENSE](LICENSE) file for details

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass (`zig build test`)
5. Submit a pull request

## Roadmap

### Implemented
- [x] 73 Kubernetes resource types across 19 API groups (current through K8s 1.37)
- [x] All HTTP methods (GET, POST, PUT, DELETE, PATCH)
- [x] Bearer token auth
- [ ] mTLS auth — blocked on `std.crypto.tls` client-certificate support
- [x] Exec credential plugins (AWS, GCP, Azure)
- [x] In-cluster configuration with service account
- [x] Delete options (grace period, propagation policy, preconditions)
- [x] Delete collection operations
- [x] Create/Update options (field manager, field validation, dry-run)
- [x] List filtering (field selectors, label selectors)
- [x] Pagination support (limit, continue tokens, resource version)
- [x] Retry logic with exponential backoff and jitter
- [x] Watch API for streaming updates
- [x] Informers with local caching
- [x] CRD support with dynamic client
- [x] Server-side apply
- [x] JSON Patch and Strategic Merge Patch
- [x] Scale subresources
- [x] WebSocket operations (pod exec, attach, port-forward)
- [x] Protobuf serialization via zig-protobuf
- [x] Gateway API (GatewayClass, Gateway, HTTPRoute, GRPCRoute, ReferenceGrant)
- [x] Dynamic Resource Allocation (ResourceClaim, DeviceClass, ResourceSlice, DeviceTaintRule)
- [x] Metrics Server API (pod and node CPU/memory metrics)
- [x] RBAC CanI (SelfSubjectAccessReview permission checks)
- [x] Operational features: rollout restart, image update, pod eviction, node cordon
- [x] Enhanced pod logs (container, previous, tail, timestamps, sinceSeconds)
- [x] Structured K8s API error responses
- [x] Response size limits and 4x larger HTTP buffers
- [x] Status-code-aware retry logic (429, 500, 502, 503, 504)
- [x] Comprehensive unit test suite + live integration entrypoints (kind/Rancher Desktop)
- [x] Migration probe force-compiles the entire public API surface
