// Clouds effect pass 3: Upsample and composite onto input image
// Input: shadedTex (R=combined, G=shaded), inputTex (original image)
// Output: Final cloud-covered image with shadow effect

@group(0) @binding(0) var shadedTex: texture_2d<f32>;
@group(0) @binding(1) var inputTex: texture_2d<f32>;
@group(0) @binding(2) var<uniform> resolution: vec2<f32>;

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

fn read_shaded_channel(coord: vec2<i32>, size: vec2<i32>, channel: u32) -> f32 {
    let width: i32 = max(size.x, 1);
    let height: i32 = max(size.y, 1);
    let safe_x: i32 = wrap_index(coord.x, width);
    let safe_y: i32 = wrap_index(coord.y, height);
    
    let val: vec4<f32> = textureLoad(shadedTex, vec2<i32>(safe_x, safe_y), 0);
    if (channel == 0u) { return val.r; }
    if (channel == 1u) { return val.g; }
    if (channel == 2u) { return val.b; }
    return val.a;
}

fn cubic_interpolate(a: f32, b: f32, c: f32, d: f32, t: f32) -> f32 {
    let t2: f32 = t * t;
    let t3: f32 = t2 * t;
    let a0: f32 = d - c - a + b;
    let a1: f32 = a - b - a0;
    let a2: f32 = c - a;
    let a3: f32 = b;
    return a0 * t3 + a1 * t2 + a2 * t + a3;
}

fn sample_channel_bicubic(uv: vec2<f32>, size: vec2<i32>, channel: u32) -> f32 {
    let width: i32 = max(size.x, 1);
    let height: i32 = max(size.y, 1);
    let scale_vec: vec2<f32> = vec2<f32>(f32(width), f32(height));
    let base_coord: vec2<f32> = uv * scale_vec - vec2<f32>(0.5, 0.5);

    let ix: i32 = i32(floor(base_coord.x));
    let iy: i32 = i32(floor(base_coord.y));
    let fx: f32 = clamp(base_coord.x - floor(base_coord.x), 0.0, 1.0);
    let fy: f32 = clamp(base_coord.y - floor(base_coord.y), 0.0, 1.0);

    var column: array<f32, 4>;

    for (var m: i32 = -1; m <= 2; m = m + 1) {
        var row: array<f32, 4>;
        for (var n: i32 = -1; n <= 2; n = n + 1) {
            let sample_coord: vec2<i32> = vec2<i32>(
                wrap_index(ix + n, width),
                wrap_index(iy + m, height)
            );
            row[n + 1] = read_shaded_channel(sample_coord, size, channel);
        }
        column[m + 1] = cubic_interpolate(row[0], row[1], row[2], row[3], fx);
    }

    let value: f32 = cubic_interpolate(column[0], column[1], column[2], column[3], fy);
    return clamp(value, 0.0, 1.0);
}

fn sample_input_bilinear(uv: vec2<f32>, tex_size: vec2<i32>) -> vec4<f32> {
    let width: f32 = f32(tex_size.x);
    let height: f32 = f32(tex_size.y);
    
    let coord: vec2<f32> = vec2<f32>(uv.x * width - 0.5, uv.y * height - 0.5);
    let coord_floor: vec2<i32> = vec2<i32>(i32(floor(coord.x)), i32(floor(coord.y)));
    let fract_part: vec2<f32> = vec2<f32>(coord.x - floor(coord.x), coord.y - floor(coord.y));
    
    let x0: i32 = wrap_index(coord_floor.x, tex_size.x);
    let y0: i32 = wrap_index(coord_floor.y, tex_size.y);
    let x1: i32 = wrap_index(coord_floor.x + 1, tex_size.x);
    let y1: i32 = wrap_index(coord_floor.y + 1, tex_size.y);
    
    let p00: vec4<f32> = textureLoad(inputTex, vec2<i32>(x0, y0), 0);
    let p10: vec4<f32> = textureLoad(inputTex, vec2<i32>(x1, y0), 0);
    let p01: vec4<f32> = textureLoad(inputTex, vec2<i32>(x0, y1), 0);
    let p11: vec4<f32> = textureLoad(inputTex, vec2<i32>(x1, y1), 0);
    
    let p0: vec4<f32> = mix(p00, p10, fract_part.x);
    let p1: vec4<f32> = mix(p01, p11, fract_part.x);
    
    return mix(p0, p1, fract_part.y);
}

