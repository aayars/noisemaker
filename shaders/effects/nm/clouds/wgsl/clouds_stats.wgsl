// Final stats pass: reduce all min/max values to a single global min/max
// Input: reduceTex with .r = local min, .g = local max
// Output: 1x1 texture with .r = global min, .g = global max

@group(0) @binding(0) var reduceTex: texture_2d<f32>;

@fragment
fn main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let in_size: vec2<u32> = textureDimensions(reduceTex, 0);
    
    var global_min: f32 = 100000.0;
    var global_max: f32 = -100000.0;
    
    // Read all pixels from the reduced texture
    for (var y: u32 = 0u; y < in_size.y; y = y + 1u) {
        for (var x: u32 = 0u; x < in_size.x; x = x + 1u) {
            let stats: vec4<f32> = textureLoad(reduceTex, vec2<i32>(i32(x), i32(y)), 0);
            global_min = min(global_min, stats.r);
            global_max = max(global_max, stats.g);
        }
    }
    
    // Store global min/max
    return vec4<f32>(global_min, global_max, 0.0, 1.0);
}
