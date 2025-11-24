/*
 * Final post-processing shader.
 * Applies brightness, contrast, saturation, hue adjustments, and optional FXAA.
 */

@group(0) @binding(0) var samp: sampler;
@group(0) @binding(1) var postTex: texture_2d<f32>;

// Uniform struct ordered to match runtime uniform packing
struct Uniforms {
    time: f32,           // global
    deltaTime: f32,      // global
    frame: i32,          // global
    _pad0: f32,          // padding for alignment before vec2
    resolution: vec2f,   // global (8-byte aligned)
    aspect: f32,         // global
    // effect params from definition order:
    enabled: i32,
    brightness: f32,
    contrast: f32,
    saturation: f32,
    hueRotation: f32,
    hueRange: f32,
    invert: i32,
    antialias: i32,
}

@group(0) @binding(2) var<uniform> u: Uniforms;

const PI: f32 = 3.14159265359;
const TAU: f32 = 6.28318530718;

const FXAA_REDUCE_MIN: f32 = 1.0 / 128.0;
const FXAA_REDUCE_MUL: f32 = 1.0 / 8.0;
const FXAA_SPAN_MAX: f32 = 8.0;

fn mapVal(value: f32, inMin: f32, inMax: f32, outMin: f32, outMax: f32) -> f32 {
    return outMin + (outMax - outMin) * (value - inMin) / (inMax - inMin);
}

fn brightnessContrast(color: vec3f) -> vec3f {
    let bright = mapVal(u.brightness, -100.0, 100.0, -1.0, 1.0);
    let cont = mapVal(u.contrast, 0.0, 100.0, 0.0, 2.0);
    return (color - 0.5) * cont + 0.5 + bright;
}

fn saturateColor(color: vec3f) -> vec3f {
    let sat = mapVal(u.saturation, -100.0, 100.0, -1.0, 1.0);
    let avg = (color.r + color.g + color.b) / 3.0;
    return color - (avg - color) * sat;
}

fn hsv2rgb(hsv: vec3f) -> vec3f {
    let h = fract(hsv.x);
    let s = hsv.y;
    let v = hsv.z;

    let c = v * s;
    let x = c * (1.0 - abs((h * 6.0) % 2.0 - 1.0));
    let m = v - c;

    var rgb: vec3f;

    if (h < 1.0/6.0) {
        rgb = vec3f(c, x, 0.0);
    } else if (h < 2.0/6.0) {
        rgb = vec3f(x, c, 0.0);
    } else if (h < 3.0/6.0) {
        rgb = vec3f(0.0, c, x);
    } else if (h < 4.0/6.0) {
        rgb = vec3f(0.0, x, c);
    } else if (h < 5.0/6.0) {
        rgb = vec3f(x, 0.0, c);
    } else {
        rgb = vec3f(c, 0.0, x);
    }

    return rgb + vec3f(m, m, m);
}

fn rgb2hsv(rgb: vec3f) -> vec3f {
    let r = rgb.r;
    let g = rgb.g;
    let b = rgb.b;

    let maxC = max(r, max(g, b));
    let minC = min(r, min(g, b));
    let delta = maxC - minC;

    var h: f32 = 0.0;
    if (delta != 0.0) {
        if (maxC == r) {
            h = ((g - b) / delta) % 6.0 / 6.0;
        } else if (maxC == g) {
            h = ((b - r) / delta + 2.0) / 6.0;
        } else {
            h = ((r - g) / delta + 4.0) / 6.0;
        }
    }
    if (h < 0.0) { h = h + 1.0; }

    var s: f32 = 0.0;
    if (maxC != 0.0) {
        s = delta / maxC;
    }
    let v = maxC;

    return vec3f(h, s, v);
}

