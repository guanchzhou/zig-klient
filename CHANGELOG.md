# Changelog

All notable changes to zig-klient are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.5.0] - 2026-08-21

### Changed
- **Kubeconfig YAML parsing switched from `guanchzhou/zig-yaml` to
  [`sakakibara/yaml-zig`](https://github.com/sakakibara/yaml-zig), and the
  hand-written tree walkers replaced with comptime typed decoding** (net -244
  lines). Upstream `kubkon/zig-yaml` has been unmaintained since 2026-01, so the
  fork inherited its bugs permanently and every future Zig migration by hand.
  The replacement is 0.16-native, actively developed, and additionally supports
  anchors, aliases and merge keys, which the fork rejects outright.

  The public API is unchanged — `Cluster`/`Context`/`User`/`Kubeconfig`, the
  lookup accessors, and `deinit(allocator)` all keep their signatures.

  `Kubeconfig` now owns a heap-allocated arena and frees its whole graph at
  once, replacing ~90 lines of per-field frees and errdefer unwinding. `deinit`
  still accepts an allocator for compatibility but ignores it in favour of the
  arena's own `child_allocator`, so a mismatched allocator can no longer
  corrupt the free.

### Fixed
- **Double free in `loadInClusterConfig`.** An `errdefer allocator.free(token)` was
  paired with an unconditional `allocator.free(token)` a few lines later, so any
  later failure unwound the errdefer and freed the same allocation twice. The
  `error.ServiceAccountCANotFound` path immediately below it is reachable in a real
  pod with no `ca.crt`.
- **Use-after-free of the watch `resourceVersion`.** A BOOKMARK stored a slice that
  pointed into the event's parse arena and then freed that arena, leaving a dangling
  value that was read by the informer and interpolated into the next watch URL — so a
  garbage `resourceVersion` was sent to the API server. `Watcher` now owns a duped
  copy and exposes `deinit()` to release it; the borrowed initial value from
  `WatchOptions` is never freed.
- **Uninitialised read on every watch event.** `WatchEnvelope.object` was
  `T = undefined` and the informer dereferenced `event.object.metadata.name` for all
  event types. It is now `?T = null`.
- **A single bookmark tore down the whole watch.** `ObjectMeta.name` is required, but
  a BOOKMARK's object carries only `resourceVersion` and an ERROR's object is a
  `Status`, so neither binds to `T` — and `allow_watch_bookmarks` defaults to true.
  Events are now dispatched on a type-only envelope first, and a single malformed
  object is logged and skipped instead of killing the stream.
- **Deadlock in the exec credential plugin.** `.stderr = .pipe` was requested and
  never drained, so a plugin writing past the pipe buffer (~64 KiB, easily reached by
  `aws eks get-token` emitting warnings) blocked on write while the client blocked in
  `child.wait()`. stderr is now inherited, and a guarded `errdefer` reaps the child on
  earlier failure paths.
- **Watch and pod-stream query parameters are percent-encoded.** The 0.4.0 encoding
  fix reached `ListOptions` but not `watch`, `exec`, `attach` or `port-forward`, which
  kept hand-building their query strings. A set-based selector from
  `LabelSelector.addIn` ("app in (a,b)") produced a malformed request line, so the
  library's own selector API could not be used with its own watch. For the pod streams
  it was also an injection: a command ending `ls&stdin=true` turned on stdin even
  though the caller had not asked for it.
- **`emit_null_optional_fields` is now false** for resource, patch and cache
  serialization. Since every Kubernetes type is `?T = null`, bodies were mostly nulls.
  `JsonPatch.build` emitted `{"op":"remove","path":"/x","value":null,"from":null}`,
  which RFC 6902 forbids and strict implementations reject.
- **A `Status` without `code` no longer makes 404s and 403s retry.** The code fell
  back to `null`, which `retry.shouldRetry` cannot distinguish from a transport
  failure, so such responses were retried the full budget with backoff. The HTTP
  status is now used as the fallback.
- **`insecure-skip-tls-verify` is no longer silently dropped.** The old
  `parseCluster` accepted only a `.boolean` YAML value, but zig-yaml built
  `.boolean` solely on its stringify path and never when parsing, so `true`
  arrived as the scalar `"true"` and was discarded. Still masked downstream by
  the `insecure_skip_verify` guard in `client.zig`, which reports it as
  unsupported because `std.http.Client` does not expose TLS internals.

### Notes
- `zig build test-fuzz --fuzz` does not compile on Zig 0.16.0 due to a bug in
  the toolchain's own `compiler/test_runner.zig` (`*builtin.StackTrace` vs
  `*const debug.StackTrace`), unrelated to this change and reproducible on an
  unmodified tree. The single-shot fuzz run under `zig build test` still works.

