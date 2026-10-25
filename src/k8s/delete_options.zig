const std = @import("std");
const QueryWriter = @import("query.zig").QueryWriter;

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
        var qw = try QueryWriter.init(allocator);
        errdefer qw.deinit();

        try qw.addOptionalInt("gracePeriodSeconds", self.grace_period_seconds);
        try qw.addOptionalString("propagationPolicy", self.propagation_policy);
        try qw.addOptionalString("dryRun", self.dry_run);

        return try qw.toOwnedSlice();
    }

    /// Build delete options body (for POST to deletecollection)
    pub fn buildBody(self: DeleteOptions, allocator: std.mem.Allocator) ![]const u8 {
        const Body = struct {
            apiVersion: []const u8 = "v1",
            kind: []const u8 = "DeleteOptions",
            gracePeriodSeconds: ?i64 = null,
            propagationPolicy: ?[]const u8 = null,
            preconditions: ?struct {
                resourceVersion: ?[]const u8 = null,
                uid: ?[]const u8 = null,
            } = null,
        };
        const body: Body = .{
            .gracePeriodSeconds = self.grace_period_seconds,
            .propagationPolicy = self.propagation_policy,
            .preconditions = if (self.preconditions) |precond| .{
                .resourceVersion = precond.resource_version,
                .uid = precond.uid,
            } else null,
        };
        return std.json.Stringify.valueAlloc(allocator, body, .{ .emit_null_optional_fields = false });
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
        var qw = try QueryWriter.init(allocator);
        errdefer qw.deinit();

        try qw.addOptionalString("fieldManager", self.field_manager);
        try qw.addOptionalString("fieldValidation", self.field_validation);
        try qw.addOptionalString("dryRun", self.dry_run);
        try qw.addBoolFlag("pretty", self.pretty);

        return try qw.toOwnedSlice();
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
        var qw = try QueryWriter.init(allocator);
        errdefer qw.deinit();

        try qw.addOptionalString("fieldManager", self.field_manager);
        try qw.addOptionalString("fieldValidation", self.field_validation);
        try qw.addOptionalString("dryRun", self.dry_run);
        try qw.addBoolFlag("pretty", self.pretty);

        return try qw.toOwnedSlice();
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
