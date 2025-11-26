// Worms effect - Agent update pass (render-based GPGPU)
// Updates agent positions based on flow field sampling
// Agent format: [pos.x, pos.y, heading_norm, age_norm]

// Packed uniform layout:
// data[0].xy = resolution
// data[0].z  = time
// data[0].w  = frame
// data[1].x  = stride
// data[1].y  = kink
// data[1].z  = quantize
// data[1].w  = behavior
// data[2].x  = lifetime

struct Uniforms {
    data : array<vec4<f32>, 3>,
};

@group(0) @binding(0) var u_sampler : sampler;
@group(0) @binding(1) var agentTex : texture_2d<f32>;
@group(0) @binding(2) var inputTex : texture_2d<f32>;
@group(0) @binding(3) var<uniform> uniforms : Uniforms;

const TAU : f32 = 6.283185307179586;
const PI : f32 = 3.14159265359;

fn hash21(p : vec2<f32>) -> f32 {
    var p3 = fract(vec3<f32>(p.x, p.y, p.x) * 0.1031);
    p3 = p3 + dot(p3, p3.zyx + 31.32);
    return fract((p3.x + p3.y) * p3.z);
}

fn rand(seed : ptr<function, f32>) -> f32 {
    *seed = fract(*seed * 43758.5453123 + 0.2137);
    return *seed;
}

fn wrap01(value : vec2<f32>) -> vec2<f32> {
    return fract(value);
}

fn spawnPosition(coord : vec2<f32>, seed : ptr<function, f32>) -> vec2<f32> {
    let rx = rand(seed);
    let ry = rand(seed);
    return vec2<f32>(rx, ry);
}

fn spawnHeading(coord : vec2<f32>, seed : f32) -> f32 {
    return hash21(coord + seed * 13.1) * TAU - PI;
}

fn srgb_to_linear(value : f32) -> f32 {
    if (value <= 0.04045) {
        return value / 12.92;
    }
    return pow((value + 0.055) / 1.055, 2.4);
}

fn cube_root(value : f32) -> f32 {
    if (value == 0.0) {
        return 0.0;
    }
    let sign_value = select(-1.0, 1.0, value >= 0.0);
    return sign_value * pow(abs(value), 1.0 / 3.0);
}

fn oklab_l(rgb : vec3<f32>) -> f32 {
    let r_lin = srgb_to_linear(clamp(rgb.x, 0.0, 1.0));
    let g_lin = srgb_to_linear(clamp(rgb.y, 0.0, 1.0));
    let b_lin = srgb_to_linear(clamp(rgb.z, 0.0, 1.0));

    let l = 0.4121656120 * r_lin + 0.5362752080 * g_lin + 0.0514575653 * b_lin;
    let m = 0.2118591070 * r_lin + 0.6807189584 * g_lin + 0.1074065790 * b_lin;
    let s = 0.0883097947 * r_lin + 0.2818474174 * g_lin + 0.6302613616 * b_lin;

    let l_c = cube_root(l);
    let m_c = cube_root(m);
    let s_c = cube_root(s);

    return 0.2104542553 * l_c + 0.7936177850 * m_c - 0.0040720468 * s_c;
}

@fragment
fn main(@builtin(position) position : vec4<f32>) -> @location(0) vec4<f32> {
    // Unpack uniforms
    let resolution = uniforms.data[0].xy;
    let time = uniforms.data[0].z;
    let frame = i32(uniforms.data[0].w);
    let stride = uniforms.data[1].x;
    let kink = uniforms.data[1].y;
    let quantize = uniforms.data[1].z;
    let behavior = uniforms.data[1].w;
    let lifetime = uniforms.data[2].x;

    let dims = textureDimensions(agentTex, 0);
    let uv = (position.xy - 0.5) / vec2<f32>(dims);

    // Agent format: [pos.x, pos.y, heading_norm, age_norm]
    let state = textureSampleLevel(agentTex, u_sampler, uv, 0.0);
    var pos = state.xy;              // normalized 0-1
    var headingNorm = state.z;       // normalized heading
    var ageNorm = state.w;           // normalized age

    var heading = headingNorm * TAU - PI;
    let maxLifetime = max(lifetime, 1.0);
    var age = ageNorm * maxLifetime;

    var noiseSeed = hash21(uv + f32(frame) * 0.013 + time * 0.11);

    // Initial spawn on first frame or uninitialized agent
    if (frame <= 1 || (pos.x == 0.0 && pos.y == 0.0)) {
        pos = spawnPosition(uv, &noiseSeed);
        heading = spawnHeading(uv, noiseSeed);
        age = 0.0;
    }

    // Respawn when lifetime exceeded
    if (age > maxLifetime) {
        pos = spawnPosition(uv + 0.17, &noiseSeed);
        heading = spawnHeading(uv + 0.53, noiseSeed);
        age = 0.0;
    }

    // Sample input texture at agent position
    let texel_here = textureSampleLevel(inputTex, u_sampler, pos, 0.0);
    let index_value = oklab_l(texel_here.rgb);

    let behavior_mode = i32(floor(behavior + 0.5));
    var rotation_bias : f32;

    if (behavior_mode <= 0) {
        // No behavior - pure index-driven
        rotation_bias = 0.0;
    } else if (behavior_mode == 10) {
        // Meandering - oscillate based on time
        let phase = fract(headingNorm);
        rotation_bias = sin((time - phase) * TAU) * 0.5 + 0.5;
        rotation_bias = rotation_bias * TAU - PI;
    } else {
        // Obedient and others - maintain heading bias
        rotation_bias = heading;
    }

    var final_angle = index_value * TAU * kink + rotation_bias;

    if (quantize > 0.5) {
        final_angle = round(final_angle / (PI * 0.25)) * (PI * 0.25);
    }

    // Update position (normalized)
    let speedPixels = max(stride, 0.1);
    let step = speedPixels / max(resolution.x, resolution.y);
    let dir = vec2<f32>(cos(final_angle), sin(final_angle));
    pos = wrap01(pos + dir * step);

    age = age + 1.0;

    // Pack output
    let headingOut = fract((heading + PI) / TAU);
    let ageOut = clamp(age / maxLifetime, 0.0, 1.0);
    return vec4<f32>(pos, headingOut, ageOut);
}
