// Pixel Sort Pass 2: True O(n²) per-row sorting with brightest alignment
// For each output pixel, find which input pixel should go there after sorting.
// No fallbacks, no approximations.

@group(0) @binding(0) var inputTex : texture_2d<f32>;

struct VertexOutput {
    @builtin(position) position : vec4<f32>,
    @location(0) uv : vec2<f32>,
};

// Oklab luminance for perceptually correct brightness comparison
fn srgb_to_lin(value : f32) -> f32 {
    if (value <= 0.04045) {
        return value / 12.92;
    }
    return pow((value + 0.055) / 1.055, 2.4);
}

fn oklab_l(rgb : vec3<f32>) -> f32 {
    let r : f32 = srgb_to_lin(clamp(rgb.r, 0.0, 1.0));
    let g : f32 = srgb_to_lin(clamp(rgb.g, 0.0, 1.0));
    let b : f32 = srgb_to_lin(clamp(rgb.b, 0.0, 1.0));
    
    let l : f32 = 0.4121656120 * r + 0.5362752080 * g + 0.0514575653 * b;
    let m : f32 = 0.2118591070 * r + 0.6807189584 * g + 0.1074065790 * b;
    let s : f32 = 0.0883097947 * r + 0.2818474174 * g + 0.6302613616 * b;
    
    let l_c : f32 = pow(abs(l), 1.0 / 3.0);
    let m_c : f32 = pow(abs(m), 1.0 / 3.0);
    let s_c : f32 = pow(abs(s), 1.0 / 3.0);
    
    return 0.2104542553 * l_c + 0.7936177850 * m_c - 0.0040720468 * s_c;
}

@fragment
fn main(input : VertexOutput) -> @location(0) vec4<f32> {
    let coord : vec2<i32> = vec2<i32>(input.position.xy);
    let size : vec2<i32> = vec2<i32>(textureDimensions(inputTex));
    let x : i32 = coord.x;
    let y : i32 = coord.y;
    let width : i32 = size.x;
    
    // Pass 1: Find the brightest pixel's x-coordinate in this row
    var maxLum : f32 = -1.0;
    var brightestX : i32 = 0;
    
    for (var i : i32 = 0; i < width; i = i + 1) {
        let texel : vec4<f32> = textureLoad(inputTex, vec2<i32>(i, y), 0);
        let lum : f32 = oklab_l(texel.rgb);
        if (lum > maxLum) {
            maxLum = lum;
            brightestX = i;
        }
    }
    
    // Python algorithm:
    // 1. Sort row descending by brightness: sorted[0] = brightest, sorted[width-1] = dimmest
    // 2. Compute offset: offset[i] = (i - brightestX + width) % width
    // 3. Apply offset: output[x] = sorted[offset[x]]
    //
    // So output position x gets the pixel at sorted index = (x - brightestX + width) % width
    // sortedIndex 0 = brightest pixel, sortedIndex width-1 = dimmest
    
    let sortedIndex : i32 = (x - brightestX + width) % width;
    
    // Pass 2: Find the pixel whose descending rank equals sortedIndex
    // Rank = count of pixels strictly brighter than this one
    // Rank 0 = brightest, Rank width-1 = dimmest
    
    var result : vec4<f32> = vec4<f32>(0.0, 0.0, 0.0, 1.0);
    
    for (var i : i32 = 0; i < width; i = i + 1) {
        let texel : vec4<f32> = textureLoad(inputTex, vec2<i32>(i, y), 0);
        let lum : f32 = oklab_l(texel.rgb);
        
        // Count how many pixels are brighter (they have lower rank)
        var rank : i32 = 0;
        for (var j : i32 = 0; j < width; j = j + 1) {
            if (j == i) {
                continue;
            }
            let other : vec4<f32> = textureLoad(inputTex, vec2<i32>(j, y), 0);
            let otherLum : f32 = oklab_l(other.rgb);
            // Pixel j is "brighter" if its lum > this lum, or same lum but lower index (stable sort)
            if (otherLum > lum || (otherLum == lum && j < i)) {
                rank = rank + 1;
            }
        }
        
        if (rank == sortedIndex) {
            result = texel;
            break;
        }
    }
    
    return result;
}