fn sobel_gradient(uv: vec2<f32>, size: vec2<i32>) -> vec2<f32> {
    let width: i32 = max(size.x, 1);
    let height: i32 = max(size.y, 1);

    var gx: f32 = 0.0;
    var gy: f32 = 0.0;

    for (var i: i32 = -1; i <= 1; i = i + 1) {
        for (var j: i32 = -1; j <= 1; j = j + 1) {
            let sample_uv: vec2<f32> = uv + vec2<f32>(f32(j) / f32(width), f32(i) / f32(height));
            let texel: vec4<f32> = sample_input_bilinear(sample_uv, size);
            let value: f32 = (texel.r + texel.g + texel.b) / 3.0;

            // Sobel kernels
            var kx: f32;
            if (j == -1) {
                if (i == -1) { kx = -1.0; }
                else if (i == 0) { kx = -2.0; }
                else { kx = -1.0; }
            } else if (j == 0) {
                kx = 0.0;
            } else {
                if (i == -1) { kx = 1.0; }
                else if (i == 0) { kx = 2.0; }
                else { kx = 1.0; }
            }
            
            var ky: f32;
            if (i == -1) {
                if (j == -1) { ky = -1.0; }
                else if (j == 0) { ky = -2.0; }
                else { ky = -1.0; }
            } else if (i == 0) {
                ky = 0.0;
            } else {
                if (j == -1) { ky = 1.0; }
                else if (j == 0) { ky = 2.0; }
                else { ky = 1.0; }
            }

            gx = gx + value * kx;
            gy = gy + value * ky;
        }
    }

    return vec2<f32>(gx, gy);
}

fn shadow_effect(original_texel: vec4<f32>, uv: vec2<f32>, size: vec2<i32>, alpha: f32) -> vec4<f32> {
    let gradient: vec2<f32> = sobel_gradient(uv, size);
    
    let distance: f32 = sqrt(gradient.x * gradient.x + gradient.y * gradient.y);
    let normalized_distance: f32 = clamp(distance, 0.0, 1.0);
    
    var shade: f32 = normalized_distance;
    shade = clamp((shade - 0.5) * 1.5 + 0.5, 0.0, 1.0);
    
    let highlight: f32 = shade * shade;
    
    let shadowed: vec3<f32> = (vec3<f32>(1.0) - ((vec3<f32>(1.0) - original_texel.rgb) * (1.0 - highlight))) * shade;
    
    return vec4<f32>(mix(original_texel.rgb, shadowed, alpha), original_texel.a);
}

@fragment
fn main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let width_f: f32 = resolution.x;
    let height_f: f32 = resolution.y;
    let width: i32 = i32(round(width_f));
    let height: i32 = i32(round(height_f));
    
    let shaded_dims: vec2<u32> = textureDimensions(shadedTex, 0);
    let down_size_i: vec2<i32> = vec2<i32>(i32(shaded_dims.x), i32(shaded_dims.y));

    let uv: vec2<f32> = vec2<f32>(
        pos.x / max(width_f, 1.0),
        pos.y / max(height_f, 1.0)
    );

    // Sample combined and shade with bicubic upsampling
    let combined_value: f32 = clamp01(sample_channel_bicubic(uv, down_size_i, 0u));
    
    let shade_mask: f32 = sample_channel_bicubic(uv, down_size_i, 1u);
    let shade_factor: f32 = smoothstep(0.0, 0.5, shade_mask * 0.75);

    // Sample input texture
    let input_size: vec2<u32> = textureDimensions(inputTex, 0);
    let texel: vec4<f32> = sample_input_bilinear(uv, vec2<i32>(i32(input_size.x), i32(input_size.y)));

    // Python: tensor = blend(tensor, zeros, shaded * 0.75) -> mix toward black
    let shaded_color: vec3<f32> = mix(texel.xyz, vec3<f32>(0.0), vec3<f32>(shade_factor));
    
    // Python: tensor = blend(tensor, ones, combined) -> mix toward white
    let lit_color: vec4<f32> = vec4<f32>(
        mix(shaded_color, vec3<f32>(1.0), vec3<f32>(combined_value)),
        clamp(mix(texel.w, 1.0, combined_value), 0.0, 1.0)
    );

    // Apply shadow effect
    let final_texel: vec4<f32> = shadow_effect(lit_color, uv, vec2<i32>(width, height), 0.5);

    return final_texel;
}
