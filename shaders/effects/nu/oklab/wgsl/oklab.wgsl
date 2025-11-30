/*
 * OKLab reinterpretation effect
 * Treats input RGB channels as OKLab values and converts to RGB
 */

@group(0) @binding(0) var inputSampler: sampler;
@group(0) @binding(1) var inputTex: texture_2d<f32>;

// OKLab to linear sRGB matrices
const fwdA = mat3x3<f32>(
    vec3<f32>(1.0, 1.0, 1.0),
    vec3<f32>(0.3963377774, -0.1055613458, -0.0894841775),
    vec3<f32>(0.2158037573, -0.0638541728, -1.2914855480)
);

const fwdB = mat3x3<f32>(
    vec3<f32>(4.0767245293, -1.2681437731, -0.0041119885),
    vec3<f32>(-3.3072168827, 2.6093323231, -0.7034763098),
    vec3<f32>(0.2307590544, -0.3411344290, 1.7068625689)
);

fn linear_srgb_from_oklab(c: vec3<f32>) -> vec3<f32> {
    let lms = fwdA * c;
    return fwdB * (lms * lms * lms);
}

fn linearToSrgb(linear: vec3<f32>) -> vec3<f32> {
    var srgb: vec3<f32>;
    for (var i: i32 = 0; i < 3; i = i + 1) {
        if (linear[i] <= 0.0031308) {
            srgb[i] = linear[i] * 12.92;
        } else {
            srgb[i] = 1.055 * pow(linear[i], 1.0 / 2.4) - 0.055;
        }
    }
    return srgb;
}

@fragment
fn main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let texSize = vec2<f32>(textureDimensions(inputTex));
    let uv = pos.xy / texSize;
    var color = textureSample(inputTex, inputSampler, uv);

    // Remap RGB to OKLab range and convert
    // magic values from py-noisemaker
    var lab = color.rgb;
    lab.g = lab.g * -0.509 + 0.276;
    lab.b = lab.b * -0.509 + 0.198;

    var rgb = linear_srgb_from_oklab(lab);
    rgb = linearToSrgb(rgb);

    return vec4<f32>(rgb, color.a);
}
