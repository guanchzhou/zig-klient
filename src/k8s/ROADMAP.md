# Kubernetes Client Library - Feature Roadmap

## 🎯 Goal: Full-featured K8s client library matching official client capabilities

### ✅ Phase 1: Core Foundation (COMPLETED)
- [x] HTTP client with Bearer token auth
- [x] Basic GET requests
- [x] JSON response parsing
- [x] Pod listing
- [x] Cluster version info
- [x] Kubeconfig parsing (kubectl JSON)

### 🚀 Phase 2: Essential API Operations (COMPLETED)
- [x] **HTTP Methods**
  - [x] GET
  - [x] POST (create resources)
  - [x] PUT (update resources)
  - [x] DELETE (delete resources)
  - [x] PATCH (strategic merge, JSON patch, merge patch)

- [x] **Authentication**
  - [x] Bearer token
  - [ ] Client certificates (mTLS) - TODO
  - [ ] Exec credential plugins (AWS IAM, GCP, Azure) - TODO
  - [ ] OIDC token refresh - TODO
  - [ ] Service account tokens - TODO

- [x] **Core Resource Types** (with generic CRUD operations)
  - [x] Pods (list, get, create, update, delete, patch, logs)
  - [x] Deployments (list, get, create, update, delete, patch, scale)
  - [x] Services (list, get, create, update, delete, patch)
  - [x] ConfigMaps (list, get, create, update, delete, patch)
  - [x] Secrets (list, get, create, update, delete, patch)
  - [x] Namespaces (list, get, create, delete)
  - [x] Nodes (list, get)
  - [ ] StatefulSets - TODO
  - [ ] DaemonSets - TODO
  - [ ] Jobs - TODO
  - [ ] CronJobs - TODO

### 📡 Phase 3: Advanced Features
- [ ] **Watch/Stream API**
  - [ ] Watch single resource
  - [ ] Watch collection
  - [ ] Informers with caching
  - [ ] Resource version tracking
  - [ ] Reconnection logic

- [ ] **Patch Operations**
  - [ ] Strategic merge patch
  - [ ] JSON patch (RFC 6902)
  - [ ] Merge patch (RFC 7396)
  - [ ] Apply patch (server-side apply)

- [ ] **Subresources**
  - [ ] Pod logs streaming
  - [ ] Pod exec
  - [ ] Pod attach
  - [ ] Pod port-forward
  - [ ] Scale
  - [ ] Status

### 🔧 Phase 4: Production Features
- [ ] **Error Handling**
  - [ ] Retry logic with exponential backoff
  - [ ] Rate limiting (client-side)
  - [ ] Timeout configuration
  - [ ] Circuit breaker pattern

- [ ] **Performance**
  - [ ] Connection pooling
  - [ ] Request batching
  - [ ] Compression (gzip)
  - [ ] Protobuf support (binary protocol)

- [ ] **Discovery**
  - [ ] API discovery
  - [ ] Server version detection
  - [ ] Resource schema validation
  - [ ] OpenAPI schema support

### 🎨 Phase 5: Custom Resources & Extensions
- [ ] **CRDs (Custom Resource Definitions)**
  - [ ] Dynamic client
  - [ ] CRD registration
  - [ ] Custom resource validation

- [ ] **Admission Control**
  - [ ] Mutating webhooks
  - [ ] Validating webhooks

### 🔐 Phase 6: Security & Compliance
- [ ] **TLS Configuration**
  - [ ] Custom CA bundles
  - [ ] Certificate validation
  - [ ] Insecure skip verify (dev only)

- [ ] **RBAC Integration**
  - [ ] Self subject access review
  - [ ] Token review
  - [ ] Authorization checks

### 📊 Phase 7: Observability
- [ ] **Metrics**
  - [ ] Request latency
  - [ ] Request count
  - [ ] Error rates
  - [ ] Connection pool stats

- [ ] **Tracing**
  - [ ] OpenTelemetry integration
  - [ ] Request ID propagation

## 🛠️ Implementation Priority

### High Priority (Week 1-2)
1. POST/PUT/DELETE methods
2. Deployments, Services, ConfigMaps
3. Client certificate auth
4. Strategic merge patch

### Medium Priority (Week 3-4)
5. Watch/Stream API
6. Pod logs streaming
7. Retry logic & error handling
8. Connection pooling

### Lower Priority (Month 2+)
9. Exec/Attach/Port-forward
10. CRDs & dynamic client
11. Protobuf support
12. Full observability

## 📝 Architecture Decisions

### Resource Types
- Use Zig structs with JSON serialization
- Generic `Resource<T>` wrapper
- Metadata + Spec + Status pattern

### Watch Implementation
- Server-Sent Events (chunked transfer)
- Resource version bookmarking
- Automatic reconnection

### Error Handling
- Typed error sets per operation
- Structured K8s API errors
- User-friendly error messages

## 🔗 References
- [Kubernetes API Conventions](https://github.com/kubernetes/community/blob/master/contributors/devel/sig-architecture/api-conventions.md)
- [Client-go Design](https://github.com/kubernetes/client-go)
- [API Machinery](https://github.com/kubernetes/apimachinery)
