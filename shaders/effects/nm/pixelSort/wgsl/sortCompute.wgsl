// Pixel Sort Pass 2: Per-row counting sort with brightest alignment
// Compute shader version for WebGPU compute pipeline

const CHANNEL_COUNT : u32 = 4u;
const NUM_BUCKETS : u32 = 256u;
const MAX_ROW_PIXELS : u32 = 4096u;

struct PixelSortParams {
    width : f32,
    height : f32,
    angled : f32,
    darkest : f32,
    want_size : f32,
    _padding : vec3<f32>,
}

@group(0) @binding(0) var<uniform> params : PixelSortParams;
@group(0) @binding(1) var<storage, read> prepared_buffer : array<f32>;
@group(0) @binding(2) var<storage, read_write> sorted_buffer : array<f32>;

fn clamp01(value : f32) -> f32 {
    return clamp(value, 0.0, 1.0);
}

fn srgb_to_linear(value : f32) -> f32 {
    if (value <= 0.04045) {
        return value / 12.92;
    }
    return pow((value + 0.055) / 1.055, 2.4);
}

fn oklab_l_component(rgb : vec3<f32>) -> f32 {
    let r : f32 = srgb_to_linear(clamp01(rgb.x));
    let g : f32 = srgb_to_linear(clamp01(rgb.y));
    let b : f32 = srgb_to_linear(clamp01(rgb.z));

    let l : f32 = 0.4121656120 * r + 0.5362752080 * g + 0.0514575653 * b;
    let m : f32 = 0.2118591070 * r + 0.6807189584 * g + 0.1074065790 * b;
    let s : f32 = 0.0883097947 * r + 0.2818474174 * g + 0.6302613616 * b;

    let l_c : f32 = pow(abs(l), 1.0 / 3.0) * sign(l);
    let m_c : f32 = pow(abs(m), 1.0 / 3.0) * sign(m);
    let s_c : f32 = pow(abs(s), 1.0 / 3.0) * sign(s);

    return clamp01(0.2104542553 * l_c + 0.7936177850 * m_c - 0.0040720468 * s_c);
}

fn compute_brightness(color : vec4<f32>) -> f32 {
    return oklab_l_component(vec3<f32>(color.x, color.y, color.z));
}

fn clamp_bucket(value : f32) -> u32 {
    let scaled : f32 = clamp(value, 0.0, 0.999999) * f32(NUM_BUCKETS - 1u);
    return u32(scaled + 0.5);
}

fn resolve_want_size() -> u32 {
    let safe_want : f32 = clamp(round(max(params.want_size, 0.0)), 0.0, f32(MAX_ROW_PIXELS));
    return u32(safe_want);
}

// One workgroup per row - workgroup_size(1,1,1) dispatched with (1, height, 1)
@compute @workgroup_size(1, 1, 1)
fn main(@builtin(global_invocation_id) gid : vec3<u32>) {
    let want : u32 = resolve_want_size();
    if (want == 0u || gid.y >= want) {
        return;
    }

    let row_index : u32 = gid.y;
    let row_start : u32 = row_index * want * CHANNEL_COUNT;

    // Find brightest pixel in this row
    var max_brightness : f32 = -1.0;
    var brightest_index : u32 = 0u;
    for (var x : u32 = 0u; x < want; x = x + 1u) {
        let base : u32 = row_start + x * CHANNEL_COUNT;
        let color : vec4<f32> = vec4<f32>(
            prepared_buffer[base + 0u],
            prepared_buffer[base + 1u],
            prepared_buffer[base + 2u],
            prepared_buffer[base + 3u]
        );
        let brightness : f32 = compute_brightness(color);
        if (brightness > max_brightness) {
            max_brightness = brightness;
            brightest_index = x;
        }
    }

    // Compute shift so brightest stays at its original position
    var shift : u32 = want - brightest_index;
    if (shift == want) {
        shift = 0u;
    }

    // Counting sort for each channel
    var histogram : array<u32, 256>;
    var positions : array<u32, 256>;

    for (var channel : u32 = 0u; channel < CHANNEL_COUNT; channel = channel + 1u) {
        // Clear histogram
        for (var i : u32 = 0u; i < NUM_BUCKETS; i = i + 1u) {
            histogram[i] = 0u;
        }

        // Build histogram
        for (var x : u32 = 0u; x < want; x = x + 1u) {
            let idx : u32 = row_start + x * CHANNEL_COUNT + channel;
            let value : f32 = prepared_buffer[idx];
            let bucket : u32 = clamp_bucket(value);
            histogram[bucket] = histogram[bucket] + 1u;
        }

        // Compute cumulative positions (descending order - brightest first)
        var cumulative : u32 = 0u;
        for (var i : i32 = i32(NUM_BUCKETS) - 1; i >= 0; i = i - 1) {
            let count : u32 = histogram[u32(i)];
            positions[u32(i)] = cumulative;
            cumulative = cumulative + count;
        }

        // Place pixels in sorted order with rotation
        for (var x : u32 = 0u; x < want; x = x + 1u) {
            let idx : u32 = row_start + x * CHANNEL_COUNT + channel;
            let value : f32 = prepared_buffer[idx];
            let bucket : u32 = clamp_bucket(value);
            let offset : u32 = positions[bucket];
            positions[bucket] = offset + 1u;

            var rotated_index : u32 = offset + shift;
            if (rotated_index >= want) {
                rotated_index = rotated_index - want;
            }

            let dest_idx : u32 = row_start + rotated_index * CHANNEL_COUNT + channel;
            sorted_buffer[dest_idx] = value;
        }
    }
}
