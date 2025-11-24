/*
 * Feedback mixer shader (WGSL port).
 * Blends the current mixer output with a delayed framebuffer while exposing offset controls for creative smearing.
 */

@group(0) @binding(0) var samp: sampler;
@group(0) @binding(1) var tex0: texture_2d<f32>;
@group(0) @binding(2) var tex1: texture_2d<f32>;
@group(0) @binding(3) var selfTex: texture_2d<f32>;
@group(0) @binding(4) var<uniform> u: Uniforms;

struct Uniforms {
    time: f32,
    deltaTime: f32,
    frame: i32,
    _pad0: f32,
    resolution: vec2f,
    aspect: f32,
    // Effect params in definition.js globals order:
    seed: i32,
    feedback: f32,
    mixAmt: f32,
    scaleAmt: f32,
    rotation: f32,
}

const PI: f32 = 3.14159265359;
const TAU: f32 = 6.28318530718;

fn aspectRatio() -> f32 {
    return u.resolution.x / u.resolution.y;
}

fn mapRange(value: f32, inMin: f32, inMax: f32, outMin: f32, outMax: f32) -> f32 {
    return outMin + (outMax - outMin) * (value - inMin) / (inMax - inMin);
}

fn rotate2D(st_in: vec2f, rot: f32) -> vec2f {
    var st = st_in;
    st.x *= aspectRatio();
    let r = mapRange(rot, 0.0, 360.0, 0.0, 2.0);
    let angle = r * PI;
    st -= vec2f(0.5 * aspectRatio(), 0.5);
    let c = cos(angle);
    let s = sin(angle);
    st = vec2f(c * st.x - s * st.y, s * st.x + c * st.y);
    st += vec2f(0.5 * aspectRatio(), 0.5);
    st.x /= aspectRatio();
    return st;
}

@fragment
fn main(@builtin(position) fragCoord: vec4f) -> @location(0) vec4f {
    var color = vec4f(0.0, 0.0, 0.0, 1.0);
    var st = fragCoord.xy / u.resolution;
    st.y = 1.0 - st.y;

    var scale = 100.0 / u.scaleAmt;
    if (scale == 0.0) { scale = 1.0; }
    st = rotate2D(st, u.rotation) * scale;

    let imageSize = u.resolution;
    // mid center
    st.x -= (u.resolution.x / imageSize.x * scale * 0.5) - (0.5 - (1.0 / imageSize.x * scale));
    st.y += (u.resolution.y / imageSize.y * scale * 0.5) + (0.5 - (1.0 / imageSize.y * scale)) - scale;

    // nudge by one pixel
    st += 1.0 / u.resolution;

    st = fract(st);

    let color1 = textureSample(tex0, samp, st);
    let color2 = textureSample(tex1, samp, st);

    color = mix(color1, color2, mapRange(u.mixAmt, -100.0, 100.0, 0.0, 1.0));
    color.a = max(color1.a, color2.a);

    color = mix(color, textureSample(selfTex, samp, st), u.feedback * 0.01);

    return color;
}
