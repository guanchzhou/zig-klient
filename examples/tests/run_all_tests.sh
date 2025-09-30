#!/bin/bash

echo ""
echo "======================================================================"
echo "  zig-klient - Comprehensive Test Suite"
echo "  Testing all functions against Rancher Desktop cluster"
echo "======================================================================"
echo ""

# Check if kubectl proxy is running
if ! curl -s http://127.0.0.1:8080/version > /dev/null 2>&1; then
    echo "⚠️  kubectl proxy is not running on port 8080"
    echo "   Please start it with: kubectl proxy --port=8080"
    echo ""
    exit 1
fi

echo "✓ kubectl proxy is running"
echo ""

# Build all tests
echo "Building tests..."
zig build > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "❌ Build failed"
    zig build
    exit 1
fi
echo "✓ All tests built successfully"
echo ""

# Run all tests
PASSED=0
FAILED=0

for test in zig-out/bin/test_*; do
    test_name=$(basename $test)
    if ./$test 2>&1 | grep -q "✓ All.*tests passed"; then
        PASSED=$((PASSED + 1))
        echo "✅ $test_name"
    else
        FAILED=$((FAILED + 1))
        echo "❌ $test_name"
        echo "   Running for details:"
        ./$test 2>&1 | grep -v "zoxide"
    fi
done

echo ""
echo "======================================================================"
echo "  Test Summary"
echo "======================================================================"
echo "  Passed: $PASSED"
echo "  Failed: $FAILED"
echo "  Total:  $((PASSED + FAILED))"
echo ""

if [ $FAILED -eq 0 ]; then
    echo "🎉 ALL TESTS PASSED! 🎉"
    echo ""
    echo "zig-klient is fully functional with your Rancher Desktop cluster!"
else
    echo "⚠️  Some tests failed. See details above."
fi

echo "======================================================================"
echo ""

exit $FAILED
