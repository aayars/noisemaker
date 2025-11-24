// Matches the host-side post-processing uniform layout: four vec4<f32> entries
// for alignment with gpu.js buffer packing.
struct Uniforms {
    data : array<vec4<f32>, 4>,
};
// Group 0 bindings align with the WebGPU pipeline configuration in gpu.js.
@group(0) @binding(0) var<uniform> uniforms : Uniforms;
@group(0) @binding(1) var samp : sampler;
@group(0) @binding(2) var srcTex : texture_2d<f32>;

fn rgb2hsv(c: vec3<f32>) -> vec3<f32> {
    let coefficients: vec4<f32> = vec4<f32>(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    let mixPrimary: vec4<f32> = mix(
        vec4<f32>(c.bg, coefficients.wz),
        vec4<f32>(c.gb, coefficients.xy),
        step(c.b, c.g),
    );
    let mixSecondary: vec4<f32> = mix(
        vec4<f32>(mixPrimary.xyw, c.r),
        vec4<f32>(c.r, mixPrimary.yzx),
        step(mixPrimary.x, c.r),
    );
    let delta: f32 = mixSecondary.x - min(mixSecondary.w, mixSecondary.y);
    let epsilon: f32 = 1.0e-10;
    return vec3<f32>(
        abs(mixSecondary.z + (mixSecondary.w - mixSecondary.y) / (6.0 * delta + epsilon)),
        delta / (mixSecondary.x + epsilon),
        mixSecondary.x,
    );
}

fn hsv2rgb(hsv: vec3<f32>) -> vec3<f32> {
    let h: f32 = fract(hsv.x);
    let s: f32 = hsv.y;
    let v: f32 = hsv.z;

    let chroma: f32 = v * s;
    let scaledHue: f32 = h * 6.0;
    let foldedHue: f32 = scaledHue - 2.0 * floor(scaledHue / 2.0);
    let intermediate: f32 = chroma * (1.0 - abs(foldedHue - 1.0));
    let matchValue: f32 = v - chroma;

    var rgb: vec3<f32> = vec3<f32>(0.0, 0.0, 0.0);
    let hueSector: i32 = i32(floor(scaledHue));
    switch (hueSector) {
        case 0: {
            rgb = vec3<f32>(chroma, intermediate, 0.0);
        }
        case 1: {
            rgb = vec3<f32>(intermediate, chroma, 0.0);
        }
        case 2: {
            rgb = vec3<f32>(0.0, chroma, intermediate);
        }
        case 3: {
            rgb = vec3<f32>(0.0, intermediate, chroma);
        }
        case 4: {
            rgb = vec3<f32>(intermediate, 0.0, chroma);
        }
        default: {
            rgb = vec3<f32>(chroma, 0.0, intermediate);
        }
    }
    return rgb + vec3<f32>(matchValue, matchValue, matchValue);
}

@fragment
fn main(@builtin(position) pos : vec4<f32>) -> @location(0) vec4<f32> {
    let resolution: vec2<f32> = uniforms.data[0].xy;
    let brightness: f32 = uniforms.data[1].x;
    let contrast: f32 = uniforms.data[1].y;
    let hueDegrees: f32 = uniforms.data[1].z;
    let saturationAdjust: f32 = uniforms.data[1].w;

    // Fragment positions follow the WGSL upper-left origin convention.
    let uv: vec2<f32> = pos.xy / resolution;
    var color: vec3<f32> = textureSample(srcTex, samp, uv).rgb;

    var hsv: vec3<f32> = rgb2hsv(color);
    hsv.x = hsv.x + hueDegrees / 360.0;
    hsv.y = clamp(hsv.y * (1.0 + saturationAdjust), 0.0, 1.0);
    color = hsv2rgb(hsv);

    color = color + vec3<f32>(brightness, brightness, brightness);
    color = (color - vec3<f32>(0.5, 0.5, 0.5)) * (1.0 + contrast) + vec3<f32>(0.5, 0.5, 0.5);
    color = clamp(color, vec3<f32>(0.0, 0.0, 0.0), vec3<f32>(1.0, 1.0, 1.0));
    return vec4<f32>(color, 1.0);
}
