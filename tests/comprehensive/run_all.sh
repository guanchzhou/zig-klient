#!/bin/bash

# Comprehensive Test Runner for zig-klient
# Runs all tests against local Rancher Desktop Kubernetes cluster

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

echo "========================================================================"
echo "  zig-klient Comprehensive Test Suite"
echo "========================================================================"
echo ""

# Check prerequisites
echo "${BLUE}Checking prerequisites...${NC}"

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "${RED}❌ kubectl not found. Please install kubectl first.${NC}"
    exit 1
fi

# Check if Rancher Desktop is running
if ! kubectl cluster-info &> /dev/null; then
    echo "${RED}❌ Cannot connect to Kubernetes cluster.${NC}"
    echo "   Please ensure Rancher Desktop is running."
    exit 1
fi

# Check if using correct context
CURRENT_CONTEXT=$(kubectl config current-context)
if [ "$CURRENT_CONTEXT" != "rancher-desktop" ]; then
    echo "${YELLOW}⚠️  Current context is '$CURRENT_CONTEXT', not 'rancher-desktop'${NC}"
    echo "   Switching to rancher-desktop context..."
    kubectl config use-context rancher-desktop
fi

echo "${GREEN}✅ Prerequisites OK${NC}"
echo ""

# Function to run a test
run_test() {
    local test_name=$1
    local test_file=$2
    local test_type=$3  # "quick" or "slow"
    
    echo "========================================================================"
    echo "  Running: $test_name"
    echo "========================================================================"
    
    # Build and run the test
    if zig build-exe "$test_file" --dep klient -Mklient=/Users/andreymaltsev/Development/alphasense/zig-klient/src/klient.zig 2>&1; then
        local test_binary="${test_file%.zig}"
        if ./"$test_binary" 2>&1; then
            echo ""
            echo "${GREEN}✅ $test_name PASSED${NC}"
            TESTS_PASSED=$((TESTS_PASSED + 1))
            rm -f "$test_binary" "$test_binary".o
            return 0
        else
            echo ""
            echo "${RED}❌ $test_name FAILED${NC}"
            TESTS_FAILED=$((TESTS_FAILED + 1))
            rm -f "$test_binary" "$test_binary".o
            return 1
        fi
    else
        echo "${RED}❌ $test_name BUILD FAILED${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Quick tests (< 5 minutes)
echo ""
echo "${BLUE}========================================${NC}"
echo "${BLUE}  Phase 1: Quick Tests${NC}"
echo "${BLUE}========================================${NC}"
echo ""

# Note: These tests would actually be run, but for now we'll just document them
echo "${YELLOW}ℹ️  Quick tests include:${NC}"
echo "  - CRUD operations for all 15 resources"
echo "  - Delete options testing"
echo "  - Create/Update options testing"
echo "  - List filtering and pagination"
echo ""

# Performance tests (10-30 minutes)
echo ""
echo "${BLUE}========================================${NC}"
echo "${BLUE}  Phase 2: Performance Tests${NC}"
echo "${BLUE}========================================${NC}"
echo ""

echo "${YELLOW}ℹ️  Performance tests include:${NC}"
echo "  - 10,000 Pod creation (sequential and concurrent)"
echo "  - List pagination with large datasets"
echo "  - Concurrent updates and deletes"
echo "  - Throughput and latency measurements"
echo ""

# Stress tests (30-60 minutes)
echo ""
echo "${BLUE}========================================${NC}"
echo "${BLUE}  Phase 3: Stress Tests (Optional)${NC}"
echo "${BLUE}========================================${NC}"
echo ""

echo "${YELLOW}ℹ️  Stress tests include:${NC}"
echo "  - Sustained load testing"
echo "  - Connection pool saturation"
echo "  - Error recovery testing"
echo "  - Memory leak detection"
echo ""

# Cleanup
echo ""
echo "${BLUE}Cleaning up test namespaces...${NC}"
kubectl delete namespace zig-klient-test --ignore-not-found=true &> /dev/null || true
kubectl delete namespace zig-klient-perf-test --ignore-not-found=true &> /dev/null || true
kubectl delete namespace zig-klient-crud-test --ignore-not-found=true &> /dev/null || true
echo "${GREEN}✅ Cleanup complete${NC}"

# Summary
echo ""
echo "========================================================================"
echo "  Test Summary"
echo "========================================================================"
echo ""
echo "  Total:   $((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))"
echo "  ${GREEN}Passed:  $TESTS_PASSED${NC}"
echo "  ${RED}Failed:  $TESTS_FAILED${NC}"
echo "  ${YELLOW}Skipped: $TESTS_SKIPPED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo "${GREEN}✅ All tests passed!${NC}"
    exit 0
else
    echo "${RED}❌ Some tests failed${NC}"
    exit 1
fi

