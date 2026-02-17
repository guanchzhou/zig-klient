const std = @import("std");
const K8sClient = @import("client.zig").K8sClient;

/// SelfSubjectAccessReview - check if the current user can perform an action
/// Equivalent to `kubectl auth can-i`
pub const AccessReview = struct {
    client: *K8sClient,

    pub fn init(k8s_client: *K8sClient) AccessReview {
        return .{ .client = k8s_client };
    }

    /// Check if the current user can perform an action on a resource
    /// Returns true if the action is allowed
    pub fn canI(
        self: AccessReview,
        verb: []const u8,
        group: []const u8,
        resource: []const u8,
        namespace: ?[]const u8,
        name: ?[]const u8,
    ) !bool {
        const allocator = self.client.allocator;

        // Build the SelfSubjectAccessReview JSON body
        var body = std.ArrayList(u8).init(allocator);
        defer body.deinit();
        const writer = body.writer();

        try writer.writeAll("{\"apiVersion\":\"authorization.k8s.io/v1\",\"kind\":\"SelfSubjectAccessReview\",\"spec\":{\"resourceAttributes\":{");

        var has_field = false;
        try writer.print("\"verb\":\"{s}\"", .{verb});
        has_field = true;

        if (group.len > 0) {
            if (has_field) try writer.writeByte(',');
            try writer.print("\"group\":\"{s}\"", .{group});
        }

        if (has_field) try writer.writeByte(',');
        try writer.print("\"resource\":\"{s}\"", .{resource});

        if (namespace) |ns| {
            try writer.writeByte(',');
            try writer.print("\"namespace\":\"{s}\"", .{ns});
        }

        if (name) |n| {
            try writer.writeByte(',');
            try writer.print("\"name\":\"{s}\"", .{n});
        }

        try writer.writeAll("}}}");

        const response = try self.client.request(
            .POST,
            "/apis/authorization.k8s.io/v1/selfsubjectaccessreviews",
            body.items,
        );
        defer allocator.free(response);

        // Parse response to check if allowed
        const parsed = try std.json.parseFromSlice(
            std.json.Value,
            allocator,
            response,
            .{ .ignore_unknown_fields = true },
        );
        defer parsed.deinit();

        if (parsed.value.object.get("status")) |status| {
            if (status.object.get("allowed")) |allowed| {
                return allowed.bool;
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
