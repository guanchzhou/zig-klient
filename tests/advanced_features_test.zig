const std = @import("std");
const klient = @import("klient");
const tls = klient.tls;
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
}

// Zig 0.16's std.crypto.tls cannot present a client certificate, and
// std.http.Client exposes no verification switches. These options used to be
// accepted and silently dropped, so the caller believed they were authenticating.
test "TLS - unsupported options are rejected at construction, not ignored" {
    const allocator = std.testing.allocator;

    try std.testing.expectError(error.ClientCertificatesUnsupported, klient.K8sClient.init(allocator, std.testing.io, .{
        .server = "https://example.invalid",
        .tls_config = .{ .client_cert_data = "-----BEGIN CERTIFICATE-----" },
    }));

    try std.testing.expectError(error.ClientCertificatesUnsupported, klient.K8sClient.init(allocator, std.testing.io, .{
        .server = "https://example.invalid",
        .tls_config = .{ .client_key_path = "/path/to/key.pem" },
    }));

    try std.testing.expectError(error.InsecureSkipVerifyUnsupported, klient.K8sClient.init(allocator, std.testing.io, .{
        .server = "https://example.invalid",
        .tls_config = .{ .insecure_skip_verify = true },
    }));

    try std.testing.expectError(error.TlsServerNameUnsupported, klient.K8sClient.init(allocator, std.testing.io, .{
        .server = "https://example.invalid",
        .tls_config = .{ .server_name = "kubernetes.default" },
    }));
}

// Direct HTTPS to an API server is blocked in std, not in this library.
// HandshakeType knows certificate_request (RFC 8446 §4.3.2); Client.zig has no
// arm for it (ziglang/zig#19521). Re-checked 0.16.0 and 0.17.0-dev.1936.
// Flip this when Options grows a client-certificate field and wire HTTPS.
test "tls: std.crypto.tls still cannot answer certificate_request" {
    const Options = std.crypto.tls.Client.Options;
    try std.testing.expect(!@hasField(Options, "client_cert"));
    try std.testing.expect(!@hasField(Options, "client_certificate"));
    const cr: std.crypto.tls.HandshakeType = .certificate_request;
    try std.testing.expectEqual(@as(u8, 13), @intFromEnum(cr));
}

// Error detail is returned, not stored on the client. There is no shared field to go
// stale, and the caller owns what it captures. (The old `last_api_error` field was
// cleared only when a new Status replaced it, so a success — or a transport failure,
// which never set it — left the previous call's error readable as the cause.)
test "error detail is caller-owned, and a transport failure yields none" {
    const allocator = std.testing.allocator;
    var client = try klient.K8sClient.init(allocator, std.testing.io, .{
        // Nothing listens here, so this fails below the HTTP layer.
        .server = "http://127.0.0.1:1",
        // One attempt — the default 3 retries only add backoff and log noise here.
        .retry_config = .{ .max_attempts = 0 },
    });
    defer client.deinit();

    // A pre-existing value must not be mistaken for this request's outcome, and a
    // transport failure must leave the caller's storage untouched.
    var api_err: ?klient.K8sClient.ApiError = null;
    _ = client.requestCapturing(.GET, "/api/v1/namespaces/default/pods", null, &api_err) catch {};
    try std.testing.expect(api_err == null);

    // The client itself holds no error state to leak into the next call.
    try std.testing.expect(!@hasField(klient.K8sClient, "last_api_error"));
}

// The JSON and Protobuf request paths were separate ~90-line copies that had
// drifted: only the Protobuf one fell back to the HTTP status when the error body
// was not a Kubernetes Status. A load balancer in front of the API server answers
// 503 with HTML, and on the JSON path that produced K8sApiError carrying nothing.
test "both wire formats share one implementation" {
    const C = klient.K8sClient;
    // If these drift apart again, the shared path is gone.
    try std.testing.expectEqualStrings("application/json", C.WireFormat.json.content_type);
    try std.testing.expect(C.WireFormat.json.accept == null);
    try std.testing.expectEqualStrings(
        "application/vnd.kubernetes.protobuf;charset=utf-8",
        C.WireFormat.protobuf.content_type,
    );
    try std.testing.expectEqualStrings(
        "application/vnd.kubernetes.protobuf",
        C.WireFormat.protobuf.accept.?,
    );
}

