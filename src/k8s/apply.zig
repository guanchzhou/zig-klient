const std = @import("std");
const K8sClient = @import("client.zig").K8sClient;

/// Server-side apply options
pub const ApplyOptions = struct {
    /// Field manager name (identifies the manager of the fields)
    field_manager: []const u8,

    /// Force the operation (take ownership of conflicting fields)
    force: bool = false,

    /// Dry run mode (validate without persisting)
    /// Options: "", "All", "None"
    dry_run: ?[]const u8 = null,

    /// Build query string from options (single allocation)
    pub fn buildQueryString(self: ApplyOptions, allocator: std.mem.Allocator) ![]const u8 {
        var buf = try std.ArrayList(u8).initCapacity(allocator, 0);
        errdefer buf.deinit(allocator);
        const writer = buf.writer(allocator);

        try writer.print("fieldManager={s}", .{self.field_manager});

        if (self.force) {
            try writer.writeAll("&force=true");
        }

        if (self.dry_run) |dr| {
            try writer.print("&dryRun={s}", .{dr});
        }

        return try buf.toOwnedSlice(allocator);
    }
};

/// Patch options for strategic merge patch and JSON patch
pub const PatchOptions = struct {
    /// Field manager name
    field_manager: ?[]const u8 = null,

    /// Force the operation
    force: bool = false,

    /// Dry run mode
    dry_run: ?[]const u8 = null,

    /// Build query string from options (single allocation)
    pub fn buildQueryString(self: PatchOptions, allocator: std.mem.Allocator) ![]const u8 {
        var buf = try std.ArrayList(u8).initCapacity(allocator, 0);
        errdefer buf.deinit(allocator);
        const writer = buf.writer(allocator);

        var first = true;
        if (self.field_manager) |fm| {
            try writer.print("fieldManager={s}", .{fm});
            first = false;
        }

        if (self.force) {
            if (!first) try writer.writeByte('&');
            try writer.writeAll("force=true");
            first = false;
        }

        if (self.dry_run) |dr| {
            if (!first) try writer.writeByte('&');
            try writer.print("dryRun={s}", .{dr});
        }

        return try buf.toOwnedSlice(allocator);
    }
};

/// Content types for different patch strategies
pub const PatchType = enum {
    /// Strategic merge patch (default for most resources)
    strategic_merge,

    /// JSON merge patch (RFC 7386)
    merge,

    /// JSON patch (RFC 6902)
    json,

    /// Server-side apply
    apply,

    pub fn contentType(self: PatchType) []const u8 {
        return switch (self) {
            .strategic_merge => "application/strategic-merge-patch+json",
            .merge => "application/merge-patch+json",
            .json => "application/json-patch+json",
            .apply => "application/apply-patch+yaml",
        };
    }
};

/// Server-side apply helper
pub const ApplyHelper = struct {
    client: *K8sClient,

    const Self = @This();

    pub fn init(client: *K8sClient) Self {
        return .{ .client = client };
    }

    /// Apply a resource using server-side apply
    /// The resource_json should be the full resource manifest
    pub fn apply(
        self: Self,
        api_path: []const u8,
        resource: []const u8,
        name: []const u8,
        namespace: ?[]const u8,
        resource_json: []const u8,
        options: ApplyOptions,
    ) ![]const u8 {
        // Build query string
        const query_string = try options.buildQueryString(self.client.allocator);
        defer self.client.allocator.free(query_string);

        // Build path
        const path = if (namespace) |ns|
            try std.fmt.allocPrint(
                self.client.allocator,
                "{s}/namespaces/{s}/{s}/{s}?{s}",
                .{ api_path, ns, resource, name, query_string },
            )
        else
            try std.fmt.allocPrint(
                self.client.allocator,
                "{s}/{s}/{s}?{s}",
                .{ api_path, resource, name, query_string },
            );
        defer self.client.allocator.free(path);

        // Use PATCH with apply content type
        return try self.client.requestWithContentType(
            .PATCH,
            path,
            resource_json,
            PatchType.apply.contentType(),
        );
    }

    /// Apply a namespaced resource
    pub fn applyNamespaced(
        self: Self,
        api_path: []const u8,
        resource: []const u8,
        name: []const u8,
        namespace: []const u8,
        resource_json: []const u8,
        options: ApplyOptions,
    ) ![]const u8 {
        return self.apply(api_path, resource, name, namespace, resource_json, options);
    }

    /// Apply a cluster-scoped resource
    pub fn applyCluster(
        self: Self,
        api_path: []const u8,
        resource: []const u8,
        name: []const u8,
        resource_json: []const u8,
        options: ApplyOptions,
    ) ![]const u8 {
        return self.apply(api_path, resource, name, null, resource_json, options);
    }
};

