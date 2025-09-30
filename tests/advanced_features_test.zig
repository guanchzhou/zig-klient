const std = @import("std");
const klient = @import("klient");
const tls = klient.tls;
const pool = klient.pool;
const crd = klient.crd;

test "TLS Config - Basic structure" {
    const config = tls.TlsConfig{
        .client_cert_path = "/path/to/cert.pem",
        .client_key_path = "/path/to/key.pem",
        .ca_cert_path = "/path/to/ca.pem",
        .insecure_skip_verify = false,
    };
    
    try std.testing.expectEqualStrings("/path/to/cert.pem", config.client_cert_path.?);
    try std.testing.expectEqualStrings("/path/to/key.pem", config.client_key_path.?);
    try std.testing.expectEqualStrings("/path/to/ca.pem", config.ca_cert_path.?);
    try std.testing.expect(!config.insecure_skip_verify);
    
    std.debug.print("✅ TLS Config structure test passed\n", .{});
}

test "TLS - PEM validation" {
    const valid_cert = 
        \\-----BEGIN CERTIFICATE-----
        \\MIIDXTCCAkWgAwIBAgIJAKL0UG+mRkSsMA0GCSqGSIb3DQEBCwUAMEUxCzAJBgNV
        \\-----END CERTIFICATE-----
    ;
    
    const valid_key = 
        \\-----BEGIN PRIVATE KEY-----
        \\MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC7VJTUt9Us8cKj
        \\-----END PRIVATE KEY-----
    ;
    
    const invalid_cert = "This is not a certificate";
    const invalid_key = "This is not a key";
    
    // Valid pair should pass
    tls.validateCertKeyPair(valid_cert, valid_key) catch |err| {
        std.debug.print("Unexpected error for valid pair: {}\n", .{err});
        return err;
    };
    
    // Invalid cert should fail
    const invalid_cert_result = tls.validateCertKeyPair(invalid_cert, valid_key);
    try std.testing.expectError(error.InvalidCertificate, invalid_cert_result);
    
    // Invalid key should fail
    const invalid_key_result = tls.validateCertKeyPair(valid_cert, invalid_key);
    try std.testing.expectError(error.InvalidPrivateKey, invalid_key_result);
    
    std.debug.print("✅ TLS PEM validation test passed\n", .{});
}

test "TLS - Base64 decoding" {
    const allocator = std.testing.allocator;
    
    const base64_data = "SGVsbG8gV29ybGQh"; // "Hello World!"
    const decoded = try tls.decodeBase64Cert(allocator, base64_data);
    defer allocator.free(decoded);
    
    try std.testing.expectEqualStrings("Hello World!", decoded);
    
    std.debug.print("✅ TLS Base64 decoding test passed\n", .{});
}

test "Connection Pool - Initialization" {
    const allocator = std.testing.allocator;
    
    var conn_pool = try pool.ConnectionPool.init(allocator, .{
        .server = "https://api.cluster.example.com",
        .max_connections = 5,
        .idle_timeout_ms = 10_000,
    });
    defer conn_pool.deinit();
    
    try std.testing.expectEqualStrings("https://api.cluster.example.com", conn_pool.server);
    try std.testing.expectEqual(@as(usize, 5), conn_pool.max_connections);
    try std.testing.expectEqual(@as(u64, 10_000), conn_pool.idle_timeout_ms);
    
    std.debug.print("✅ Connection Pool initialization test passed\n", .{});
}

test "Connection Pool - Statistics" {
    const allocator = std.testing.allocator;
    
    var conn_pool = try pool.ConnectionPool.init(allocator, .{
        .server = "https://api.cluster.example.com",
        .max_connections = 10,
        .idle_timeout_ms = 30_000,
    });
    defer conn_pool.deinit();
    
    const stats = conn_pool.stats();
    try std.testing.expectEqual(@as(usize, 0), stats.total);
    try std.testing.expectEqual(@as(usize, 0), stats.idle);
    try std.testing.expectEqual(@as(usize, 0), stats.in_use);
    try std.testing.expectEqual(@as(usize, 10), stats.max);
    try std.testing.expectEqual(@as(f64, 0.0), stats.utilization());
    
    std.debug.print("✅ Connection Pool statistics test passed\n", .{});
}

test "Connection Pool - Utilization calculation" {
    const stats1 = pool.PoolStats{
        .total = 10,
        .idle = 3,
        .in_use = 7,
        .max = 10,
    };
    
    try std.testing.expectEqual(@as(f64, 70.0), stats1.utilization());
    
    const stats2 = pool.PoolStats{
        .total = 5,
        .idle = 5,
        .in_use = 0,
        .max = 10,
    };
    
    try std.testing.expectEqual(@as(f64, 0.0), stats2.utilization());
    
    std.debug.print("✅ Pool utilization calculation test passed\n", .{});
}

