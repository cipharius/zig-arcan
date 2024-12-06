const std = @import("std");

const a12_version = std.SemanticVersion{
    .major = 0,
    .minor = 1,
    .patch = 0,
};
const shmif_version = std.SemanticVersion{
    .major = 0,
    .minor = 16,
    .patch = 0,
};

const flags = [_][]const u8{"-latomic"};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const static_build = b.option(bool, "static", "Build static libraries (default: true)") orelse true;
    const with_debugif = b.option(bool, "with_debugif", "Build with shmif debugif (default: false)") orelse false;

    const arcan_src = b.dependency("arcan_src", .{});
    const platform_header_path = arcan_src.path("./src/platform/platform.h").getPath(b);
    const platform_header = b.fmt("\"{s}\"", .{platform_header_path});

    const arcan_raw_api = b.addTranslateC(.{
        .root_source_file = b.path("src/c_api.h"),
        .target = target,
        .optimize = optimize,
    });
    arcan_raw_api.defineCMacroRaw(b.fmt("PLATFORM_HEADER={s}", .{platform_header}));
    inline for (shmif_include_paths) |dir| {
        arcan_raw_api.addIncludeDir(arcan_src.path(dir).getPath(b));
    }
    inline for (a12_include_paths) |dir| {
        arcan_raw_api.addIncludeDir(arcan_src.path(dir).getPath(b));
    }
    inline for (shmif_tui_include_paths) |dir| {
        arcan_raw_api.addIncludeDir(arcan_src.path(dir).getPath(b));
    }
    const arcan_raw_module = arcan_raw_api.addModule("arcan_raw");

    const arcan_shmif_server = if (static_build)
        b.addStaticLibrary(.{
            .name = "arcan_shmif_server",
            .version = shmif_version,
            .target = target,
            .optimize = optimize,
            .pic = true,
        })
    else
        b.addSharedLibrary(.{
            .name = "arcan_shmif_server",
            .version = shmif_version,
            .target = target,
            .optimize = optimize,
            .pic = true,
        });
    setupShmifServerStep(arcan_shmif_server, arcan_src);
    arcan_shmif_server.root_module.addCMacro("PLATFORM_HEADER", platform_header);
    b.installArtifact(arcan_shmif_server);

    const arcan_shmif = if (static_build)
        b.addStaticLibrary(.{
            .name = "arcan_shmif",
            .version = shmif_version,
            .target = target,
            .optimize = optimize,
            .pic = true,
        })
    else
        b.addSharedLibrary(.{
            .name = "arcan_shmif",
            .version = shmif_version,
            .target = target,
            .optimize = optimize,
            .pic = true,
        });
    setupShmifStep(arcan_shmif, arcan_src);
    arcan_shmif.linkLibrary(arcan_shmif_server);
    arcan_shmif.root_module.addCMacro("PLATFORM_HEADER", platform_header);
    if (with_debugif) {
        arcan_shmif.addCSourceFile(.{
            .file = arcan_src.path("src/shmif/arcan_shmif_debugif.c"),
            .flags = &flags,
        });
        arcan_shmif.root_module.addCMacro("SHMIF_DEBUG_IF", "");
    }
    b.installArtifact(arcan_shmif);

    const arcan_a12 = if (static_build)
        b.addStaticLibrary(.{
            .name = "arcan_a12",
            .version = a12_version,
            .target = target,
            .optimize = optimize,
            .pic = true,
        })
    else
        b.addSharedLibrary(.{
            .name = "arcan_a12",
            .version = a12_version,
            .target = target,
            .optimize = optimize,
            .pic = true,
        });
    setupA12Step(arcan_a12, arcan_src);
    arcan_a12.linkLibrary(arcan_shmif);
    arcan_a12.linkLibrary(arcan_shmif_server);
    arcan_a12.root_module.addCMacro("PLATFORM_HEADER", platform_header);
    b.installArtifact(arcan_a12);

    const arcan_tui = if (static_build)
        b.addStaticLibrary(.{
            .name = "arcan_tui",
            .version = shmif_version,
            .target = target,
            .optimize = optimize,
            .pic = true,
        })
    else
        b.addSharedLibrary(.{
            .name = "arcan_tui",
            .version = shmif_version,
            .target = target,
            .optimize = optimize,
            .pic = true,
        });
    setupShmifTuiStep(arcan_tui, arcan_src);
    arcan_tui.linkLibrary(arcan_shmif);
    arcan_tui.root_module.addCMacro("PLATFORM_HEADER", platform_header);
    b.installArtifact(arcan_tui);

}

