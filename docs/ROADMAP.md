# Kubernetes Client Library - Roadmap

## Current Status

### Implemented Features

#### Core Foundation
- [x] HTTP client with Bearer token auth
- [x] All HTTP methods (GET, POST, PUT, DELETE, PATCH)
- [x] JSON request/response handling
- [x] Kubeconfig parsing (kubectl JSON)

#### Authentication
- [x] Bearer token
- [x] Client certificates (mTLS)
- [x] Exec credential plugins (AWS EKS, GCP GKE, Azure AKS)
- [ ] OIDC token refresh
- [ ] Service account token rotation

#### Resource Types (14 total)
- [x] Pods (with logs)
- [x] Deployments (with scaling)
- [x] Services
- [x] ConfigMaps
- [x] Secrets
- [x] Namespaces
- [x] Nodes
- [x] StatefulSets
- [x] DaemonSets
- [x] Jobs
- [x] CronJobs
- [x] ReplicaSets
- [x] PersistentVolumes
- [x] PersistentVolumeClaims

#### Advanced Features
- [x] Watch/Stream API
- [x] Informers with local caching
- [x] Resource version tracking
- [x] Automatic reconnection
- [x] Retry logic with exponential backoff
- [x] Connection pooling
- [x] CRD support (dynamic client)
- [x] Strategic merge patch
- [x] JSON patch (RFC 6902)

### Future Enhancements

#### Subresources
- [ ] Pod exec (requires WebSocket)
- [ ] Pod attach (requires WebSocket)
- [ ] Pod port-forward (requires WebSocket)
- [x] Pod logs (implemented)
- [x] Scale subresource (implemented)

#### Performance
- [ ] Request batching
- [ ] gzip compression
- [ ] Protobuf support (binary protocol)

#### Discovery & Schema
- [ ] API discovery
- [ ] OpenAPI schema support
- [ ] Resource schema validation

#### Security
- [ ] Custom CA bundle configuration
- [ ] RBAC integration (self subject access review)
- [ ] Token review API

#### Observability
- [ ] Built-in metrics collection
- [ ] OpenTelemetry integration
- [ ] Request tracing

## Architecture Notes

### Resource Types
Uses Zig structs with JSON serialization following the generic `Resource<T>` pattern with Metadata + Spec + Status structure.

### Watch Implementation
Implements newline-delimited JSON streaming with resource version bookmarking and automatic reconnection on disconnect.

### Error Handling
Provides typed error sets per operation with structured Kubernetes API error responses.

## References
- [Kubernetes API Conventions](https://github.com/kubernetes/community/blob/master/contributors/devel/sig-architecture/api-conventions.md)
- [Client-go Design](https://github.com/kubernetes/client-go)
- [API Machinery](https://github.com/kubernetes/apimachinery)