### Removed
- Dead code, each verified unreferenced across `src/`, `tests/`, `docs/` and the
  README before deletion: `client.KubeConfig` (superseded by
  `kubeconfig_yaml.Kubeconfig`), `tls.readFileToAlloc` (whose doc comment cited two
  functions that do not exist), and `retry.retryWithBackoff` (which duplicated
  `sendWithRetry`'s loop and took `operation: anytype` but invoked it with no
  arguments).
- `version` / `versionString()` in `klient.zig` reported `0.1.0-alpha` while the
  manifest declared `0.4.0` — three releases stale, in two hand-maintained copies.
  Both must now be bumped alongside `build.zig.zon`; there is no compile-time link.

### Build
- **`test-comprehensive` and the WebSocket integration test now actually compile.**
  The former was `_ = b.step(...)` — a step with no dependencies, so it built and ran
  nothing — and the latter was never referenced by `build.zig` at all. Between them
  1,933 lines of test code had silently stopped compiling against Zig 0.16. Both are
  wired up, and the suites migrated to the 0.16 APIs (`std.process.run`,
  `std.heap.DebugAllocator`, and threading `std.Io`). They still require a live
  cluster to run; compiling them in CI is what stops them rotting again.

## [0.4.0] - 2026-08-10

### Fixed
- **A non-JSON error body no longer discards the status code.** `setApiErrorFromStatusJson`
  is best-effort, and the JSON request path had no fallback: when a load balancer or
  ingress in front of the API server answered `503` with an HTML body, the caller got
  `error.K8sApiError` with `last_api_error == null` — no reason, no message, not even
  the status. The Protobuf path already handled this; both now do.
- **`last_api_error` no longer leaks across requests.** It was cleared only when a
  *new* Kubernetes `Status` error replaced it, so a successful call — or any
  transport-level failure, which never populates it — left the previous call's error
  in place. A caller inspecting the field after catching an error (the documented
  way to get error detail, and what the integration entrypoints do) reported a
  stale, unrelated cause. It is now cleared at the start of every request attempt,
  so it describes the current request or is null.
- **TLS options that cannot be honoured are now rejected instead of silently
  dropped.** `K8sClient.init` accepted `client_cert_data`, `client_key_data`,
  `client_cert_path`, `client_key_path`, `insecure_skip_verify` and `server_name`
  and then used none of them — only the CA was ever wired up. A caller configuring
  client-certificate auth got an unauthenticated client and, much later, an opaque
  `error.TlsInitializationFailed`. These now fail at construction with
  `error.ClientCertificatesUnsupported`, `error.InsecureSkipVerifyUnsupported` or
  `error.TlsServerNameUnsupported`.
  - Zig 0.16's `std.crypto.tls.Client` has no client-certificate support, and
    `std.http.Client` exposes no verification or SNI overrides, so none of these
    can be implemented here today.
  - The README advertised mTLS as a supported feature with a worked example. That
    claim is withdrawn.
- **`error.TlsInitializationFailed` now explains itself.** `std.http.Client` returns
  it for every handshake failure with the cause discarded. The real cause against a
  Kubernetes cluster is that `std.crypto.tls.Client` has no handling for the
  `certificate_request` handshake message (it appears nowhere in
  `std/crypto/tls/Client.zig`), and an API server sends one whenever started with
  `--client-ca-file` — the default everywhere. The handshake aborts with
  `TlsUnexpectedMessage`. The client now logs the cause and the `kubectl proxy`
  workaround. The README previously blamed self-signed certificates, which was
  wrong: a publicly-trusted managed cluster fails identically.
- **A failed TLS handshake is no longer retried.** It is deterministic, so the retry
  loop only burned the backoff budget and repeated the diagnostic four times.
