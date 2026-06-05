const std = @import("std");
const klient = @import("klient");

test "GatewayClass - create structure" {
    const gc = klient.GatewayClass{
        .apiVersion = "gateway.networking.k8s.io/v1",
        .kind = "GatewayClass",
        .metadata = .{
            .name = "test-gateway-class",
        },
        .spec = .{
            .controllerName = "example.com/gateway-controller",
            .description = "Test gateway class",
            .parametersRef = null,
        },
    };

    try std.testing.expectEqualStrings("gateway.networking.k8s.io/v1", gc.apiVersion.?);
    try std.testing.expectEqualStrings("GatewayClass", gc.kind.?);
    try std.testing.expectEqualStrings("test-gateway-class", gc.metadata.name);
    try std.testing.expectEqualStrings("example.com/gateway-controller", gc.spec.?.controllerName);
    try std.testing.expectEqualStrings("Test gateway class", gc.spec.?.description.?);
}

test "GatewayClass - JSON deserialization" {
    const json_data =
        \\{
        \\  "apiVersion": "gateway.networking.k8s.io/v1",
        \\  "kind": "GatewayClass",
        \\  "metadata": {
        \\    "name": "example-gateway"
        \\  },
        \\  "spec": {
        \\    "controllerName": "example.io/gateway-controller"
        \\  }
        \\}
    ;

    const parsed = try std.json.parseFromSlice(
        klient.GatewayClass,
        std.testing.allocator,
        json_data,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();

    try std.testing.expectEqualStrings("gateway.networking.k8s.io/v1", parsed.value.apiVersion.?);
    try std.testing.expectEqualStrings("GatewayClass", parsed.value.kind.?);
    try std.testing.expectEqualStrings("example-gateway", parsed.value.metadata.name);
    try std.testing.expectEqualStrings("example.io/gateway-controller", parsed.value.spec.?.controllerName);
}

test "Gateway - create structure" {
    const gateway = klient.Gateway{
        .apiVersion = "gateway.networking.k8s.io/v1",
        .kind = "Gateway",
        .metadata = .{
            .name = "test-gateway",
            .namespace = "default",
        },
        .spec = .{
            .gatewayClassName = "example-gateway-class",
            .listeners = &[_]std.json.Value{},
            .addresses = null,
        },
    };

    try std.testing.expectEqualStrings("gateway.networking.k8s.io/v1", gateway.apiVersion.?);
    try std.testing.expectEqualStrings("Gateway", gateway.kind.?);
    try std.testing.expectEqualStrings("test-gateway", gateway.metadata.name);
    try std.testing.expectEqualStrings("example-gateway-class", gateway.spec.?.gatewayClassName);
}

test "Gateway - JSON deserialization" {
    const json_data =
        \\{
        \\  "apiVersion": "gateway.networking.k8s.io/v1",
        \\  "kind": "Gateway",
        \\  "metadata": {
        \\    "name": "my-gateway",
        \\    "namespace": "default"
        \\  },
        \\  "spec": {
        \\    "gatewayClassName": "my-gateway-class",
        \\    "listeners": []
        \\  }
        \\}
    ;

    const parsed = try std.json.parseFromSlice(
        klient.Gateway,
        std.testing.allocator,
        json_data,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();

    try std.testing.expectEqualStrings("gateway.networking.k8s.io/v1", parsed.value.apiVersion.?);
    try std.testing.expectEqualStrings("Gateway", parsed.value.kind.?);
    try std.testing.expectEqualStrings("my-gateway", parsed.value.metadata.name);
    try std.testing.expectEqualStrings("my-gateway-class", parsed.value.spec.?.gatewayClassName);
}

test "HTTPRoute - create structure" {
    const route = klient.HTTPRoute{
        .apiVersion = "gateway.networking.k8s.io/v1",
        .kind = "HTTPRoute",
        .metadata = .{
            .name = "test-http-route",
            .namespace = "default",
        },
        .spec = .{
            .parentRefs = null,
            .hostnames = null,
            .rules = null,
        },
    };

    try std.testing.expectEqualStrings("gateway.networking.k8s.io/v1", route.apiVersion.?);
    try std.testing.expectEqualStrings("HTTPRoute", route.kind.?);
    try std.testing.expectEqualStrings("test-http-route", route.metadata.name);
}

test "HTTPRoute - JSON deserialization" {
    const json_data =
        \\{
        \\  "apiVersion": "gateway.networking.k8s.io/v1",
        \\  "kind": "HTTPRoute",
        \\  "metadata": {
        \\    "name": "example-route",
        \\    "namespace": "default"
        \\  },
        \\  "spec": {
        \\    "hostnames": ["example.com"],
        \\    "rules": []
        \\  }
        \\}
    ;

    const parsed = try std.json.parseFromSlice(
        klient.HTTPRoute,
        std.testing.allocator,
        json_data,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();

    try std.testing.expectEqualStrings("gateway.networking.k8s.io/v1", parsed.value.apiVersion.?);
    try std.testing.expectEqualStrings("HTTPRoute", parsed.value.kind.?);
    try std.testing.expectEqualStrings("example-route", parsed.value.metadata.name);
}

test "GRPCRoute - create structure" {
    const route = klient.GRPCRoute{
        .apiVersion = "gateway.networking.k8s.io/v1",
        .kind = "GRPCRoute",
        .metadata = .{
            .name = "test-grpc-route",
            .namespace = "default",
        },
        .spec = .{
            .parentRefs = null,
            .hostnames = null,
            .rules = null,
        },
    };

    try std.testing.expectEqualStrings("gateway.networking.k8s.io/v1", route.apiVersion.?);
    try std.testing.expectEqualStrings("GRPCRoute", route.kind.?);
    try std.testing.expectEqualStrings("test-grpc-route", route.metadata.name);
}

test "GRPCRoute - JSON deserialization" {
    const json_data =
        \\{
        \\  "apiVersion": "gateway.networking.k8s.io/v1",
        \\  "kind": "GRPCRoute",
        \\  "metadata": {
        \\    "name": "grpc-service",
        \\    "namespace": "default"
        \\  },
        \\  "spec": {
        \\    "hostnames": ["grpc.example.com"],
        \\    "rules": []
        \\  }
        \\}
    ;

    const parsed = try std.json.parseFromSlice(
        klient.GRPCRoute,
        std.testing.allocator,
        json_data,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();

    try std.testing.expectEqualStrings("gateway.networking.k8s.io/v1", parsed.value.apiVersion.?);
    try std.testing.expectEqualStrings("GRPCRoute", parsed.value.kind.?);
    try std.testing.expectEqualStrings("grpc-service", parsed.value.metadata.name);
}

test "ReferenceGrant - create structure" {
    const grant = klient.ReferenceGrant{
        .apiVersion = "gateway.networking.k8s.io/v1beta1",
        .kind = "ReferenceGrant",
        .metadata = .{
            .name = "test-ref-grant",
            .namespace = "default",
        },
        .spec = .{
            .from = &[_]std.json.Value{},
            .to = &[_]std.json.Value{},
        },
    };

    try std.testing.expectEqualStrings("gateway.networking.k8s.io/v1beta1", grant.apiVersion.?);
    try std.testing.expectEqualStrings("ReferenceGrant", grant.kind.?);
    try std.testing.expectEqualStrings("test-ref-grant", grant.metadata.name);
}

test "ReferenceGrant - JSON deserialization" {
    const json_data =
        \\{
        \\  "apiVersion": "gateway.networking.k8s.io/v1beta1",
        \\  "kind": "ReferenceGrant",
        \\  "metadata": {
        \\    "name": "backend-grant",
        \\    "namespace": "backend"
        \\  },
        \\  "spec": {
        \\    "from": [],
        \\    "to": []
        \\  }
        \\}
    ;

    const parsed = try std.json.parseFromSlice(
        klient.ReferenceGrant,
        std.testing.allocator,
        json_data,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();

    try std.testing.expectEqualStrings("gateway.networking.k8s.io/v1beta1", parsed.value.apiVersion.?);
    try std.testing.expectEqualStrings("ReferenceGrant", parsed.value.kind.?);
    try std.testing.expectEqualStrings("backend-grant", parsed.value.metadata.name);
}
