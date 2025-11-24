/*
 * WGSL text blit shader.
 * Copies the prepared glyph atlas into the swap chain using the same normalized coordinates as the GLSL path.
 * Maintains consistent sampling so layout edits remain pixel-aligned across rendering backends.
 */


struct Uniforms {
    data : array<vec4<f32>, 4>,
};

@group(0) @binding(0) var<uniform> uniforms : Uniforms;
@group(0) @binding(1) var samp : sampler;
@group(0) @binding(2) var fontTex : texture_2d<f32>;

@fragment
fn main(@builtin(position) pos : vec4<f32>) -> @location(0) vec4<f32> {
    let resolution = uniforms.data[0].xy;

    let glyphUV1 = uniforms.data[1].xy;
    let glyphUV2 = uniforms.data[1].zw;

    let scale = uniforms.data[2].x;
    let offset = uniforms.data[2].yz;

    let color = uniforms.data[3].xyz;

    var st = pos.xy / resolution;
    st = glyphUV1 + st * (glyphUV2 - glyphUV1);
    st = (st - 0.5) / scale + 0.5 + offset;
    st.y = 1.0 - st.y;

    var texColor = textureSample(fontTex, samp, st) * vec4<f32>(color, 1.0);
    return texColor;
}
