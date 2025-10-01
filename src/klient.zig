/// Zig Kubernetes Client Library
///
/// A production-ready Kubernetes client library for Zig, providing:
/// - Full CRUD operations on 14+ resource types
/// - Bearer token, mTLS, and exec credential authentication
/// - Retry logic with exponential backoff
/// - Watch API for real-time resource updates
/// - Thread-safe connection pooling
/// - Custom Resource Definitions (CRD) support
///
/// Example usage:
/// ```zig
/// const klient = @import("klient");
///
/// var client = try klient.K8sClient.init(allocator, .{
///     .server = "https://api.k8s.example.com",
///     .token = "your-bearer-token",
/// });
/// defer client.deinit();
///
/// // List all pods
/// var pods_client = klient.Pods.init(&client);
/// const pods = try pods_client.listAll();
/// ```
const std = @import("std");

// Core K8s client
pub const K8sClient = @import("k8s/client.zig").K8sClient;

// Type definitions
pub const types = @import("k8s/types.zig");
pub const ObjectMeta = types.ObjectMeta;
pub const Pod = types.Pod;
pub const Deployment = types.Deployment;
pub const Service = types.Service;
pub const ConfigMap = types.ConfigMap;
pub const Secret = types.Secret;
pub const Namespace = types.Namespace;
pub const Node = types.Node;
pub const ReplicaSet = types.ReplicaSet;
pub const StatefulSet = types.StatefulSet;
pub const DaemonSet = types.DaemonSet;
pub const Job = types.Job;
pub const CronJob = types.CronJob;
pub const PersistentVolume = types.PersistentVolume;
pub const PersistentVolumeClaim = types.PersistentVolumeClaim;

// Resource clients
pub const resources = @import("k8s/resources.zig");
pub const Pods = resources.Pods;
pub const Deployments = resources.Deployments;
pub const Services = resources.Services;
pub const ConfigMaps = resources.ConfigMaps;
pub const Secrets = resources.Secrets;
pub const Namespaces = resources.Namespaces;
pub const Nodes = resources.Nodes;
pub const ReplicaSets = resources.ReplicaSets;
pub const StatefulSets = resources.StatefulSets;
pub const DaemonSets = resources.DaemonSets;
pub const Jobs = resources.Jobs;
pub const CronJobs = resources.CronJobs;
pub const PersistentVolumes = resources.PersistentVolumes;
pub const PersistentVolumeClaims = resources.PersistentVolumeClaims;
pub const Ingresses = resources.Ingresses;

// Advanced features
pub const retry = @import("k8s/retry.zig");
pub const RetryConfig = retry.RetryConfig;
pub const defaultConfig = retry.defaultConfig;
pub const aggressiveConfig = retry.aggressiveConfig;
pub const conservativeConfig = retry.conservativeConfig;

pub const watch = @import("k8s/watch.zig");
pub const Watcher = watch.Watcher;
pub const Informer = watch.Informer;
pub const WatchOptions = watch.WatchOptions;

pub const tls = @import("k8s/tls.zig");
pub const TlsConfig = tls.TlsConfig;
pub const TlsBundle = tls.TlsBundle;

pub const pool = @import("k8s/connection_pool.zig");
pub const ConnectionPool = pool.ConnectionPool;
pub const PoolManager = pool.PoolManager;
pub const PoolStats = pool.PoolStats;

pub const crd = @import("k8s/crd.zig");
pub const CRDInfo = crd.CRDInfo;
pub const DynamicClient = crd.DynamicClient;

// Predefined CRDs
pub const CertManagerCertificate = crd.CertManagerCertificate;
pub const IstioVirtualService = crd.IstioVirtualService;
pub const PrometheusServiceMonitor = crd.PrometheusServiceMonitor;
pub const ArgoRollout = crd.ArgoRollout;
pub const KnativeService = crd.KnativeService;

// Authentication
pub const exec_credential = @import("k8s/exec_credential.zig");
pub const ExecCredential = exec_credential.ExecCredential;
pub const awsEksConfig = exec_credential.awsEksConfig;
pub const gcpGkeConfig = exec_credential.gcpGkeConfig;
pub const azureAksConfig = exec_credential.azureAksConfig;

// Kubeconfig parsing (direct YAML parsing, no kubectl required)
pub const KubeconfigParser = @import("k8s/kubeconfig_yaml.zig").KubeconfigParser;

// In-cluster configuration
pub const incluster = @import("k8s/incluster_config.zig");
pub const InClusterConfig = incluster.InClusterConfig;
pub const loadInClusterConfig = incluster.loadInClusterConfig;
pub const isInCluster = incluster.isInCluster;

// List options for filtering and pagination
pub const list_options = @import("k8s/list_options.zig");
pub const ListOptions = list_options.ListOptions;
pub const LabelSelector = list_options.LabelSelector;
pub const FieldSelector = list_options.FieldSelector;
pub const PaginatedList = list_options.PaginatedList;

// Delete, create, and update options
pub const delete_options = @import("k8s/delete_options.zig");
pub const DeleteOptions = delete_options.DeleteOptions;
pub const CreateOptions = delete_options.CreateOptions;
pub const UpdateOptions = delete_options.UpdateOptions;
pub const PropagationPolicy = delete_options.PropagationPolicy;
pub const FieldValidation = delete_options.FieldValidation;

// Server-side apply and patch options
pub const apply = @import("k8s/apply.zig");
pub const ApplyOptions = apply.ApplyOptions;
pub const PatchOptions = apply.PatchOptions;
pub const PatchType = apply.PatchType;
pub const ApplyHelper = apply.ApplyHelper;
pub const JsonPatch = apply.JsonPatch;
pub const StrategicMergePatch = apply.StrategicMergePatch;

// WebSocket operations (pod exec, attach, port-forward)
pub const websocket = @import("k8s/websocket_client.zig");
pub const WebSocketClient = websocket.WebSocketClient;
pub const WebSocketConnection = websocket.WebSocketConnection;
pub const Channel = websocket.Channel;
pub const Subprotocol = websocket.Subprotocol;

pub const exec_mod = @import("k8s/exec.zig");
pub const ExecClient = exec_mod.ExecClient;
pub const ExecOptions = exec_mod.ExecOptions;
pub const ExecResult = exec_mod.ExecResult;
pub const ExecSession = exec_mod.ExecSession;

pub const attach_mod = @import("k8s/attach.zig");
pub const AttachClient = attach_mod.AttachClient;
pub const AttachOptions = attach_mod.AttachOptions;
pub const AttachSession = attach_mod.AttachSession;

pub const port_forward_mod = @import("k8s/port_forward.zig");
pub const PortForwarder = port_forward_mod.PortForwarder;
pub const PortForwardOptions = port_forward_mod.PortForwardOptions;
pub const PortMapping = port_forward_mod.PortMapping;
pub const ForwardSession = port_forward_mod.ForwardSession;

// Version information
pub const version = .{
    .major = 0,
    .minor = 1,
    .patch = 0,
    .pre_release = "alpha",
};

pub fn versionString() []const u8 {
    return "0.1.0-alpha";
}

test {
    std.testing.refAllDecls(@This());
}
