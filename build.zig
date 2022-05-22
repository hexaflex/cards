const std = @import("std");
const Builder = std.build.Builder;
const LibExeObjStep = std.build.LibExeObjStep;

pub fn build(b: *Builder) !void {
    const mode = b.standardReleaseOptions();

    const lib_cmd = b.addStaticLibrary("cards", thisDir() ++ "/src/main.zig");
    lib_cmd.setBuildMode(mode);
    lib_cmd.install();
    link(lib_cmd);

    const test_cmd = b.addTest(thisDir() ++ "/src/main.zig");
    test_cmd.setBuildMode(mode);
    link(test_cmd);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&test_cmd.step);
}

pub fn link(step: *LibExeObjStep) void {
    step.addPackage(pkg);
}

const pkg = std.build.Pkg{
    .name = "cards",
    .path = .{ .path = thisDir() ++ "/src/main.zig" },
};

fn thisDir() []const u8 {
    return std.fs.path.dirname(@src().file) orelse ".";
}