- **`K8sClient.init` no longer leaks the system trust store on error paths.** The CA
  bundle rescan allocates before any later failure could return; added an `errdefer`
  and moved config validation ahead of all allocation.

### Fixed (earlier in this release)
- **Query values are now percent-encoded.** `QueryWriter.addString` emitted values
  raw, so any value containing a space or reserved character corrupted the HTTP
  request target. This made the library's own `LabelSelector.addIn`/`addNotIn`
  unusable: `app in (traefik,coredns)` produced the request line
  `GET /...?labelSelector=app in (traefik,coredns) HTTP/1.1`, which a spec-compliant
  server rejects with **400 Bad Request** — and the retry loop then repeated it
  four times. Verified fixed against a live apiserver.
  - Continue tokens were never affected: the apiserver emits them with base64
    `RawURLEncoding`, which is already URL-safe.
  - Query strings now read `fieldSelector=metadata.name%3Dmy-pod`. The apiserver
    decodes before parsing selectors, so behaviour is unchanged for values that
    previously worked.

### Performance
- **`Pod.status` and `Node.status` are typed** rather than `std.json.Value`. An
  untyped status is parsed into a DOM — one hash map per object, per item.
  Measured on a 500-pod / 2.5 MB list: **5.33 ms -> 4.46 ms (-16%)** and
  **10.5 MB -> 5.25 MB resident (-50%)**.
  - `PodStatus`/`ContainerStatus` already existed but nothing referenced them —
    `Pod` was `Resource(PodSpec)`, whose `status` is dynamic. They are now used,
    and extended to cover what real objects carry (conditions, podIPs/hostIPs,
    qosClass, startTime, container state/lastState, image, containerID).
  - `ContainerState` is typed too, so `state.waiting.reason` — the reason kubectl
    prints in the STATUS column (`CrashLoopBackOff`, `ImagePullBackOff`) — no
    longer needs a DOM lookup.
  - `NodeStatus` covers conditions, addresses, nodeInfo and images. `capacity`/
    `allocatable` stay dynamic: their keys are open-ended (`hugepages-*`, vendor
    devices). `status.images` is routinely the largest part of a Node object.
  - Reads of `pod.status.?.object.get("phase").?.string` become `pod.status.?.phase`.
- **`getNodeCount` no longer downloads the cluster.** It listed every Node in full
  and DOM-parsed the result to return one integer; it now requests `?limit=1` and
  reads `metadata.remainingItemCount`, so cost is independent of cluster size.
- **`ResourceClient.listPages`** walks a collection page by page, following
  `continue` tokens. `list()` buffers the entire collection, so memory scales with
  the cluster and the request fails outright past `max_response_size` (16 MB by
  default — roughly 3k pods). `listPages` keeps both O(page). Covered by
  `tests/entrypoints/test_list_pages.zig`, which needs no cluster.

### Changed (breaking)
- **`client.last_api_error` is removed; error detail is returned, not stored.**
  Capture it with `requestCapturing` / `requestCapturingWithContentType` /
  `requestWithProtobufCapturing`, or by setting `ResourceClient.error_sink`. The
  storage and the strings belong to the caller (`ApiError.deinit(allocator)`).

  The field was mutable per-request state on a shared object, with three consequences:
  - `K8sClient` could not be shared across threads, even though the `std.http.Client`
    underneath is thread-safe ("Connections are opened in a thread-safe manner").
    Every thread therefore needed its own client and its own connection pool. A
    `ResourceClient` is a value, so `error_sink` lives at the call site: one client now
    serves many threads, each with its own sink. Exercised by
    `tests/entrypoints/test_error_capture.zig`.
  - The strings were freed by the following request, so anything a caller kept became
    a dangling reference.
  - It survived across calls (fixed earlier in this release, and now structurally
    impossible).

  A sink holds the detail of the most recent call made through it, or null. Each
  call frees whatever the previous one left there, so a sink is safe to reuse and a
  success clears it. (Assigning without freeing leaked the earlier status/message/
  reason — reported by Cursor Bugbot on the PR — and leaving it in place brought
  back the staleness this change set out to remove.)

  Migration:
  ```zig
  // before
  _ = client.request(.GET, path, null) catch |err| {
      if (client.last_api_error) |e| { ... }
  };

  // after
  var api_err: ?klient.K8sClient.ApiError = null;
  defer if (api_err) |*e| e.deinit(allocator);
  _ = client.requestCapturing(.GET, path, null, &api_err) catch |err| {
      if (api_err) |e| { ... }
  };
  ```
  `request`, `requestWithContentType`, `requestWithProtobuf` and `requestWithRetry`
  keep their signatures and simply report no detail.