const shmif_sources = [_][]const u8{
    "src/shmif/arcan_shmif_control.c",
    "src/shmif/arcan_shmif_sub.c",
    "src/shmif/arcan_shmif_evpack.c",
    "src/shmif/arcan_shmif_a11y.c",
    "src/engine/arcan_trace.c",
    "src/shmif/platform/exec.c",
};
const shmif_include_paths = [_][]const u8{
    "src/shmif",
    "src/shmif/tui",
    "src/shmif/tui/lua",
    "src/shmif/tui/widgets",
    "src/shmif/platform",
    "src/engine",
    "src/platform",
};
const shmif_headers = [_][2][]const u8{
    .{ "src/shmif/arcan_shmif_control.h", "arcan_shmif_control.h" },
    .{ "src/shmif/arcan_shmif_interop.h", "arcan_shmif_interop.h" },
    .{ "src/shmif/arcan_shmif_event.h", "arcan_shmif_event.h" },
    .{ "src/shmif/arcan_shmif_server.h", "arcan_shmif_server.h" },
    .{ "src/shmif/arcan_shmif_sub.h", "arcan_shmif_sub.h" },
    .{ "src/shmif/arcan_shmif_defs.h", "arcan_shmif_defs.h" },
    .{ "src/shmif/arcan_shmif.h", "arcan_shmif.h" },
};

fn setupShmifStep(step: *std.Build.Step.Compile, arcan_src: *std.Build.Dependency) void {
    step.linkLibC();

    inline for (shmif_sources) |source| {
        step.addCSourceFile(.{
            .file = arcan_src.path(source),
            .flags = &flags,
        });
    }

    inline for (shmif_include_paths) |dir| {
        step.addIncludePath(arcan_src.path(dir));
    }

    inline for (shmif_headers) |header| {
        step.installHeader(
            arcan_src.path(header[0]),
            header[1],
        );
    }

    addShmifPlatformSources(step, arcan_src);
    addPlatformDefinitions(step);
}

const shmif_server_sources = [_][]const u8{
    "src/shmif/arcan_shmif_server.c",
    "src/platform/posix/frameserver.c",
    "src/shmif/arcan_shmif_control.c",
    "src/platform/posix/fsrv_guard.c",
    "src/platform/posix/mem.c",
    "src/shmif/arcan_shmif_evpack.c",
    "src/shmif/platform/exec.c",
};

fn setupShmifServerStep(step: *std.Build.Step.Compile, arcan_src: *std.Build.Dependency) void {
    step.linkLibC();

    inline for (shmif_server_sources) |source| {
        step.addCSourceFile(.{
            .file = arcan_src.path(source),
            .flags = &.{},
        });
    }

    inline for (shmif_include_paths) |dir| {
        step.addIncludePath(arcan_src.path(dir));
    }

    inline for (shmif_headers) |header| {
        step.installHeader(
            arcan_src.path(header[0]),
            header[1],
        );
    }

    addShmifPlatformSources(step, arcan_src);
    addPlatformDefinitions(step);
}

