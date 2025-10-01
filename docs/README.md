# zig-klient Documentation

## Overview

This directory contains comprehensive documentation for the zig-klient Kubernetes client library.

---

## Quick Links

### Getting Started
- **[Main README](../README.md)** - Start here! Installation, features, usage examples
- **[Implementation Status](../IMPLEMENTATION_COMPLETE.md)** - Complete feature overview
- **[Test Results](../TEST_RESULTS.md)** - Comprehensive test coverage report

### Technical Documentation
- **[Comparison](COMPARISON.md)** - Feature comparison with other Kubernetes clients
- **[Project Structure](PROJECT_STRUCTURE.md)** - Codebase organization and architecture
- **[Resource Matrix](RESOURCE_MATRIX.md)** - Complete list of 61 supported K8s resources

### Testing
- **[Testing Status](TESTING_STATUS.md)** - What's tested and how (92 tests)
- **[Integration Tests](INTEGRATION_TESTS.md)** - Live cluster testing guide
- **[Test Plan](COMPREHENSIVE_TEST_PLAN.md)** - Comprehensive testing strategy
- **[Comprehensive Tests README](../tests/comprehensive/README.md)** - User-facing test guide

### Implementation Details
- **[Implementation Guide](IMPLEMENTATION.md)** - Technical implementation details
- **[Roadmap](ROADMAP.md)** - Future enhancements and planned features

---

## Document Status

### Active Documents ✅
All documents listed above are **current, accurate, and maintained**.

### Recently Updated 🆕
- **TESTING_STATUS.md** - Updated with WebSocket and Protobuf coverage (Oct 2025)
- **TEST_RESULTS.md** - 92 passing tests documented (Oct 2025)
- **IMPLEMENTATION_COMPLETE.md** - Updated with zig-protobuf integration (Oct 2025)

### Removed Documents 🗑️
The following obsolete documents were removed to avoid confusion:
- ❌ `PROTOBUF_ROADMAP.md` - Protobuf is now implemented
- ❌ `WEBSOCKET_SETUP.md` - WebSocket is native, no setup needed
- ❌ `WEBSOCKET_PROTOBUF_IMPLEMENTATION.md` - Already implemented
- ❌ `CORRECTION_SUMMARY.md` - Historical, not needed
- ❌ `ACCURATE_FEATURE_PARITY.md` - Superseded by current docs
- ❌ `FINAL_FEATURE_PARITY.md` - Superseded by IMPLEMENTATION_COMPLETE.md
- ❌ `WEBSOCKET_TEST_SUMMARY.md` - Merged into TEST_RESULTS.md
- ❌ `TEST_COVERAGE_SUMMARY.md` - Merged into TEST_RESULTS.md
- ❌ `TEST_ENTRYPOINTS_STATUS.md` - Merged into TEST_RESULTS.md
- ❌ `100_PERCENT_ACHIEVEMENT.md` - Merged into IMPLEMENTATION_COMPLETE.md
- ❌ `FEATURE_PARITY_STATUS.md` - Merged into README.md

---

## Documentation by Topic

### 🚀 Getting Started
Start with the [main README](../README.md) for:
- Installation instructions
- Quick start guide
- Basic usage examples
- Feature overview

### 📊 Feature Coverage
See [RESOURCE_MATRIX.md](RESOURCE_MATRIX.md) for:
- All 61 Kubernetes 1.34 resource types
- API groups and versions
- Cluster-scoped vs namespaced resources

### 🧪 Testing
Multiple test-related documents:
- **[TESTING_STATUS.md](TESTING_STATUS.md)** - What's tested (92 tests)
- **[TEST_RESULTS.md](../TEST_RESULTS.md)** - Detailed test metrics
- **[INTEGRATION_TESTS.md](INTEGRATION_TESTS.md)** - Live cluster testing
- **[COMPREHENSIVE_TEST_PLAN.md](COMPREHENSIVE_TEST_PLAN.md)** - Full test strategy

### 🔬 Technical Details
For developers and contributors:
- **[COMPARISON.md](COMPARISON.md)** - Compare with other clients
- **[PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md)** - Codebase architecture
- **[IMPLEMENTATION.md](IMPLEMENTATION.md)** - Implementation details
- **[ROADMAP.md](ROADMAP.md)** - Future plans

### 📦 Complete Status
See [IMPLEMENTATION_COMPLETE.md](../IMPLEMENTATION_COMPLETE.md) for:
- WebSocket implementation details (native, zero dependencies)
- Protobuf integration (via zig-protobuf library)
- Dependency analysis
- Performance metrics

---

## Quick Reference

### Supported Features
✅ All 61 Kubernetes 1.34 resources  
✅ Full CRUD operations  
✅ Watch API & Informers  
✅ Field & Label selectors  
✅ Pagination  
✅ Retry logic  
✅ WebSocket (exec, attach, port-forward)  
✅ Protobuf serialization  
✅ Server-Side Apply  
✅ Authentication (bearer token, mTLS, exec plugins)  
✅ In-cluster configuration  

### Test Coverage
- **92 tests passing** (0 failures)
- **86 tests** for K8s resources and features
- **7 tests** for Protobuf integration
- **11 tests** for WebSocket functionality

### Dependencies
- **zig-yaml** - YAML parsing (pure Zig)
- **zig-protobuf** - Protocol Buffers (pure Zig)
- **Zero C dependencies**

---

## Contributing to Documentation

### Guidelines
1. Keep docs concise and accurate
2. Update version numbers and dates
3. Remove outdated information immediately
4. Cross-reference related documents
5. Test all code examples

### Document Lifecycle
- **Create**: New features get dedicated docs
- **Update**: Keep current with code changes
- **Archive**: Move outdated docs to archive/ (currently none)
- **Delete**: Remove obsolete docs to avoid confusion

### Reporting Issues
Found outdated or incorrect documentation?
- Open an issue on GitHub
- PR with corrections welcome
- Tag with "documentation" label

---

## Version History

### v0.1.0 (October 2025)
- ✅ 100% Kubernetes 1.34 resource coverage
- ✅ Native WebSocket implementation
- ✅ Protobuf integration (zig-protobuf)
- ✅ 92 comprehensive tests
- ✅ Complete documentation suite

---

## Contact

**Repository**: https://github.com/guanchzhou/zig-klient  
**Documentation Issues**: Open a GitHub issue with "documentation" label  
**Questions**: Discussions tab on GitHub

---

**Last Updated**: October 1, 2025  
**Documentation Version**: 1.0.0  
**Library Version**: 0.1.0-alpha  
**Status**: ✅ Up-to-date

