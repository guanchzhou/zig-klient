#!/bin/bash

set -euo pipefail

cd "$(dirname "$0")/../.."

echo "═══════════════════════════════════════════════════════════"
echo "  Building Integration Test Entrypoints"
echo "═══════════════════════════════════════════════════════════"
echo

# Create output directory
mkdir -p zig-out/integration-tests

# List of test files
tests=(
    "test_list_pods"
    "test_create_pod"
    "test_get_pod"
    "test_update_pod"
    "test_delete_pod"
    "test_watch_pods"
    "test_full_integration"
)

echo "🔨 Building test executables..."
echo

failed_count=0
success_count=0

for test in "${tests[@]}"; do
    echo "  Building ${test}..."
    
    # Create a temporary minimal build.zig for this test
    cat > .zig-cache/${test}_build.zig <<EOF
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const klient_module = b.addModule("klient", .{
        .root_source_file = b.path("src/klient.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe_module = b.createModule(.{
        .root_source_file = b.path("tests/entrypoints/${test}.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_module.addImport("klient", klient_module);

    const exe = b.addExecutable(.{
        .name = "${test}",
        .root_module = exe_module,
    });

    b.installArtifact(exe);
}
EOF

    # Build using the temporary build file - capture output
    BUILD_OUTPUT=$(zig build -Dbuild-file=.zig-cache/${test}_build.zig \
        --cache-dir .zig-cache \
        --prefix zig-out/integration-tests 2>&1)
    
    if [ $? -eq 0 ]; then
        echo "    ✅ Built ${test}"
        ((success_count++))
    else
        echo "    ❌ Failed to build ${test}"
        echo "    Error output:"
        echo "$BUILD_OUTPUT" | head -20 | sed 's/^/       /'
        echo
        ((failed_count++))
    fi
done

echo
if [ $failed_count -eq 0 ]; then
    echo "✅ All ${success_count} tests built successfully!"
else
    echo "❌ Build failed: ${failed_count} failed, ${success_count} succeeded"
    exit 1
fi
echo
echo "Test executables are in: zig-out/integration-tests/bin/"
echo
echo "Run tests with:"
for test in "${tests[@]}"; do
    echo "  ./zig-out/integration-tests/bin/${test}"
done
echo
echo "═══════════════════════════════════════════════════════════"

