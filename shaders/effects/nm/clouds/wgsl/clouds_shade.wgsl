// Clouds effect pass 2: Compute shaded mask from control texture
// Input: downsampleTex with control_raw in B channel
// Input: statsTex with global min/max for normalization
// Output: R=combined, G=shaded (offset + boosted + blurred), B=control_raw, A=1

@group(0) @binding(0) var downsampleTex: texture_2d<f32>;
@group(0) @binding(1) var statsTex: texture_2d<f32>;
@group(0) @binding(2) var<uniform> resolution: vec2<f32>;

const BLUR_RADIUS: i32 = 6;
const TRIPLE_GAUSS_KERNEL: array<f32, 13> = array<f32, 13>(
    0.0002441406,
    0.0029296875,
    0.0161132812,
    0.0537109375,
    0.1208496094,
    0.1933593750,
    0.2255859375,
    0.1933593750,
    0.1208496094,
    0.0537109375,
    0.0161132812,
    0.0029296875,
    0.0002441406,
);

fn clamp01(value: f32) -> f32 {
    return clamp(value, 0.0, 1.0);
}

fn wrap_index(value: i32, limit: i32) -> i32 {
    if (limit <= 0) {
        return 0;
    }
    var wrapped: i32 = value % limit;
    if (wrapped < 0) {
        wrapped = wrapped + limit;
    }
    return wrapped;
}

fn read_control_raw(coord: vec2<i32>, size: vec2<i32>) -> f32 {
    let width: i32 = max(size.x, 1);
    let height: i32 = max(size.y, 1);
    let safe_x: i32 = wrap_index(coord.x, width);
    let safe_y: i32 = wrap_index(coord.y, height);
    
    // Control is stored in B channel
    let val: vec4<f32> = textureLoad(downsampleTex, vec2<i32>(safe_x, safe_y), 0);
    return val.b;
}

fn normalize_control(raw_value: f32, min_value: f32, max_value: f32) -> f32 {
    let delta: f32 = max(max_value - min_value, 1e-6);
    return clamp((raw_value - min_value) / delta, 0.0, 1.0);
}

fn combined_from_normalized(control_norm: f32) -> f32 {
    // Python blend_layers(control, 1.0, ones, zeros):
    // - control in [0, 0.5]: result = 1 - control*2 (white fading to black)
    // - control >= 0.5: result = 0 (black)
    let scaled: f32 = control_norm * 2.0;
    return max(1.0 - scaled, 0.0);
}

fn blur_shade(coord: vec2<i32>, size: vec2<i32>, offset: vec2<i32>, min_value: f32, max_value: f32) -> f32 {
    let width: i32 = max(size.x, 1);
    let height: i32 = max(size.y, 1);
    
    var accum: f32 = 0.0;
    for (var dy: i32 = -BLUR_RADIUS; dy <= BLUR_RADIUS; dy = dy + 1) {
        let weight_y: f32 = TRIPLE_GAUSS_KERNEL[dy + BLUR_RADIUS];
        var row_accum: f32 = 0.0;
        for (var dx: i32 = -BLUR_RADIUS; dx <= BLUR_RADIUS; dx = dx + 1) {
            let weight_x: f32 = TRIPLE_GAUSS_KERNEL[dx + BLUR_RADIUS];
            
            let sample_coord: vec2<i32> = vec2<i32>(
                wrap_index(coord.x + dx + offset.x, width),
                wrap_index(coord.y + dy + offset.y, height)
            );
            
            // Read control, normalize, compute combined, boost
            let control_raw: f32 = read_control_raw(sample_coord, size);
            let control_norm: f32 = normalize_control(control_raw, min_value, max_value);
            let combined: f32 = combined_from_normalized(control_norm);
            let boosted: f32 = min(combined * 2.5, 1.0);
            row_accum = row_accum + boosted * weight_x;
        }
        accum = accum + row_accum * weight_y;
    }

    return clamp01(accum);
}

@fragment
fn main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let dims: vec2<f32> = resolution;
    
    if (pos.x >= dims.x || pos.y >= dims.y) {
        return vec4<f32>(0.0);
    }

    let size_i: vec2<i32> = vec2<i32>(i32(dims.x), i32(dims.y));
    let coord_i: vec2<i32> = vec2<i32>(i32(floor(pos.x)), i32(floor(pos.y)));
    
    // Read global min/max from stats texture (computed via reduction)
    let stats: vec4<f32> = textureLoad(statsTex, vec2<i32>(0, 0), 0);
    let min_value: f32 = stats.r;
    let max_value: f32 = stats.g;
    
    // Python uses randomInt(-15, 15) for offset; we use a deterministic pseudo-random based on resolution
    let hash_val: f32 = fract(sin(dot(dims, vec2<f32>(12.9898, 78.233))) * 43758.5453123);
    let offset_range: f32 = 15.0;
    let offset_x: i32 = i32(floor((hash_val * 2.0 - 1.0) * offset_range));
    let hash_val2: f32 = fract(sin(dot(dims, vec2<f32>(78.233, 12.9898))) * 43758.5453123);
    let offset_y: i32 = i32(floor((hash_val2 * 2.0 - 1.0) * offset_range));
    let offset_i: vec2<i32> = vec2<i32>(offset_x, offset_y);
    
    // Read control and compute normalized combined
    let control_raw: f32 = read_control_raw(coord_i, size_i);
    let control_norm: f32 = normalize_control(control_raw, min_value, max_value);
    let combined: f32 = combined_from_normalized(control_norm);
    
    // Compute blurred shade (3 blur passes equivalent via larger kernel)
    let shade: f32 = blur_shade(coord_i, size_i, offset_i, min_value, max_value);
    
    // Output: R=combined, G=shaded, B=control_raw (for upsample), A=1
    return vec4<f32>(combined, shade, control_raw, 1.0);
}
