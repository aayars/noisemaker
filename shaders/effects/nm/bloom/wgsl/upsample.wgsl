// Bloom upsample pass - fragment shader version for texture output
// Bicubic interpolates the downsampled data and blends with original

const BRIGHTNESS_ADJUST : f32 = 0.25;
const CONTRAST_SCALE : f32 = 1.5;

@group(0) @binding(0) var inputTex : texture_2d<f32>;
@group(0) @binding(1) var downsampleBuffer : texture_2d<f32>;
@group(0) @binding(2) var<uniform> resolution : vec2<f32>;
@group(0) @binding(3) var<uniform> downsampleSize : vec2<f32>;
@group(0) @binding(4) var<uniform> bloomAlpha : f32;

struct VertexOutput {
    @builtin(position) position : vec4<f32>,
    @location(0) uv : vec2<f32>,
}

fn clamp_vec01(value : vec3<f32>) -> vec3<f32> {
    return clamp(value, vec3<f32>(0.0), vec3<f32>(1.0));
}

fn clamp_vec11(value : vec3<f32>) -> vec3<f32> {
    return clamp(value, vec3<f32>(-1.0), vec3<f32>(1.0));
}

fn wrap_index(value : i32, limit : i32) -> i32 {
    if (limit <= 0) {
        return 0;
    }
    var wrapped : i32 = value % limit;
    if (wrapped < 0) {
        wrapped = wrapped + limit;
    }
    return wrapped;
}

fn read_compressed_cell(coord : vec2<i32>, down_size : vec2<i32>) -> vec4<f32> {
    let width : i32 = max(down_size.x, 1);
    let height : i32 = max(down_size.y, 1);
    let safe_x : i32 = wrap_index(coord.x, width);
    let safe_y : i32 = wrap_index(coord.y, height);
    return textureLoad(downsampleBuffer, vec2<i32>(safe_x, safe_y), 0);
}

fn cubic_interpolate_vec3(a : vec3<f32>, b : vec3<f32>, c : vec3<f32>, d : vec3<f32>, t : f32) -> vec3<f32> {
    let t2 : f32 = t * t;
    let t3 : f32 = t2 * t;
    let a0 : vec3<f32> = d - c - a + b;
    let a1 : vec3<f32> = a - b - a0;
    let a2 : vec3<f32> = c - a;
    let a3 : vec3<f32> = b;
    return ((a0 * t3) + (a1 * t2)) + (a2 * t) + a3;
}

@fragment
fn main(input : VertexOutput) -> @location(0) vec4<f32> {
    let width : i32 = max(i32(round(resolution.x)), 1);
    let height : i32 = max(i32(round(resolution.y)), 1);
    let coords : vec2<i32> = vec2<i32>(input.position.xy);
    
    if (coords.x >= width || coords.y >= height) {
        return vec4<f32>(0.0);
    }

    let alpha : f32 = clamp(bloomAlpha, 0.0, 1.0);
    let source_sample : vec4<f32> = textureLoad(inputTex, coords, 0);

    if (alpha <= 0.0) {
        let clamped_source : vec3<f32> = clamp_vec01(source_sample.xyz);
        return vec4<f32>(clamped_source, source_sample.w);
    }

    let down_width : i32 = max(i32(round(downsampleSize.x)), 1);
    let down_height : i32 = max(i32(round(downsampleSize.y)), 1);
    let down_size : vec2<i32> = vec2<i32>(down_width, down_height);

    let width_f : f32 = max(resolution.x, 1.0);
    let height_f : f32 = max(resolution.y, 1.0);
    let down_width_f : f32 = f32(down_width);
    let down_height_f : f32 = f32(down_height);

    let sample_pos : vec2<f32> = vec2<f32>(
        (f32(coords.x) + 0.5) / width_f * down_width_f,
        (f32(coords.y) + 0.5) / height_f * down_height_f,
    );

    let base_floor : vec2<i32> = vec2<i32>(
        clamp(i32(floor(sample_pos.x)), 0, down_width - 1),
        clamp(i32(floor(sample_pos.y)), 0, down_height - 1),
    );
    let frac : vec2<f32> = vec2<f32>(
        clamp(sample_pos.x - f32(base_floor.x), 0.0, 1.0),
        clamp(sample_pos.y - f32(base_floor.y), 0.0, 1.0),
    );

    var sample_x : array<i32, 4> = array<i32, 4>(
        wrap_index(base_floor.x - 1, down_width),
        base_floor.x,
        wrap_index(base_floor.x + 1, down_width),
        wrap_index(base_floor.x + 2, down_width),
    );
    var sample_y : array<i32, 4> = array<i32, 4>(
        wrap_index(base_floor.y - 1, down_height),
        base_floor.y,
        wrap_index(base_floor.y + 1, down_height),
        wrap_index(base_floor.y + 2, down_height),
    );

    var rows : array<vec3<f32>, 4>;
    for (var j : i32 = 0; j < 4; j = j + 1) {
        var samples : array<vec3<f32>, 4>;
        for (var i : i32 = 0; i < 4; i = i + 1) {
            let cell : vec4<f32> = read_compressed_cell(vec2<i32>(sample_x[i], sample_y[j]), down_size);
            samples[u32(i)] = cell.xyz;
        }
        rows[u32(j)] = cubic_interpolate_vec3(samples[0u], samples[1u], samples[2u], samples[3u], frac.x);
    }

    let boosted_sample : vec3<f32> = cubic_interpolate_vec3(rows[0u], rows[1u], rows[2u], rows[3u], frac.y);
    let brightened_pixel : vec3<f32> = clamp_vec11(boosted_sample + vec3<f32>(BRIGHTNESS_ADJUST));

    var bright_sum : vec3<f32> = vec3<f32>(0.0);
    var total_weight : f32 = 0.0;
    for (var y : i32 = 0; y < down_height; y = y + 1) {
        for (var x : i32 = 0; x < down_width; x = x + 1) {
            let cell : vec4<f32> = read_compressed_cell(vec2<i32>(x, y), down_size);
            if (cell.w <= 0.0) {
                continue;
            }
            let brightened_cell : vec3<f32> = clamp_vec11(cell.xyz + vec3<f32>(BRIGHTNESS_ADJUST));
            bright_sum = bright_sum + brightened_cell * cell.w;
            total_weight = total_weight + cell.w;
        }
    }

    var global_mean : vec3<f32> = brightened_pixel;
    if (total_weight > 0.0) {
        global_mean = bright_sum / total_weight;
    }

    let contrasted : vec3<f32> = (brightened_pixel - global_mean) * vec3<f32>(CONTRAST_SCALE) + global_mean;
    let blurred : vec3<f32> = clamp_vec01(contrasted);

    let source_clamped : vec3<f32> = clamp_vec01(source_sample.xyz);
    let mixed : vec3<f32> = clamp_vec01((source_clamped + blurred) * 0.5);
    let final_rgb : vec3<f32> = clamp_vec01(source_clamped * (1.0 - alpha) + mixed * alpha);

    return vec4<f32>(final_rgb, source_sample.w);
}