### Changed
- **The JSON and Protobuf request paths now share one implementation.**
  `requestWithProtobuf` carried its own ~90-line copy of the send/receive logic —
  URL building, auth, redirects, status handling, decompression, size limiting —
  differing only in two headers. The copies had already drifted (only one had the
  status-code fallback above, and a fix earlier in this release had to be applied
  twice). `K8sClient.WireFormat` now carries the `Content-Type`/`Accept` pair and
  `sendOnce` takes it.
  - Protobuf requests consequently follow the same retry policy as JSON ones
    (idempotent methods retried, POST sent once). Previously they were never
    retried, which was an accident of the duplication rather than a decision.
- **The four list entry points share one fetch-and-parse body.** `list`,
  `listAll`, `listWithOptions` and `listAllWithOptions` each repeated the same
  request/parse block; they are now thin wrappers that differ only in base path.
  Verified against a logging server to produce byte-identical URLs.

### Removed
- `PaginatedList` — declared but never constructed by anything; `listPages`
  supersedes it.
- `src/k8s/kubeconfig_json.zig` (212 LOC) — self-marked deprecated, shadowed by
  `kubeconfig_yaml.zig`, and referenced by nothing: not by `build.zig`, not
  re-exported from `klient.zig`, not imported by any module or test.
- `tls.TlsBundle`, `tls.createBundle`, `tls.CertInfo`, `tls.loadFromFiles` and
  `tls.validateCertKeyPair` — all existed to assemble or check a client
  certificate/key pair, which `K8sClient.init` now rejects outright. `createBundle`,
  `CertInfo` and `loadFromFiles` additionally had no callers at all, and
  `loadFromFiles` produced a `TlsConfig` that `init` would refuse. Supply a CA with
  `TlsConfig.ca_cert_path` / `ca_cert_data` instead. `tls.decodeBase64Cert` stays —
  it is still useful for CA data out of a kubeconfig.
  - `src/k8s/tls.zig` shrank from 201 to 80 lines.

### Added
- `EventSeries` (`count`, `lastObservedTime`) and `Event.series`. The modern
  `client-go/tools/events` recorder (kubelet `BackOff`, `Unhealthy`, …) collapses
  repeated events into `series` and leaves the deprecated `count`/`lastTimestamp`
  unset. Consumers rendering COUNT / LAST-SEEN must prefer `series` when present,
  as kubectl does — otherwise an aggregated series renders as count `0` with a
  last-seen stuck at the first occurrence.
- `PersistentVolumeSpec.claimRef` (`ObjectReference`) for the PV CLAIM column.

### Changed (breaking)
- `Event` is no longer `Resource(EventSpec)`. core/v1 Events carry
  `type`/`reason`/`message`/`involvedObject`/`count`/timestamps as **top-level**
  fields, which the generic spec/status wrapper silently dropped via
  `ignore_unknown_fields`. `Event` is now a flat struct with those fields.
  - `types.EventSpec` is **removed**. Reads of `event.spec.?.reason` become
    `event.reason`.
  - `reportingController` → `reportingComponent` (the former is the
    `events.k8s.io/v1` spelling; core/v1 uses the latter).
