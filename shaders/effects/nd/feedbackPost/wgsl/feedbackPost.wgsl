/*
 * Feedback post-processing shader (WGSL port).
 * Offers mixer blend modes alongside hue, distortion, and brightness controls for the accumulated feedback buffer.
 */

@group(0) @binding(0) var samp: sampler;
@group(0) @binding(1) var inputTex: texture_2d<f32>;
@group(0) @binding(2) var selfTex: texture_2d<f32>;
@group(0) @binding(3) var<uniform> u: Uniforms;

struct Uniforms {
    time: f32,
    deltaTime: f32,
    frame: i32,
    _pad0: f32,
    resolution: vec2f,
    aspect: f32,
    // Effect params in definition.js globals order:
    seed: i32,
    blendMode: i32,
    mixAmt: f32,
    scaleAmt: f32,
    rotation: f32,
    refractAAmt: f32,
    refractBAmt: f32,
    refractADir: f32,
    refractBDir: f32,
    hueRotation: f32,
    intensity: f32,
    aberrationAmt: f32,
    distortion: f32,
    aspectLens: i32,
}

const PI: f32 = 3.14159265359;
const TAU: f32 = 6.28318530718;

fn aspectRatio() -> f32 {
    return u.resolution.x / u.resolution.y;
}

fn mapRange(value: f32, inMin: f32, inMax: f32, outMin: f32, outMax: f32) -> f32 {
    return outMin + (outMax - outMin) * (value - inMin) / (inMax - inMin);
}

fn blendOverlay(a: f32, b: f32) -> f32 {
    return select(1.0 - 2.0 * (1.0 - a) * (1.0 - b), 2.0 * a * b, a < 0.5);
}

fn blendSoftLight(base: f32, blend: f32) -> f32 {
    return select(sqrt(base) * (2.0 * blend - 1.0) + 2.0 * base * (1.0 - blend), 2.0 * base * blend + base * base * (1.0 - 2.0 * blend), blend < 0.5);
}

fn hsv2rgb(hsv: vec3f) -> vec3f {
    let h = fract(hsv.x);
    let s = hsv.y;
    let v = hsv.z;
    let c = v * s;
    let x = c * (1.0 - abs(fract(h * 6.0) * 2.0 - 1.0));
    let m = v - c;
    var rgb: vec3f;
    if (h < 1.0/6.0) { rgb = vec3f(c, x, 0.0); }
    else if (h < 2.0/6.0) { rgb = vec3f(x, c, 0.0); }
    else if (h < 3.0/6.0) { rgb = vec3f(0.0, c, x); }
    else if (h < 4.0/6.0) { rgb = vec3f(0.0, x, c); }
    else if (h < 5.0/6.0) { rgb = vec3f(x, 0.0, c); }
    else { rgb = vec3f(c, 0.0, x); }
    return rgb + vec3f(m);
}

fn rgb2hsv(rgb: vec3f) -> vec3f {
    let maxC = max(rgb.r, max(rgb.g, rgb.b));
    let minC = min(rgb.r, min(rgb.g, rgb.b));
    let delta = maxC - minC;
    var h = 0.0;
    if (delta != 0.0) {
        if (maxC == rgb.r) { h = ((rgb.g - rgb.b) / delta) % 6.0 / 6.0; }
        else if (maxC == rgb.g) { h = ((rgb.b - rgb.r) / delta + 2.0) / 6.0; }
        else { h = ((rgb.r - rgb.g) / delta + 4.0) / 6.0; }
    }
    let s = select(0.0, delta / maxC, maxC != 0.0);
    return vec3f(h, s, maxC);
}

