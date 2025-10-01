// Final 9 resource clients for 100% coverage
const std = @import("std");
const types = @import("types.zig");
const K8sClient = @import("client.zig").K8sClient;
const ResourceClient = @import("resources.zig").ResourceClient;

pub const CertificateSigningRequests = struct {
    client: ResourceClient(types.CertificateSigningRequest),

    pub fn init(k8s_client: *K8sClient) CertificateSigningRequests {
        return .{
            .client = ResourceClient(types.CertificateSigningRequest){
                .client = k8s_client,
                .api_path = "/apis/certificates.k8s.io/v1",
                .resource = "certificatesigningrequests",
            },
        };
    }

    pub fn list(self: CertificateSigningRequests) !std.json.Parsed(types.List(types.CertificateSigningRequest)) {
        const path = "/apis/certificates.k8s.io/v1/certificatesigningrequests";
        const body = try self.client.client.request(.GET, path, null);
        defer self.client.client.allocator.free(body);
        const parsed = try std.json.parseFromSlice(types.List(types.CertificateSigningRequest), self.client.client.allocator, body, .{.ignore_unknown_fields = true, .allocate = .alloc_always});
        return parsed;
    }
};

pub const ValidatingWebhookConfigurations = struct {
    client: ResourceClient(types.ValidatingWebhookConfiguration),

    pub fn init(k8s_client: *K8sClient) ValidatingWebhookConfigurations {
        return .{
            .client = ResourceClient(types.ValidatingWebhookConfiguration){
                .client = k8s_client,
                .api_path = "/apis/admissionregistration.k8s.io/v1",
                .resource = "validatingwebhookconfigurations",
            },
        };
    }

    pub fn list(self: ValidatingWebhookConfigurations) !std.json.Parsed(types.List(types.ValidatingWebhookConfiguration)) {
        const path = "/apis/admissionregistration.k8s.io/v1/validatingwebhookconfigurations";
        const body = try self.client.client.request(.GET, path, null);
        defer self.client.client.allocator.free(body);
        const parsed = try std.json.parseFromSlice(types.List(types.ValidatingWebhookConfiguration), self.client.client.allocator, body, .{.ignore_unknown_fields = true, .allocate = .alloc_always});
        return parsed;
    }
};

pub const MutatingWebhookConfigurations = struct {
    client: ResourceClient(types.MutatingWebhookConfiguration),

    pub fn init(k8s_client: *K8sClient) MutatingWebhookConfigurations {
        return .{
            .client = ResourceClient(types.MutatingWebhookConfiguration){
                .client = k8s_client,
                .api_path = "/apis/admissionregistration.k8s.io/v1",
                .resource = "mutatingwebhookconfigurations",
            },
        };
    }

    pub fn list(self: MutatingWebhookConfigurations) !std.json.Parsed(types.List(types.MutatingWebhookConfiguration)) {
        const path = "/apis/admissionregistration.k8s.io/v1/mutatingwebhookconfigurations";
        const body = try self.client.client.request(.GET, path, null);
        defer self.client.client.allocator.free(body);
        const parsed = try std.json.parseFromSlice(types.List(types.MutatingWebhookConfiguration), self.client.client.allocator, body, .{.ignore_unknown_fields = true, .allocate = .alloc_always});
        return parsed;
    }
};

pub const ValidatingAdmissionPolicies = struct {
    client: ResourceClient(types.ValidatingAdmissionPolicy),

    pub fn init(k8s_client: *K8sClient) ValidatingAdmissionPolicies {
        return .{
            .client = ResourceClient(types.ValidatingAdmissionPolicy){
                .client = k8s_client,
                .api_path = "/apis/admissionregistration.k8s.io/v1",
                .resource = "validatingadmissionpolicies",
            },
        };
    }

    pub fn list(self: ValidatingAdmissionPolicies) !std.json.Parsed(types.List(types.ValidatingAdmissionPolicy)) {
        const path = "/apis/admissionregistration.k8s.io/v1/validatingadmissionpolicies";
        const body = try self.client.client.request(.GET, path, null);
        defer self.client.client.allocator.free(body);
        const parsed = try std.json.parseFromSlice(types.List(types.ValidatingAdmissionPolicy), self.client.client.allocator, body, .{.ignore_unknown_fields = true, .allocate = .alloc_always});
        return parsed;
    }
};

