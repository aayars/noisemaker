// Erosion Worms - Agent update pass (render-based GPGPU)
// Updates agent positions based on luminance gradient
// Agent format: [pos.x, pos.y, heading_norm, age_norm]

// Packed uniform layout:
// data[0].xy = resolution
// data[0].z  = time
// data[0].w  = frame
// data[1].x  = density
// data[1].y  = stride
// data[1].z  = quantize (0 or 1)
// data[1].w  = inverse (0 or 1)
// data[2].x  = xy_blend (0 or 1)
// data[2].y  = worm_lifetime

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

fn sampleGradient(uv : vec2<f32>, resolution : vec2<f32>) -> vec2<f32> {
    let texel = vec2<f32>(1.0) / resolution;
    let c = textureSampleLevel(inputTex, u_sampler, uv, 0.0).rgb;
    let cx1 = textureSampleLevel(inputTex, u_sampler, uv + vec2<f32>(texel.x, 0.0), 0.0).rgb;
    let cx2 = textureSampleLevel(inputTex, u_sampler, uv - vec2<f32>(texel.x, 0.0), 0.0).rgb;
    let cy1 = textureSampleLevel(inputTex, u_sampler, uv + vec2<f32>(0.0, texel.y), 0.0).rgb;
    let cy2 = textureSampleLevel(inputTex, u_sampler, uv - vec2<f32>(0.0, texel.y), 0.0).rgb;
    let luma = vec3<f32>(0.299, 0.587, 0.114);
    let gx = dot(cx1 - cx2, luma);
    let gy = dot(cy1 - cy2, luma);
    var grad = vec2<f32>(gx, gy);
    if (length(grad) < 1e-4) {
        return vec2<f32>(0.0, 1.0);
    }
    return normalize(grad);
}

@fragment
fn main(@builtin(position) position : vec4<f32>) -> @location(0) vec4<f32> {
    // Unpack uniforms
    let resolution = uniforms.data[0].xy;
    let time = uniforms.data[0].z;
    let frame = i32(uniforms.data[0].w);
    let density = uniforms.data[1].x;
    let stride = uniforms.data[1].y;
    let quantize = uniforms.data[1].z > 0.5;
    let inverse = uniforms.data[1].w > 0.5;
    let xy_blend = uniforms.data[2].x > 0.5;
    let worm_lifetime = uniforms.data[2].y;

    let dims = textureDimensions(agentTex, 0);
    let uv = (position.xy - 0.5) / vec2<f32>(dims);

    // Agent format: [pos.x, pos.y, heading_norm, age_norm]
    let state = textureSampleLevel(agentTex, u_sampler, uv, 0.0);
    var pos = state.xy;
    var headingNorm = state.z;
    var ageNorm = state.w;

    var heading = headingNorm * TAU - PI;
    let lifetime = max(worm_lifetime, 1.0);
    var age = ageNorm * lifetime;

    var noiseSeed = hash21(uv + f32(frame) * 0.013 + time * 0.11);

    // Initial spawn on first frame or uninitialized agent
    if (frame <= 1 || (pos.x == 0.0 && pos.y == 0.0)) {
        pos = spawnPosition(uv, &noiseSeed);
        heading = spawnHeading(uv, noiseSeed);
        age = 0.0;
    }

    // Respawn when lifetime exceeded
    if (age > lifetime) {
        pos = spawnPosition(uv + 0.17, &noiseSeed);
        heading = spawnHeading(uv + 0.53, noiseSeed);
        age = 0.0;
    }

    // Sample gradient at agent position
    var grad = sampleGradient(pos, resolution);
    
    if (xy_blend) {
        grad = normalize(grad + vec2<f32>(grad.y, -grad.x));
    }
    if (quantize) {
        grad = sign(grad);
        if (grad.x == 0.0 && grad.y == 0.0) {
            grad = vec2<f32>(1.0, 0.0);
        }
        grad = normalize(grad);
    }
    if (inverse) {
        grad = -grad;
    }

    // Steer towards gradient with inertia
    let steer = atan2(grad.y, grad.x);
    let inertia = mix(0.6, 0.92, clamp(density / 100.0, 0.0, 1.0));
    heading = mix(heading, steer, 1.0 - inertia);
    heading = heading + (rand(&noiseSeed) - 0.5) * 0.35;

    // Update position
    let speedPixels = max(stride, 0.1);
    let step = speedPixels / max(resolution.x, resolution.y);
    let dir = vec2<f32>(cos(heading), sin(heading));
    pos = wrap01(pos + dir * step);

    age = age + 1.0;

    // Pack output
    let headingOut = fract((heading + PI) / TAU);
    let ageOut = clamp(age / lifetime, 0.0, 1.0);
    return vec4<f32>(pos, headingOut, ageOut);
}
