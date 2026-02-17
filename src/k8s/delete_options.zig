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

    /// Build query string from options (single allocation)
    pub fn buildQueryString(self: DeleteOptions, allocator: std.mem.Allocator) ![]const u8 {
        var buf = try std.ArrayList(u8).initCapacity(allocator, 0);
        errdefer buf.deinit(allocator);
        const writer = buf.writer(allocator);

        var first = true;
        if (self.grace_period_seconds) |grace| {
            try writer.print("gracePeriodSeconds={d}", .{grace});
            first = false;
        }

        if (self.propagation_policy) |policy| {
            if (!first) try writer.writeByte('&');
            try writer.print("propagationPolicy={s}", .{policy});
            first = false;
        }

        if (self.dry_run) |dr| {
            if (!first) try writer.writeByte('&');
            try writer.print("dryRun={s}", .{dr});
        }

        return try buf.toOwnedSlice(allocator);
    }

    /// Build delete options body (for POST to deletecollection)
    pub fn buildBody(self: DeleteOptions, allocator: std.mem.Allocator) ![]const u8 {
        var buffer = try std.ArrayList(u8).initCapacity(allocator, 256);
        errdefer buffer.deinit(allocator);
        const writer = buffer.writer(allocator);

        try writer.writeAll("{\"apiVersion\":\"v1\",\"kind\":\"DeleteOptions\"");

        if (self.grace_period_seconds) |grace| {
            try writer.print(",\"gracePeriodSeconds\":{d}", .{grace});
        }

        if (self.propagation_policy) |policy| {
            try writer.print(",\"propagationPolicy\":\"{s}\"", .{policy});
        }

        if (self.preconditions) |precond| {
            try writer.writeAll(",\"preconditions\":{");
            var first = true;
            if (precond.resource_version) |rv| {
                try writer.print("\"resourceVersion\":\"{s}\"", .{rv});
                first = false;
            }
            if (precond.uid) |uid| {
                if (!first) try writer.writeByte(',');
                try writer.print("\"uid\":\"{s}\"", .{uid});
            }
            try writer.writeByte('}');
        }

        try writer.writeByte('}');

        return try buffer.toOwnedSlice(allocator);
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

    /// Build query string from options (single allocation)
    pub fn buildQueryString(self: CreateOptions, allocator: std.mem.Allocator) ![]const u8 {
        var buf = try std.ArrayList(u8).initCapacity(allocator, 0);
        errdefer buf.deinit(allocator);
        const writer = buf.writer(allocator);

        var first = true;
        inline for (.{
            .{ "fieldManager", self.field_manager },
            .{ "fieldValidation", self.field_validation },
            .{ "dryRun", self.dry_run },
        }) |entry| {
            if (entry[1]) |val| {
                if (!first) try writer.writeByte('&');
                try writer.print("{s}={s}", .{ entry[0], val });
                first = false;
            }
        }

        if (self.pretty) {
            if (!first) try writer.writeByte('&');
            try writer.writeAll("pretty=true");
        }

        return try buf.toOwnedSlice(allocator);
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

    /// Build query string from options (single allocation)
    pub fn buildQueryString(self: UpdateOptions, allocator: std.mem.Allocator) ![]const u8 {
        var buf = try std.ArrayList(u8).initCapacity(allocator, 0);
        errdefer buf.deinit(allocator);
        const writer = buf.writer(allocator);

        var first = true;
        inline for (.{
            .{ "fieldManager", self.field_manager },
            .{ "fieldValidation", self.field_validation },
            .{ "dryRun", self.dry_run },
        }) |entry| {
            if (entry[1]) |val| {
                if (!first) try writer.writeByte('&');
                try writer.print("{s}={s}", .{ entry[0], val });
                first = false;
            }
        }

        if (self.pretty) {
            if (!first) try writer.writeByte('&');
            try writer.writeAll("pretty=true");
        }

        return try buf.toOwnedSlice(allocator);
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
