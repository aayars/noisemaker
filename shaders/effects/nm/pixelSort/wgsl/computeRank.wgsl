// GPGPU Pass 3: Compute rank for each pixel
// Input: luminance texture (R = luminance)
// Output: R = rank (normalized), G = luminance, B = original x, A = 1

@group(0) @binding(0) var lumTex : texture_2d<f32>;

struct VertexOutput {
    @builtin(position) position : vec4<f32>,
    @location(0) uv : vec2<f32>,
};

@fragment
fn main(input : VertexOutput) -> @location(0) vec4<f32> {
    let coord : vec2<i32> = vec2<i32>(input.position.xy);
    let size : vec2<i32> = vec2<i32>(textureDimensions(lumTex));
    let x : i32 = coord.x;
    let y : i32 = coord.y;
    let width : i32 = size.x;
    
    let myLum : f32 = textureLoad(lumTex, coord, 0).r;
    
    // Count how many pixels in this row are brighter (have lower rank)
    var rank : i32 = 0;
    for (var i : i32 = 0; i < width; i = i + 1) {
        if (i == x) {
            continue;
        }
        let otherLum : f32 = textureLoad(lumTex, vec2<i32>(i, y), 0).r;
        // Brighter = lower rank; tie-breaker: lower index wins
        if (otherLum > myLum || (otherLum == myLum && i < x)) {
            rank = rank + 1;
        }
    }
    
    // Output: rank (normalized), luminance, original x (normalized)
    return vec4<f32>(f32(rank) / f32(width - 1), myLum, f32(x) / f32(width - 1), 1.0);
}
