# WebSocket and Protobuf Implementation Plan

## Goal: Achieve True 100% Feature Parity

Currently at **100% core feature parity**, now adding the final features that require external dependencies:
- WebSocket operations (pod exec, attach, port-forward)
- Protobuf protocol support

## Libraries Identified

### 1. WebSocket Support
**Library**: `websocket.zig` by Karl Seguin
- **Repository**: https://github.com/karlseguin/websocket.zig
- **Features**:
  - Client and server WebSocket implementation
  - Text and binary message handling
  - Connection lifecycle management
  - Blocking and non-blocking modes
  - Well-maintained and documented

**Use Cases**:
- Pod exec: Execute commands in running containers
- Pod attach: Attach to running container processes
- Pod port-forward: Forward local ports to pod ports
- Pod logs (streaming): Real-time log tailing

### 2. Protobuf Support
**Library Options**:

**Option A: Zig bindings to C Protobuf (Recommended)**
- Use Google's official Protobuf C library
- Create Zig bindings using `@cImport`
- Most compatible with Kubernetes API

**Option B: nanopb (Lightweight)**
- Small-footprint C implementation
- Easier to integrate
- Good for embedded systems

**Use Cases**:
- Binary protocol communication (more efficient than JSON)
- Large data transfers
- High-performance scenarios
- Reduced bandwidth usage

## Implementation Phases

### Phase 1: WebSocket Foundation (Week 1-2)

#### 1.1 Add WebSocket Dependency
```zig
// build.zig.zon
.{
    .name = "zig-klient",
    .version = "0.1.0",
    .dependencies = .{
        .yaml = .{
            .path = "../zig-yaml",
        },
        .websocket = .{
            .url = "https://github.com/karlseguin/websocket.zig/archive/main.tar.gz",
            .hash = "...", // zig will provide this
        },
    },
}
```

#### 1.2 Create WebSocket Client Module
```
src/k8s/
├── websocket_client.zig    # WebSocket wrapper for K8s
├── exec.zig                # Pod exec implementation
├── attach.zig              # Pod attach implementation
└── port_forward.zig        # Port forwarding implementation
```

#### 1.3 Implement Core WebSocket Functionality
- WebSocket connection establishment
- SPDY/HTTP2 upgrade handling (Kubernetes specific)
- Stream multiplexing
- Error handling and reconnection

### Phase 2: Pod Exec (Week 2)

#### 2.1 Exec API Implementation
```zig
// src/k8s/exec.zig
pub const ExecOptions = struct {
    command: []const []const u8,
    stdin: bool = false,
    stdout: bool = true,
    stderr: bool = true,
    tty: bool = false,
    container: ?[]const u8 = null,
};

pub const ExecClient = struct {
    ws_client: *WebSocketClient,
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator, k8s_client: *K8sClient) !ExecClient;
    pub fn exec(
        self: *ExecClient,
        pod_name: []const u8,
        namespace: []const u8,
        options: ExecOptions,
    ) !ExecResult;
};
```

#### 2.2 Stream Handling
- stdin stream (channel 0)
- stdout stream (channel 1)
- stderr stream (channel 2)
- error stream (channel 3)
- resize stream (channel 4) for TTY

#### 2.3 Example Usage
```zig
var exec_client = try klient.ExecClient.init(allocator, &k8s_client);
defer exec_client.deinit();

const result = try exec_client.exec("my-pod", "default", .{
    .command = &[_][]const u8{ "ls", "-la" },
    .stdout = true,
    .stderr = true,
});
defer result.deinit();

std.debug.print("Output: {s}\n", .{result.stdout});
```

### Phase 3: Pod Attach (Week 3)

#### 3.1 Attach API Implementation
```zig
// src/k8s/attach.zig
pub const AttachOptions = struct {
    stdin: bool = false,
    stdout: bool = true,
    stderr: bool = true,
    tty: bool = false,
    container: ?[]const u8 = null,
};

pub const AttachClient = struct {
    pub fn attach(
        self: *AttachClient,
        pod_name: []const u8,
        namespace: []const u8,
        options: AttachOptions,
    ) !AttachSession;
};
```

