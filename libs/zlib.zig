const std = @import("std");

pub fn create(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    dep: *std.Build.Dependency,
    root: []const u8,
) *std.Build.Step.Compile {
    const src = Source{ .b = b, .dep = dep, .root = root };
    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "z",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    inline for (srcs) |s| {
        lib.root_module.addCSourceFile(.{ .file = src.path(s), .flags = &.{"-std=c89"} });
    }
    lib.installHeader(src.path("zlib.h"), "zlib.h");
    lib.installHeader(src.path("zconf.h"), "zconf.h");
    return lib;
}

const srcs = &.{
    "adler32.c", "compress.c", "crc32.c",   "deflate.c", "gzclose.c",
    "gzlib.c",   "gzread.c",   "gzwrite.c", "infback.c", "inffast.c",
    "inflate.c", "inftrees.c", "trees.c",   "uncompr.c", "zutil.c",
};

const Source = struct {
    b: *std.Build,
    dep: *std.Build.Dependency,
    root: []const u8,

    fn path(self: Source, sub: []const u8) std.Build.LazyPath {
        return self.dep.path(self.b.pathJoin(&.{ self.root, sub }));
    }
};
