/*
 * WGSL feedback synthesizer shader.
 * Resamples the prior frame with rotation, aberration, and hue adjustments to build evolving feedback textures.
 * Distortion and scale ranges are clamped so the sampling coordinates stay within the framebuffer over long sessions.
 */

struct Uniforms {
    resolution: vec2<f32>,
    time: f32,
    frame: f32,
    seed: f32,
    scaleAmt: f32,
    rotation: f32,
    translateX: f32,
    translateY: f32,
    mixAmt: f32,
    hueRotation: f32,
    intensity: f32,
    distortion: f32,
    aberrationAmt: f32,
    aspectLens: f32,
    _pad0: f32,
    _pad1: f32,
};
@group(0) @binding(0) var<uniform> uniforms: Uniforms;
@group(0) @binding(1) var samp: sampler;
@group(0) @binding(2) var selfTex: texture_2d<f32>;

const PI: f32 = 3.14159265359;
const TAU: f32 = 6.28318530718;

fn random(st: vec2<f32>) -> f32 {
    return fract(sin(dot(st, vec2<f32>(12.9898, 78.233))) * 43758.5453123);
}

fn map(value: f32, inMin: f32, inMax: f32, outMin: f32, outMax: f32) -> f32 {
    return outMin + (outMax - outMin) * (value - inMin) / (inMax - inMin);
}

fn brightnessContrast(color: vec3<f32>, intensity: f32) -> vec3<f32> {
    let bright = map(intensity * 0.1, -100.0, 100.0, -0.5, 0.5);
    let cont = map(intensity * 0.1, -100.0, 100.0, 0.5, 1.5);
    return (color - 0.5) * cont + 0.5 + bright;
}

fn rotate2D(st: vec2<f32>, rot: f32, aspectRatio: f32) -> vec2<f32> {
    var st2 = st;
    st2.x = st2.x * aspectRatio;
    let r = map(rot, 0.0, 360.0, 0.0, 2.0);
    let angle = r * PI;
    st2 = st2 - vec2<f32>(0.5 * aspectRatio, 0.5);
    let s = sin(angle);
    let c = cos(angle);
    st2 = mat2x2<f32>(c, -s, s, c) * st2;
    st2 = st2 + vec2<f32>(0.5 * aspectRatio, 0.5);
    st2.x = st2.x / aspectRatio;
    return st2;
}

fn hsv2rgb(hsv: vec3<f32>) -> vec3<f32> {
    let h = fract(hsv.x);
    let s = hsv.y;
    let v = hsv.z;
    
    let c = v * s;
    let x = c * (1.0 - abs(h * 6.0 % 2.0 - 1.0));
    let m = v - c;

    var rgb: vec3<f32>;
    if (h < 1.0/6.0) {
        rgb = vec3<f32>(c, x, 0.0);
    } else if (h < 2.0/6.0) {
        rgb = vec3<f32>(x, c, 0.0);
    } else if (h < 3.0/6.0) {
        rgb = vec3<f32>(0.0, c, x);
    } else if (h < 4.0/6.0) {
        rgb = vec3<f32>(0.0, x, c);
    } else if (h < 5.0/6.0) {
        rgb = vec3<f32>(x, 0.0, c);
    } else {
        rgb = vec3<f32>(c, 0.0, x);
    }

    return rgb + vec3<f32>(m, m, m);
}

fn rgb2hsv(rgb: vec3<f32>) -> vec3<f32> {
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
    if (h < 0.0) {
        h = h + 1.0;
    }
    
    var s: f32 = 0.0;
    if (maxC != 0.0) {
        s = delta / maxC;
    }
    let v = maxC;

    return vec3<f32>(h, s, v);
}

fn getImage(pos: vec2<f32>, resolution: vec2<f32>, aspectRatio: f32) -> vec4<f32> {
    var st = pos / resolution;
    st.y = 1.0 - st.y;
    
    st = rotate2D(st, uniforms.rotation, aspectRatio);

    // aberration and lensing
    var diff = vec2<f32>(0.5, 0.5) - st;
    if (uniforms.aspectLens > 0.5) {
        diff = vec2<f32>(0.5 * aspectRatio, 0.5) - vec2<f32>(st.x * aspectRatio, st.y);
    }
    let centerDist = length(diff);

    var distort: f32 = 0.0;
    var zoom: f32 = 0.0;
    if (uniforms.distortion < 0.0) {
        distort = map(uniforms.distortion, -100.0, 0.0, -2.0, 0.0);
        zoom = map(uniforms.distortion, -100.0, 0.0, 0.04, 0.0);
    } else {
        distort = map(uniforms.distortion, 0.0, 100.0, 0.0, 2.0);
        zoom = map(uniforms.distortion, 0.0, 100.0, 0.0, -1.0);
    }

    st = fract((st - diff * zoom) - diff * centerDist * centerDist * distort);

    var scale = 100.0 / uniforms.scaleAmt;
    if (scale == 0.0) {
        scale = 1.0;
    }
    st = st * scale;
    
    // mid center
    st.x = st.x - (scale * 0.5) + (0.5 - (1.0 / resolution.x * scale));
    st.y = st.y + (scale * 0.5) + (0.5 - (1.0 / resolution.y * scale)) - scale;

    // nudge by one pixel, otherwise it drifts for reasons unknown
    st = st + 1.0 / resolution;

    // tile
    st = fract(st);

    // chromatic aberration
    let aberrationOffset = map(uniforms.aberrationAmt, 0.0, 100.0, 0.0, 0.1) * centerDist * PI * 0.5;

    let redOffset = mix(clamp(st.x + aberrationOffset, 0.0, 1.0), st.x, st.x);
    let red = textureSample(selfTex, samp, vec2<f32>(redOffset, st.y));

    let green = textureSample(selfTex, samp, st);

    let blueOffset = mix(st.x, clamp(st.x - aberrationOffset, 0.0, 1.0), st.x);
    let blue = textureSample(selfTex, samp, vec2<f32>(blueOffset, st.y));

    var text = vec4<f32>(red.r, green.g, blue.b, 1.0);
    
    // premultiply texture alpha
    text = vec4<f32>(text.rgb * text.a, text.a);
    
    return text;
}

@fragment
fn main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let resolution = uniforms.resolution;
    let aspectRatio = resolution.x / resolution.y;

    // Initialize with noise for first 60 frames
    if (uniforms.frame < 60.0) {
        let uv = pos.xy / resolution;
        let r = random(uv + uniforms.seed);
        return vec4<f32>(vec3<f32>(r), 1.0);
    }

    var color = getImage(pos.xy, resolution, aspectRatio);

    // Hue rotation
    var hsv = rgb2hsv(color.rgb);
    hsv.x = (hsv.x + map(uniforms.hueRotation, -180.0, 180.0, -0.05, 0.05)) % 1.0;
    if (hsv.x < 0.0) {
        hsv.x = hsv.x + 1.0;
    }
    color = vec4<f32>(hsv2rgb(hsv), color.a);

    // Brightness/contrast
    color = vec4<f32>(brightnessContrast(color.rgb, uniforms.intensity), color.a);

    return color;
}
