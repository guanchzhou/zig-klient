# Project Structure

```
zig-klient/
├── build.zig                      # Build configuration
├── build.zig.zon                  # Package metadata
├── .gitignore                     # Git ignore (build artifacts, IDE files)
├── LICENSE                        # Apache 2.0 license
├── README.md                      # Main documentation
│
├── docs/                          # 📚 Documentation
│   ├── COMPARISON.md              # Feature comparison with C client
│   ├── IMPLEMENTATION.md          # Implementation details
│   ├── INTEGRATION_TESTS.md       # Integration test results
│   ├── ROADMAP.md                 # Feature roadmap
│   └── TESTING.md                 # Testing guide
│
├── src/                           # 📦 Library source code
│   ├── klient.zig                 # Main module entry point
│   └── k8s/                       # Kubernetes client implementation
│       ├── client.zig             # Core HTTP client
│       ├── types.zig              # Kubernetes resource types
│       ├── resources.zig          # Resource CRUD operations
│       ├── retry.zig              # Retry logic with backoff
│       ├── watch.zig              # Watch API & Informers
│       ├── tls.zig                # TLS/mTLS support
│       ├── connection_pool.zig    # Connection pooling
│       ├── crd.zig                # CRD dynamic client
│       ├── exec_credential.zig    # Exec credential plugins
│       ├── kubeconfig_json.zig    # Kubeconfig parser (kubectl JSON)
│       └── index.zig              # Module exports
│
├── tests/                         # 🧪 Unit tests (isolated)
│   ├── retry_test.zig             # Retry logic tests
│   └── advanced_features_test.zig # TLS, pool, CRD tests
│
└── examples/                      # 💡 Examples & integration tests
    ├── build.zig                  # Examples build config
    ├── test_cluster.zig           # TLS cluster test
    ├── test_proxy.zig             # kubectl proxy test
    ├── test_simple.zig            # Simple usage example
    ├── test_all_functions.zig     # Comprehensive test
    └── tests/                     # Integration tests (real cluster)
        ├── build.zig              # Integration tests build
        ├── run_all_tests.sh       # Test runner script
        ├── test-resources.yaml    # K8s test resources
        └── test_*.zig             # 19 individual test files
```

## Directory Purpose

### `/src`
Library source code. Import via `@import("klient")` in your project.

### `/tests`
Unit tests for isolated functionality. Run with `zig build test`.

### `/examples`
Usage examples and integration tests. Shows how to use the library.

### `/docs`
All documentation in markdown format.

## Build Artifacts (Ignored)

The following are excluded via `.gitignore`:
- `zig-out/` - Build output
- `.zig-cache/` - Build cache
- IDE files (`.vscode/`, `.idea/`, etc.)

## Module Exports

```zig
const klient = @import("klient");

// Core
klient.K8sClient
klient.types
klient.resources

// Advanced
klient.retry
klient.watch
klient.tls
klient.pool
klient.crd
klient.exec_credential
klient.KubeconfigParser
```
