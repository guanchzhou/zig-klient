const std = @import("std");
const K8sClient = @import("client.zig").K8sClient;

/// SelfSubjectAccessReview - check if the current user can perform an action.
/// Equivalent to `kubectl auth can-i`.
pub const AccessReview = struct {
    client: *K8sClient,

    pub fn init(k8s_client: *K8sClient) AccessReview {
        return .{ .client = k8s_client };
    }

    // Internal types for JSON serialization (uses std.json.stringify for
    // proper escaping instead of hand-built format strings).

    const ResourceAttributes = struct {
        verb: []const u8,
        group: ?[]const u8 = null,
        resource: []const u8,
        namespace: ?[]const u8 = null,
        name: ?[]const u8 = null,
    };

    const ReviewSpec = struct {
        resourceAttributes: ResourceAttributes,
    };

    const ReviewRequest = struct {
        apiVersion: []const u8 = "authorization.k8s.io/v1",
        kind: []const u8 = "SelfSubjectAccessReview",
        spec: ReviewSpec,
    };

    /// Check if the current user can perform an action on a resource.
    /// Returns true if the action is allowed.
    pub fn canI(
        self: AccessReview,
        verb: []const u8,
        group: []const u8,
        resource: []const u8,
        namespace: ?[]const u8,
        name: ?[]const u8,
    ) !bool {
        const allocator = self.client.allocator;

        const review = ReviewRequest{
            .spec = .{
                .resourceAttributes = .{
                    .verb = verb,
                    .group = if (group.len > 0) group else null,
                    .resource = resource,
                    .namespace = namespace,
                    .name = name,
                },
            },
        };

        var buf = try std.ArrayList(u8).initCapacity(allocator, 0);
        defer buf.deinit(allocator);
        try std.json.stringify(review, .{}, buf.writer(allocator));

        const response = try self.client.request(
            .POST,
            "/apis/authorization.k8s.io/v1/selfsubjectaccessreviews",
            buf.items,
        );
        defer allocator.free(response);

        const parsed = try std.json.parseFromSlice(
            std.json.Value,
            allocator,
            response,
            .{ .ignore_unknown_fields = true },
        );
        defer parsed.deinit();

        if (parsed.value == .object) {
            if (parsed.value.object.get("status")) |status| {
                if (status == .object) {
                    if (status.object.get("allowed")) |allowed| {
                        if (allowed == .bool) return allowed.bool;
                    }
                }
            }
        }

        return false;
    }

    /// Check if current user can list resources
    pub fn canList(self: AccessReview, group: []const u8, resource: []const u8, namespace: ?[]const u8) !bool {
        return self.canI("list", group, resource, namespace, null);
    }

    /// Check if current user can watch resources
    pub fn canWatch(self: AccessReview, group: []const u8, resource: []const u8, namespace: ?[]const u8) !bool {
        return self.canI("watch", group, resource, namespace, null);
    }

    /// Check if current user can create resources
    pub fn canCreate(self: AccessReview, group: []const u8, resource: []const u8, namespace: ?[]const u8) !bool {
        return self.canI("create", group, resource, namespace, null);
    }

    /// Check if current user can delete resources
    pub fn canDelete(self: AccessReview, group: []const u8, resource: []const u8, namespace: ?[]const u8) !bool {
        return self.canI("delete", group, resource, namespace, null);
    }
};
