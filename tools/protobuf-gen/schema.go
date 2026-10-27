package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"reflect"
	"runtime/debug"
	"sort"
	"strconv"
	"strings"

	"k8s.io/apimachinery/pkg/api/resource"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/util/intstr"
)

// Types whose Protobuf message and JSON value differ in shape. The decoder
// handles each one by name.
var special = map[reflect.Type]string{
	reflect.TypeFor[metav1.Time]():          "time",
	reflect.TypeFor[metav1.MicroTime]():     "micro_time",
	reflect.TypeFor[resource.Quantity]():    "quantity",
	reflect.TypeFor[intstr.IntOrString]():   "int_or_string",
	reflect.TypeFor[runtime.RawExtension](): "raw_json",
	reflect.TypeFor[metav1.FieldsV1]():      "raw_json",
}

var jsonMarshaler = reflect.TypeFor[json.Marshaler]()

type field struct {
	number   int
	json     string
	typ      string
	message  reflect.Type
	repeated bool
	isMap    bool
	embedded bool
	omitZero bool
}

type schema struct {
	messages map[reflect.Type][]field
	order    []reflect.Type
}

func (s *schema) add(t reflect.Type) {
	if _, ok := s.messages[t]; ok {
		return
	}
	s.messages[t] = nil
	s.order = append(s.order, t)
	fields := messageFields(t)
	s.messages[t] = fields
	for _, f := range fields {
		if f.message != nil {
			s.add(f.message)
		}
	}
}

func messageFields(t reflect.Type) []field {
	var fields []field
	for i := 0; i < t.NumField(); i++ {
		sf := t.Field(i)
		tag := sf.Tag.Get("protobuf")
		if tag == "" {
			continue
		}
		parts := strings.Split(tag, ",")
		number, err := strconv.Atoi(parts[1])
		if err != nil {
			panic(fmt.Sprintf("%v.%s: protobuf tag %q", t, sf.Name, tag))
		}
		name, opts := parseJSONTag(sf.Tag.Get("json"))
		if name == "-" {
			continue
		}
		// Repetition comes from the Go type: some upstream tags say `rep` on a
		// scalar (PodStatus.QOSClass).
		f := field{number: number, json: name}

		ft := sf.Type
		pointer := ft.Kind() == reflect.Pointer
		if pointer {
			ft = ft.Elem()
		}
		switch {
		case ft.Kind() == reflect.Map:
			if ft.Key().Kind() != reflect.String {
				panic(fmt.Sprintf("%v.%s: map key %v", t, sf.Name, ft.Key()))
			}
			f.isMap = true
			ft = ft.Elem()
		case ft.Kind() == reflect.Slice && ft.Elem().Kind() != reflect.Uint8:
			f.repeated = true
			ft = ft.Elem()
		}
		if ft.Kind() == reflect.Pointer {
			ft = ft.Elem()
		}
		f.typ, f.message = classify(t, sf.Name, ft)
		if opts["inline"] || (sf.Anonymous && name == "") {
			if f.message == nil {
				panic(fmt.Sprintf("%v.%s: inline field is not a message", t, sf.Name))
			}
			f.embedded = true
		}

		switch {
		case pointer:
			f.omitZero = false
		case f.repeated || f.isMap || f.embedded:
			f.omitZero = true
		case f.typ == "message":
			// encoding/json never omits a struct value, so the message is
			// always present unless `omitzero` drops its zero value.
			f.omitZero = opts["omitzero"]
		default:
			f.omitZero = opts["omitempty"] || opts["omitzero"]
		}
		fields = append(fields, f)
	}
	return fields
}

func classify(owner reflect.Type, name string, t reflect.Type) (string, reflect.Type) {
	if kind, ok := special[t]; ok {
		return kind, nil
	}
	switch t.Kind() {
	case reflect.String:
		return "string", nil
	case reflect.Bool:
		return "bool", nil
	case reflect.Int32:
		return "int32", nil
	case reflect.Int64:
		return "int64", nil
	case reflect.Float64:
		return "double", nil
	case reflect.Slice:
		if t.Elem().Kind() == reflect.Uint8 {
			return "bytes", nil
		}
		// A named []string inside a map is a wrapper message whose field 1
		// repeats the strings; JSON shows it as a plain array.
		if t.Elem().Kind() == reflect.String {
			return "string_list", nil
		}
	case reflect.Struct:
		if t.Implements(jsonMarshaler) || reflect.PointerTo(t).Implements(jsonMarshaler) {
			panic(fmt.Sprintf("%v.%s: %v has its own JSON encoding; add it to `special`", owner, name, t))
		}
		return "message", t
	}
	panic(fmt.Sprintf("%v.%s: unsupported type %v", owner, name, t))
}

