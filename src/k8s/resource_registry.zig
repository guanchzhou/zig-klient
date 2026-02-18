/// Comptime resource registry — single source of truth for K8s resource metadata.
///
/// This replaces the 51+ hand-written wrapper structs that each hardcoded
/// api_path, resource name, and scope. Adding a new resource is now a single
/// table entry instead of a new struct + init() + optional list() override.
const types = @import("types.zig");

pub const Scope = enum {
    namespaced,
    cluster,
};

pub const ResourceMeta = struct {
    api_path: []const u8,
    resource_name: []const u8,
    scope: Scope,
};

/// Comptime lookup: given a K8s resource type, return its API metadata.
pub fn metaFor(comptime T: type) ResourceMeta {
    const table = .{
        // Core API v1
        .{ types.Pod, "/api/v1", "pods", Scope.namespaced },
        .{ types.Service, "/api/v1", "services", Scope.namespaced },
        .{ types.ConfigMap, "/api/v1", "configmaps", Scope.namespaced },
        .{ types.Secret, "/api/v1", "secrets", Scope.namespaced },
        .{ types.Namespace, "/api/v1", "namespaces", Scope.cluster },
        .{ types.Node, "/api/v1", "nodes", Scope.cluster },
        .{ types.PersistentVolume, "/api/v1", "persistentvolumes", Scope.cluster },
        .{ types.PersistentVolumeClaim, "/api/v1", "persistentvolumeclaims", Scope.namespaced },
        .{ types.ServiceAccount, "/api/v1", "serviceaccounts", Scope.namespaced },
        .{ types.Endpoints, "/api/v1", "endpoints", Scope.namespaced },
        .{ types.Event, "/api/v1", "events", Scope.namespaced },
        .{ types.ResourceQuota, "/api/v1", "resourcequotas", Scope.namespaced },
        .{ types.LimitRange, "/api/v1", "limitranges", Scope.namespaced },
        .{ types.ReplicationController, "/api/v1", "replicationcontrollers", Scope.namespaced },
        .{ types.PodTemplate, "/api/v1", "podtemplates", Scope.namespaced },
        .{ types.Binding, "/api/v1", "bindings", Scope.namespaced },
        .{ types.ComponentStatus, "/api/v1", "componentstatuses", Scope.cluster },

        // Apps v1
        .{ types.Deployment, "/apis/apps/v1", "deployments", Scope.namespaced },
        .{ types.StatefulSet, "/apis/apps/v1", "statefulsets", Scope.namespaced },
        .{ types.DaemonSet, "/apis/apps/v1", "daemonsets", Scope.namespaced },
        .{ types.ReplicaSet, "/apis/apps/v1", "replicasets", Scope.namespaced },
        .{ types.ControllerRevision, "/apis/apps/v1", "controllerrevisions", Scope.namespaced },

        // Batch v1
        .{ types.Job, "/apis/batch/v1", "jobs", Scope.namespaced },
        .{ types.CronJob, "/apis/batch/v1", "cronjobs", Scope.namespaced },

        // RBAC
        .{ types.Role, "/apis/rbac.authorization.k8s.io/v1", "roles", Scope.namespaced },
        .{ types.RoleBinding, "/apis/rbac.authorization.k8s.io/v1", "rolebindings", Scope.namespaced },
        .{ types.ClusterRole, "/apis/rbac.authorization.k8s.io/v1", "clusterroles", Scope.cluster },
        .{ types.ClusterRoleBinding, "/apis/rbac.authorization.k8s.io/v1", "clusterrolebindings", Scope.cluster },

        // Networking
        .{ types.Ingress, "/apis/networking.k8s.io/v1", "ingresses", Scope.namespaced },
        .{ types.NetworkPolicy, "/apis/networking.k8s.io/v1", "networkpolicies", Scope.namespaced },
        .{ types.IPAddress, "/apis/networking.k8s.io/v1", "ipaddresses", Scope.cluster },
        .{ types.ServiceCIDR, "/apis/networking.k8s.io/v1", "servicecidrs", Scope.cluster },
        .{ types.IngressClass, "/apis/networking.k8s.io/v1", "ingressclasses", Scope.cluster },

        // Storage
        .{ types.StorageClass, "/apis/storage.k8s.io/v1", "storageclasses", Scope.cluster },
        .{ types.VolumeAttachment, "/apis/storage.k8s.io/v1", "volumeattachments", Scope.cluster },
        .{ types.CSIDriver, "/apis/storage.k8s.io/v1", "csidrivers", Scope.cluster },
        .{ types.CSINode, "/apis/storage.k8s.io/v1", "csinodes", Scope.cluster },
        .{ types.CSIStorageCapacity, "/apis/storage.k8s.io/v1", "csistoragecapacities", Scope.namespaced },
        .{ types.VolumeAttributesClass, "/apis/storage.k8s.io/v1", "volumeattributesclasses", Scope.cluster },

        // Autoscaling
        .{ types.HorizontalPodAutoscaler, "/apis/autoscaling/v2", "horizontalpodautoscalers", Scope.namespaced },

        // Policy
        .{ types.PodDisruptionBudget, "/apis/policy/v1", "poddisruptionbudgets", Scope.namespaced },

        // Discovery
        .{ types.EndpointSlice, "/apis/discovery.k8s.io/v1", "endpointslices", Scope.namespaced },

        // Coordination
        .{ types.Lease, "/apis/coordination.k8s.io/v1", "leases", Scope.namespaced },

        // Scheduling
        .{ types.PriorityClass, "/apis/scheduling.k8s.io/v1", "priorityclasses", Scope.cluster },

        // Certificates
        .{ types.CertificateSigningRequest, "/apis/certificates.k8s.io/v1", "certificatesigningrequests", Scope.cluster },

        // Admission
        .{ types.ValidatingWebhookConfiguration, "/apis/admissionregistration.k8s.io/v1", "validatingwebhookconfigurations", Scope.cluster },
        .{ types.MutatingWebhookConfiguration, "/apis/admissionregistration.k8s.io/v1", "mutatingwebhookconfigurations", Scope.cluster },
        .{ types.ValidatingAdmissionPolicy, "/apis/admissionregistration.k8s.io/v1", "validatingadmissionpolicies", Scope.cluster },
        .{ types.ValidatingAdmissionPolicyBinding, "/apis/admissionregistration.k8s.io/v1", "validatingadmissionpolicybindings", Scope.cluster },

        // API Registration
        .{ types.APIService, "/apis/apiregistration.k8s.io/v1", "apiservices", Scope.cluster },

        // Flow Control
        .{ types.FlowSchema, "/apis/flowcontrol.apiserver.k8s.io/v1", "flowschemas", Scope.cluster },
        .{ types.PriorityLevelConfiguration, "/apis/flowcontrol.apiserver.k8s.io/v1", "prioritylevelconfigurations", Scope.cluster },

        // Node
        .{ types.RuntimeClass, "/apis/node.k8s.io/v1", "runtimeclasses", Scope.cluster },

        // Gateway API
        .{ types.GatewayClass, "/apis/gateway.networking.k8s.io/v1", "gatewayclasses", Scope.cluster },
        .{ types.Gateway, "/apis/gateway.networking.k8s.io/v1", "gateways", Scope.namespaced },
        .{ types.HTTPRoute, "/apis/gateway.networking.k8s.io/v1", "httproutes", Scope.namespaced },
        .{ types.GRPCRoute, "/apis/gateway.networking.k8s.io/v1", "grpcroutes", Scope.namespaced },
        .{ types.ReferenceGrant, "/apis/gateway.networking.k8s.io/v1beta1", "referencegrants", Scope.namespaced },

        // Dynamic Resource Allocation
        .{ types.ResourceClaim, "/apis/resource.k8s.io/v1", "resourceclaims", Scope.namespaced },
        .{ types.ResourceClaimTemplate, "/apis/resource.k8s.io/v1", "resourceclaimtemplates", Scope.namespaced },
        .{ types.ResourceSlice, "/apis/resource.k8s.io/v1", "resourceslices", Scope.cluster },
        .{ types.DeviceClass, "/apis/resource.k8s.io/v1", "deviceclasses", Scope.cluster },

        // Storage Migration
        .{ types.StorageVersionMigration, "/apis/storagemigration.k8s.io/v1beta1", "storageversionmigrations", Scope.cluster },
    };

    inline for (table) |entry| {
        if (entry[0] == T) {
            return .{
                .api_path = entry[1],
                .resource_name = entry[2],
                .scope = entry[3],
            };
        }
    }
    @compileError("Unknown resource type: " ++ @typeName(T) ++ ". Register it in resource_registry.zig.");
}
