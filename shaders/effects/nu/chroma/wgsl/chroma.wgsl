/*
 * Chroma isolation effect
 * Isolate specific color with range and feathering
 * Outputs mono mask based on hue distance from target
 */

struct Uniforms {
    targetHue: f32,
    range: f32,
    feather: f32,
    _pad: f32,
}

@group(0) @binding(0) var inputSampler: sampler;
@group(0) @binding(1) var inputTex: texture_2d<f32>;
@group(0) @binding(2) var<uniform> uniforms: Uniforms;

fn rgb2hsv(c: vec3<f32>) -> vec3<f32> {
    let K = vec4<f32>(0.0, -1.0/3.0, 2.0/3.0, -1.0);
    let p = mix(vec4<f32>(c.bg, K.wz), vec4<f32>(c.gb, K.xy), step(c.b, c.g));
    let q = mix(vec4<f32>(p.xyw, c.r), vec4<f32>(c.r, p.yzx), step(p.x, c.r));

    let d = q.x - min(q.w, q.y);
    let e = 1.0e-10;
    return vec3<f32>(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

fn hueDistance(h1: f32, h2: f32) -> f32 {
    let d = abs(h1 - h2);
    return min(d, 1.0 - d);
}

@fragment
fn main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let targetHue = uniforms.targetHue;
    let range = uniforms.range;
    let feather = uniforms.feather;

    let texSize = vec2<f32>(textureDimensions(inputTex));
    let uv = pos.xy / texSize;
    let color = textureSample(inputTex, inputSampler, uv);

    let hsv = rgb2hsv(color.rgb);
    let hue = hsv.x;
    let sat = hsv.y;

    let dist = hueDistance(hue, targetHue);
    
    // Apply range and feather to create smooth mask
    let inner = range;
    let outer = range + feather;
    var mask = 1.0 - smoothstep(inner, outer, dist);
    
    // Scale by saturation - desaturated colors don't have meaningful hue
    mask *= sat;

    return vec4<f32>(vec3<f32>(mask), color.a);
}
