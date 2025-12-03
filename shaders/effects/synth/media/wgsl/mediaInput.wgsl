/*
 * WGSL media input shader.
 * Mirrors the GLSL normalization and crop logic for camera feeds.
 * Coordinate remapping keeps offsets within bounds to avoid sampling garbage memory on the GPU path.
 */

@group(0) @binding(0) var<uniform> resolution: vec2<f32>;
@group(0) @binding(1) var<uniform> aspect: f32;
@group(0) @binding(2) var<uniform> time: f32;
@group(0) @binding(3) var<uniform> seed: f32;
@group(0) @binding(4) var<uniform> position: i32;
@group(0) @binding(5) var<uniform> rotation: f32;
@group(0) @binding(6) var<uniform> scaleAmt: f32;
@group(0) @binding(7) var<uniform> offsetX: f32;
@group(0) @binding(8) var<uniform> offsetY: f32;
@group(0) @binding(9) var<uniform> tiling: i32;
@group(0) @binding(10) var<uniform> flip: i32;
@group(0) @binding(11) var<uniform> backgroundColor: vec3<f32>;
@group(0) @binding(12) var<uniform> backgroundOpacity: f32;
@group(0) @binding(13) var<uniform> motionBlur: f32;
@group(0) @binding(14) var<uniform> imageSize: vec2<f32>;

@group(1) @binding(0) var imageTex: texture_2d<f32>;
@group(1) @binding(1) var imageSampler: sampler;
@group(1) @binding(2) var selfTex: texture_2d<f32>;
@group(1) @binding(3) var selfSampler: sampler;

const PI: f32 = 3.14159265359;
const TAU: f32 = 6.28318530718;

fn map(value: f32, inMin: f32, inMax: f32, outMin: f32, outMax: f32) -> f32 {
    return outMin + (outMax - outMin) * (value - inMin) / (inMax - inMin);
}

fn rotate2D(st: vec2<f32>) -> vec2<f32> {
    var st2 = st;
    let rot = map(rotation, -180.0, 180.0, 0.5, -0.5);
    let angle = rot * TAU * -1.0;

    let imgAspect = imageSize.x / imageSize.y;
    st2 = st2 - vec2<f32>(0.5 * imgAspect, 0.5);
    let c = cos(angle);
    let s = sin(angle);
    st2 = mat2x2<f32>(c, -s, s, c) * st2;
    st2 = st2 + vec2<f32>(0.5 * imgAspect, 0.5);
    return st2;
}

fn tile(st: vec2<f32>) -> vec2<f32> {
    if (tiling == 0) {
        return st;
    } else if (tiling == 1) {
        return fract(st);
    } else if (tiling == 2) {
        return vec2<f32>(fract(st.x), st.y);
    } else if (tiling == 3) {
        return vec2<f32>(st.x, fract(st.y));
    }
    return st;
}

