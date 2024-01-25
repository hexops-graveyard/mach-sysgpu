const std = @import("std");
const ErrorList = @import("ErrorList.zig");
const Ast = @import("Ast.zig");
const Air = @import("Air.zig");
const CodeGen = @import("CodeGen.zig");
const printAir = @import("print_air.zig").printAir;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const allocator = std.testing.allocator;

test "boids-sprite" {
    const boids_sprite = @embedFile("test/boids-sprite.wgsl");
    try expectCodegen(boids_sprite, "boids-sprite.spv", &.{}, .spirv);
    try expectCodegen(boids_sprite, "boids-sprite.hlsl", &.{}, .hlsl);
    try expectCodegen(boids_sprite, "boids-sprite.msl", &.{
        .{ .stage = .fragment, .name = "frag_main" },
        .{ .stage = .vertex, .name = "vert_main" },
    }, .msl);
}

test "boids-sprite-update" {
    const boids_sprite_update = @embedFile("test/boids-sprite-update.wgsl");
    try expectCodegen(boids_sprite_update, "boids-sprite-update.spv", &.{}, .spirv);
    try expectCodegen(boids_sprite_update, "boids-sprite-update.hlsl", &.{}, .hlsl);
    try expectCodegen(boids_sprite_update, "boids-sprite-update.msl", &.{
        .{ .stage = .compute, .name = "main" },
    }, .msl);
}

test "cube-map" {
    const cube_map = @embedFile("test/cube-map.wgsl");
    try expectCodegen(cube_map, "cube-map.spv", &.{}, .spirv);
    try expectCodegen(cube_map, "cube-map.hlsl", &.{}, .hlsl);
    try expectCodegen(cube_map, "cube-map.msl", &.{
        .{ .stage = .vertex, .name = "vertex_main" },
        .{ .stage = .fragment, .name = "frag_main" },
    }, .msl);
}

test "fractal-cube" {
    const fractal_cube = @embedFile("test/fractal-cube.wgsl");
    try expectCodegen(fractal_cube, "fractal-cube.spv", &.{}, .spirv);
    try expectCodegen(fractal_cube, "fractal-cube.hlsl", &.{}, .hlsl);
    try expectCodegen(fractal_cube, "fractal-cube.msl", &.{
        .{ .stage = .fragment, .name = "frag_main" },
    }, .msl);
}

test "gen-texture-light" {
    const gen_texture_light = @embedFile("test/gen-texture-light.wgsl");
    try expectCodegen(gen_texture_light, "gen-texture-light.spv", &.{}, .spirv);
    try expectCodegen(gen_texture_light, "gen-texture-light.hlsl", &.{}, .hlsl);
    try expectCodegen(gen_texture_light, "gen-texture-light.msl", &.{
        .{ .stage = .vertex, .name = "vs_main" },
        .{ .stage = .fragment, .name = "fs_main" },
    }, .msl);
}

test "gen-texture-light-cube" {
    const gen_texture_light_cube = @embedFile("test/gen-texture-light-cube.wgsl");
    try expectCodegen(gen_texture_light_cube, "gen-texture-light-cube.spv", &.{}, .spirv);
    try expectCodegen(gen_texture_light_cube, "gen-texture-light-cube.hlsl", &.{}, .hlsl);
    try expectCodegen(gen_texture_light_cube, "gen-texture-light-cube.msl", &.{
        .{ .stage = .vertex, .name = "vs_main" },
        .{ .stage = .fragment, .name = "fs_main" },
    }, .msl);
}

test "sprite2d" {
    const sprite2d = @embedFile("test/sprite2d.wgsl");
    try expectCodegen(sprite2d, "sprite2d.spv", &.{}, .spirv);
    try expectCodegen(sprite2d, "sprite2d.hlsl", &.{}, .hlsl);
    try expectCodegen(sprite2d, "sprite2d.msl", &.{
        .{ .stage = .vertex, .name = "vertex_main" },
        .{ .stage = .fragment, .name = "frag_main" },
    }, .msl);
}

