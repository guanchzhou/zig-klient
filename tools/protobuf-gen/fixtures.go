package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"math/rand"
	"os"
	"path/filepath"
	"reflect"
	"time"

	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/apitesting/fuzzer"
	"k8s.io/apimachinery/pkg/api/meta"
	"k8s.io/apimachinery/pkg/api/resource"
	metafuzzer "k8s.io/apimachinery/pkg/apis/meta/fuzzer"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/runtime/serializer"
	"k8s.io/apimachinery/pkg/runtime/serializer/protobuf"
)

// Items per generated list, and the seed of the first one; a fixed seed keeps
// regenerated fixtures byte-identical.
const (
	fuzzItems = 2
	fuzzSeed  = 1
)

// writeFixtures writes hand-built Pod lists to dir and one randomly filled
// list per resource to dir/types. The JSON body is the Protobuf body decoded
// and re-encoded, the way the API server serves objects it stored as
// Protobuf, so both files describe the same object.
func writeFixtures(dir string) error {
	scheme := runtime.NewScheme()
	for _, add := range addToScheme {
		if err := add(scheme); err != nil {
			return err
		}
	}
	codecs := serializer.NewCodecFactory(scheme)
	pb := protobuf.NewSerializer(scheme, scheme)

	pods := map[string]runtime.Object{
		"pod_list":       podList("4242", "", richPod(), minimalPod()),
		"pod_list_empty": podList("17", ""),
		"pod_list_page":  podList("99", "eyJ2IjoibWV0YS5rOHMuaW8vdjEifQ", minimalPod()),
	}
	for name, obj := range pods {
		if err := writePair(pb, dir, name, obj); err != nil {
			return err
		}
	}

	typesDir := filepath.Join(dir, "types")
	if err := os.MkdirAll(typesDir, 0o755); err != nil {
		return err
	}
	for i, r := range roots {
		list, err := fuzzList(scheme, codecs, r.list, fuzzSeed+int64(i))
		if err != nil {
			return fmt.Errorf("%s: %w", r.zig, err)
		}
		if err := writePair(pb, typesDir, r.zig, list); err != nil {
			return err
		}
	}
	return nil
}

func fuzzList(scheme *runtime.Scheme, codecs serializer.CodecFactory, template runtime.Object, seed int64) (runtime.Object, error) {
	list := template.DeepCopyObject()
	f := fuzzer.FuzzerFor(metafuzzer.Funcs, rand.NewSource(seed), codecs).NilChance(0.25).NumElements(1, 2)
	items := reflect.ValueOf(list).Elem().FieldByName("Items")
	items.Set(reflect.MakeSlice(items.Type(), fuzzItems, fuzzItems))
	for i := 0; i < fuzzItems; i++ {
		f.Fill(items.Index(i).Addr().Interface())
		fillEmptyStrings(items.Index(i))
	}
	listMeta, err := meta.ListAccessor(list)
	if err != nil {
		return nil, err
	}
	listMeta.SetResourceVersion("1")
	kinds, _, err := scheme.ObjectKinds(list)
	if err != nil {
		return nil, err
	}
	accessor, err := meta.TypeAccessor(list)
	if err != nil {
		return nil, err
	}
	accessor.SetAPIVersion(kinds[0].GroupVersion().String())
	accessor.SetKind(kinds[0].Kind)
	return list, nil
}

// fillEmptyStrings replaces empty strings and nil lists, so that neither
// `omitempty` nor a JSON null drops a field that real objects always set and
// zig-klient structs require. Zero values are covered by the hand-built Pod
// fixtures.
func fillEmptyStrings(v reflect.Value) {
	switch v.Kind() {
	case reflect.String:
		if v.String() == "" && v.CanSet() {
			v.SetString("x")
		}
	case reflect.Slice:
		if v.IsNil() && v.CanSet() {
			v.Set(reflect.MakeSlice(v.Type(), 1, 1))
		}
		for i := 0; i < v.Len(); i++ {
			fillEmptyStrings(v.Index(i))
		}
	case reflect.Pointer:
		if !v.IsNil() {
			fillEmptyStrings(v.Elem())
		}
	case reflect.Struct:
		if v.Type() == reflect.TypeFor[runtime.RawExtension]() || v.Type() == reflect.TypeFor[metav1.FieldsV1]() {
			return
		}
		for i := 0; i < v.NumField(); i++ {
			if v.Type().Field(i).IsExported() {
				fillEmptyStrings(v.Field(i))
			}
		}
	case reflect.Map:
		for _, key := range v.MapKeys() {
			value := reflect.New(v.Type().Elem()).Elem()
			value.Set(v.MapIndex(key))
			fillEmptyStrings(value)
			v.SetMapIndex(key, value)
		}
	}
}

