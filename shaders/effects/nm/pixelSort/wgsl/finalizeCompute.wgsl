// Pixel Sort Pass 3: Finalize - rotate back and blend
// Compute shader version for WebGPU compute pipeline

const CHANNEL_COUNT : u32 = 4u;
const MAX_ROW_PIXELS : u32 = 4096u;
const PI : f32 = 3.14159265359;

struct PixelSortParams {
    width : f32,
    height : f32,
    angled : f32,
    darkest : f32,
    want_size : f32,
    _padding : vec3<f32>,
}

@group(0) @binding(0) var inputTex : texture_2d<f32>;
@group(0) @binding(1) var output_texture : texture_storage_2d<rgba8unorm, write>;
@group(0) @binding(2) var<uniform> params : PixelSortParams;
@group(0) @binding(3) var<storage, read> sorted_buffer : array<f32>;

fn resolve_want_size() -> u32 {
    let safe_want : f32 = clamp(round(max(params.want_size, 0.0)), 0.0, f32(MAX_ROW_PIXELS));
    return u32(safe_want);
}

fn rotate_uv(uv : vec2<f32>, angle : f32) -> vec2<f32> {
    let centered : vec2<f32> = uv - vec2<f32>(0.5, 0.5);
    let cos_a : f32 = cos(angle);
    let sin_a : f32 = sin(angle);
    let rotated : vec2<f32> = vec2<f32>(
        centered.x * cos_a - centered.y * sin_a,
        centered.x * sin_a + centered.y * cos_a
    );
    return rotated + vec2<f32>(0.5, 0.5);
}

fn clamp01(value : f32) -> f32 {
    return clamp(value, 0.0, 1.0);
}

@compute @workgroup_size(8, 8, 1)
fn main(@builtin(global_invocation_id) gid : vec3<u32>) {
    let width : u32 = u32(params.width);
    let height : u32 = u32(params.height);

    if (gid.x >= width || gid.y >= height) {
        return;
    }

    let want : u32 = resolve_want_size();
    let angle_rad : f32 = params.angled * PI / 180.0;
    let darkest : bool = params.darkest > 0.5;

    // Get original pixel
    let original : vec4<f32> = textureLoad(inputTex, vec2<i32>(i32(gid.x), i32(gid.y)), 0);

    // Sample sorted buffer with inverse rotation
    let uv : vec2<f32> = vec2<f32>(f32(gid.x) + 0.5, f32(gid.y) + 0.5) / vec2<f32>(f32(want), f32(want));
    let rotated_uv : vec2<f32> = rotate_uv(uv, -angle_rad); // Inverse rotation

    let src_x : i32 = i32(floor(rotated_uv.x * f32(want)));
    let src_y : i32 = i32(floor(rotated_uv.y * f32(want)));

    var sorted_color : vec4<f32>;

    if (src_x < 0 || src_x >= i32(want) || src_y < 0 || src_y >= i32(want)) {
        // Out of bounds - use transparent
        sorted_color = vec4<f32>(0.0, 0.0, 0.0, 0.0);
    } else {
        let base_idx : u32 = (u32(src_y) * want + u32(src_x)) * CHANNEL_COUNT;
        sorted_color = vec4<f32>(
            sorted_buffer[base_idx + 0u],
            sorted_buffer[base_idx + 1u],
            sorted_buffer[base_idx + 2u],
            sorted_buffer[base_idx + 3u]
        );
    }

    // Max blend (Python uses tf.maximum)
    var blended : vec4<f32>;
    if (darkest) {
        // For darkest mode: invert sorted back, then take max with inverted original, then invert result
        // Simplified: take min of sorted and original
        blended = vec4<f32>(
            min(sorted_color.x, original.x),
            min(sorted_color.y, original.y),
            min(sorted_color.z, original.z),
            max(sorted_color.w, original.w) // Keep max alpha
        );
    } else {
        // Brightest mode: max blend
        blended = vec4<f32>(
            max(sorted_color.x, original.x),
            max(sorted_color.y, original.y),
            max(sorted_color.z, original.z),
            max(sorted_color.w, original.w)
        );
    }

    textureStore(output_texture, vec2<i32>(i32(gid.x), i32(gid.y)), blended);
}