test "two-cubes" {
    const two_cubes = @embedFile("test/two-cubes.wgsl");
    try expectCodegen(two_cubes, "two-cubes.spv", &.{}, .spirv);
    try expectCodegen(two_cubes, "two-cubes.hlsl", &.{}, .hlsl);
    try expectCodegen(two_cubes, "two-cubes.msl", &.{
        .{ .stage = .vertex, .name = "vertex_main" },
        .{ .stage = .fragment, .name = "frag_main" },
    }, .msl);
}

test "fullscreen-textured-quad" {
    const fullscreen_textured_quad = @embedFile("test/fullscreen-textured-quad.wgsl");
    try expectCodegen(fullscreen_textured_quad, "fullscreen-textured-quad.spv", &.{}, .spirv);
    try expectCodegen(fullscreen_textured_quad, "fullscreen-textured-quad.hlsl", &.{}, .hlsl);
    try expectCodegen(fullscreen_textured_quad, "fullscreen-textured-quad.msl", &.{
        .{ .stage = .fragment, .name = "frag_main" },
        .{ .stage = .vertex, .name = "vert_main" },
    }, .msl);
}

test "image-blur" {
    const image_blur = @embedFile("test/image-blur.wgsl");
    try expectCodegen(image_blur, "image-blur.spv", &.{}, .spirv);
    try expectCodegen(image_blur, "image-blur.hlsl", &.{}, .hlsl);
    try expectCodegen(image_blur, "image-blur.msl", &.{
        .{ .stage = .compute, .name = "main" },
    }, .msl);
}

test "instanced-cube" {
    const instanced_cube = @embedFile("test/instanced-cube.wgsl");
    try expectCodegen(instanced_cube, "instanced-cube.spv", &.{}, .spirv);
    try expectCodegen(instanced_cube, "instanced-cube.hlsl", &.{}, .hlsl);
    try expectCodegen(instanced_cube, "instanced-cube.msl", &.{
        .{ .stage = .vertex, .name = "vertex_main" },
        .{ .stage = .fragment, .name = "frag_main" },
    }, .msl);
}

test "map-async" {
    const map_async = @embedFile("test/map-async.wgsl");
    try expectCodegen(map_async, "map-async.spv", &.{}, .spirv);
    try expectCodegen(map_async, "map-async.hlsl", &.{}, .hlsl);
    try expectCodegen(map_async, "map-async.msl", &.{
        .{ .stage = .compute, .name = "main" },
    }, .msl);
}

test "pbr-basic" {
    const pbr_basic = @embedFile("test/pbr-basic.wgsl");
    try expectCodegen(pbr_basic, "pbr-basic.spv", &.{}, .spirv);
    try expectCodegen(pbr_basic, "pbr-basic.hlsl", &.{}, .hlsl);
    try expectCodegen(pbr_basic, "pbr-basic.msl", &.{
        .{ .stage = .vertex, .name = "vertex_main" },
        .{ .stage = .fragment, .name = "frag_main" },
    }, .msl);
}

test "pixel-post-process-normal-frag" {
    const pixel_post_process_normal_frag = @embedFile("test/pixel-post-process-normal-frag.wgsl");
    try expectCodegen(pixel_post_process_normal_frag, "pixel-post-process-normal-frag.spv", &.{}, .spirv);
    try expectCodegen(pixel_post_process_normal_frag, "pixel-post-process-normal-frag.hlsl", &.{}, .hlsl);
    try expectCodegen(pixel_post_process_normal_frag, "pixel-post-process-normal-frag.msl", &.{
        .{ .stage = .compute, .name = "main" },
    }, .msl);
}