fn cloak(st: vec2f) -> vec4f {
    let m = mapRange(u.mixAmt, 0.0, 100.0, 0.0, 1.0);
    let ra = mapRange(u.refractAAmt, 0.0, 100.0, 0.0, 0.125);
    let rb = mapRange(u.refractBAmt, 0.0, 100.0, 0.0, 0.125);

    let leftColor = textureSample(inputTex, samp, st);
    let rightColor = textureSample(selfTex, samp, st);

    var leftUV = st;
    let rightLen = length(rightColor.rgb);
    leftUV.x += cos(rightLen * TAU) * ra;
    leftUV.y += sin(rightLen * TAU) * ra;
    let leftRefracted = textureSample(inputTex, samp, fract(leftUV));

    var rightUV = st;
    let leftLen = length(leftColor.rgb);
    rightUV.x += cos(leftLen * TAU) * rb;
    rightUV.y += sin(leftLen * TAU) * rb;
    let rightRefracted = textureSample(selfTex, samp, fract(rightUV));

    let leftReflected = min(rightRefracted * rightColor / (1.0 - leftRefracted * leftColor), vec4f(1.0));
    let rightReflected = min(leftRefracted * leftColor / (1.0 - rightRefracted * rightColor), vec4f(1.0));

    var left = vec4f(1.0);
    var right = vec4f(1.0);
    if (u.mixAmt < 50.0) {
        left = mix(leftRefracted, leftReflected, mapRange(u.mixAmt, 0.0, 50.0, 0.0, 1.0));
        right = rightReflected;
    } else {
        left = leftReflected;
        right = mix(rightReflected, rightRefracted, mapRange(u.mixAmt, 50.0, 100.0, 0.0, 1.0));
    }

    return mix(left, right, m);
}

fn blend(color1: vec4f, color2: vec4f, mode: i32, factor: f32) -> vec4f {
    let amt = mapRange(u.mixAmt, 0.0, 100.0, 0.0, 1.0);
    var middle = vec4f(0.0);

    if (mode == 0) { middle = min(color1 + color2, vec4f(1.0)); }
    else if (mode == 2) { middle = select(max((1.0 - ((1.0 - color1) / color2)), vec4f(0.0)), color2, color2 == vec4f(0.0)); }
    else if (mode == 3) { middle = select(min(color1 / (1.0 - color2), vec4f(1.0)), color2, color2 == vec4f(1.0)); }
    else if (mode == 4) { middle = min(color1, color2); }
    else if (mode == 5) { middle = vec4f(abs(color1.rgb - color2.rgb), max(color1.a, color2.a)); }
    else if (mode == 6) { middle = vec4f((color1.rgb + color2.rgb - 2.0 * color1.rgb * color2.rgb), max(color1.a, color2.a)); }
    else if (mode == 7) { middle = select(min(color1 * color1 / (1.0 - color2), vec4f(1.0)), color2, color2 == vec4f(1.0)); }
    else if (mode == 8) { middle = vec4f(blendOverlay(color2.r, color1.r), blendOverlay(color2.g, color1.g), blendOverlay(color2.b, color1.b), mix(color1.a, color2.a, 0.5)); }
    else if (mode == 9) { middle = max(color1, color2); }
    else if (mode == 10) { middle = mix(color1, color2, 0.5); }
    else if (mode == 11) { middle = color1 * color2; }
    else if (mode == 12) { middle = vec4f((vec3f(1.0) - abs(vec3f(1.0) - color1.rgb - color2.rgb)), max(color1.a, color2.a)); }
    else if (mode == 13) { middle = vec4f(blendOverlay(color1.r, color2.r), blendOverlay(color1.g, color2.g), blendOverlay(color1.b, color2.b), mix(color1.a, color2.a, 0.5)); }
    else if (mode == 14) { middle = min(color1, color2) - max(color1, color2) + vec4f(1.0); }
    else if (mode == 15) { middle = select(min(color2 * color2 / (1.0 - color1), vec4f(1.0)), color1, color1 == vec4f(1.0)); }
    else if (mode == 16) { middle = 1.0 - ((1.0 - color1) * (1.0 - color2)); }
    else if (mode == 17) { middle = vec4f(blendSoftLight(color1.r, color2.r), blendSoftLight(color1.g, color2.g), blendSoftLight(color1.b, color2.b), mix(color1.a, color2.a, 0.5)); }
    else if (mode == 18) { middle = max(color1 + color2 - 1.0, vec4f(0.0)); }

    var color = middle;
    var f = factor;
    if (f == 0.5) { color = middle; }
    else if (f < 0.5) { f = mapRange(amt, 0.0, 0.5, 0.0, 1.0); color = mix(color1, middle, f); }
    else { f = mapRange(amt, 0.5, 1.0, 0.0, 1.0); color = mix(middle, color2, f); }

    return color;
}

