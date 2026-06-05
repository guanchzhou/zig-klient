# Changelog

All notable changes to zig-klient are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.1] - 2026-06-05

Verification, CI, and portability follow-ups to 0.2.0. No library API changes.

### Added
- Live integration entrypoint `test-mutating-admission-policy` — full list → create →
  get → delete round-trip of the 1.36 GA resource through zig-klient, verified against
  Rancher Desktop running **Kubernetes 1.36.1** (via `kubectl proxy`).
- GitHub Actions: `ci.yml` (build + unit tests + integration-compile on push/PR) and
  `release.yml` (release-on-tag, attaches the CycloneDX SBOM).
- Integration helper now wires client-certificate kubeconfig auth into `TlsConfig`.

### Fixed
- `build.zig`: link libc for the library, test, and integration-exe modules. Linux
  requires explicit libc for the std functions used (clock_gettime, threads, file I/O);
  macOS links it implicitly, so this only surfaced in CI.
- CI installs Zig 0.16.0 directly from ziglang.org (sha256-verified) — the setup-zig
  action's mirror 404s on 0.16.0.

### Notes
- README readability pass and accurate "tested against 1.36.1" status.
- The TLS path still fails against self-signed clusters (`error.TlsInitializationFailed`,
  a `std.crypto.tls` limitation); use `kubectl proxy` or `connectWithFallback()`.

## [0.2.0] - 2026-06-05

First tagged release. Builds on the completed Zig 0.16 migration with Kubernetes 1.36 API support.

### Added
- **Kubernetes 1.36 API support** (65 resource types across 20 API groups):
  - `MutatingAdmissionPolicy` and `MutatingAdmissionPolicyBinding` — new GA resource
    kinds in `admissionregistration.k8s.io/v1`.
  - `PodSpec.hostUsers` — user-namespace isolation (GA in 1.36).
  - `Volume.image` + `ImageVolumeSource` (`reference`, `pullPolicy`) — OCI image
    volumes (stable in 1.36).
  - DRA `adminAccess` / prioritized lists (GA) are preserved via
    `ResourceClaimSpec.devices` (`std.json.Value`) — covered by a round-trip test.
- `tests/k8s_136_fields_test.zig` and new admission-policy tests, including a
  registry-metadata assertion for the new kinds.

### Changed
- Requires **Zig 0.16.0** (`minimum_zig_version`).
- README updated to reflect 65 resource types and K8s 1.36; corrected a
  pre-existing miscount (header said 62 while the registry held 63).

### Fixed
- Removed redundant `std.debug.print("✅ …")` success lines from the 24-file unit
  suite. Under Zig 0.16's `--listen=` build-runner protocol these caused ~20
  spurious "failed command" lines even though every test passed (exit 0) — noise
  that could mask a genuine failure. `zig build test` now produces clean output.

### Notes
- Tested against Rancher Desktop running Kubernetes 1.35.3. The 1.36-only resource
  kinds (e.g. `MutatingAdmissionPolicy`) are unit-tested only; exercising them live
  requires a 1.36 API server.

## [0.1.0]

- Baseline: Kubernetes client library with CRUD across the standard resource set,
  WebSocket exec/attach/port-forward, watch/informers, connection pooling, retry
  logic, exec-credential plugins, and Protobuf serialization. Completed the
  Zig 0.15 → 0.16 migration.

[0.2.1]: https://github.com/guanchzhou/zig-klient/releases/tag/v0.2.1
[0.2.0]: https://github.com/guanchzhou/zig-klient/releases/tag/v0.2.0
