// Reindex remaps pixels along a monotonic index derived from value_map(), mirroring
// noisemaker.effects.reindex(). The shader scans the frame to normalize reference
// values and re-samples using the normalized offsets.

struct ReindexParams {
    width_height_channels_displacement : vec4<f32>,
    time_speed_padding : vec4<f32>,
};

const CHANNEL_COUNT : u32 = 4u;
const F32_MAX : f32 = 0x1.fffffep+127;
const F32_MIN : f32 = -0x1.fffffep+127;

@group(0) @binding(0) var input_texture : texture_2d<f32>;
@group(0) @binding(1) var<storage, read_write> output_buffer : array<f32>;
@group(0) @binding(2) var<uniform> params : ReindexParams;

fn as_u32(value : f32) -> u32 {
    return u32(max(value, 0.0));
}

fn clamp01(value : f32) -> f32 {
    return clamp(value, 0.0, 1.0);
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
    let sign_value : f32 = select(-1.0, 1.0, value >= 0.0);
    return sign_value * pow(abs(value), 1.0 / 3.0);
}

fn oklab_l_component(rgb : vec3<f32>) -> f32 {
    let r_lin : f32 = srgb_to_linear(clamp01(rgb.x));
    let g_lin : f32 = srgb_to_linear(clamp01(rgb.y));
    let b_lin : f32 = srgb_to_linear(clamp01(rgb.z));

    let l : f32 = 0.4121656120 * r_lin + 0.5362752080 * g_lin + 0.0514575653 * b_lin;
    let m : f32 = 0.2118591070 * r_lin + 0.6807189584 * g_lin + 0.1074065790 * b_lin;
    let s : f32 = 0.0883097947 * r_lin + 0.2818474174 * g_lin + 0.6302613616 * b_lin;

    let l_c : f32 = cube_root(l);
    let m_c : f32 = cube_root(m);
    let s_c : f32 = cube_root(s);

    let lightness : f32 = 0.2104542553 * l_c + 0.7936177850 * m_c - 0.0040720468 * s_c;
    return clamp01(lightness);
}

fn value_map_component(texel : vec4<f32>) -> f32 {
    let rgb : vec3<f32> = vec3<f32>(texel.x, texel.y, texel.z);
    return oklab_l_component(rgb);
}

fn wrap_float(value : f32, range : f32) -> f32 {
    if (range <= 0.0) {
        return 0.0;
    }
    let scaled : f32 = floor(value / range);
    return value - range * scaled;
}

fn wrap_index(value : f32, dimension : i32) -> i32 {
    if (dimension <= 0) {
        return 0;
    }
    let dimension_f : f32 = f32(dimension);
    let wrapped : f32 = wrap_float(value, dimension_f);
    let max_index : f32 = f32(dimension - 1);
    return i32(clamp(floor(wrapped), 0.0, max_index));
}

fn write_pixel(base_index : u32, color : vec4<f32>) {
    output_buffer[base_index + 0u] = color.x;
    output_buffer[base_index + 1u] = color.y;
    output_buffer[base_index + 2u] = color.z;
    output_buffer[base_index + 3u] = color.w;
}

fn reference_bounds(width : u32, height : u32) -> vec2<f32> {
    var min_value : f32 = F32_MAX;
    var max_value : f32 = F32_MIN;

    for (var y : u32 = 0u; y < height; y = y + 1u) {
        for (var x : u32 = 0u; x < width; x = x + 1u) {
            let texel : vec4<f32> = textureLoad(input_texture, vec2<i32>(i32(x), i32(y)), 0);
            let reference_value : f32 = value_map_component(texel);
            min_value = min(min_value, reference_value);
            max_value = max(max_value, reference_value);
        }
    }

    return vec2<f32>(min_value, max_value);
}

@compute @workgroup_size(8, 8, 1)
fn main(@builtin(global_invocation_id) global_id : vec3<u32>) {
    if (global_id.x != 0u || global_id.y != 0u || global_id.z != 0u) {
        return;
    }

    let width : u32 = as_u32(params.width_height_channels_displacement.x);
    let height : u32 = as_u32(params.width_height_channels_displacement.y);
    if (width == 0u || height == 0u) {
        return;
    }

    let width_i : i32 = i32(width);
    let height_i : i32 = i32(height);
    let min_dimension : u32 = min(width, height);
    let mod_range : f32 = f32(min_dimension);

    let bounds : vec2<f32> = reference_bounds(width, height);
    let min_value : f32 = bounds.x;
    let max_value : f32 = bounds.y;
    let range : f32 = max_value - min_value;
    let has_range : bool = range != 0.0;

    let displacement : f32 = params.width_height_channels_displacement.w;

    for (var y : u32 = 0u; y < height; y = y + 1u) {
        for (var x : u32 = 0u; x < width; x = x + 1u) {
            let coord : vec2<i32> = vec2<i32>(i32(x), i32(y));
            let texel : vec4<f32> = textureLoad(input_texture, coord, 0);
            let reference_raw : f32 = value_map_component(texel);

            var normalized : f32 = reference_raw;
            if (has_range) {
                normalized = (reference_raw - min_value) / range;
            }

            let offset_value : f32 = normalized * displacement * mod_range + normalized;
            let sample_x : i32 = wrap_index(offset_value, width_i);
            let sample_y : i32 = wrap_index(offset_value, height_i);

            let sampled : vec4<f32> = textureLoad(input_texture, vec2<i32>(sample_x, sample_y), 0);

            let pixel_index : u32 = y * width + x;
            let base_index : u32 = pixel_index * CHANNEL_COUNT;
            write_pixel(base_index, sampled);
        }
    }
}
