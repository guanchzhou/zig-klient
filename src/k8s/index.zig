/// Kubernetes client module
/// Provides native Zig implementation of Kubernetes API client

pub const client = @import("client.zig");
pub const kubeconfig = @import("kubeconfig.zig");
pub const manager = @import("manager.zig");

// Re-export commonly used types
pub const K8sClient = client.K8sClient;
pub const K8sManager = manager.K8sManager;
pub const KubeconfigParser = kubeconfig.KubeconfigParser;
pub const Kubeconfig = kubeconfig.Kubeconfig;
pub const Pod = client.Pod;
pub const ClusterInfo = client.ClusterInfo;
pub const ClusterData = manager.ClusterData;
