// Multi-octave image "reverberation" effect mirroring the CPU implementation.
// The shader optionally ridge-transforms the input image and accumulates tiled,
// downsampled layers across the requested octaves and iterations. Each layer
// averages the contributing source pixels so the result matches the reference
// proportional downsample + expand tile CPU implementation.

@group(0) @binding(0) var input_texture: texture_2d<f32>;
@group(0) @binding(1) var<uniform> octaves: i32;
@group(0) @binding(2) var<uniform> iterations: i32;
@group(0) @binding(3) var<uniform> ridges: i32;

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

fn clamp_coord(coord: i32, limit: i32) -> i32 {
    return clamp(coord, 0, max(limit - 1, 0));
}

fn ridge_transform(color: vec4<f32>) -> vec4<f32> {
    return vec4<f32>(1.0) - abs(color * 2.0 - vec4<f32>(1.0));
}

fn load_source_pixel(coord: vec2<i32>, dims: vec2<i32>) -> vec4<f32> {
    let safe_x: i32 = clamp_coord(coord.x, dims.x);
    let safe_y: i32 = clamp_coord(coord.y, dims.y);
    return textureLoad(input_texture, vec2<i32>(safe_x, safe_y), 0);
}

fn load_reference_pixel(coord: vec2<i32>, dims: vec2<i32>, use_ridges: bool) -> vec4<f32> {
    let src = load_source_pixel(coord, dims);
    if (use_ridges) {
        return ridge_transform(src);
    }
    return src;
}

fn compute_kernel_size(dimension: i32, downsampled: i32) -> i32 {
    if (downsampled <= 0) {
        return 0;
    }
    let ratio: i32 = dimension / downsampled;
    return max(ratio, 1);
}

fn compute_block_start(tile_index: i32, kernel: i32, dimension: i32) -> i32 {
    if (kernel <= 0 || dimension <= 0) {
        return 0;
    }
    let max_start: i32 = max(dimension - kernel, 0);
    let unclamped: i32 = tile_index * kernel;
    return clamp(unclamped, 0, max_start);
}

fn downsampled_value(tile: vec2<i32>, dims: vec2<i32>, down_dims: vec2<i32>, use_ridges: bool) -> vec4<f32> {
    let kernel_w: i32 = compute_kernel_size(dims.x, down_dims.x);
    let kernel_h: i32 = compute_kernel_size(dims.y, down_dims.y);
    if (kernel_w <= 0 || kernel_h <= 0) {
        return vec4<f32>(0.0);
    }

    let start_x: i32 = compute_block_start(tile.x, kernel_w, dims.x);
    let start_y: i32 = compute_block_start(tile.y, kernel_h, dims.y);

    var sum: vec4<f32> = vec4<f32>(0.0);
    for (var ky: i32 = 0; ky < kernel_h; ky = ky + 1) {
        let sample_y: i32 = start_y + ky;
        for (var kx: i32 = 0; kx < kernel_w; kx = kx + 1) {
            let sample_x: i32 = start_x + kx;
            sum = sum + load_reference_pixel(vec2<i32>(sample_x, sample_y), dims, use_ridges);
        }
    }

    let sample_count: i32 = kernel_w * kernel_h;
    if (sample_count <= 0) {
        return vec4<f32>(0.0);
    }

    return sum / f32(sample_count);
}

fn clamp01(value: f32) -> f32 {
    return clamp(value, 0.0, 1.0);
}

@fragment
fn main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let dims_u: vec2<u32> = textureDimensions(input_texture, 0);
    let dims: vec2<i32> = vec2<i32>(i32(dims_u.x), i32(dims_u.y));
    
    if (dims.x <= 0 || dims.y <= 0) {
        return vec4<f32>(0.0);
    }

    let gid: vec2<i32> = vec2<i32>(i32(pos.x), i32(pos.y));
    if (gid.x < 0 || gid.x >= dims.x || gid.y < 0 || gid.y >= dims.y) {
        return vec4<f32>(0.0);
    }

    let use_ridges: bool = ridges != 0;
    let source_texel = load_source_pixel(gid, dims);
    var accum: vec4<f32> = load_reference_pixel(gid, dims, use_ridges);
    var weight_sum: f32 = 1.0;

    let iter_count: i32 = max(iterations, 0);
    let octave_count: i32 = max(octaves, 0);

    if (iter_count > 0 && octave_count > 0) {
        for (var iter: i32 = 0; iter < iter_count; iter = iter + 1) {
            for (var octave: i32 = 1; octave <= octave_count; octave = octave + 1) {
                let clamped_octave: u32 = min(u32(octave), 30u);
                let multiplier_u: u32 = 1u << clamped_octave;
                if (multiplier_u == 0u) {
                    continue;
                }
                let multiplier: i32 = max(i32(multiplier_u), 1);

                let down_width: i32 = max(dims.x / multiplier, 1);
                let down_height: i32 = max(dims.y / multiplier, 1);
                if (down_width <= 0 || down_height <= 0) {
                    break;
                }

                let offset_x: i32 = down_width / 2;
                let offset_y: i32 = down_height / 2;
                let tile_x: i32 = wrap_index(gid.x + offset_x, down_width);
                let tile_y: i32 = wrap_index(gid.y + offset_y, down_height);

                let averaged = downsampled_value(
                    vec2<i32>(tile_x, tile_y),
                    dims,
                    vec2<i32>(down_width, down_height),
                    use_ridges
                );

                let weight: f32 = 1.0 / f32(multiplier);
                accum = accum + averaged * weight;
                weight_sum = weight_sum + weight;
            }
        }
    }

    if (weight_sum > 0.0) {
        accum = accum / weight_sum;
    }

    let rgb = vec3<f32>(clamp01(accum.x), clamp01(accum.y), clamp01(accum.z));
    return vec4<f32>(rgb, 1.0);
}
