/// Zig bindings for the official Kubernetes C client library
/// Based on: https://github.com/kubernetes-client/c
const std = @import("std");

// C library functions and types
pub extern "c" fn load_kube_config(
    basePath: **u8,
    sslConfig: **anyopaque,
    apiKeys: **anyopaque,
    configFile: ?[*:0]const u8,
) c_int;

pub extern "c" fn load_incluster_config(
    basePath: **u8,
    sslConfig: **anyopaque,
    apiKeys: **anyopaque,
) c_int;

pub extern "c" fn apiClient_create_with_base_path(
    basePath: [*:0]const u8,
    sslConfig: *anyopaque,
    apiKeys: *anyopaque,
) ?*anyopaque;

pub extern "c" fn apiClient_free(apiClient: *anyopaque) void;
pub extern "c" fn free_client_config(
    basePath: *u8,
    sslConfig: *anyopaque,
    apiKeys: *anyopaque,
) void;

pub extern "c" fn apiClient_setupGlobalEnv() void;
pub extern "c" fn apiClient_unsetupGlobalEnv() void;

// CoreV1 API functions
pub extern "c" fn CoreV1API_listNamespacedPod(
    apiClient: *anyopaque,
    namespace: [*:0]const u8,
    pretty: ?[*:0]const u8,
    allowWatchBookmarks: ?*c_int,
    continue_: ?[*:0]const u8,
    fieldSelector: ?[*:0]const u8,
    labelSelector: ?[*:0]const u8,
    limit: ?*c_int,
    resourceVersion: ?[*:0]const u8,
    resourceVersionMatch: ?[*:0]const u8,
    sendInitialEvents: ?*c_int,
    timeoutSeconds: ?*c_int,
    watch: ?*c_int,
) ?*anyopaque;

pub extern "c" fn CoreV1API_listPodForAllNamespaces(
    apiClient: *anyopaque,
    allowWatchBookmarks: ?*c_int,
    continue_: ?[*:0]const u8,
    fieldSelector: ?[*:0]const u8,
    labelSelector: ?[*:0]const u8,
    limit: ?*c_int,
    pretty: ?[*:0]const u8,
    resourceVersion: ?[*:0]const u8,
    resourceVersionMatch: ?[*:0]const u8,
    sendInitialEvents: ?*c_int,
    timeoutSeconds: ?*c_int,
    watch: ?*c_int,
) ?*anyopaque;

pub extern "c" fn CoreV1API_listNode(
    apiClient: *anyopaque,
    pretty: ?[*:0]const u8,
    allowWatchBookmarks: ?*c_int,
    continue_: ?[*:0]const u8,
    fieldSelector: ?[*:0]const u8,
    labelSelector: ?[*:0]const u8,
    limit: ?*c_int,
    resourceVersion: ?[*:0]const u8,
    resourceVersionMatch: ?[*:0]const u8,
    sendInitialEvents: ?*c_int,
    timeoutSeconds: ?*c_int,
    watch: ?*c_int,
) ?*anyopaque;

// Metrics API (metrics.k8s.io/v1beta1)
pub extern "c" fn MetricsAPI_listPodMetrics(
    apiClient: *anyopaque,
    namespace: [*:0]const u8,
) ?*anyopaque;

pub extern "c" fn MetricsAPI_listNodeMetrics(
    apiClient: *anyopaque,
) ?*anyopaque;

// Version API
pub extern "c" fn VersionAPI_getCode(
    apiClient: *anyopaque,
) ?*anyopaque;

// Pod list structure (simplified - actual structure is more complex)
pub const v1_pod_list_t = extern struct {
    apiVersion: [*:0]const u8,
    kind: [*:0]const u8,
    metadata: *anyopaque,
    items: *anyopaque, // list_t of v1_pod_t
};

// API client structure (opaque in C)
pub const ApiClient = opaque {};
pub const SslConfig = opaque {};
pub const ApiKeys = opaque {};

/// Initialize the global Kubernetes client environment
/// Must be called once at program startup before any K8s operations
pub fn setupGlobalEnv() void {
    apiClient_setupGlobalEnv();
}

/// Cleanup the global Kubernetes client environment
/// Must be called once at program shutdown after all K8s operations
pub fn unsetupGlobalEnv() void {
    apiClient_unsetupGlobalEnv();
}
