// Shadow blend pass - final blending
// Matches shadowBlend.glsl (GPGPU fragment shader)

struct Uniforms {
    alpha: f32,
    _pad0: f32,
    _pad1: f32,
    _pad2: f32,
};

@group(0) @binding(0) var inputTex: texture_2d<f32>;
@group(0) @binding(1) var sobelTexture: texture_2d<f32>;
@group(0) @binding(2) var sharpenTexture: texture_2d<f32>;
@group(0) @binding(3) var inputSampler: sampler;
@group(0) @binding(4) var<uniform> uniforms: Uniforms;

fn clamp01(value: f32) -> f32 {
    return clamp(value, 0.0, 1.0);
}

fn clampVec3(value: vec3<f32>) -> vec3<f32> {
    return clamp(value, vec3<f32>(0.0), vec3<f32>(1.0));
}

fn rgbToHsv(rgb: vec3<f32>) -> vec3<f32> {
    let color = clampVec3(rgb);
    let maxVal = max(max(color.r, color.g), color.b);
    let minVal = min(min(color.r, color.g), color.b);
    let delta = maxVal - minVal;

    var hue: f32 = 0.0;
    if (delta > 1e-6) {
        if (maxVal == color.r) {
            hue = (color.g - color.b) / delta;
        } else if (maxVal == color.g) {
            hue = 2.0 + (color.b - color.r) / delta;
        } else {
            hue = 4.0 + (color.r - color.g) / delta;
        }
        hue /= 6.0;
        if (hue < 0.0) {
            hue += 1.0;
        }
    }

    var saturation: f32 = 0.0;
    if (maxVal > 1e-6) {
        saturation = delta / maxVal;
    }
    return vec3<f32>(hue, saturation, maxVal);
}

fn hsvToRgb(hsv: vec3<f32>) -> vec3<f32> {
    let h = hsv.x * 6.0;
    let s = clamp01(hsv.y);
    let v = clamp01(hsv.z);

    let sector = floor(h);
    let fraction = h - sector;

    let p = v * (1.0 - s);
    let q = v * (1.0 - fraction * s);
    let t = v * (1.0 - (1.0 - fraction) * s);

    if (sector == 0.0) {
        return vec3<f32>(v, t, p);
    }
    if (sector == 1.0) {
        return vec3<f32>(q, v, p);
    }
    if (sector == 2.0) {
        return vec3<f32>(p, v, t);
    }
    if (sector == 3.0) {
        return vec3<f32>(p, q, v);
    }
    if (sector == 4.0) {
        return vec3<f32>(t, p, v);
    }
    return vec3<f32>(v, p, q);
}

fn shadeComponent(srcValue: f32, finalShade: f32, highlight: f32) -> f32 {
    let dark = (1.0 - srcValue) * (1.0 - highlight);
    let lit = 1.0 - dark;
    return clamp01(lit * finalShade);
}

@fragment
fn main(@builtin(position) fragCoord: vec4<f32>) -> @location(0) vec4<f32> {
    let dimensions = textureDimensions(inputTex);
    if (dimensions.x == 0u || dimensions.y == 0u) {
        return vec4<f32>(0.0);
    }

    let uv = (fragCoord.xy - vec2<f32>(0.5)) / vec2<f32>(f32(max(dimensions.x, 1u)), f32(max(dimensions.y, 1u)));
    let baseColor = textureSampleLevel(inputTex, inputSampler, uv, 0.0);
    let shadeNorm = textureSampleLevel(sobelTexture, inputSampler, uv, 0.0).r;
    let sharpenNorm = textureSampleLevel(sharpenTexture, inputSampler, uv, 0.0).r;

    let finalShade = mix(shadeNorm, sharpenNorm, 0.5);
    let highlight = clamp01(finalShade * finalShade);
    let blendFactor = clamp01(uniforms.alpha);

    let shadeR = shadeComponent(baseColor.r, finalShade, highlight);
    let shadeG = shadeComponent(baseColor.g, finalShade, highlight);
    let shadeB = shadeComponent(baseColor.b, finalShade, highlight);

    let baseHSV = rgbToHsv(baseColor.rgb);
    let shadeHSV = rgbToHsv(vec3<f32>(shadeR, shadeG, shadeB));
    let finalValue = mix(baseHSV.z, shadeHSV.z, blendFactor);
    let finalRGB = hsvToRgb(vec3<f32>(baseHSV.x, baseHSV.y, finalValue));

    return vec4<f32>(finalRGB, baseColor.a);
}
