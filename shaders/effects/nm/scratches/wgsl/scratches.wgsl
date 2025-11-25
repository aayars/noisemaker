// Scratches Pass 2 (Combine): blend scratch mask with the input frame.
@group(0) @binding(0) var input_texture : texture_2d<f32>;
@group(0) @binding(1) var mask_texture : texture_2d<f32>;
@group(0) @binding(2) var<uniform> enabled : bool;

@fragment
fn main(@builtin(position) position : vec4<f32>) -> @location(0) vec4<f32> {
    let dims : vec2<u32> = textureDimensions(input_texture, 0);
    if (dims.x == 0u || dims.y == 0u) {
        return vec4<f32>(0.0);
    }

    let coord : vec2<i32> = vec2<i32>(i32(position.x), i32(position.y));
    if (coord.x < 0 || coord.y < 0 || coord.x >= i32(dims.x) || coord.y >= i32(dims.y)) {
        return vec4<f32>(0.0);
    }

    let base_color : vec4<f32> = textureLoad(input_texture, coord, 0);
    if (!enabled) {
        return base_color;
    }

    let mask_color : vec4<f32> = textureLoad(mask_texture, coord, 0);
    let scratch_mask : f32 = mask_color.r;
    let scratch_rgb : vec3<f32> = max(base_color.rgb, vec3<f32>(scratch_mask * 4.0));
    return vec4<f32>(clamp(scratch_rgb, vec3<f32>(0.0), vec3<f32>(1.0)), base_color.a);
}