fn brightnessContrast(color: vec3f) -> vec3f {
    let bright = mapRange(u.intensity * 0.1, -100.0, 100.0, -0.5, 0.5);
    let cont = mapRange(u.intensity * 0.1, -100.0, 100.0, 0.5, 1.5);
    return (color - 0.5) * cont + 0.5 + bright;
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

fn getImage(st_in: vec2f) -> vec4f {
    var st = rotate2D(st_in, u.rotation);

    var diff = 0.5 - st;
    if (u.aspectLens != 0) {
        diff = vec2f(0.5 * aspectRatio(), 0.5) - vec2f(st.x * aspectRatio(), st.y);
    }
    let centerDist = length(diff);

    var distort = 0.0;
    var zoom = 0.0;
    if (u.distortion < 0.0) {
        distort = mapRange(u.distortion, -100.0, 0.0, -2.0, 0.0);
        zoom = mapRange(u.distortion, -100.0, 0.0, 0.04, 0.0);
    } else {
        distort = mapRange(u.distortion, 0.0, 100.0, 0.0, 2.0);
        zoom = mapRange(u.distortion, 0.0, 100.0, 0.0, -1.0);
    }

    st = (st - diff * zoom) - diff * centerDist * centerDist * distort;

    var scale = 100.0 / u.scaleAmt;
    if (scale == 0.0) { scale = 1.0; }
    st *= scale;

    st.x -= (scale * 0.5) - (0.5 - (1.0 / u.resolution.x * scale));
    st.y += (scale * 0.5) + (0.5 - (1.0 / u.resolution.y * scale)) - scale;
    st += 1.0 / u.resolution;
    st = fract(st);

    let aberrationOffset = mapRange(u.aberrationAmt, 0.0, 100.0, 0.0, 0.1) * centerDist * PI * 0.5;
    let redOffset = mix(clamp(st.x + aberrationOffset, 0.0, 1.0), st.x, st.x);
    let red = textureSample(inputTex, samp, vec2f(redOffset, st.y));
    let green = textureSample(inputTex, samp, st);
    let blueOffset = mix(st.x, clamp(st.x - aberrationOffset, 0.0, 1.0), st.x);
    let blue = textureSample(inputTex, samp, vec2f(blueOffset, st.y));

    var text = vec4f(red.r, green.g, blue.b, 1.0);
    text = vec4f(text.rgb * text.a, text.a);
    return text;
}

@fragment
fn main(@builtin(position) fragCoord: vec4f) -> @location(0) vec4f {
    var uv = fragCoord.xy / u.resolution;
    uv.y = 1.0 - uv.y;

    var color = vec4f(0.0);

    if (u.blendMode == 100) {
        color = cloak(uv);
    } else {
        let ra = mapRange(u.refractAAmt, 0.0, 100.0, 0.0, 0.125);
        let rb = mapRange(u.refractBAmt, 0.0, 100.0, 0.0, 0.125);

        let leftColor = textureSample(inputTex, samp, uv);
        let rightColor = textureSample(selfTex, samp, uv);

        var leftUV = uv;
        let rightLen = length(rightColor.rgb) + u.refractADir / 360.0;
        leftUV.x += cos(rightLen * TAU) * ra;
        leftUV.y += sin(rightLen * TAU) * ra;

        var rightUV = uv;
        let leftLen = length(leftColor.rgb) + u.refractBDir / 360.0;
        rightUV.x += cos(leftLen * TAU) * rb;
        rightUV.y += sin(leftLen * TAU) * rb;

        color = blend(textureSample(inputTex, samp, leftUV), getImage(rightUV), u.blendMode, u.mixAmt * 0.01);
    }

    var hsv = rgb2hsv(color.rgb);
    hsv.x = (hsv.x + mapRange(u.hueRotation, -180.0, 180.0, -0.05, 0.05)) % 1.0;
    if (hsv.x < 0.0) { hsv.x += 1.0; }
    color = vec4f(hsv2rgb(hsv), color.a);

    color = vec4f(brightnessContrast(color.rgb), color.a);

    return color;
}
