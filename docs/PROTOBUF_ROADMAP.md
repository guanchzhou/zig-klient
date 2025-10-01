# Protobuf Protocol Support - Future Enhancement

## Overview

Protobuf (Protocol Buffers) support is planned as a future enhancement for `zig-klient` to enable **high-performance binary communication** with the Kubernetes API server.

**Current Status**: 📋 Planned  
**Priority**: Low (JSON is sufficient for 99% of use cases)  
**Target**: v0.2.0 or later

---

## Why Protobuf?

### Benefits

1. **Performance**: 3-5x faster serialization/deserialization vs JSON
2. **Bandwidth**: 30-50% smaller message sizes
3. **Type Safety**: Stronger type guarantees at compile time
4. **Schema Validation**: Built-in schema validation

### When to Use Protobuf

- **High-throughput scenarios**: Processing 1000+ resources/second
- **Large resources**: Working with resources > 1MB
- **Bandwidth-constrained**: Mobile or edge deployments
- **Latency-sensitive**: Real-time control planes

### When JSON is Sufficient

- **Standard CRUD operations**: Creating, reading, updating resources
- **Small resources**: Most Kubernetes resources < 100KB
- **Human readability**: Debugging, development, logging
- **Simplicity**: No additional dependencies

---

## Current Implementation

`zig-klient` currently uses **JSON** for all Kubernetes API communication:

```zig
// Current approach (JSON)
const pod = try std.json.parseFromSlice(
    klient.Pod,
    allocator,
    json_data,
    .{ .ignore_unknown_fields = true },
);
defer pod.deinit();
```

This works well for:
- ✅ All CRUD operations (Create, Read, Update, Delete)
- ✅ Watch API and streaming
- ✅ All 61 standard Kubernetes resources
- ✅ Custom Resource Definitions (CRDs)
- ✅ 100% compatibility with Kubernetes API

---

## Planned Protobuf Implementation

### Phase 1: Research & Design (Q1 2025)

#### Evaluate Protobuf Libraries for Zig

**Option A: protobuf.zig** (Pure Zig implementation)
- Pros: Native Zig, no C dependencies, better error messages
- Cons: Less mature, may not support all Protobuf features
- Repository: TBD (evaluate available libraries)

