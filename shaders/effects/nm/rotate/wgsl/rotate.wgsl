// Rotate effect: matches Noisemaker's rotate() by tiling the input into a square,
// rotating in normalized space, and cropping back to the original dimensions.

@group(0) @binding(0) var inputTex : texture_2d<f32>;
@group(0) @binding(1) var<uniform> angle : f32;

fn wrap_index(value : i32, size : i32) -> i32 {
    if (size <= 0) {
        return 0;
    }

    var wrapped : i32 = value % size;
    if (wrapped < 0) {
        wrapped = wrapped + size;
    }

    return wrapped;
}

@fragment
fn main(@builtin(position) position : vec4<f32>) -> @location(0) vec4<f32> {
    let dims = textureDimensions(inputTex, 0);
    let width_i = i32(dims.x);
    let height_i = i32(dims.y);
    
    if (width_i <= 0 || height_i <= 0) {
        return vec4<f32>(0.0);
    }

    let global_id = vec2<i32>(position.xy);
    if (global_id.x >= width_i || global_id.y >= height_i) {
        return vec4<f32>(0.0);
    }

    let padded_size_i = max(width_i, height_i) * 2;
    if (padded_size_i <= 0) {
        return vec4<f32>(0.0);
    }

    let padded_size_f = f32(padded_size_i);
    let crop_offset_x = (padded_size_i - width_i) / 2;
    let crop_offset_y = (padded_size_i - height_i) / 2;
    let tile_offset_x = width_i / 2;
    let tile_offset_y = height_i / 2;

    let padded_coord = vec2<i32>(
        global_id.x + crop_offset_x,
        global_id.y + crop_offset_y
    );

    let padded_coord_f = vec2<f32>(
        f32(padded_coord.x),
        f32(padded_coord.y)
    );
    let normalized = padded_coord_f / padded_size_f - vec2<f32>(0.5, 0.5);

    let angle_radians = radians(angle);
    let cos_angle = cos(angle_radians);
    let sin_angle = sin(angle_radians);
    let rotation = mat2x2<f32>(
        cos_angle, -sin_angle,
        sin_angle, cos_angle
    );

    let rotated = rotation * normalized + vec2<f32>(0.5, 0.5);
    let rotated_scaled = rotated * padded_size_f;

    let padded_sample = vec2<i32>(
        wrap_index(i32(rotated_scaled.x), padded_size_i),
        wrap_index(i32(rotated_scaled.y), padded_size_i)
    );

    let source = vec2<i32>(
        wrap_index(padded_sample.x + tile_offset_x, width_i),
        wrap_index(padded_sample.y + tile_offset_y, height_i)
    );

    let texel = textureLoad(inputTex, source, 0);
    return texel;
}