#### 3.2 Interactive Session Handling
- Bidirectional communication
- Signal handling (SIGTERM, SIGKILL)
- Terminal resize events

### Phase 4: Port Forward (Week 3-4)

#### 4.1 Port Forward API Implementation
```zig
// src/k8s/port_forward.zig
pub const PortForwardOptions = struct {
    ports: []const PortMapping,
};

pub const PortMapping = struct {
    local: u16,
    remote: u16,
};

pub const PortForwarder = struct {
    pub fn forward(
        self: *PortForwarder,
        pod_name: []const u8,
        namespace: []const u8,
        options: PortForwardOptions,
    ) !ForwardSession;
};
```

#### 4.2 Example Usage
```zig
var forwarder = try klient.PortForwarder.init(allocator, &k8s_client);
defer forwarder.deinit();

const session = try forwarder.forward("my-pod", "default", .{
    .ports = &[_]PortMapping{
        .{ .local = 8080, .remote = 80 },
        .{ .local = 5432, .remote = 5432 },
    },
});
defer session.stop();

// Ports are now forwarded
// Access pod's port 80 via localhost:8080
```

### Phase 5: Protobuf Support (Week 4-5)

#### 5.1 Add Protobuf Dependency
```zig
// build.zig
const protobuf_dep = b.dependency("protobuf-c", .{
    .target = target,
    .optimize = optimize,
});
```

#### 5.2 Create Protobuf Module
```
src/k8s/
├── protobuf.zig           # Protobuf serialization/deserialization
├── proto/                 # Generated proto bindings
│   ├── api.pb.zig
│   ├── meta.pb.zig
│   └── runtime.pb.zig
```

#### 5.3 Implement Protobuf Client
```zig
// src/k8s/protobuf.zig
pub const ProtobufClient = struct {
    allocator: std.mem.Allocator,
    
    pub fn encode(self: *ProtobufClient, resource: anytype) ![]u8;
    pub fn decode(self: *ProtobufClient, comptime T: type, data: []const u8) !T;
};
```

#### 5.4 Protocol Negotiation
```zig
// Add content negotiation to K8sClient
const headers = .{
    .accept = "application/vnd.kubernetes.protobuf",
    .content_type = "application/vnd.kubernetes.protobuf",
};
```

### Phase 6: Integration and Testing (Week 5-6)

#### 6.1 Comprehensive Tests
```
tests/websocket/
├── exec_test.zig           # Pod exec tests
├── attach_test.zig         # Pod attach tests
├── port_forward_test.zig   # Port forwarding tests
└── protobuf_test.zig       # Protobuf encoding/decoding
```

#### 6.2 Test Scenarios
**Exec Tests:**
- Simple command execution
- Multi-line output
- Large output (>1MB)
- Binary output
- Interactive commands
- Error handling
- Timeout scenarios

**Attach Tests:**
- Attach to running process
- Send input via stdin
- Receive stdout/stderr
- Terminal resize
- Detach/reattach

**Port Forward Tests:**
- Single port forward
- Multiple ports
- Long-running connections
- Connection errors
- Auto-reconnect

**Protobuf Tests:**
- Encode/decode all resource types
- Large resource lists
- Performance comparison with JSON
- Binary data handling

#### 6.3 Performance Benchmarks
- Exec latency vs kubectl
- Port forward throughput
- Protobuf vs JSON size reduction
- Memory usage comparison

## Technical Considerations

### WebSocket Protocol for Kubernetes

Kubernetes uses a modified WebSocket protocol with SPDY framing:

```
GET /api/v1/namespaces/{namespace}/pods/{name}/exec?command=ls&stdout=true
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Protocol: v4.channel.k8s.io
```

**SPDY Channels**:
- Channel 0: stdin
- Channel 1: stdout
- Channel 2: stderr
- Channel 3: error
- Channel 4: resize (for TTY)

Each frame has:
```
[channel byte][data...]
```

