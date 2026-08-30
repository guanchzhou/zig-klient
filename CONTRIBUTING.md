# Contributing to zig-klient

Thanks for your interest! This is a Kubernetes client library for Zig **0.16.0**.

## Building & testing

```sh
zig build                      # build the library
zig build test                 # run all unit tests
zig build build-integration-tests   # compile the live integration entrypoints
zig fmt --check src/ tests/ build.zig build.zig.zon   # formatting gate (CI enforces this)
```

Dependencies (yaml-zig, zig-protobuf) are git-pinned in `build.zig.zon` and fetched
automatically — no sibling checkout needed.

### Integration tests

Live exec/CRUD entrypoints connect through `kubectl proxy` (the direct TLS path has a
known `std.crypto.tls` limitation against API servers that send
`certificate_request` (the default whenever `--client-ca-file` is set):

```sh
kubectl proxy --port=8080 --reject-paths='^$' &   # --reject-paths to allow exec
zig build test-pod-exec
zig build test-via-proxy
```

## Expectations for PRs

- **Formatting**: `zig fmt` clean (CI runs `zig fmt --check`).
- **Tests**: `zig build test` green. Add tests for new behavior. For new resource
  types, register them in `src/k8s/resource_registry.zig` (the single source of truth)
  and add a binding/round-trip test.
- **No lazy-compilation gaps**: if you add a public method to a lazily-compiled area
  (e.g. the streaming subsystem), reference it in `tests/migration_probe_test.zig`
  (`_ = &T.method`) so it is type-checked — `refAllDecls` alone does not analyze
  method bodies.
- **Commits**: [Conventional Commits](https://www.conventionalcommits.org/)
  (`feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `ci:`, `chore:`). No
  `Co-Authored-By` trailers.
- **Memory**: every allocation has a matching free / `errdefer`; functions returning
  parsed data return `std.json.Parsed(T)` with documented caller-frees-it semantics.

## Releasing (maintainers)

Bump `version` in `build.zig.zon`, add a `CHANGELOG.md` section, regenerate
`sbom.cdx.json`, then `git tag -a vX.Y.Z && git push origin vX.Y.Z` — the release
workflow builds, tests, and publishes the GitHub release with the SBOM + checksums.