fn getImage(pos: vec2<f32>) -> vec4<f32> {
    var st = pos / imageSize;
    st.y = 1.0 - st.y;

    var scale = 100.0 / scaleAmt;
    if (scale == 0.0) { scale = 1.0; }
    st = st * scale;

    if (position == 0) {
        st.y = st.y + (resolution.y / imageSize.y * scale) - (scale - (1.0 / imageSize.y * scale));
    } else if (position == 1) {
        st.x = st.x - (resolution.x / imageSize.x * scale * 0.5) + (0.5 - (1.0 / imageSize.x * scale));
        st.y = st.y + (resolution.y / imageSize.y * scale) - (scale - (1.0 / imageSize.y * scale));
    } else if (position == 2) {
        st.x = st.x - (resolution.x / imageSize.x * scale) + (1.0 - (1.0 / imageSize.x * scale));
        st.y = st.y + (resolution.y / imageSize.y * scale) - (scale - (1.0 / imageSize.y * scale));
    } else if (position == 3) {
        st.y = st.y + (resolution.y / imageSize.y * scale * 0.5) + (0.5 - (1.0 / imageSize.y * scale)) - scale;
    } else if (position == 4) {
        st.x = st.x - (resolution.x / imageSize.x * scale * 0.5) + (0.5 - (1.0 / imageSize.x * scale));
        st.y = st.y + (resolution.y / imageSize.y * scale * 0.5) + (0.5 - (1.0 / imageSize.y * scale)) - scale;
    } else if (position == 5) {
        st.x = st.x - (resolution.x / imageSize.x * scale) + (1.0 - (1.0 / imageSize.x * scale));
        st.y = st.y + (resolution.y / imageSize.y * scale * 0.5) + (0.5 - (1.0 / imageSize.y * scale)) - scale;
    } else if (position == 6) {
        st.y = st.y + 1.0 - (scale - (1.0 / imageSize.y * scale));
    } else if (position == 7) {
        st.x = st.x - (resolution.x / imageSize.x * scale * 0.5) + (0.5 - (1.0 / imageSize.x * scale));
        st.y = st.y + 1.0 - (scale - (1.0 / imageSize.y * scale));
    } else if (position == 8) {
        st.x = st.x - (resolution.x / imageSize.x * scale) + (1.0 - (1.0 / imageSize.x * scale));
        st.y = st.y + 1.0 - (scale - (1.0 / imageSize.y * scale));
    }

    st.x = st.x - map(offsetX, -100.0, 100.0, -resolution.x / imageSize.x * scale, resolution.x / imageSize.x * scale) * 1.5;
    st.y = st.y - map(offsetY, -100.0, 100.0, -resolution.y / imageSize.y * scale, resolution.y / imageSize.y * scale) * 1.5;

    st.x = st.x * (imageSize.x / imageSize.y);
    st = rotate2D(st);
    st.x = st.x / (imageSize.x / imageSize.y);

    st = tile(st);

    st = st + 1.0 / imageSize;

    if (flip == 1) {
        st.x = 1.0 - st.x;
        st.y = 1.0 - st.y;
    } else if (flip == 2) {
        st.x = 1.0 - st.x;
    } else if (flip == 3) {
        st.y = 1.0 - st.y;
    } else if (flip == 11) {
        if (st.x > 0.5) { st.x = 1.0 - st.x; }
    } else if (flip == 12) {
        if (st.x < 0.5) { st.x = 1.0 - st.x; }
    } else if (flip == 13) {
        if (st.y > 0.5) { st.y = 1.0 - st.y; }
    } else if (flip == 14) {
        if (st.y < 0.5) { st.y = 1.0 - st.y; }
    } else if (flip == 15) {
        if (st.x > 0.5) { st.x = 1.0 - st.x; }
        if (st.y > 0.5) { st.y = 1.0 - st.y; }
    } else if (flip == 16) {
        if (st.x > 0.5) { st.x = 1.0 - st.x; }
        if (st.y < 0.5) { st.y = 1.0 - st.y; }
    } else if (flip == 17) {
        if (st.x < 0.5) { st.x = 1.0 - st.x; }
        if (st.y > 0.5) { st.y = 1.0 - st.y; }
    } else if (flip == 18) {
        if (st.x < 0.5) { st.x = 1.0 - st.x; }
        if (st.y < 0.5) { st.y = 1.0 - st.y; }
    }

    var text = textureSample(imageTex, imageSampler, st);

    if (st.x < 0.0 || st.x > 1.0 || st.y < 0.0 || st.y > 1.0) {
        return vec4<f32>(backgroundColor, backgroundOpacity * 0.01);
    }

    text.r = text.r * text.a;
    text.g = text.g * text.a;
    text.b = text.b * text.a;
    return text;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    var st = pos.xy / resolution;
    st.y = 1.0 - st.y;

    let img = getImage(pos.xy);
    let prev = textureSample(selfTex, selfSampler, st);
    var color = mix(img, prev, motionBlur * 0.009);

    return color;
}