### Protobuf Schema

Kubernetes Protobuf schemas are in:
- `k8s.io/api` - API definitions
- `k8s.io/apimachinery` - Common types

We'll need to:
1. Generate Zig bindings from `.proto` files
2. Handle oneof/any types
3. Support all Kubernetes API groups

### Security Considerations

**WebSocket Security**:
- TLS for wss://
- Bearer token authentication
- Certificate validation
- Timeout handling

**Protobuf Security**:
- Size limits (prevent DoS)
- Schema validation
- Backwards compatibility

## File Structure After Implementation

```
zig-klient/
├── src/
│   ├── klient.zig
│   └── k8s/
│       ├── client.zig
│       ├── types.zig
│       ├── resources.zig
│       ├── websocket_client.zig  # NEW
│       ├── exec.zig               # NEW
│       ├── attach.zig             # NEW
│       ├── port_forward.zig       # NEW
│       ├── protobuf.zig           # NEW
│       └── proto/                 # NEW
│           ├── api.pb.zig
│           └── meta.pb.zig
│
├── tests/
│   ├── websocket/                 # NEW
│   │   ├── exec_test.zig
│   │   ├── attach_test.zig
│   │   └── port_forward_test.zig
│   └── protobuf/                  # NEW
│       └── protobuf_test.zig
│
└── build.zig.zon                  # UPDATED with dependencies
```

## Dependencies Update

```zig
// build.zig.zon
.{
    .name = "zig-klient",
    .version = "0.1.0",
    .dependencies = .{
        .yaml = .{
            .path = "../zig-yaml",
        },
        .websocket = .{
            .url = "https://github.com/karlseguin/websocket.zig/archive/main.tar.gz",
            .hash = "1220...", // Will be provided by zig
        },
        // Protobuf will be added after WebSocket is complete
    },
}
```

## Timeline

| Phase | Duration | Deliverable |
|-------|----------|-------------|
| WebSocket Foundation | Week 1-2 | WebSocket client module |
| Pod Exec | Week 2 | Exec functionality |
| Pod Attach | Week 3 | Attach functionality |
| Port Forward | Week 3-4 | Port forwarding |
| Protobuf | Week 4-5 | Protobuf support |
| Testing | Week 5-6 | Complete test suite |
| **Total** | **6 weeks** | **100% Feature Parity** |

## Success Criteria

### WebSocket Features
- ✅ Pod exec works for all command types
- ✅ Pod attach supports interactive sessions
- ✅ Port forward handles multiple ports
- ✅ All features work with TLS/mTLS
- ✅ Error handling and reconnection
- ✅ Performance comparable to kubectl

### Protobuf Support
- ✅ All resource types encode/decode
- ✅ Binary protocol negotiation
- ✅ 30-50% size reduction vs JSON
- ✅ Backward compatible with JSON
- ✅ Performance improvement measured

## Benefits After Implementation

### For Developers
- ✅ Complete Kubernetes client in pure Zig
- ✅ No kubectl dependency for any operation
- ✅ Interactive debugging capabilities
- ✅ Production-ready for all use cases

### For DevOps/SREs
- ✅ Single binary for all K8s operations
- ✅ Reduced bandwidth (Protobuf)
- ✅ Better performance
- ✅ Complete automation possible

### For End Users
- ✅ True 100% feature parity with C client
- ✅ All Kubernetes operations supported
- ✅ Interactive and automated workflows
- ✅ Production-grade reliability

## Next Steps

1. **Immediate**: Add websocket.zig dependency to build.zig.zon
2. **Week 1**: Implement WebSocket client wrapper
3. **Week 2**: Implement pod exec
4. **Week 3**: Implement pod attach and port-forward
5. **Week 4-5**: Add Protobuf support
6. **Week 6**: Comprehensive testing

---

**Status**: Ready to implement
**Target**: True 100% Feature Parity (including WebSocket & Protobuf)
**Timeline**: 6 weeks
**Dependencies**: websocket.zig, protobuf-c