// `error_sink` lives on the ResourceClient value, not on the shared K8sClient, which
// is what lets several threads drive one client. Capture against a live API server is
// covered by tests/entrypoints/test_error_capture.zig.
test "ResourceClient carries a caller-owned error sink" {
    const allocator = std.testing.allocator;
    var client = try klient.K8sClient.init(allocator, std.testing.io, .{
        .server = "http://127.0.0.1:1",
        .retry_config = .{ .max_attempts = 0 },
    });
    defer client.deinit();

    var api_err: ?klient.K8sClient.ApiError = null;
    var pods = klient.Pods.init(&client);

    // Default is opt-out: no sink, no detail.
    try std.testing.expect(pods.client.error_sink == null);

    pods.client.error_sink = &api_err;
    try std.testing.expect(pods.client.error_sink != null);

    // Two ResourceClients over the same K8sClient keep independent sinks — the
    // property the removed shared field could not provide.
    var other_err: ?klient.K8sClient.ApiError = null;
    var other = klient.Pods.init(&client);
    other.client.error_sink = &other_err;
    try std.testing.expect(pods.client.error_sink.? != other.client.error_sink.?);

    // Transport failure: nothing to report, so the sink stays empty.
    if (pods.client.list("default")) |p| {
        var q = p;
        q.deinit();
    } else |_| {}
    try std.testing.expect(api_err == null);
}

test "TLS - a CA-only config is still accepted" {
    const allocator = std.testing.allocator;
    // No client cert, no verification overrides: nothing to reject.
    var client = try klient.K8sClient.init(allocator, std.testing.io, .{
        .server = "http://127.0.0.1:1",
        .tls_config = .{},
    });
    defer client.deinit();
    try std.testing.expectEqualStrings("http://127.0.0.1:1", client.api_server);
}

test "TLS - Base64 decoding" {
    const allocator = std.testing.allocator;

    const base64_data = "SGVsbG8gV29ybGQh"; // "Hello World!"
    const decoded = try tls.decodeBase64Cert(allocator, base64_data);
    defer allocator.free(decoded);

    try std.testing.expectEqualStrings("Hello World!", decoded);
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
}

// --- Regression guard for JSON-Patch serialization (2026-08-21) -------------

test "JsonPatch: a remove op carries no value/from keys" {
    // std.json's emit_null_optional_fields defaults to TRUE, which serialized
    // {"op":"remove","path":"/x","value":null,"from":null}. RFC 6902 forbids
    // `value` on a remove, and strict JSON-Patch implementations reject it.
    const allocator = std.testing.allocator;

    var patch = klient.JsonPatch.init(allocator);
    defer patch.deinit();

    try patch.remove("/metadata/labels/obsolete");
    const body = try patch.build();
    defer allocator.free(body);

    try std.testing.expectEqualStrings(
        \\[{"op":"remove","path":"/metadata/labels/obsolete"}]
    ,
        body,
    );
    try std.testing.expect(std.mem.indexOf(u8, body, "null") == null);
}

test "JsonPatch: replace still emits its value" {
    // Guard the other direction: suppressing nulls must not drop a real value.
    const allocator = std.testing.allocator;

    var patch = klient.JsonPatch.init(allocator);
    defer patch.deinit();

    try patch.replace("/spec/replicas", .{ .integer = 3 });
    const body = try patch.build();
    defer allocator.free(body);

    try std.testing.expectEqualStrings(
        \\[{"op":"replace","path":"/spec/replicas","value":3}]
    ,
        body,
    );
}
