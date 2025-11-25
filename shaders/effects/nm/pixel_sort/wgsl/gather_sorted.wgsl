// GPGPU Pass 4: Gather sorted pixels with alignment
// Input: prepared texture (original colors), rank texture, brightest texture
// Output: Sorted row with brightest pixel aligned to its original position

@group(0) @binding(0) var preparedTex : texture_2d<f32>;
@group(0) @binding(1) var rankTex : texture_2d<f32>;
@group(0) @binding(2) var brightestTex : texture_2d<f32>;

struct VertexOutput {
    @builtin(position) position : vec4<f32>,
    @location(0) uv : vec2<f32>,
};

@fragment
fn main(input : VertexOutput) -> @location(0) vec4<f32> {
    let coord : vec2<i32> = vec2<i32>(input.position.xy);
    let size : vec2<i32> = vec2<i32>(textureDimensions(preparedTex));
    let x : i32 = coord.x;
    let y : i32 = coord.y;
    let width : i32 = size.x;
    
    // Get brightest x for this row (stored at any x position, same for whole row)
    let brightestXNorm : f32 = textureLoad(brightestTex, vec2<i32>(0, y), 0).r;
    let brightestX : i32 = i32(round(brightestXNorm * f32(width - 1)));
    
    // Python algorithm:
    // sortedIndex = (x - brightestX + width) % width
    // Output position x gets the pixel whose rank == sortedIndex
    let sortedIndex : i32 = (x - brightestX + width) % width;
    
    // Find the pixel in this row whose rank matches sortedIndex
    var result : vec4<f32> = vec4<f32>(0.0, 0.0, 0.0, 1.0);
    
    for (var i : i32 = 0; i < width; i = i + 1) {
        let rankData : vec4<f32> = textureLoad(rankTex, vec2<i32>(i, y), 0);
        let pixelRank : i32 = i32(round(rankData.r * f32(width - 1)));
        
        if (pixelRank == sortedIndex) {
            // Found it - fetch the original color
            result = textureLoad(preparedTex, vec2<i32>(i, y), 0);
            break;
        }
    }
    
    return result;
}