func writePair(pb *protobuf.Serializer, dir, name string, obj runtime.Object) error {
	var body bytes.Buffer
	if err := pb.Encode(obj, &body); err != nil {
		return fmt.Errorf("%s: %w", name, err)
	}
	decoded, _, err := pb.Decode(body.Bytes(), nil, nil)
	if err != nil {
		return fmt.Errorf("%s: %w", name, err)
	}
	js, err := json.Marshal(decoded)
	if err != nil {
		return fmt.Errorf("%s: %w", name, err)
	}
	if err := os.WriteFile(filepath.Join(dir, name+".pb"), body.Bytes(), 0o644); err != nil {
		return err
	}
	return os.WriteFile(filepath.Join(dir, name+".json"), append(js, '\n'), 0o644)
}

func podList(rv, cont string, pods ...corev1.Pod) *corev1.PodList {
	list := &corev1.PodList{
		TypeMeta: metav1.TypeMeta{APIVersion: "v1", Kind: "PodList"},
		ListMeta: metav1.ListMeta{ResourceVersion: rv, Continue: cont},
		Items:    pods,
	}
	if cont != "" {
		remaining := int64(3)
		list.RemainingItemCount = &remaining
	}
	return list
}

func at(s string) metav1.Time {
	t, err := time.Parse(time.RFC3339Nano, s)
	if err != nil {
		panic(err)
	}
	return metav1.NewTime(t)
}

