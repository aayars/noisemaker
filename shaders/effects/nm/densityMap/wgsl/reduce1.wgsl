// First reduction pass: 32x32 tile min/max for densityMap
// Matches reduce1.glsl (GPGPU fragment shader)

@group(0) @binding(0) var inputTex: texture_2d<f32>;

@fragment
fn main(@builtin(position) fragCoord: vec4<f32>) -> @location(0) vec4<f32> {
    if (fragCoord.x >= 32.0 || fragCoord.y >= 32.0) {
        return vec4<f32>(0.0);
    }
    
    let texSize = textureDimensions(inputTex);
    let width = f32(texSize.x);
    let height = f32(texSize.y);
    
    let block_w = width / 32.0;
    let block_h = height / 32.0;
    
    let start_x = i32(floor(fragCoord.x * block_w));
    let start_y = i32(floor(fragCoord.y * block_h));
    let end_x = min(i32(floor((fragCoord.x + 1.0) * block_w)), i32(texSize.x));
    let end_y = min(i32(floor((fragCoord.y + 1.0) * block_h)), i32(texSize.y));
    
    var min_val: f32 = 1e30;
    var max_val: f32 = -1e30;
    
    // Process RGB channels (textures are always RGBA per AGENTS.md)
    for (var y = start_y; y < end_y; y++) {
        for (var x = start_x; x < end_x; x++) {
            let texel = textureLoad(inputTex, vec2<i32>(x, y), 0);
            
            min_val = min(min_val, texel.r);
            max_val = max(max_val, texel.r);
            min_val = min(min_val, texel.g);
            max_val = max(max_val, texel.g);
            min_val = min(min_val, texel.b);
            max_val = max(max_val, texel.b);
        }
    }
    
    if (min_val > max_val) {
        min_val = 0.0;
        max_val = 0.0;
    }
    
    return vec4<f32>(min_val, max_val, 0.0, 1.0);
}
