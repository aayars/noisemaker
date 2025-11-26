// Bloom downsample pass - fragment shader version for texture output
// Averages source pixels into a smaller grid with highlight boost

const BOOST : f32 = 4.0;

@group(0) @binding(0) var inputTex : texture_2d<f32>;
@group(0) @binding(1) var<uniform> resolution : vec2<f32>;
@group(0) @binding(2) var<uniform> downsampleSize : vec2<f32>;

struct VertexOutput {
    @builtin(position) position : vec4<f32>,
    @location(0) uv : vec2<f32>,
}

fn ceil_div_i32(numerator : i32, denominator : i32) -> i32 {
    if (denominator <= 0) {
        return 0;
    }
    return (numerator + denominator - 1) / denominator;
}

@fragment
fn main(input : VertexOutput) -> @location(0) vec4<f32> {
    let down_width : i32 = max(i32(round(downsampleSize.x)), 1);
    let down_height : i32 = max(i32(round(downsampleSize.y)), 1);
    let gid : vec2<i32> = vec2<i32>(input.position.xy);
    
    if (gid.x >= down_width || gid.y >= down_height) {
        return vec4<f32>(0.0);
    }

    let width : i32 = max(i32(round(resolution.x)), 1);
    let height : i32 = max(i32(round(resolution.y)), 1);
    let kernel_width : i32 = max(ceil_div_i32(width, down_width), 1);
    let kernel_height : i32 = max(ceil_div_i32(height, down_height), 1);

    let origin_x : i32 = gid.x * kernel_width;
    let origin_y : i32 = gid.y * kernel_height;

    var accum : vec3<f32> = vec3<f32>(0.0);
    var sample_count : f32 = 0.0;

    for (var ky : i32 = 0; ky < kernel_height; ky = ky + 1) {
        let sample_y : i32 = origin_y + ky;
        if (sample_y >= height) {
            break;
        }

        for (var kx : i32 = 0; kx < kernel_width; kx = kx + 1) {
            let sample_x : i32 = origin_x + kx;
            if (sample_x >= width) {
                break;
            }

            let texel : vec3<f32> = textureLoad(inputTex, vec2<i32>(sample_x, sample_y), 0).xyz;
            let highlight : vec3<f32> = clamp(texel, vec3<f32>(0.0), vec3<f32>(1.0));
            accum = accum + highlight;
            sample_count = sample_count + 1.0;
        }
    }

    if (sample_count <= 0.0) {
        return vec4<f32>(0.0);
    }

    let average : vec3<f32> = accum / sample_count;
    let boosted : vec3<f32> = average * vec3<f32>(BOOST);

    return vec4<f32>(boosted, sample_count);
}