pub const ValidatingAdmissionPolicyBindings = struct {
    client: ResourceClient(types.ValidatingAdmissionPolicyBinding),

    pub fn init(k8s_client: *K8sClient) ValidatingAdmissionPolicyBindings {
        return .{
            .client = ResourceClient(types.ValidatingAdmissionPolicyBinding){
                .client = k8s_client,
                .api_path = "/apis/admissionregistration.k8s.io/v1",
                .resource = "validatingadmissionpolicybindings",
            },
        };
    }

    pub fn list(self: ValidatingAdmissionPolicyBindings) !std.json.Parsed(types.List(types.ValidatingAdmissionPolicyBinding)) {
        const path = "/apis/admissionregistration.k8s.io/v1/validatingadmissionpolicybindings";
        const body = try self.client.client.request(.GET, path, null);
        defer self.client.client.allocator.free(body);
        const parsed = try std.json.parseFromSlice(types.List(types.ValidatingAdmissionPolicyBinding), self.client.client.allocator, body, .{.ignore_unknown_fields = true, .allocate = .alloc_always});
        return parsed;
    }
};

pub const APIServices = struct {
    client: ResourceClient(types.APIService),

    pub fn init(k8s_client: *K8sClient) APIServices {
        return .{
            .client = ResourceClient(types.APIService){
                .client = k8s_client,
                .api_path = "/apis/apiregistration.k8s.io/v1",
                .resource = "apiservices",
            },
        };
    }

    pub fn list(self: APIServices) !std.json.Parsed(types.List(types.APIService)) {
        const path = "/apis/apiregistration.k8s.io/v1/apiservices";
        const body = try self.client.client.request(.GET, path, null);
        defer self.client.client.allocator.free(body);
        const parsed = try std.json.parseFromSlice(types.List(types.APIService), self.client.client.allocator, body, .{.ignore_unknown_fields = true, .allocate = .alloc_always});
        return parsed;
    }
};

pub const FlowSchemas = struct {
    client: ResourceClient(types.FlowSchema),

    pub fn init(k8s_client: *K8sClient) FlowSchemas {
        return .{
            .client = ResourceClient(types.FlowSchema){
                .client = k8s_client,
                .api_path = "/apis/flowcontrol.apiserver.k8s.io/v1",
                .resource = "flowschemas",
            },
        };
    }

    pub fn list(self: FlowSchemas) !std.json.Parsed(types.List(types.FlowSchema)) {
        const path = "/apis/flowcontrol.apiserver.k8s.io/v1/flowschemas";
        const body = try self.client.client.request(.GET, path, null);
        defer self.client.client.allocator.free(body);
        const parsed = try std.json.parseFromSlice(types.List(types.FlowSchema), self.client.client.allocator, body, .{.ignore_unknown_fields = true, .allocate = .alloc_always});
        return parsed;
    }
};

pub const PriorityLevelConfigurations = struct {
    client: ResourceClient(types.PriorityLevelConfiguration),

    pub fn init(k8s_client: *K8sClient) PriorityLevelConfigurations {
        return .{
            .client = ResourceClient(types.PriorityLevelConfiguration){
                .client = k8s_client,
                .api_path = "/apis/flowcontrol.apiserver.k8s.io/v1",
                .resource = "prioritylevelconfigurations",
            },
        };
    }

    pub fn list(self: PriorityLevelConfigurations) !std.json.Parsed(types.List(types.PriorityLevelConfiguration)) {
        const path = "/apis/flowcontrol.apiserver.k8s.io/v1/prioritylevelconfigurations";
        const body = try self.client.client.request(.GET, path, null);
        defer self.client.client.allocator.free(body);
        const parsed = try std.json.parseFromSlice(types.List(types.PriorityLevelConfiguration), self.client.client.allocator, body, .{.ignore_unknown_fields = true, .allocate = .alloc_always});
        return parsed;
    }
};

pub const RuntimeClasses = struct {
    client: ResourceClient(types.RuntimeClass),

    pub fn init(k8s_client: *K8sClient) RuntimeClasses {
        return .{
            .client = ResourceClient(types.RuntimeClass){
                .client = k8s_client,
                .api_path = "/apis/node.k8s.io/v1",
                .resource = "runtimeclasses",
            },
        };
    }

    pub fn list(self: RuntimeClasses) !std.json.Parsed(types.List(types.RuntimeClass)) {
        const path = "/apis/node.k8s.io/v1/runtimeclasses";
        const body = try self.client.client.request(.GET, path, null);
        defer self.client.client.allocator.free(body);
        const parsed = try std.json.parseFromSlice(types.List(types.RuntimeClass), self.client.client.allocator, body, .{.ignore_unknown_fields = true, .allocate = .alloc_always});
        return parsed;
    }
};

