// Scratches Pass 2 (Combine): blend scratch mask with the input frame.
@group(0) @binding(0) var inputTex : texture_2d<f32>;
@group(0) @binding(1) var maskTexture : texture_2d<f32>;
@group(0) @binding(2) var<uniform> enabled : i32;

@fragment
fn main(@builtin(position) position : vec4<f32>) -> @location(0) vec4<f32> {
    let dims : vec2<u32> = textureDimensions(inputTex, 0);
    if (dims.x == 0u || dims.y == 0u) {
        return vec4<f32>(0.0);
    }

    let coord : vec2<i32> = vec2<i32>(i32(position.x), i32(position.y));
    if (coord.x < 0 || coord.y < 0 || coord.x >= i32(dims.x) || coord.y >= i32(dims.y)) {
        return vec4<f32>(0.0);
    }

    let baseColor : vec4<f32> = textureLoad(inputTex, coord, 0);
    if (enabled == 0) {
        return baseColor;
    }

    let maskColor : vec4<f32> = textureLoad(maskTexture, coord, 0);
    let scratchMask : f32 = maskColor.r;
    let scratchRgb : vec3<f32> = max(baseColor.rgb, vec3<f32>(scratchMask * 4.0));
    return vec4<f32>(clamp(scratchRgb, vec3<f32>(0.0), vec3<f32>(1.0)), baseColor.a);
}
