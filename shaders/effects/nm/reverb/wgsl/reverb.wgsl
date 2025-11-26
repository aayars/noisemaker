// Multi-octave image "reverberation" effect mirroring the CPU implementation.
// The shader optionally ridge-transforms the input image and accumulates tiled,
// downsampled layers across the requested octaves and iterations. Each layer
// averages the contributing source pixels so the result matches the reference
// proportional downsample + expand tile CPU implementation.

@group(0) @binding(0) var inputTex: texture_2d<f32>;
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
    let safeX: i32 = clamp_coord(coord.x, dims.x);
    let safeY: i32 = clamp_coord(coord.y, dims.y);
    return textureLoad(inputTex, vec2<i32>(safeX, safeY), 0);
}

fn load_reference_pixel(coord: vec2<i32>, dims: vec2<i32>, useRidges: bool) -> vec4<f32> {
    let src = load_source_pixel(coord, dims);
    if (useRidges) {
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

fn compute_block_start(tileIndex: i32, kernel: i32, dimension: i32) -> i32 {
    if (kernel <= 0 || dimension <= 0) {
        return 0;
    }
    let maxStart: i32 = max(dimension - kernel, 0);
    let unclamped: i32 = tileIndex * kernel;
    return clamp(unclamped, 0, maxStart);
}

fn downsampled_value(tile: vec2<i32>, dims: vec2<i32>, downDims: vec2<i32>, useRidges: bool) -> vec4<f32> {
    let kernelW: i32 = compute_kernel_size(dims.x, downDims.x);
    let kernelH: i32 = compute_kernel_size(dims.y, downDims.y);
    if (kernelW <= 0 || kernelH <= 0) {
        return vec4<f32>(0.0);
    }

    let startX: i32 = compute_block_start(tile.x, kernelW, dims.x);
    let startY: i32 = compute_block_start(tile.y, kernelH, dims.y);

    var sum: vec4<f32> = vec4<f32>(0.0);
    for (var ky: i32 = 0; ky < kernelH; ky = ky + 1) {
        let sampleY: i32 = startY + ky;
        for (var kx: i32 = 0; kx < kernelW; kx = kx + 1) {
            let sampleX: i32 = startX + kx;
            sum = sum + load_reference_pixel(vec2<i32>(sampleX, sampleY), dims, useRidges);
        }
    }

    let sampleCount: i32 = kernelW * kernelH;
    if (sampleCount <= 0) {
        return vec4<f32>(0.0);
    }

    return sum / f32(sampleCount);
}

fn clamp01(value: f32) -> f32 {
    return clamp(value, 0.0, 1.0);
}

@fragment
fn main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let dimsU: vec2<u32> = textureDimensions(inputTex, 0);
    let dims: vec2<i32> = vec2<i32>(i32(dimsU.x), i32(dimsU.y));
    
    if (dims.x <= 0 || dims.y <= 0) {
        return vec4<f32>(0.0);
    }

    let gid: vec2<i32> = vec2<i32>(i32(pos.x), i32(pos.y));
    if (gid.x < 0 || gid.x >= dims.x || gid.y < 0 || gid.y >= dims.y) {
        return vec4<f32>(0.0);
    }

    let useRidges: bool = ridges != 0;
    let sourceTexel = load_source_pixel(gid, dims);
    var accum: vec4<f32> = load_reference_pixel(gid, dims, useRidges);
    var weightSum: f32 = 1.0;

    let iterCount: i32 = max(iterations, 0);
    let octaveCount: i32 = max(octaves, 0);

    if (iterCount > 0 && octaveCount > 0) {
        for (var iter: i32 = 0; iter < iterCount; iter = iter + 1) {
            for (var octave: i32 = 1; octave <= octaveCount; octave = octave + 1) {
                let clampedOctave: u32 = min(u32(octave), 30u);
                let multiplierU: u32 = 1u << clampedOctave;
                if (multiplierU == 0u) {
                    continue;
                }
                let multiplier: i32 = max(i32(multiplierU), 1);

                let downWidth: i32 = max(dims.x / multiplier, 1);
                let downHeight: i32 = max(dims.y / multiplier, 1);
                if (downWidth <= 0 || downHeight <= 0) {
                    break;
                }

                let offsetX: i32 = downWidth / 2;
                let offsetY: i32 = downHeight / 2;
                let tileX: i32 = wrap_index(gid.x + offsetX, downWidth);
                let tileY: i32 = wrap_index(gid.y + offsetY, downHeight);

                let averaged = downsampled_value(
                    vec2<i32>(tileX, tileY),
                    dims,
                    vec2<i32>(downWidth, downHeight),
                    useRidges
                );

                let weight: f32 = 1.0 / f32(multiplier);
                accum = accum + averaged * weight;
                weightSum = weightSum + weight;
            }
        }
    }

    if (weightSum > 0.0) {
        accum = accum / weightSum;
    }

    let rgb = vec3<f32>(clamp01(accum.x), clamp01(accum.y), clamp01(accum.z));
    return vec4<f32>(rgb, 1.0);
}
