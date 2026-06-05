# Testing Guide

## Unit tests (`tests/`)

Isolated tests that need no cluster — type/JSON binding, registry metadata, retry
logic, kubeconfig parsing, query/option builders, watch/informer structure, the K8s
1.36 additions, etc. Each `tests/<name>_test.zig` is wired in `build.zig`.

```sh
zig build test                 # run the whole unit suite
zig build test-retry           # a single suite (see build.zig for names)
zig build test-json-binding    # e.g. the type/continue field-binding regression
```

`tests/migration_probe_test.zig` force-compiles the public API surface — including
every streaming method body — so lazy-compilation breakage fails here rather than in
a downstream consumer.

## Integration entrypoints (`tests/entrypoints/`)

Standalone executables that exercise the client against a **real cluster**. Because
the direct TLS path has a known `std.crypto.tls` limitation against self-signed
clusters, they connect through `kubectl proxy`:

```sh
kubectl proxy --port=8080 --reject-paths='^$' &   # --reject-paths needed for exec/attach
zig build build-integration-tests                 # compile them all (also run in CI)
zig build test-via-proxy                           # pods / namespaces / nodes + pod CRUD
zig build test-pod-exec                            # pod exec over WebSocket (needs a running pod)
zig build test-mutating-admission-policy           # K8s >= 1.36 MutatingAdmissionPolicy CRUD
```

For `test-pod-exec`, create a target pod first:

```sh
kubectl run zig-klient-exec-test --image=busybox:1.36 --restart=Never --command -- sleep 3600
kubectl wait --for=condition=Ready pod/zig-klient-exec-test
```

## Comprehensive suite (`tests/comprehensive/`)

Larger scenarios (e.g. high-volume list pagination) that require a cluster — see that
directory's README.

## Prerequisites

- A running cluster (Rancher Desktop, kind, minikube). Verified against Kubernetes
  1.36.1.
- `kubectl proxy` for the integration entrypoints (see above).

## Notes

- CI runs the unit suite on Linux + macOS, a `zig fmt --check` gate, and a
  non-blocking Zig-`master` canary. Integration entrypoints are compiled in CI but
  run against a live cluster locally.