const a12_sources = [_][]const u8{
    "src/a12/a12.c",
    "src/a12/a12_decode.c",
    "src/a12/a12_encode.c",
    "src/platform/posix/mem.c",
    "src/platform/posix/base64.c",
    "src/platform/posix/random.c",
};
const a12_external_sources = [_][]const u8{
    "src/a12/external/blake3/blake3.c",
    "src/a12/external/blake3/blake3_dispatch.c",
    "src/a12/external/blake3/blake3_portable.c",
    "src/a12/external/x25519.c",
    "src/a12/external/fts.c",

    "src/a12/external/zstd/common/debug.c",
    "src/a12/external/zstd/common/entropy_common.c",
    "src/a12/external/zstd/common/error_private.c",
    "src/a12/external/zstd/common/fse_decompress.c",
    "src/a12/external/zstd/common/pool.c",
    "src/a12/external/zstd/common/threading.c",
    "src/a12/external/zstd/common/xxhash.c",
    "src/a12/external/zstd/common/zstd_common.c",
    "src/a12/external/zstd/compress/fse_compress.c",
    "src/a12/external/zstd/compress/hist.c",
    "src/a12/external/zstd/compress/huf_compress.c",
    "src/a12/external/zstd/compress/zstd_compress.c",
    "src/a12/external/zstd/compress/zstd_compress_literals.c",
    "src/a12/external/zstd/compress/zstd_compress_sequences.c",
    "src/a12/external/zstd/compress/zstd_compress_superblock.c",
    "src/a12/external/zstd/compress/zstd_double_fast.c",
    "src/a12/external/zstd/compress/zstd_fast.c",
    "src/a12/external/zstd/compress/zstd_lazy.c",
    "src/a12/external/zstd/compress/zstd_ldm.c",
    "src/a12/external/zstd/compress/zstd_opt.c",
    "src/a12/external/zstd/compress/zstdmt_compress.c",
    "src/a12/external/zstd/decompress/huf_decompress.c",
    "src/a12/external/zstd/decompress/zstd_ddict.c",
    "src/a12/external/zstd/decompress/zstd_decompress.c",
    "src/a12/external/zstd/decompress/zstd_decompress_block.c",
};
const a12_include_paths = [_][]const u8{
    "src/a12",
    "src/a12/external/blake3",
    "src/a12/external/zstd",
    "src/a12/external/zstd/common",
    "src/a12/external",
    "src/engine",
    "src/shmif",
};
const a12_headers = [_][2][]const u8{
    .{ "src/a12/a12.h", "a12.h" },
    .{ "src/a12/pack.h", "pack.h" },
    .{ "src/a12/a12_decode.h", "a12_decode.h" },
    .{ "src/a12/a12_encode.h", "a12_encode.h" },
};
const a12_definitions = [_][2][]const u8{
    .{ "BLAKE3_NO_AVX2", "" },
    .{ "BLAKE3_NO_AVX512", "" },
    .{ "BLAKE3_NO_SSE41", "" },
    .{ "ZSTD_MULTITHREAD", "" },
    .{ "ZSTD_DISABLE_ASM", "" },
};

fn setupA12Step(step: *std.Build.Step.Compile, arcan_src: *std.Build.Dependency) void {
    step.linkLibC();

    inline for (a12_sources) |source| {
        step.addCSourceFile(.{
            .file = arcan_src.path(source),
            .flags = &.{"-fPIC"},
        });
    }

    inline for (a12_external_sources) |source| {
        step.addCSourceFile(.{
            .file = arcan_src.path(source),
            .flags = &.{"-fPIC"},
        });
    }

    inline for (a12_include_paths) |path| {
        step.addIncludePath(arcan_src.path(path));
    }

    inline for (a12_headers) |header| {
        step.installHeader(arcan_src.path(header[0]), header[1]);
    }

    inline for (a12_definitions) |definition| {
        step.root_module.addCMacro(definition[0], definition[1]);
    }

    addPlatformDefinitions(step);
}

const shmif_tui_sources = [_][]const u8{
    "src/shmif/tui/tui.c",
    "src/shmif/tui/core/clipboard.c",
    "src/shmif/tui/core/input.c",
    "src/shmif/tui/core/setup.c",
    "src/shmif/tui/core/screen.c",
    "src/shmif/tui/core/dispatch.c",
    "src/shmif/tui/raster/pixelfont.c",
    "src/shmif/tui/raster/raster.c",
    "src/shmif/tui/raster/fontmgmt.c",
    "src/shmif/tui/widgets/bufferwnd.c",
    "src/shmif/tui/widgets/listwnd.c",
    "src/shmif/tui/widgets/linewnd.c",
    "src/shmif/tui/widgets/readline.c",
    "src/shmif/tui/widgets/copywnd.c",
};
const shmif_tui_include_paths = [_][]const u8{
    "src/frameserver",
    "src/engine",
    "src/engine/external",
    "src/shmif",
};
const shmif_tui_headers = [_][2][]const u8{
    .{ "src/shmif/arcan_tui.h", "arcan_tui.h" },
    .{ "src/shmif/arcan_tuidefs.h", "arcan_tuidefs.h" },
    .{ "src/shmif/arcan_tuisym.h", "arcan_tuisym.h" },
};

fn setupShmifTuiStep(step: *std.Build.Step.Compile, arcan_src: *std.Build.Dependency) void {
    step.linkLibC();

    inline for (shmif_tui_sources) |source| {
        step.addCSourceFile(.{
            .file = arcan_src.path(source),
            .flags = &flags,
        });
    }

    // Only support TUI_RASTER_NO_TTF for now
    step.addCSourceFile(.{
        .file = arcan_src.path("src/shmif/tui/raster/ttfstub.c"),
        .flags = &flags,
    });

    inline for (shmif_tui_include_paths) |path| {
        step.addIncludePath(arcan_src.path(path));
    }

    inline for (shmif_tui_headers) |header| {
        step.installHeader(
            arcan_src.path(header[0]),
            header[1],
        );
    }

    step.root_module.addCMacro("NO_ARCAN_AGP", "");
    step.root_module.addCMacro("SHMIF_TTF", "");
}

