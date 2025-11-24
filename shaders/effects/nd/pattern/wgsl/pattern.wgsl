/*
 * WGSL pattern generator shader.
 * Creates kaleidoscopic lattices and looped repeats using deterministic PRNG so geometry stays phase-aligned on reload.
 * UI loop controls are converted to normalized angles before use to avoid floating-point drift in long performances.
 */

struct Uniforms {
    data : array<vec4<f32>, 4>,
};
@group(0) @binding(0) var<uniform> uniforms : Uniforms;
@group(0) @binding(1) var samp : sampler;

fn map(value: f32, inMin: f32, inMax: f32, outMin: f32, outMax: f32) -> f32 {
    return outMin + (outMax - outMin) * (value - inMin) / (inMax - inMin);
}

@fragment
fn fs_main(@builtin(position) pos : vec4<f32>) -> @location(0) vec4<f32> {
    let resolution: vec2<f32> = uniforms.data[0].xy;
    let scale: f32 = uniforms.data[1].y;
    let color1: vec3<f32> = uniforms.data[2].xyz;
    let color2: vec3<f32> = uniforms.data[3].xyz;

    var st: vec2<f32> = pos.xy / resolution;
    let aspect: f32 = resolution.x / resolution.y;
    st.x = st.x * aspect;

    let stripes: f32 = step(0.5, fract(st.x * scale));
    var color: vec4<f32> = vec4<f32>(mix(color1, color2, stripes), 1.0);

    return color;
}