- New exports: `types.Event`, `types.EventInvolvedObject`, `types.EventSeries`.
- Seven more kinds had the same defect and are now flat structs. Each has **no
  `spec`** in the Kubernetes API — their payload is top-level — so modelling them
  as `Resource(T)` parsed without error while dropping every field (`spec` bound
  to `null`, the real keys eaten by `ignore_unknown_fields`). Most visibly,
  **every `ConfigMap` read returned no data**.

  | Type | Fields recovered |
  |---|---|
  | `ConfigMap` | `data`, `binaryData`, `immutable` (new) |
  | `Endpoints` | `subsets` |
  | `PodTemplate` | `template` |
  | `Binding` | `target` |
  | `ControllerRevision` | `revision`, `data` |
  | `EndpointSlice` | `addressType`, `endpoints`, `ports` |
  | `CSIStorageCapacity` | `storageClassName`, `capacity`, `maximumVolumeSize`, `nodeTopology` |

  `Binding` was also broken on the write path: it serialized as
  `{"spec":{"target":…}}`, which the API server accepts and ignores, so binding a
  pod to a node silently did nothing.

  Removed with them: `types.ConfigMapData`, `types.EndpointsSpec`,
  `types.PodTemplateResourceSpec`, `types.BindingSpec`,
  `types.ControllerRevisionSpec`, `types.EndpointSliceSpec`,
  `types.CSIStorageCapacitySpec`. Reads of `cm.spec.?.data` become `cm.data`.

## [0.3.2] - 2026-06-05

### Fixed
- `getNodeCount`/`ClusterInfo.node_count` now return `?u32` — `null` means the count
  could not be determined (request/parse failure), distinct from a real empty
  cluster (`0`). Previously any error was silently reported as `0`.

### Docs
- Corrected the README to match the 0.16 API: every example now passes `io` to
  `K8sClient.init`/`WebSocketClient.init`/`executeCredentialPlugin`/`isInCluster`/
  `loadInClusterConfig`; `DebugAllocator` (not `GeneralPurposeAllocator`); the Watch
  example uses the real callback API; `Informer.init`'s 5 args; snake_case
  `ListOptions`; removed all Connection Pooling references; fixed the Auth Methods
  parity (4/5, not 100% — no HTTP basic auth) and cluster-scoped count (30).

### Notes
- The remaining review items (re-export chain, spin-lock mutex, `client.client`
  indirection) are blocked by hard Zig 0.16 constraints (no blocking mutex;
  `usingnamespace` removed; `.client` is public API) and are not pursued.

## [0.3.1] - 2026-06-05

Remaining review backlog: functional robustness, supply-chain, and CI/docs.

### Fixed
- **Informer relist on `410 Gone`**: an expired/compacted `resourceVersion` now
  surfaces as `error.ExpiredResourceVersion`; the Informer re-lists from scratch
  (clearing the cache) and resumes watching instead of spinning on a doomed watch.
- **Protobuf error detail**: the protobuf request path now reads the error body and
  parses the JSON `Status` the API server returns (message/reason/code), instead of
  only the HTTP code. Shared `setApiErrorFromStatusJson` across both paths.

### Added
- Live **kind-based integration CI** (`integration.yml`, manual + nightly): runs
  `test-via-proxy` + `test-pod-exec` against a real cluster.
- **Fuzz target** for the kubeconfig YAML parser (`zig build test-fuzz --fuzz`).
- **API docs**: `zig build docs` (autodoc) + a GitHub Pages deploy workflow.
- **Release signing**: cosign keyless signatures for `SHA256SUMS` + the SBOM, with
  verification instructions in SECURITY.md.

### Removed
- Dead `examples/` tree (referenced the removed connection pool, stale path dep,
  never built). Usage lives in the README and `tests/entrypoints/`.

### Notes (deliberate deferrals)
- `ExecConfig.env` is still not applied (0.16 exposes no live-environ accessor to
  build a merged env without dropping PATH/HOME — documented in code).
- Spin-lock mutexes retained (0.16 has no blocking `std.Thread.Mutex`; held briefly).
- Cosmetic refactors (re-export chain, `client.client` indirection) deferred —
  breaking the public surface for cosmetics. `kcov` coverage deferred (immature on Zig).

## [0.3.0] - 2026-06-05

Functional-bug, correctness, and SDLC fixes from a full code review. Two more masked
Zig-0.16 build breaks (same class as the 0.2.2 streaming fix) were found and fixed.

### Breaking
- Removed the connection-pool API (`ConnectionPool`, `PoolManager`, `PoolStats`). It
  was never wired into `K8sClient`, leaked connections, and `std.http.Client` already
  pools internally. (H2)

### Fixed
- **JSON field binding**: `List(T).metadata.continue` and `ServiceSpec`/`SecretData`/
  deployment-strategy `type` (and `WatchEvent.type`) now bind the real wire names —
  Zig's `std.json` does no underscore stripping, so pagination tokens and Service
  `type` were silently dropped/mis-serialized. (H1)
