/*
 * Physarum render shader (WGSL port).
 * Final output with palette coloring.
 */

@group(0) @binding(0) var samp: sampler;
@group(0) @binding(1) var bufTex: texture_2d<f32>;
@group(0) @binding(2) var inputTex: texture_2d<f32>;
@group(0) @binding(3) var<uniform> u: Uniforms;

struct Uniforms {
    time: f32,
    deltaTime: f32,
    frame: i32,
    _pad0: f32,
    resolution: vec2f,
    aspect: f32,
    colorMode: i32,
    paletteMode: i32,
    cyclePalette: i32,
    _pad1: f32,
    paletteOffset: vec3f,
    _pad2: f32,
    paletteAmp: vec3f,
    _pad3: f32,
    paletteFreq: vec3f,
    _pad4: f32,
    palettePhase: vec3f,
    rotatePalette: f32,
    repeatPalette: f32,
    inputIntensity: f32,
}

fn hsv2rgb(hsv: vec3f) -> vec3f {
    let h = fract(hsv.x);
    let s = clamp(hsv.y, 0.0, 1.0);
    let v = clamp(hsv.z, 0.0, 1.0);

    let c = v * s;
    let x = c * (1.0 - abs((h * 6.0) % 2.0 - 1.0));
    let m = v - c;

    var rgb: vec3f;
    if (h < 1.0 / 6.0) {
        rgb = vec3f(c, x, 0.0);
    } else if (h < 2.0 / 6.0) {
        rgb = vec3f(x, c, 0.0);
    } else if (h < 3.0 / 6.0) {
        rgb = vec3f(0.0, c, x);
    } else if (h < 4.0 / 6.0) {
        rgb = vec3f(0.0, x, c);
    } else if (h < 5.0 / 6.0) {
        rgb = vec3f(x, 0.0, c);
    } else {
        rgb = vec3f(c, 0.0, x);
    }
    return rgb + vec3f(m);
}

fn linearToSrgb(linear: vec3f) -> vec3f {
    var srgb: vec3f;
    srgb.x = select(1.055 * pow(linear.x, 1.0/2.4) - 0.055, linear.x * 12.92, linear.x <= 0.0031308);
    srgb.y = select(1.055 * pow(linear.y, 1.0/2.4) - 0.055, linear.y * 12.92, linear.y <= 0.0031308);
    srgb.z = select(1.055 * pow(linear.z, 1.0/2.4) - 0.055, linear.z * 12.92, linear.z <= 0.0031308);
    return srgb;
}

const fwdA: mat3x3f = mat3x3f(
    vec3f(1.0, 1.0, 1.0),
    vec3f(0.3963377774, -0.1055613458, -0.0894841775),
    vec3f(0.2158037573, -0.0638541728, -1.2914855480)
);
const fwdB: mat3x3f = mat3x3f(
    vec3f(4.0767245293, -1.2681437731, -0.0041119885),
    vec3f(-3.3072168827, 2.6093323231, -0.7034763098),
    vec3f(0.2307590544, -0.3411344290, 1.7068625689)
);

fn linear_srgb_from_oklab(c: vec3f) -> vec3f {
    let lms = fwdA * c;
    return fwdB * (lms * lms * lms);
}

fn pal(t: f32) -> vec3f {
    let tt = t * u.repeatPalette + u.rotatePalette * 0.01;
    var color = u.paletteOffset + u.paletteAmp * cos(6.28318 * (u.paletteFreq * tt + u.palettePhase));

    if (u.paletteMode == 1) {
        color = hsv2rgb(color);
    } else if (u.paletteMode == 2) {
        color.g = color.g * -0.509 + 0.276;
        color.b = color.b * -0.509 + 0.198;
        color = linear_srgb_from_oklab(color);
        color = linearToSrgb(color);
    }

    return color;
}

fn grade(v: f32) -> vec3f {
    let luma = clamp(v, 0.0, 1.0);
    if (u.colorMode == 1) {
        var d = luma;
        if (u.cyclePalette == -1) {
            d += u.time;
        } else if (u.cyclePalette == 1) {
            d -= u.time;
        }
        return pal(d);
    } else {
        return vec3f(luma);
    }
}

fn sampleInputColor(uv: vec2f) -> vec3f {
    let flippedUV = vec2f(uv.x, 1.0 - uv.y);
    return textureSample(inputTex, samp, flippedUV).rgb;
}

@fragment
fn main(@builtin(position) fragCoord: vec4f) -> @location(0) vec4f {
    let uv = fragCoord.xy / u.resolution;
    let trail = textureSample(bufTex, samp, uv).r;
    let tone = trail / (1.0 + trail);
    var color = grade(tone);
    
    // Blend input texture at output stage
    if (u.inputIntensity > 0.0) {
        let intensity = clamp(u.inputIntensity * 0.01, 0.0, 1.0);
        let inputColor = sampleInputColor(uv);
        color = clamp(inputColor * intensity + color, vec3f(0.0), vec3f(1.0));
    }
    
    return vec4f(color, 1.0);
}