const shmif_platform_sources = [_][]const u8{
    "src/platform/posix/shmemop.c",
    "src/platform/posix/warning.c",
    "src/platform/posix/random.c",
    "src/platform/posix/fdscan.c",
};
const shmif_platform_posix_sources = [_][]const u8{
    "src/platform/posix/time.c",
    "src/platform/posix/sem.c",
};
const shmif_platform_darwin_sources = [_][]const u8{
    "src/platform/darwin/time.c",
    "src/platform/darwin/sem.c",
};

fn addShmifPlatformSources(
    lib: *std.Build.Step.Compile,
    arcan_src: *std.Build.Dependency,
) void {
    inline for (shmif_platform_sources) |source| {
        lib.addCSourceFile(.{
            .file = arcan_src.path(source),
            .flags = &flags,
        });
    }
    lib.addCSourceFile(.{
        .file = arcan_src.path("src/platform/posix/fdpassing.c"),
        .flags = &.{ "-fPIC", "-w", "-DNONBLOCK_RECV" },
    });

    const target = lib.root_module.resolved_target orelse
        @panic("Unresolved library target");

    switch (target.result.os.tag) {
        .linux, .freebsd, .openbsd, .dragonfly, .kfreebsd, .netbsd => {
            inline for (shmif_platform_posix_sources) |source| {
                lib.addCSourceFile(.{
                    .file = arcan_src.path(source),
                    .flags = &flags,
                });
            }
        },
        .ios, .macos, .watchos, .tvos => {
            inline for (shmif_platform_darwin_sources) |source| {
                lib.addCSourceFile(.{
                    .file = arcan_src.path(source),
                    .flags = &flags,
                });
            }
        },
        else => @panic("attempted to build arcan-shmif on an unsupported OS/platform"),
    }
}

const darwin_platform_definitions = [_][2][]const u8{
    .{ "__UNIX", "" },
    .{ "POSIX_C_SOURCE", "" },
    .{ "__APPLE__", "" },
    .{ "ARCAN_SHMIF_OVERCOMMIT", "" },
    .{ "_WITH_DPRINTF", "" },
    .{ "_GNU_SOURCE", "" },
};
const linux_platform_definitions = [_][2][]const u8{
    .{ "__UNIX", "" },
    .{ "__LINUX", "" },
    .{ "POSIX_C_SOURCE", "" },
    .{ "_GNU_SOURCE", "" },
};
const bsd_platform_definitions = [_][2][]const u8{
    .{ "PLATFORM_HEADER", "\"\"" },
    .{ "_WITH_GETLINE", "" },
    .{ "__UNIX", "" },
    .{ "__BSD", "" },
    .{ "LIBUSB_BSD", "" },
};

fn addPlatformDefinitions(step: *std.Build.Step.Compile) void {
    const target = step.root_module.resolved_target orelse
        @panic("Unresolved library target");

    const platform_definitions: []const [2][]const u8 = switch (target.result.os.tag) {
        .linux => &linux_platform_definitions,
        .ios, .macos, .watchos, .tvos => &darwin_platform_definitions,
        .freebsd => &(bsd_platform_definitions ++ .{.{ "__FreeBSD__", "" }}),
        .dragonfly => &(bsd_platform_definitions ++ .{.{ "__DragonFly__", "" }}),
        .kfreebsd => &(bsd_platform_definitions ++ .{.{ "__kFreeBSD__", "" }}),
        .openbsd => &(bsd_platform_definitions ++ .{
            .{ "__OpenBSD__", "" },
            .{ "CLOCK_MONOTONIC_RAW", "CLOCK_MONOTONIC" },
        }),
        .netbsd => &(bsd_platform_definitions ++ .{
            .{ "__NetBSD__", "" },
            .{ "CLOCK_MONOTONIC_RAW", "CLOCK_MONOTONIC" },
        }),
        else => &(.{}),
    };

    for (platform_definitions) |def| {
        step.root_module.addCMacro(def[0], def[1]);
    }
}