- **Retry actually runs**: idempotent CRUD (GET/PUT/DELETE/PATCH) is retried per
  `retry_config`; previously every operation used the non-retrying path. POST stays
  single-attempt. (H3)
- **apply/auth/crd JSON serialization** didn't compile on 0.16 (used removed
  `std.json.stringify`, `ArrayList.writer`, and managed map/list APIs) — masked by
  lazy compilation. Migrated to `std.json.Stringify.valueAlloc` + unmanaged
  collections; `StrategicMergePatch` now stores a serializable `ObjectMap`.
- Plugged error-path memory leaks in the kubeconfig parse helpers (errdefer per
  duped field). Added `ClusterInfo.deinit`.

### Security / hardening
- `exec_credential` logs via `std.log` instead of stderr; documented that
  `ExecConfig.env` is not yet applied. `proxy_fallback` now logs the TLS→plaintext
  downgrade instead of failing open silently. Documented that `K8sClient` is
  single-threaded (`last_api_error` is unsynchronized).

### CI / DevEx
- `build.zig.zon` git-pins zig-yaml (was a relative path) so a clean clone builds;
  CI drops the sibling checkout.
- CI: `zig fmt --check` gate, `{ubuntu, macos}` build matrix, non-blocking Zig-master
  canary. Release attaches `SHA256SUMS`.
- Added `SECURITY.md`, `CONTRIBUTING.md`, `CODEOWNERS`, a PR template, a README
  Stability section; rewrote the stale `docs/TESTING.md`; removed dead
  `websocket_live_test.zig`; `zig fmt` across the tree.
- The migration probe now force-compiles every public method body (`_ = &T.method`),
  so removed-API breakage fails the build instead of a downstream consumer.

## [0.2.2] - 2026-06-05

Critical correctness and security fixes from a full SDLC/design/security review.

### Security
- **Custom-CA temp file hardening**: the staged CA PEM is now written with an
  unpredictable random name (`io.randomSecure`) + exclusive (`O_EXCL`) creation and
  deleted immediately after loading, closing a symlink/TOCTOU race on shared `/tmp`
  that could inject an attacker CA and MITM the API session. Shared via
  `tls.addCaCertData`, which also now loads the cluster CA for the WebSocket client
  (previously ignored — a `wss://` trust gap).

### Fixed
- **Streaming subsystem now compiles on Zig 0.16.** websocket/exec/attach/port-forward
  used removed APIs (`std.http.Headers`, `http_client.open`, `std.net.Stream`, managed
  `ArrayList`, `std.crypto.random`) and never type-checked — masked by a shallow
  `refAllDecls` probe. Rewritten against 0.16 `std.http` (request + `extra_headers` +
  `receiveHead`, framing over the TLS-aware connection). **Live-verified**: pod `exec`
  round-trips stdout + exit code against K8s 1.36.1.
- **exec()** no longer returns empty stdout: it treated Kubernetes' initial
  zero-length channel frame as EOF. Now terminates on the terminal status / close and
  parses the real exit code.
- **Informer cache use-after-free**: cached objects (and `resourceVersion`) pointed
  into a freed parse arena. The cache now owns each entry (`std.json.Parsed(T)`),
  freed on overwrite/delete/deinit.

### Added
- Migration probe now forces every streaming method body (`_ = &T.method`) so
  lazy-compilation breakage fails the build, not downstream consumers. (It immediately
  caught a masked `bool and optional` type error in exec.)
- `test-pod-exec` integration entrypoint (live exec over `kubectl proxy`).

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

[0.3.2]: https://github.com/guanchzhou/zig-klient/releases/tag/v0.3.2
[0.3.1]: https://github.com/guanchzhou/zig-klient/releases/tag/v0.3.1
[0.3.0]: https://github.com/guanchzhou/zig-klient/releases/tag/v0.3.0
[0.2.2]: https://github.com/guanchzhou/zig-klient/releases/tag/v0.2.2
[0.2.1]: https://github.com/guanchzhou/zig-klient/releases/tag/v0.2.1
[0.2.0]: https://github.com/guanchzhou/zig-klient/releases/tag/v0.2.0
