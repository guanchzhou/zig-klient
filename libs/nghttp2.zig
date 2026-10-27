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
        .name = "nghttp2",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    const m = lib.root_module;
    inline for (srcs) |s| {
        m.addCSourceFile(.{ .file = src.path("lib/" ++ s), .flags = &.{"-std=gnu99"} });
    }
    m.addIncludePath(src.path("lib"));
    m.addIncludePath(src.path("lib/includes"));
    m.addCMacro("BUILDING_NGHTTP2", "1");
    m.addCMacro("NGHTTP2_STATICLIB", "1");
    m.addCMacro("HAVE_ARPA_INET_H", "1");
    m.addCMacro("HAVE_NETINET_IN_H", "1");
    m.addCMacro("HAVE_CLOCK_GETTIME", "1");
    m.addCMacro("HAVE_DECL_CLOCK_MONOTONIC", "1");
    lib.installHeadersDirectory(src.path("lib/includes/nghttp2"), "nghttp2", .{
        .include_extensions = &.{".h"},
    });
    return lib;
}

const srcs = &.{
    "nghttp2_alpn.c",    "nghttp2_buf.c",           "nghttp2_callbacks.c",
    "nghttp2_debug.c",   "nghttp2_extpri.c",        "nghttp2_frame.c",
    "nghttp2_hd.c",      "nghttp2_hd_huffman.c",    "nghttp2_hd_huffman_data.c",
    "nghttp2_helper.c",  "nghttp2_http.c",          "nghttp2_map.c",
    "nghttp2_mem.c",     "nghttp2_option.c",        "nghttp2_outbound_item.c",
    "nghttp2_pq.c",      "nghttp2_priority_spec.c", "nghttp2_queue.c",
    "nghttp2_ratelim.c", "nghttp2_rcbuf.c",         "nghttp2_session.c",
    "nghttp2_stream.c",  "nghttp2_submit.c",        "nghttp2_time.c",
    "nghttp2_version.c", "sfparse.c",
};

const Source = struct {
    b: *std.Build,
    dep: *std.Build.Dependency,
    root: []const u8,

    fn path(self: Source, sub: []const u8) std.Build.LazyPath {
        return self.dep.path(self.b.pathJoin(&.{ self.root, sub }));
    }
};