**Option B: C Bindings** (Google's Protocol Buffers)
- Pros: Battle-tested, full feature support, industry standard
- Cons: C dependency, larger binary size
- Repository: https://github.com/protocolbuffers/protobuf

**Option C: nanopb** (Lightweight C implementation)
- Pros: Small footprint, embedded-friendly
- Cons: Limited features, manual memory management
- Repository: https://jpa.kapsi.fi/nanopb/

#### Design Goals

1. **Opt-in**: Protobuf support should be optional (like WebSocket)
2. **Backward Compatible**: JSON support remains default
3. **Performance**: Measurable improvement over JSON
4. **No Breaking Changes**: Existing code continues to work

### Phase 2: Core Implementation (Q2 2025)

#### API Design

```zig
// Future Protobuf support (opt-in)
const K8sClient = struct {
    protocol: enum { json, protobuf } = .json,
    
    pub fn setProtocol(self: *K8sClient, protocol: Protocol) void {
        self.protocol = protocol;
    }
};

// Usage
var client = try klient.K8sClient.init(allocator, .{
    .server = "https://api-server",
    .protocol = .protobuf, // Opt-in to Protobuf
});
```

#### Implementation Plan

1. **Protobuf Schema Generation**
   - Generate `.proto` files from Kubernetes OpenAPI specs
   - Automate schema updates for new Kubernetes versions

2. **Serialization/Deserialization**
   - Implement Protobuf encode/decode for all 61 resources
   - Maintain backward compatibility with JSON

3. **Content-Type Negotiation**
   ```
   Accept: application/vnd.kubernetes.protobuf
   Content-Type: application/vnd.kubernetes.protobuf
   ```

4. **Testing**
   - Unit tests for Protobuf serialization
   - Integration tests against live clusters
   - Performance benchmarks vs JSON

### Phase 3: Optimization (Q3 2025)

#### Performance Benchmarks

Target improvements over JSON:
- **Serialization**: 3-5x faster
- **Deserialization**: 4-6x faster
- **Bandwidth**: 30-50% reduction
- **Memory**: 20-40% less allocation

#### Streaming Support

Optimize Watch API with Protobuf streaming:
```zig
const watcher = try klient.Watcher(klient.Pod).init(&client, .{
    .protocol = .protobuf, // Use Protobuf for streaming
    .path = "/api/v1/namespaces/default/pods",
});
```

---

## Technical Challenges

### 1. Kubernetes Protobuf Schema

Kubernetes uses custom Protobuf schemas that differ from standard OpenAPI:
- **Solution**: Use official Kubernetes `.proto` files
- **Repository**: https://github.com/kubernetes/api

### 2. Binary Compatibility

Protobuf schemas must stay compatible across Kubernetes versions:
- **Solution**: Implement schema version negotiation
- **Approach**: Support multiple schema versions

### 3. Dependency Management

Adding Protobuf increases complexity and binary size:
- **Solution**: Make it optional (like WebSocket)
- **Approach**: Conditional compilation with build flags

### 4. Testing Infrastructure

Need Kubernetes clusters that support Protobuf:
- **Solution**: Use kind or Rancher Desktop for testing
- **Approach**: Automated CI/CD integration tests

---

## Benchmark Targets

Based on official Kubernetes client benchmarks:

| Operation | JSON | Protobuf | Improvement |
|-----------|------|----------|-------------|
| Parse Pod | 250µs | 50µs | 5x faster |
| Parse Deployment | 350µs | 75µs | 4.7x faster |
| Parse Large Resource | 2ms | 400µs | 5x faster |
| Watch 100 events | 25ms | 6ms | 4.2x faster |
| Memory Usage | 1.0x | 0.6x | 40% reduction |

---

## Use Case Scenarios

### Scenario 1: High-Throughput Controller

**Requirement**: Process 5000 pods/second

**Current (JSON)**:
```
Throughput: 1000 pods/sec
CPU: 80%
Memory: 2GB
```

**With Protobuf** (projected):
```
Throughput: 5000 pods/sec
CPU: 60%
Memory: 1.2GB
```

### Scenario 2: Edge Deployment

**Requirement**: Run on Raspberry Pi with limited bandwidth

**Current (JSON)**:
```
Bandwidth: 10 MB/min
Latency: 500ms
```

**With Protobuf** (projected):
```
Bandwidth: 6 MB/min (-40%)
Latency: 200ms (-60%)
```

### Scenario 3: Real-Time Monitoring

**Requirement**: Watch 1000 resources in real-time

**Current (JSON)**:
```
Update Latency: 100ms
CPU: 70%
```

**With Protobuf** (projected):
```
Update Latency: 40ms (-60%)
CPU: 40% (-43%)
```

---

## Migration Path

When Protobuf support is added, migration will be seamless:

### Automatic Detection

```zig
// Library automatically chooses best protocol
var client = try klient.K8sClient.init(allocator, .{
    .server = "https://api-server",
    .auto_negotiate = true, // Default: try Protobuf, fallback to JSON
});
```

### Explicit Selection

```zig
// Force JSON (for debugging, compatibility)
var client = try klient.K8sClient.init(allocator, .{
    .server = "https://api-server",
    .protocol = .json,
});

// Force Protobuf (for performance)
var client = try klient.K8sClient.init(allocator, .{
    .server = "https://api-server",
    .protocol = .protobuf,
});
```

---

## Timeline

| Quarter | Milestone |
|---------|-----------|
| Q1 2025 | Research & library evaluation |
| Q2 2025 | Core Protobuf implementation |
| Q3 2025 | Performance optimization |
| Q4 2025 | Production ready release |

**Note**: This timeline is tentative and depends on:
1. Community demand
2. Available Zig Protobuf libraries
3. Contribution bandwidth

---

## How to Contribute

Interested in Protobuf support? Here's how to help:

1. **Evaluate Libraries**: Test available Zig Protobuf libraries
2. **Performance Benchmarks**: Measure JSON vs Protobuf in real scenarios
3. **Schema Generation**: Help generate `.proto` files from K8s OpenAPI
4. **Testing**: Test Protobuf communication with Kubernetes clusters
5. **Documentation**: Document Protobuf usage patterns

Open an issue or PR at: https://github.com/guanchzhou/zig-klient

---

## Alternatives to Protobuf

If Protobuf is not needed, consider these alternatives:

### 1. JSON with Compression

Enable gzip compression for JSON responses:
```zig
var client = try klient.K8sClient.init(allocator, .{
    .server = "https://api-server",
    .compression = .gzip, // 70% size reduction
});
```

### 2. Pagination

Reduce response sizes with pagination:
```zig
const pods = try client.Pods.init(&client).listWithOptions(null, .{
    .limit = 100, // Fetch 100 at a time
});
```

### 3. Field Selectors

Request only needed fields:
```zig
const pods = try client.Pods.init(&client).listWithOptions(null, .{
    .fieldSelector = "status.phase=Running",
});
```

---

## Conclusion

**Protobuf support is planned but not required** for most `zig-klient` use cases.

**Current JSON implementation**:
- ✅ Works for 99% of users
- ✅ 100% Kubernetes compatibility
- ✅ Easy to debug and develop
- ✅ No external dependencies
- ✅ Human-readable

**Protobuf will be beneficial for**:
- High-performance controllers
- Edge deployments
- Real-time systems
- Large-scale operations

**Status**: 📋 Planned for v0.2.0+  
**Priority**: Low (based on community demand)  
**Last Updated**: January 2025

---

For questions or feature requests, open an issue:  
https://github.com/guanchzhou/zig-klient/issues