test "CRD - API path construction" {
    const allocator = std.testing.allocator;
    
    // Core API (no group)
    const core_crd = crd.CRDInfo{
        .group = "",
        .version = "v1",
        .kind = "MyResource",
        .plural = "myresources",
    };
    
    const core_path = try core_crd.apiPath(allocator);
    defer allocator.free(core_path);
    try std.testing.expectEqualStrings("/api/v1", core_path);
    
    // Custom API group
    const custom_crd = crd.CRDInfo{
        .group = "example.com",
        .version = "v1alpha1",
        .kind = "CustomResource",
        .plural = "customresources",
    };
    
    const custom_path = try custom_crd.apiPath(allocator);
    defer allocator.free(custom_path);
    try std.testing.expectEqualStrings("/apis/example.com/v1alpha1", custom_path);
    
    std.debug.print("✅ CRD API path construction test passed\n", .{});
}

test "CRD - Resource path construction" {
    const allocator = std.testing.allocator;
    
    const namespaced_crd = crd.CRDInfo{
        .group = "cert-manager.io",
        .version = "v1",
        .kind = "Certificate",
        .plural = "certificates",
        .namespaced = true,
    };
    
    // List path (namespaced)
    const list_path = try namespaced_crd.resourcePath(allocator, "production", null);
    defer allocator.free(list_path);
    try std.testing.expectEqualStrings("/apis/cert-manager.io/v1/namespaces/production/certificates", list_path);
    
    // Get path (namespaced)
    const get_path = try namespaced_crd.resourcePath(allocator, "production", "my-cert");
    defer allocator.free(get_path);
    try std.testing.expectEqualStrings("/apis/cert-manager.io/v1/namespaces/production/certificates/my-cert", get_path);
    
    // Cluster-scoped CRD
    const cluster_crd = crd.CRDInfo{
        .group = "custom.io",
        .version = "v1",
        .kind = "ClusterResource",
        .plural = "clusterresources",
        .namespaced = false,
    };
    
    const cluster_list_path = try cluster_crd.resourcePath(allocator, null, null);
    defer allocator.free(cluster_list_path);
    try std.testing.expectEqualStrings("/apis/custom.io/v1/clusterresources", cluster_list_path);
    
    const cluster_get_path = try cluster_crd.resourcePath(allocator, null, "my-resource");
    defer allocator.free(cluster_get_path);
    try std.testing.expectEqualStrings("/apis/custom.io/v1/clusterresources/my-resource", cluster_get_path);
    
    std.debug.print("✅ CRD resource path construction test passed\n", .{});
}

test "CRD - Predefined CRDs" {
    const allocator = std.testing.allocator;
    
    // Test Cert-Manager Certificate
    const cert_path = try crd.CertManagerCertificate.apiPath(allocator);
    defer allocator.free(cert_path);
    try std.testing.expectEqualStrings("/apis/cert-manager.io/v1", cert_path);
    try std.testing.expectEqualStrings("Certificate", crd.CertManagerCertificate.kind);
    
    // Test Istio VirtualService
    const istio_path = try crd.IstioVirtualService.apiPath(allocator);
    defer allocator.free(istio_path);
    try std.testing.expectEqualStrings("/apis/networking.istio.io/v1beta1", istio_path);
    try std.testing.expectEqualStrings("VirtualService", crd.IstioVirtualService.kind);
    
    // Test Prometheus ServiceMonitor
    const prom_path = try crd.PrometheusServiceMonitor.apiPath(allocator);
    defer allocator.free(prom_path);
    try std.testing.expectEqualStrings("/apis/monitoring.coreos.com/v1", prom_path);
    try std.testing.expectEqualStrings("ServiceMonitor", crd.PrometheusServiceMonitor.kind);
    
    std.debug.print("✅ Predefined CRDs test passed\n", .{});
}

test "CRD - Argo and Knative" {
    // Test Argo Rollout
    try std.testing.expectEqualStrings("argoproj.io", crd.ArgoRollout.group);
    try std.testing.expectEqualStrings("v1alpha1", crd.ArgoRollout.version);
    try std.testing.expectEqualStrings("rollouts", crd.ArgoRollout.plural);
    
    // Test Knative Service
    try std.testing.expectEqualStrings("serving.knative.dev", crd.KnativeService.group);
    try std.testing.expectEqualStrings("v1", crd.KnativeService.version);
    try std.testing.expectEqualStrings("services", crd.KnativeService.plural);
    
    std.debug.print("✅ Argo and Knative CRDs test passed\n", .{});
}
