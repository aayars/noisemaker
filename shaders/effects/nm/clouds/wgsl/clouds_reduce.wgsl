// Reduce pass: sample 16x16 block from downsample texture, compute local min/max of control (blue channel)
// Output: .r = min, .g = max

@group(0) @binding(0) var downsampleTex: texture_2d<f32>;

@fragment
fn main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let out_coord: vec2<i32> = vec2<i32>(i32(pos.x), i32(pos.y));
    let in_size: vec2<u32> = textureDimensions(downsampleTex, 0);
    
    // Each output pixel covers a 16x16 area of input
    let base_coord: vec2<i32> = out_coord * 16;
    
    var min_val: f32 = 100000.0;
    var max_val: f32 = -100000.0;
    
    // Sample 16x16 block
    for (var dy: i32 = 0; dy < 16; dy = dy + 1) {
        for (var dx: i32 = 0; dx < 16; dx = dx + 1) {
            let sample_coord: vec2<i32> = base_coord + vec2<i32>(dx, dy);
            
            // Skip if out of bounds
            if (sample_coord.x >= i32(in_size.x) || sample_coord.y >= i32(in_size.y)) {
                continue;
            }
            
            let color: vec4<f32> = textureLoad(downsampleTex, sample_coord, 0);
            
            // Control is in blue channel
            let control: f32 = color.b;
            
            min_val = min(min_val, control);
            max_val = max(max_val, control);
        }
    }
    
    // Store min in r, max in g
    return vec4<f32>(min_val, max_val, 0.0, 1.0);
}
