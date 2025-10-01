const std = @import("std");

/// Options for delete operations
pub const DeleteOptions = struct {
    /// Grace period in seconds before the object is deleted
    /// 0 means delete immediately
    grace_period_seconds: ?i64 = null,

    /// Whether to cascade delete dependent objects
    /// Options: "Orphan", "Background", "Foreground"
    propagation_policy: ?[]const u8 = null,

    /// Dry run mode
    /// Options: "All" (all dry run stages)
    dry_run: ?[]const u8 = null,

    /// Preconditions for deletion (resource version, UID)
    preconditions: ?Preconditions = null,

    pub const Preconditions = struct {
        /// Expected resource version
        resource_version: ?[]const u8 = null,

        /// Expected UID
        uid: ?[]const u8 = null,
    };

    /// Build query string from options
    pub fn buildQueryString(self: DeleteOptions, allocator: std.mem.Allocator) ![]const u8 {
        var query_parts = std.ArrayList([]const u8).init(allocator);
        defer {
            for (query_parts.items) |part| {
                allocator.free(part);
            }
            query_parts.deinit();
        }

        // Grace period
        if (self.grace_period_seconds) |grace| {
            const part = try std.fmt.allocPrint(allocator, "gracePeriodSeconds={d}", .{grace});
            try query_parts.append(part);
        }

        // Propagation policy
        if (self.propagation_policy) |policy| {
            const part = try std.fmt.allocPrint(allocator, "propagationPolicy={s}", .{policy});
            try query_parts.append(part);
        }

        // Dry run
        if (self.dry_run) |dr| {
            const part = try std.fmt.allocPrint(allocator, "dryRun={s}", .{dr});
            try query_parts.append(part);
        }

        if (query_parts.items.len == 0) {
            return try allocator.dupe(u8, "");
        }

        return try std.mem.join(allocator, "&", query_parts.items);
    }

    /// Build delete options body (for POST to deletecollection)
    pub fn buildBody(self: DeleteOptions, allocator: std.mem.Allocator) ![]const u8 {
        var json_obj = std.StringHashMap(std.json.Value).init(allocator);
        defer json_obj.deinit();

        try json_obj.put("apiVersion", .{ .string = "v1" });
        try json_obj.put("kind", .{ .string = "DeleteOptions" });

        if (self.grace_period_seconds) |grace| {
            try json_obj.put("gracePeriodSeconds", .{ .integer = grace });
        }

        if (self.propagation_policy) |policy| {
            try json_obj.put("propagationPolicy", .{ .string = policy });
        }

        if (self.preconditions) |precond| {
            var precond_map = std.StringHashMap(std.json.Value).init(allocator);
            defer precond_map.deinit();

            if (precond.resource_version) |rv| {
                try precond_map.put("resourceVersion", .{ .string = rv });
            }
            if (precond.uid) |uid| {
                try precond_map.put("uid", .{ .string = uid });
            }

            try json_obj.put("preconditions", .{ .object = precond_map });
        }

        var result = std.ArrayList(u8).init(allocator);
        defer result.deinit();

        try std.json.stringify(json_obj, .{}, result.writer());

        return try result.toOwnedSlice();
    }
};

/// Options for create operations
pub const CreateOptions = struct {
    /// Field manager for tracking field ownership
    field_manager: ?[]const u8 = null,

    /// Field validation level
    /// Options: "Strict", "Warn", "Ignore"
    field_validation: ?[]const u8 = null,

    /// Dry run mode
    dry_run: ?[]const u8 = null,

    /// Pretty print output
    pretty: bool = false,

    /// Build query string from options
    pub fn buildQueryString(self: CreateOptions, allocator: std.mem.Allocator) ![]const u8 {
        var query_parts = std.ArrayList([]const u8).init(allocator);
        defer {
            for (query_parts.items) |part| {
                allocator.free(part);
            }
            query_parts.deinit();
        }

        if (self.field_manager) |fm| {
            const part = try std.fmt.allocPrint(allocator, "fieldManager={s}", .{fm});
            try query_parts.append(part);
        }

        if (self.field_validation) |fv| {
            const part = try std.fmt.allocPrint(allocator, "fieldValidation={s}", .{fv});
            try query_parts.append(part);
        }

        if (self.dry_run) |dr| {
            const part = try std.fmt.allocPrint(allocator, "dryRun={s}", .{dr});
            try query_parts.append(part);
        }

        if (self.pretty) {
            const part = try std.fmt.allocPrint(allocator, "pretty=true", .{});
            try query_parts.append(part);
        }

        if (query_parts.items.len == 0) {
            return try allocator.dupe(u8, "");
        }

        return try std.mem.join(allocator, "&", query_parts.items);
    }
};

/// Options for update operations
pub const UpdateOptions = struct {
    /// Field manager for tracking field ownership
    field_manager: ?[]const u8 = null,

    /// Field validation level
    field_validation: ?[]const u8 = null,

    /// Dry run mode
    dry_run: ?[]const u8 = null,

    /// Pretty print output
    pretty: bool = false,

    /// Build query string from options
    pub fn buildQueryString(self: UpdateOptions, allocator: std.mem.Allocator) ![]const u8 {
        var query_parts = std.ArrayList([]const u8).init(allocator);
        defer {
            for (query_parts.items) |part| {
                allocator.free(part);
            }
            query_parts.deinit();
        }

        if (self.field_manager) |fm| {
            const part = try std.fmt.allocPrint(allocator, "fieldManager={s}", .{fm});
            try query_parts.append(part);
        }

        if (self.field_validation) |fv| {
            const part = try std.fmt.allocPrint(allocator, "fieldValidation={s}", .{fv});
            try query_parts.append(part);
        }

        if (self.dry_run) |dr| {
            const part = try std.fmt.allocPrint(allocator, "dryRun={s}", .{dr});
            try query_parts.append(part);
        }

        if (self.pretty) {
            const part = try std.fmt.allocPrint(allocator, "pretty=true", .{});
            try query_parts.append(part);
        }

        if (query_parts.items.len == 0) {
            return try allocator.dupe(u8, "");
        }

        return try std.mem.join(allocator, "&", query_parts.items);
    }
};

/// Propagation policies for cascading deletes
pub const PropagationPolicy = enum {
    /// Delete the object immediately, leave dependents orphaned
    orphan,

    /// Delete in the background, controller deletes dependents
    background,

    /// Delete in the foreground, wait for dependents first
    foreground,

    pub fn toString(self: PropagationPolicy) []const u8 {
        return switch (self) {
            .orphan => "Orphan",
            .background => "Background",
            .foreground => "Foreground",
        };
    }
};

/// Field validation levels
pub const FieldValidation = enum {
    /// Strict validation, reject on unknown fields
    strict,

    /// Warn on unknown fields but accept
    warn,

    /// Ignore unknown fields
    ignore,

    pub fn toString(self: FieldValidation) []const u8 {
        return switch (self) {
            .strict => "Strict",
            .warn => "Warn",
            .ignore => "Ignore",
        };
    }
};