/// Strategic merge patch builder
pub const StrategicMergePatch = struct {
    allocator: std.mem.Allocator,
    patches: std.StringHashMap(std.json.Value),

    pub fn init(allocator: std.mem.Allocator) StrategicMergePatch {
        return .{
            .allocator = allocator,
            .patches = std.StringHashMap(std.json.Value).init(allocator),
        };
    }

    pub fn deinit(self: *StrategicMergePatch) void {
        self.patches.deinit();
    }

    /// Add a patch for a specific path
    pub fn addPatch(self: *StrategicMergePatch, path: []const u8, value: std.json.Value) !void {
        try self.patches.put(path, value);
    }

    /// Build the patch JSON
    pub fn build(self: *StrategicMergePatch) ![]const u8 {
        var result = std.ArrayList(u8).init(self.allocator);
        defer result.deinit();

        try std.json.stringify(self.patches, .{}, result.writer());

        return try result.toOwnedSlice();
    }
};

/// JSON Patch (RFC 6902) builder
pub const JsonPatch = struct {
    allocator: std.mem.Allocator,
    operations: std.ArrayList(Operation),

    pub const Operation = struct {
        op: []const u8, // "add", "remove", "replace", "move", "copy", "test"
        path: []const u8,
        value: ?std.json.Value = null,
        from: ?[]const u8 = null, // For "move" and "copy" operations
    };

    pub fn init(allocator: std.mem.Allocator) JsonPatch {
        return .{
            .allocator = allocator,
            .operations = std.ArrayList(Operation).init(allocator),
        };
    }

    pub fn deinit(self: *JsonPatch) void {
        self.operations.deinit();
    }

    /// Add an "add" operation
    pub fn add(self: *JsonPatch, path: []const u8, value: std.json.Value) !void {
        try self.operations.append(.{
            .op = "add",
            .path = path,
            .value = value,
        });
    }

    /// Add a "remove" operation
    pub fn remove(self: *JsonPatch, path: []const u8) !void {
        try self.operations.append(.{
            .op = "remove",
            .path = path,
        });
    }

    /// Add a "replace" operation
    pub fn replace(self: *JsonPatch, path: []const u8, value: std.json.Value) !void {
        try self.operations.append(.{
            .op = "replace",
            .path = path,
            .value = value,
        });
    }

    /// Add a "test" operation
    pub fn test_(self: *JsonPatch, path: []const u8, value: std.json.Value) !void {
        try self.operations.append(.{
            .op = "test",
            .path = path,
            .value = value,
        });
    }

    /// Add a "move" operation
    pub fn move(self: *JsonPatch, from: []const u8, path: []const u8) !void {
        try self.operations.append(.{
            .op = "move",
            .path = path,
            .from = from,
        });
    }

    /// Add a "copy" operation
    pub fn copy(self: *JsonPatch, from: []const u8, path: []const u8) !void {
        try self.operations.append(.{
            .op = "copy",
            .path = path,
            .from = from,
        });
    }

    /// Build the patch JSON
    pub fn build(self: *JsonPatch) ![]const u8 {
        var result = std.ArrayList(u8).init(self.allocator);
        defer result.deinit();

        try std.json.stringify(self.operations.items, .{}, result.writer());

        return try result.toOwnedSlice();
    }
};