test "pixel-post-process-pixel-vert" {
    const pixel_post_process_pixel_vert = @embedFile("test/pixel-post-process-pixel-vert.wgsl");
    try expectCodegen(pixel_post_process_pixel_vert, "pixel-post-process-pixel-vert.spv", &.{}, .spirv);
    try expectCodegen(pixel_post_process_pixel_vert, "pixel-post-process-pixel-vert.hlsl", &.{}, .hlsl);
    try expectCodegen(pixel_post_process_pixel_vert, "pixel-post-process-pixel-vert.msl", &.{
        .{ .stage = .compute, .name = "main" },
    }, .msl);
}

test "pixel-post-process-pixel-frag" {
    const pixel_post_process_pixel_frag = @embedFile("test/pixel-post-process-pixel-frag.wgsl");
    try expectCodegen(pixel_post_process_pixel_frag, "pixel-post-process-pixel-frag.spv", &.{}, .spirv);
    try expectCodegen(pixel_post_process_pixel_frag, "pixel-post-process-pixel-frag.hlsl", &.{}, .hlsl);
    try expectCodegen(pixel_post_process_pixel_frag, "pixel-post-process-pixel-frag.msl", &.{
        .{ .stage = .compute, .name = "main" },
    }, .msl);
}

test "pixel-post-process" {
    const pixel_post_process = @embedFile("test/pixel-post-process.wgsl");
    try expectCodegen(pixel_post_process, "pixel-post-process.spv", &.{}, .spirv);
    try expectCodegen(pixel_post_process, "pixel-post-process.hlsl", &.{}, .hlsl);
    try expectCodegen(pixel_post_process, "pixel-post-process.msl", &.{
        .{ .stage = .vertex, .name = "vertex_main" },

        .{ .stage = .fragment, .name = "frag_main" },
    }, .msl);
}

test "procedural-primitives" {
    const procedural_primitives = @embedFile("test/procedural-primitives.wgsl");
    try expectCodegen(procedural_primitives, "procedural-primitives.spv", &.{}, .spirv);
    try expectCodegen(procedural_primitives, "procedural-primitives.hlsl", &.{}, .hlsl);
    try expectCodegen(procedural_primitives, "procedural-primitives.msl", &.{
        .{ .stage = .vertex, .name = "vertex_main" },
        .{ .stage = .fragment, .name = "frag_main" },
    }, .msl);
}

test "rotating-cube" {
    const rotating_cube = @embedFile("test/rotating-cube.wgsl");
    try expectCodegen(rotating_cube, "rotating-cube.spv", &.{}, .spirv);
    try expectCodegen(rotating_cube, "rotating-cube.hlsl", &.{}, .hlsl);
    try expectCodegen(rotating_cube, "rotating-cube.msl", &.{
        .{ .stage = .vertex, .name = "vertex_main" },
        .{ .stage = .fragment, .name = "frag_main" },
    }, .msl);
}

test "triangle" {
    const triangle = @embedFile("test/triangle.wgsl");
    try expectCodegen(triangle, "triangle.spv", &.{}, .spirv);
    try expectCodegen(triangle, "triangle.hlsl", &.{}, .hlsl);
    try expectCodegen(triangle, "triangle.msl", &.{
        .{ .stage = .vertex, .name = "vertex_main" },
        .{ .stage = .fragment, .name = "frag_main" },
    }, .msl);
}

test "fragmentDeferredRendering" {
    const fragmentDeferredRendering = @embedFile("test/fragmentDeferredRendering.wgsl");
    try expectCodegen(fragmentDeferredRendering, "fragmentDeferredRendering.spv", &.{}, .spirv);
    try expectCodegen(fragmentDeferredRendering, "fragmentDeferredRendering.hlsl", &.{}, .hlsl);
    try expectCodegen(fragmentDeferredRendering, "fragmentDeferredRendering.msl", &.{
        .{ .stage = .compute, .name = "main" },
    }, .msl);
}

