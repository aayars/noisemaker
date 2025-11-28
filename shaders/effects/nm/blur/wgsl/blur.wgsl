// Blur effect: downsample pass
// Renders to a 64x64 buffer, averaging blocks from the input
// Higher amount = more blur by averaging larger blocks

@group(0) @binding(0) var inputTex: texture_2d<f32>;
@group(0) @binding(1) var<uniform> amount: f32;
// splineOrder not used in downsample pass

@fragment
fn main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let inputSize: vec2<u32> = textureDimensions(inputTex, 0);
    let outputSize: vec2<i32> = vec2<i32>(64, 64);  // Fixed downsample buffer size
    
    let outCoord: vec2<i32> = vec2<i32>(i32(pos.x), i32(pos.y));
    
    // Each output pixel represents a region of input pixels
    // Map output coord to input space center
    let inputX: f32 = (f32(outCoord.x) + 0.5) / f32(outputSize.x) * f32(inputSize.x);
    let inputY: f32 = (f32(outCoord.y) + 0.5) / f32(outputSize.y) * f32(inputSize.y);
    
    // Block size determines how much we average (blur radius)
    // amount=10 should give visible blur
    let blockRadius: i32 = max(1, i32(amount * 0.5));
    
    // Average the block around this position
    var sum: vec4<f32> = vec4<f32>(0.0);
    var count: i32 = 0;
    
    let centerX: i32 = i32(inputX);
    let centerY: i32 = i32(inputY);
    
    for (var dy: i32 = -blockRadius; dy <= blockRadius; dy = dy + 1) {
        for (var dx: i32 = -blockRadius; dx <= blockRadius; dx = dx + 1) {
            let sampleX: i32 = clamp(centerX + dx, 0, i32(inputSize.x) - 1);
            let sampleY: i32 = clamp(centerY + dy, 0, i32(inputSize.y) - 1);
            sum = sum + textureLoad(inputTex, vec2<i32>(sampleX, sampleY), 0);
            count = count + 1;
        }
    }
    
    return sum / f32(count);
}
