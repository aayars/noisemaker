// Simple blur effect - fragment shader version
// Uses a box blur with configurable radius

@group(0) @binding(0) var inputTex: texture_2d<f32>;
@group(0) @binding(1) var<uniform> amount: f32;
@group(0) @binding(2) var<uniform> splineOrder: f32;

fn wrapIndex(value: i32, limit: i32) -> i32 {
    if (limit <= 0) { return 0; }
    var wrapped: i32 = value % limit;
    if (wrapped < 0) { wrapped = wrapped + limit; }
    return wrapped;
}

@fragment
fn main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let dims: vec2<u32> = textureDimensions(inputTex, 0);
    let width: i32 = i32(dims.x);
    let height: i32 = i32(dims.y);
    
    if (width <= 0 || height <= 0) {
        return vec4<f32>(0.0);
    }
    
    let coord: vec2<i32> = vec2<i32>(i32(pos.x), i32(pos.y));
    
    // Calculate blur radius from amount (clamped to reasonable range)
    let radius: i32 = max(1, min(i32(amount), 32));
    
    // Box blur - average pixels in a square kernel
    var accum: vec4<f32> = vec4<f32>(0.0);
    var count: f32 = 0.0;
    
    for (var dy: i32 = -radius; dy <= radius; dy = dy + 1) {
        for (var dx: i32 = -radius; dx <= radius; dx = dx + 1) {
            let sampleX: i32 = wrapIndex(coord.x + dx, width);
            let sampleY: i32 = wrapIndex(coord.y + dy, height);
            accum = accum + textureLoad(inputTex, vec2<i32>(sampleX, sampleY), 0);
            count = count + 1.0;
        }
    }
    
    if (count <= 0.0) {
        return textureLoad(inputTex, coord, 0);
    }
    
    return accum / count;
}