test "fragmentGBuffersDebugView" {
    const fragmentGBuffersDebugView = @embedFile("test/fragmentGBuffersDebugView.wgsl");
    try expectCodegen(fragmentGBuffersDebugView, "fragmentGBuffersDebugView.spv", &.{}, .spirv);
    try expectCodegen(fragmentGBuffersDebugView, "fragmentGBuffersDebugView.hlsl", &.{}, .hlsl);
    try expectCodegen(fragmentGBuffersDebugView, "fragmentGBuffersDebugView.msl", &.{
        .{ .stage = .compute, .name = "main" },
    }, .msl);
}

test "fragmentWriteGBuffers" {
    const fragmentWriteGBuffers = @embedFile("test/fragmentWriteGBuffers.wgsl");
    try expectCodegen(fragmentWriteGBuffers, "fragmentWriteGBuffers.spv", &.{}, .spirv);
    try expectCodegen(fragmentWriteGBuffers, "fragmentWriteGBuffers.hlsl", &.{}, .hlsl);
    try expectCodegen(fragmentWriteGBuffers, "fragmentWriteGBuffers.msl", &.{
        .{ .stage = .compute, .name = "main" },
    }, .msl);
}

test "lightUpdate" {
    const lightUpdate = @embedFile("test/lightUpdate.wgsl");
    try expectCodegen(lightUpdate, "lightUpdate.spv", &.{}, .spirv);
    try expectCodegen(lightUpdate, "lightUpdate.hlsl", &.{}, .hlsl);
    try expectCodegen(lightUpdate, "lightUpdate.msl", &.{
        .{ .stage = .compute, .name = "main" },
    }, .msl);
}

test "vertexTextureQuad" {
    const vertexTextureQuad = @embedFile("test/vertexTextureQuad.wgsl");
    try expectCodegen(vertexTextureQuad, "vertexTextureQuad.spv", &.{}, .spirv);
    try expectCodegen(vertexTextureQuad, "vertexTextureQuad.hlsl", &.{}, .hlsl);
    try expectCodegen(vertexTextureQuad, "vertexTextureQuad.msl", &.{
        .{ .stage = .compute, .name = "main" },
    }, .msl);
}

test "vertexWriteGBuffers" {
    const vertexWriteGBuffers = @embedFile("test/vertexWriteGBuffers.wgsl");
    try expectCodegen(vertexWriteGBuffers, "vertexWriteGBuffers.spv", &.{}, .spirv);
    try expectCodegen(vertexWriteGBuffers, "vertexWriteGBuffers.hlsl", &.{}, .hlsl);
    try expectCodegen(vertexWriteGBuffers, "vertexWriteGBuffers.msl", &.{
        .{ .stage = .compute, .name = "main" },
    }, .msl);
}

fn expectCodegen(
    source: [:0]const u8,
    comptime file_name: []const u8,
    comptime entry_points: []const CodeGen.Entrypoint,
    lang: CodeGen.Language,
) !void {
    var errors = try ErrorList.init(allocator);
    defer errors.deinit();

    var tree = Ast.parse(allocator, &errors, source) catch |err| {
        if (err == error.Parsing) {
            try errors.print(source, null);
        }
        return err;
    };
    defer tree.deinit(allocator);

    var ir = Air.generate(allocator, &tree, &errors, null) catch |err| {
        if (err == error.AnalysisFail) {
            try errors.print(source, null);
        }
        return err;
    };
    defer ir.deinit(allocator);

    try std.fs.cwd().makePath("zig-out/shader/");

    const empty_bindings = CodeGen.BindingTable{};

    inline for (entry_points) |entry_point| {
        const out = try CodeGen.generate(allocator, &ir, lang, .{}, entry_point, &empty_bindings);
        defer allocator.free(out);

        try std.fs.cwd().writeFile("zig-out/shader/" ++ @tagName(entry_point.stage) ++ "-" ++ file_name, out);
    }
    if (entry_points.len == 0) {
        const out = try CodeGen.generate(allocator, &ir, lang, .{}, null, null);
        defer allocator.free(out);
        try std.fs.cwd().writeFile("zig-out/shader/" ++ file_name, out);
    }
}
