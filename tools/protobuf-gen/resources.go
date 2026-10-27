package main

import (
	admissionregistrationv1 "k8s.io/api/admissionregistration/v1"
	appsv1 "k8s.io/api/apps/v1"
	autoscalingv2 "k8s.io/api/autoscaling/v2"
	batchv1 "k8s.io/api/batch/v1"
	certificatesv1 "k8s.io/api/certificates/v1"
	coordinationv1 "k8s.io/api/coordination/v1"
	corev1 "k8s.io/api/core/v1"
	discoveryv1 "k8s.io/api/discovery/v1"
	networkingv1 "k8s.io/api/networking/v1"
	nodev1 "k8s.io/api/node/v1"
	policyv1 "k8s.io/api/policy/v1"
	rbacv1 "k8s.io/api/rbac/v1"
	resourcev1 "k8s.io/api/resource/v1"
	schedulingv1 "k8s.io/api/scheduling/v1"
	storagev1 "k8s.io/api/storage/v1"
	storagemigrationv1 "k8s.io/api/storagemigration/v1"
	"k8s.io/apimachinery/pkg/runtime"
)

// root pairs a zig-klient type (a declaration in src/k8s/types.zig) with
// the upstream list type the API server sends for it.
type root struct {
	zig  string
	list runtime.Object
}

var roots = []root{
	{"Pod", &corev1.PodList{}},
	{"Namespace", &corev1.NamespaceList{}},
	{"Node", &corev1.NodeList{}},
	{"Service", &corev1.ServiceList{}},
	{"ConfigMap", &corev1.ConfigMapList{}},
	{"Secret", &corev1.SecretList{}},
	{"PersistentVolume", &corev1.PersistentVolumeList{}},
	{"PersistentVolumeClaim", &corev1.PersistentVolumeClaimList{}},
	{"ServiceAccount", &corev1.ServiceAccountList{}},
	{"Endpoints", &corev1.EndpointsList{}},
	{"Event", &corev1.EventList{}},
	{"ResourceQuota", &corev1.ResourceQuotaList{}},
	{"LimitRange", &corev1.LimitRangeList{}},
	{"Deployment", &appsv1.DeploymentList{}},
	{"StatefulSet", &appsv1.StatefulSetList{}},
	{"DaemonSet", &appsv1.DaemonSetList{}},
	{"ReplicaSet", &appsv1.ReplicaSetList{}},
	{"Job", &batchv1.JobList{}},
	{"CronJob", &batchv1.CronJobList{}},
	{"Role", &rbacv1.RoleList{}},
	{"RoleBinding", &rbacv1.RoleBindingList{}},
	{"ClusterRole", &rbacv1.ClusterRoleList{}},
	{"ClusterRoleBinding", &rbacv1.ClusterRoleBindingList{}},
	{"Ingress", &networkingv1.IngressList{}},
	{"NetworkPolicy", &networkingv1.NetworkPolicyList{}},
	{"IPAddress", &networkingv1.IPAddressList{}},
	{"ServiceCIDR", &networkingv1.ServiceCIDRList{}},
	{"IngressClass", &networkingv1.IngressClassList{}},
	{"StorageClass", &storagev1.StorageClassList{}},
	{"CSIDriver", &storagev1.CSIDriverList{}},
	{"VolumeAttributesClass", &storagev1.VolumeAttributesClassList{}},
	{"HorizontalPodAutoscaler", &autoscalingv2.HorizontalPodAutoscalerList{}},
	{"PodDisruptionBudget", &policyv1.PodDisruptionBudgetList{}},
	{"EndpointSlice", &discoveryv1.EndpointSliceList{}},
	{"Lease", &coordinationv1.LeaseList{}},
	{"PriorityClass", &schedulingv1.PriorityClassList{}},
	{"CertificateSigningRequest", &certificatesv1.CertificateSigningRequestList{}},
	{"ValidatingWebhookConfiguration", &admissionregistrationv1.ValidatingWebhookConfigurationList{}},
	{"MutatingWebhookConfiguration", &admissionregistrationv1.MutatingWebhookConfigurationList{}},
	{"ValidatingAdmissionPolicy", &admissionregistrationv1.ValidatingAdmissionPolicyList{}},
	{"ValidatingAdmissionPolicyBinding", &admissionregistrationv1.ValidatingAdmissionPolicyBindingList{}},
	{"MutatingAdmissionPolicy", &admissionregistrationv1.MutatingAdmissionPolicyList{}},
	{"MutatingAdmissionPolicyBinding", &admissionregistrationv1.MutatingAdmissionPolicyBindingList{}},
	{"RuntimeClass", &nodev1.RuntimeClassList{}},
	{"ResourceClaim", &resourcev1.ResourceClaimList{}},
	{"DeviceClass", &resourcev1.DeviceClassList{}},
	{"StorageVersionMigration", &storagemigrationv1.StorageVersionMigrationList{}},
}

var addToScheme = []func(*runtime.Scheme) error{
	admissionregistrationv1.AddToScheme,
	appsv1.AddToScheme,
	autoscalingv2.AddToScheme,
	batchv1.AddToScheme,
	certificatesv1.AddToScheme,
	coordinationv1.AddToScheme,
	corev1.AddToScheme,
	discoveryv1.AddToScheme,
	networkingv1.AddToScheme,
	nodev1.AddToScheme,
	policyv1.AddToScheme,
	rbacv1.AddToScheme,
	resourcev1.AddToScheme,
	schedulingv1.AddToScheme,
	storagev1.AddToScheme,
	storagemigrationv1.AddToScheme,
}