func richPod() corev1.Pod {
	hostUsers := false
	started := true
	deleted := at("2026-10-26T12:30:00Z")
	sizeLimit := resource.MustParse("1Gi")
	return corev1.Pod{
		ObjectMeta: metav1.ObjectMeta{
			Name:              "web-7d9f8c6b5-x2k4p",
			GenerateName:      "web-7d9f8c6b5-",
			Namespace:         "shop",
			UID:               "0b6f3c1e-2a7d-4c58-9e1f-5d2b8a4c7e90",
			ResourceVersion:   "4241",
			Generation:        3,
			CreationTimestamp: at("2026-10-26T12:00:00.123456789Z"),
			DeletionTimestamp: &deleted,
			Labels:            map[string]string{"app": "web", "pod-template-hash": "7d9f8c6b5"},
			Annotations:       map[string]string{"example.com/note": "multi\nline \"quoted\""},
			Finalizers:        []string{"example.com/finalizer"},
			OwnerReferences: []metav1.OwnerReference{{
				APIVersion: "apps/v1", Kind: "ReplicaSet", Name: "web-7d9f8c6b5", UID: "rs-uid",
			}},
			ManagedFields: []metav1.ManagedFieldsEntry{{
				Manager: "kube-controller-manager", Operation: metav1.ManagedFieldsOperationUpdate,
				FieldsType: "FieldsV1", FieldsV1: &metav1.FieldsV1{Raw: []byte(`{"f:metadata":{}}`)},
			}},
		},
		Spec: corev1.PodSpec{
			RestartPolicy:      corev1.RestartPolicyAlways,
			NodeName:           "node-a",
			ServiceAccountName: "web",
			HostUsers:          &hostUsers,
			Tolerations:        []corev1.Toleration{{Key: "dedicated", Operator: "Exists"}},
			Containers: []corev1.Container{{
				Name:    "app",
				Image:   "registry.example.com/web:1.4.2",
				Command: []string{"/bin/web"},
				Args:    []string{"--port=8080", ""},
				Ports: []corev1.ContainerPort{
					{Name: "http", ContainerPort: 8080, Protocol: corev1.ProtocolTCP},
					{ContainerPort: 9090},
				},
				Env: []corev1.EnvVar{
					{Name: "MODE", Value: "prod"},
					{Name: "EMPTY"},
					{Name: "CM", ValueFrom: &corev1.EnvVarSource{ConfigMapKeyRef: &corev1.ConfigMapKeySelector{
						LocalObjectReference: corev1.LocalObjectReference{Name: "web-config"}, Key: "mode",
					}}},
					{Name: "SECRET", ValueFrom: &corev1.EnvVarSource{SecretKeyRef: &corev1.SecretKeySelector{
						LocalObjectReference: corev1.LocalObjectReference{Name: "web-secret"}, Key: "token",
					}}},
					{Name: "POD_IP", ValueFrom: &corev1.EnvVarSource{FieldRef: &corev1.ObjectFieldSelector{FieldPath: "status.podIP"}}},
				},
				VolumeMounts: []corev1.VolumeMount{
					{Name: "config", MountPath: "/etc/web", ReadOnly: true},
					{Name: "scratch", MountPath: "/tmp"},
				},
				Resources: corev1.ResourceRequirements{
					Limits:   corev1.ResourceList{corev1.ResourceCPU: resource.MustParse("500m"), corev1.ResourceMemory: resource.MustParse("256Mi")},
					Requests: corev1.ResourceList{corev1.ResourceCPU: resource.MustParse("0.1")},
				},
				LivenessProbe: &corev1.Probe{InitialDelaySeconds: 5},
			}},
			Volumes: []corev1.Volume{
				{Name: "config", VolumeSource: corev1.VolumeSource{ConfigMap: &corev1.ConfigMapVolumeSource{
					LocalObjectReference: corev1.LocalObjectReference{Name: "web-config"},
				}}},
				{Name: "token", VolumeSource: corev1.VolumeSource{Secret: &corev1.SecretVolumeSource{SecretName: "web-secret"}}},
				{Name: "scratch", VolumeSource: corev1.VolumeSource{EmptyDir: &corev1.EmptyDirVolumeSource{}}},
				{Name: "cache", VolumeSource: corev1.VolumeSource{EmptyDir: &corev1.EmptyDirVolumeSource{Medium: corev1.StorageMediumMemory, SizeLimit: &sizeLimit}}},
				{Name: "model", VolumeSource: corev1.VolumeSource{Image: &corev1.ImageVolumeSource{Reference: "registry.example.com/model:v1", PullPolicy: corev1.PullIfNotPresent}}},
				{Name: "host", VolumeSource: corev1.VolumeSource{HostPath: &corev1.HostPathVolumeSource{Path: "/var/log"}}},
			},
		},
		Status: corev1.PodStatus{
			Phase:     corev1.PodRunning,
			PodIP:     "10.0.0.7",
			PodIPs:    []corev1.PodIP{{IP: "10.0.0.7"}, {IP: "fd00::7"}},
			HostIP:    "192.0.2.10",
			HostIPs:   []corev1.HostIP{{IP: "192.0.2.10"}},
			StartTime: ptr(at("2026-10-26T12:00:01Z")),
			QOSClass:  corev1.PodQOSBurstable,
			Conditions: []corev1.PodCondition{
				{Type: corev1.PodReady, Status: corev1.ConditionTrue, LastTransitionTime: at("2026-10-26T12:00:09Z")},
				{Type: corev1.PodScheduled, Status: corev1.ConditionTrue, Reason: "Scheduled", Message: "ok", LastTransitionTime: at("2026-10-26T12:00:00Z")},
			},
			InitContainerStatuses: []corev1.ContainerStatus{{
				Name: "init", Ready: true, Image: "busybox:1.36", ImageID: "docker.io/library/busybox@sha256:abc",
				State: corev1.ContainerState{Terminated: &corev1.ContainerStateTerminated{
					ExitCode: 0, Reason: "Completed", StartedAt: at("2026-10-26T12:00:02Z"), FinishedAt: at("2026-10-26T12:00:03Z"), ContainerID: "containerd://init",
				}},
			}},
			ContainerStatuses: []corev1.ContainerStatus{{
				Name: "app", Ready: true, RestartCount: 2, Started: &started,
				Image: "registry.example.com/web:1.4.2", ImageID: "registry.example.com/web@sha256:def", ContainerID: "containerd://app",
				State: corev1.ContainerState{Running: &corev1.ContainerStateRunning{StartedAt: at("2026-10-26T12:00:04Z")}},
				LastTerminationState: corev1.ContainerState{Terminated: &corev1.ContainerStateTerminated{
					ExitCode: 137, Signal: 9, Reason: "OOMKilled", Message: "killed",
					StartedAt: at("2026-10-26T11:59:00Z"), FinishedAt: at("2026-10-26T11:59:59Z"),
				}},
			}},
			EphemeralContainerStatuses: []corev1.ContainerStatus{{
				Name: "debug", RestartCount: 0,
				State: corev1.ContainerState{Waiting: &corev1.ContainerStateWaiting{Reason: "CrashLoopBackOff", Message: "back-off"}},
			}},
		},
	}
}

func minimalPod() corev1.Pod {
	return corev1.Pod{
		ObjectMeta: metav1.ObjectMeta{Name: "bare", Namespace: "default"},
		Spec:       corev1.PodSpec{Containers: []corev1.Container{{Name: "c", Image: "pause:3.10"}}},
		Status:     corev1.PodStatus{Phase: corev1.PodPending},
	}
}

func ptr[T any](v T) *T { return &v }
