// Scratches Pass 1 (Mask): generate intensity mask approximating worms trails.
@group(0) @binding(0) var samp : sampler;
@group(0) @binding(1) var inputTex : texture_2d<f32>;
@group(0) @binding(2) var<uniform> time : f32;
@group(0) @binding(3) var<uniform> speed : f32;
@group(0) @binding(4) var<uniform> seed : f32;

fn hash(p : vec2<f32>) -> f32 {
    let dot_val : f32 = dot(p, vec2<f32>(127.1, 311.7));
    return fract(sin(dot_val) * 43758.5453123);
}

fn stripe_pattern(pixel_pos : vec2<f32>, angle : f32, period : f32, thickness : f32, t : f32, resolution : vec2<f32>) -> f32 {
    let c : f32 = cos(angle);
    let s : f32 = sin(angle);
    let rotation : mat2x2<f32> = mat2x2<f32>(vec2<f32>(c, s), vec2<f32>(-s, c));
    let rotated : vec2<f32> = rotation * (pixel_pos - 0.5 * resolution);
    let phase : f32 = (rotated.y + t) / max(period, 1.0);
    let band : f32 = abs(fract(phase) - 0.5);
    return smoothstep(thickness, 0.0, band);
}

@fragment
fn main(@builtin(position) position : vec4<f32>) -> @location(0) vec4<f32> {
    let dims_u : vec2<u32> = textureDimensions(inputTex, 0);
    if (dims_u.x == 0u || dims_u.y == 0u) {
        return vec4<f32>(0.0);
    }

    let resolution : vec2<f32> = vec2<f32>(f32(dims_u.x), f32(dims_u.y));
    let pixel_pos : vec2<f32> = position.xy + vec2<f32>(0.5, 0.5);
    let uv : vec2<f32> = pixel_pos / resolution;

    let base_sample : vec4<f32> = textureSampleLevel(inputTex, samp, uv, 0.0);
    let luminance : f32 = dot(base_sample.rgb, vec3<f32>(0.299, 0.587, 0.114));

    let speed_scale : f32 = speed * 0.6 + 0.4;
    let time_offset : f32 = time * speed_scale * resolution.y;

    let h1 : f32 = hash(vec2<f32>(seed, 1.0));
    let h2 : f32 = hash(vec2<f32>(seed, 5.0));
    let h3 : f32 = hash(vec2<f32>(seed, 11.0));

    let stripes_a : f32 = stripe_pattern(pixel_pos, mix(-0.45, 0.35, h1), mix(60.0, 110.0, h2), 0.18, time_offset * 0.25, resolution);
    let stripes_b : f32 = stripe_pattern(pixel_pos, mix(-1.1, 1.1, h2), mix(40.0, 80.0, h3), 0.12, time_offset * 0.15, resolution);
    let stripes_c : f32 = stripe_pattern(pixel_pos, mix(-0.2, 0.2, h3), mix(90.0, 160.0, h1), 0.09, time_offset * 0.35, resolution);

    let noise_seed : vec2<f32> = pixel_pos / max(resolution, vec2<f32>(1.0, 1.0));
    let random_noise : f32 = hash(noise_seed + seed * 1.37 + time * 0.01);
    let base_influence : f32 = smoothstep(0.35, 0.85, luminance);

    var mask : f32 = stripes_a * 0.65 + stripes_b * 0.55 + stripes_c * 0.75;
    mask = max(mask, base_influence * 0.5);
    mask = clamp(mask + random_noise * 0.15, 0.0, 1.0);

    return vec4<f32>(mask, mask, mask, 1.0);
}
