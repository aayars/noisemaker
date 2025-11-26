// Pixel Sort Pass 1: Pad and rotate into prepared_buffer
// Compute shader version for WebGPU compute pipeline

const PI : f32 = 3.141592653589793;
const CHANNEL_COUNT : u32 = 4u;
const MAX_ROW_PIXELS : u32 = 4096u;

struct PixelSortParams {
    width : f32,
    height : f32,
    angled : f32,
    darkest : f32,
    want_size : f32,
    _padding : vec3<f32>,
}

@group(0) @binding(0) var inputTex : texture_2d<f32>;
@group(0) @binding(1) var<uniform> params : PixelSortParams;
@group(0) @binding(2) var<storage, read_write> prepared_buffer : array<f32>;

fn resolve_want_size() -> u32 {
    let safe_want : f32 = clamp(round(max(params.want_size, 0.0)), 0.0, f32(MAX_ROW_PIXELS));
    return u32(safe_want);
}

@compute @workgroup_size(8, 8, 1)
fn main(@builtin(global_invocation_id) gid : vec3<u32>) {
    let want : u32 = resolve_want_size();
    if (want == 0u || gid.x >= want || gid.y >= want) {
        return;
    }

    let width : u32 = max(u32(params.width), 1u);
    let height : u32 = max(u32(params.height), 1u);

    let pad_x : i32 = (i32(want) - i32(width)) / 2;
    let pad_y : i32 = (i32(want) - i32(height)) / 2;
    
    let angle_rad : f32 = params.angled * PI / 180.0;
    let cos_a : f32 = cos(angle_rad);
    let sin_a : f32 = sin(angle_rad);

    let center : f32 = (f32(want) - 1.0) * 0.5;
    let px : f32 = f32(gid.x);
    let py : f32 = f32(gid.y);

    let dx : f32 = px - center;
    let dy : f32 = py - center;

    let src_x_f : f32 = cos_a * dx + sin_a * dy + center;
    let src_y_f : f32 = -sin_a * dx + cos_a * dy + center;

    let src_x : i32 = i32(round(src_x_f));
    let src_y : i32 = i32(round(src_y_f));

    let orig_x : i32 = src_x - pad_x;
    let orig_y : i32 = src_y - pad_y;

    var color : vec4<f32> = vec4<f32>(0.0, 0.0, 0.0, 1.0);
    if (orig_x >= 0 && orig_x < i32(width) && orig_y >= 0 && orig_y < i32(height)) {
        color = textureLoad(inputTex, vec2<i32>(orig_x, orig_y), 0);
    }

    if (params.darkest != 0.0) {
        color = vec4<f32>(1.0) - color;
        color.a = 1.0;
    }

    let base : u32 = (gid.y * want + gid.x) * CHANNEL_COUNT;
    prepared_buffer[base + 0u] = color.x;
    prepared_buffer[base + 1u] = color.y;
    prepared_buffer[base + 2u] = color.z;
    prepared_buffer[base + 3u] = color.w;
}