fn fxaa(fragCoord: vec2f) -> vec4f {
    let inverseVP = 1.0 / u.resolution;
    let v_rgbNW = (fragCoord + vec2f(-1.0, -1.0)) * inverseVP;
    let v_rgbNE = (fragCoord + vec2f(1.0, -1.0)) * inverseVP;
    let v_rgbSW = (fragCoord + vec2f(-1.0, 1.0)) * inverseVP;
    let v_rgbSE = (fragCoord + vec2f(1.0, 1.0)) * inverseVP;
    let v_rgbM = fragCoord * inverseVP;

    let rgbNW = textureSample(postTex, samp, v_rgbNW).xyz;
    let rgbNE = textureSample(postTex, samp, v_rgbNE).xyz;
    let rgbSW = textureSample(postTex, samp, v_rgbSW).xyz;
    let rgbSE = textureSample(postTex, samp, v_rgbSE).xyz;
    let texColor = textureSample(postTex, samp, v_rgbM);
    let rgbM = texColor.xyz;

    let luma = vec3f(0.299, 0.587, 0.114);
    let lumaNW = dot(rgbNW, luma);
    let lumaNE = dot(rgbNE, luma);
    let lumaSW = dot(rgbSW, luma);
    let lumaSE = dot(rgbSE, luma);
    let lumaM = dot(rgbM, luma);
    let lumaMin = min(lumaM, min(min(lumaNW, lumaNE), min(lumaSW, lumaSE)));
    let lumaMax = max(lumaM, max(max(lumaNW, lumaNE), max(lumaSW, lumaSE)));

    var dir: vec2f;
    dir.x = -((lumaNW + lumaNE) - (lumaSW + lumaSE));
    dir.y = ((lumaNW + lumaSW) - (lumaNE + lumaSE));

    let dirReduce = max((lumaNW + lumaNE + lumaSW + lumaSE) *
                        (0.25 * FXAA_REDUCE_MUL), FXAA_REDUCE_MIN);

    let rcpDirMin = 1.0 / (min(abs(dir.x), abs(dir.y)) + dirReduce);
    dir = min(vec2f(FXAA_SPAN_MAX, FXAA_SPAN_MAX),
              max(vec2f(-FXAA_SPAN_MAX, -FXAA_SPAN_MAX),
              dir * rcpDirMin)) * inverseVP;

    let rgbA = 0.5 * (
        textureSample(postTex, samp, fragCoord * inverseVP + dir * (1.0 / 3.0 - 0.5)).xyz +
        textureSample(postTex, samp, fragCoord * inverseVP + dir * (2.0 / 3.0 - 0.5)).xyz);
    let rgbB = rgbA * 0.5 + 0.25 * (
        textureSample(postTex, samp, fragCoord * inverseVP + dir * -0.5).xyz +
        textureSample(postTex, samp, fragCoord * inverseVP + dir * 0.5).xyz);

    let lumaB = dot(rgbB, luma);
    if (lumaB < lumaMin || lumaB > lumaMax) {
        return vec4f(rgbA, texColor.a);
    } else {
        return vec4f(rgbB, texColor.a);
    }
}

@fragment
fn main(@builtin(position) fragCoord: vec4f) -> @location(0) vec4f {
    var uv = fragCoord.xy / u.resolution;
    uv.y = 1.0 - uv.y;

    var color = textureSample(postTex, samp, uv);

    // antialiasing
    if (u.antialias != 0) {
        color = fxaa(uv * u.resolution);
    }

    if (u.enabled == 0) {
        return color;
    }

    var hsv = rgb2hsv(color.rgb);
    hsv.x = (hsv.x * mapVal(u.hueRange, 0.0, 200.0, 0.0, 2.0) + (u.hueRotation / 360.0)) % 1.0;
    color = vec4f(hsv2rgb(hsv), color.a);

    if (u.invert != 0) {
        color = vec4f(vec3f(1.0) - color.rgb, color.a);
    }

    // brightness/contrast/saturation
    color = vec4f(brightnessContrast(color.rgb), color.a);
    color = vec4f(saturateColor(color.rgb), color.a);

    return color;
}