func parseJSONTag(tag string) (string, map[string]bool) {
	parts := strings.Split(tag, ",")
	opts := map[string]bool{}
	for _, opt := range parts[1:] {
		opts[opt] = true
	}
	return parts[0], opts
}

// zigName turns a Go package path and type name into a Zig identifier:
// k8s.io/api/core/v1.PodSpec becomes core_v1_PodSpec.
func zigName(t reflect.Type) string {
	path := t.PkgPath()
	for _, prefix := range []string{"k8s.io/api/", "k8s.io/apimachinery/pkg/apis/", "k8s.io/apimachinery/pkg/"} {
		if strings.HasPrefix(path, prefix) {
			path = strings.TrimPrefix(path, prefix)
			break
		}
	}
	path = strings.NewReplacer("/", "_", ".", "_", "-", "_").Replace(path)
	return path + "_" + t.Name()
}

func itemType(list runtime.Object) reflect.Type {
	items, ok := reflect.TypeOf(list).Elem().FieldByName("Items")
	if !ok {
		panic(fmt.Sprintf("%T has no Items", list))
	}
	return items.Type.Elem()
}

func moduleVersion(path string) string {
	info, ok := debug.ReadBuildInfo()
	if !ok {
		return "unknown"
	}
	for _, dep := range info.Deps {
		if dep.Path == path {
			return dep.Version
		}
	}
	return "unknown"
}

func generateSchema() []byte {
	s := &schema{messages: map[reflect.Type][]field{}}
	for _, r := range roots {
		s.add(itemType(r.list))
	}
	names := make([]reflect.Type, len(s.order))
	copy(names, s.order)
	sort.Slice(names, func(i, j int) bool { return zigName(names[i]) < zigName(names[j]) })

	var out bytes.Buffer
	fmt.Fprintf(&out, "//! Protobuf message tables for the Kubernetes types zig-klient decodes,\n")
	fmt.Fprintf(&out, "//! generated from k8s.io/api %s by tools/protobuf-gen. Do not edit;\n", moduleVersion("k8s.io/api"))
	fmt.Fprintf(&out, "//! run `zig build gen-protobuf` instead.\n\n")
	fmt.Fprintf(&out, "const Message = @import(\"protobuf.zig\").Message;\n\n")

	fmt.Fprintf(&out, "/// zig-klient type name and the message of one list item.\n")
	fmt.Fprintf(&out, "pub const roots = .{\n")
	for _, r := range roots {
		fmt.Fprintf(&out, "    .{ \"%s\", &%s },\n", r.zig, zigName(itemType(r.list)))
	}
	fmt.Fprintf(&out, "};\n")

	for _, t := range names {
		fmt.Fprintf(&out, "\npub const %s: Message = .{ .fields = &.{", zigName(t))
		fields := s.messages[t]
		if len(fields) == 0 {
			fmt.Fprintf(&out, "} };\n")
			continue
		}
		fmt.Fprintf(&out, "\n")
		for _, f := range fields {
			fmt.Fprintf(&out, "    .{ .number = %d, .json = \"%s\", .type = .%s", f.number, f.json, f.typ)
			if f.message != nil {
				fmt.Fprintf(&out, ", .message = &%s", zigName(f.message))
			}
			if f.repeated {
				fmt.Fprintf(&out, ", .repeated = true")
			}
			if f.isMap {
				fmt.Fprintf(&out, ", .map = true")
			}
			if f.embedded {
				fmt.Fprintf(&out, ", .embedded = true")
			}
			if !f.omitZero {
				fmt.Fprintf(&out, ", .omit_zero = false")
			}
			fmt.Fprintf(&out, " },\n")
		}
		fmt.Fprintf(&out, "} };\n")
	}
	return out.Bytes()
}
