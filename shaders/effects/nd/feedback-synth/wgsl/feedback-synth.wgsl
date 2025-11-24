/*
 * WGSL feedback synthesizer shader.
 * Reprojects the previous frame and mixes it with the synth feed using shared rotation and scale controls.
 * Mix and translation uniforms are normalized so presets animate identically between WebGL and WebGPU.
 */


struct Uniforms {
    data : array<vec4<f32>, 3>,
};
@group(0) @binding(0) var<uniform> uniforms : Uniforms;
@group(0) @binding(1) var samp : sampler;
@group(0) @binding(2) var selfTex : texture_2d<f32>;

const PI : f32 = 3.14159265359;

fn map(value: f32, inMin: f32, inMax: f32, outMin: f32, outMax: f32) -> f32 {
    return outMin + (outMax - outMin) * (value - inMin) / (inMax - inMin);
}

fn rotate2D(st: vec2<f32>, rot: f32, aspectRatio: f32) -> vec2<f32> {
    var st2 = st;
    let r = map(rot, 0.0, 360.0, 0.0, 2.0);
    let angle = r * PI;
    st2.x = st2.x * aspectRatio;
    st2 = st2 - vec2<f32>(0.5 * aspectRatio, 0.5);
    let s = sin(angle);
    let c = cos(angle);
    st2 = mat2x2<f32>(c, -s, s, c) * st2;
    st2 = st2 + vec2<f32>(0.5 * aspectRatio, 0.5);
    st2.x = st2.x / aspectRatio;
    return st2;
}

@fragment
fn main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let resolution = uniforms.data[0].xy;
    let scaleAmt = uniforms.data[1].x;
    let rotation = uniforms.data[1].y;
    let translate = uniforms.data[1].zw;
    let mixAmt = uniforms.data[2].x;

    var st = pos.xy / resolution;
    st.y = 1.0 - st.y;

    let aspectRatio = resolution.x / resolution.y;
    st = rotate2D(st, rotation, aspectRatio);

    var scale = 100.0 / scaleAmt;
    if (scale == 0.0) {
        scale = 1.0;
    }
    st = st * scale;
    st = st + vec2<f32>(translate.x / 100.0, translate.y / 100.0);
    st = fract(st);

    let selfColor = textureSample(selfTex, samp, st).rgb;
    let synthColor = vec3<f32>(0.0);
    let color = mix(selfColor, synthColor, mixAmt);
    return vec4<f32>(color, 1.0);
}
