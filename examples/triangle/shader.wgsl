@vertex fn vertex_main(@builtin(vertex_index) vertex_index : u32) -> @builtin(position) vec4<f32> {
    var pos = array<vec2<f32>, 3>(
        vec2<f32>( 0.0,  0.5),
        vec2<f32>(-0.5, -0.5),
        vec2<f32>( 0.5, -0.5)
    );
    return vec4<f32>(pos[vertex_index], 0, 1);
}

@fragment fn fragment_main() -> @location(0) vec4<f32> {
    return vec4<f32>(0.447, 1, 0.447, 1);
}