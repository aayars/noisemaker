// Spooky ticker effect - flickering segmented glyphs crawling across the image

const INV_U32_MAX : f32 = 1.0 / 4294967295.0;

@group(0) @binding(0) var inputTex : texture_2d<f32>;
@group(0) @binding(1) var<uniform> time : f32;
@group(0) @binding(2) var<uniform> speed : f32;

// Hash function
fn hash_mix(v : u32) -> u32 {
    var result = v;
    result = result ^ (result >> 16u);
    result = result * 0x7feb352du;
    result = result ^ (result >> 15u);
    result = result * 0x846ca68bu;
    result = result ^ (result >> 16u);
    return result;
}

fn random_float(seed : u32, salt : u32) -> f32 {
    return f32(hash_mix(seed ^ salt)) * INV_U32_MAX;
}

// Simple digital segment pattern (7-segment-like display)
fn segment_pattern(uv : vec2<f32>, seed : u32) -> f32 {
    // Create a grid of segments
    let cell = floor(uv * 4.0);
    let local = fract(uv * 4.0);
    
    let cellSeed = hash_mix(u32(cell.x) + u32(cell.y) * 100u + seed);
    let on = step(0.5, random_float(cellSeed, 42u));
    
    // Segment shape: thin rectangles
    var segment = 0.0;
    if (local.x > 0.1 && local.x < 0.9 && local.y > 0.3 && local.y < 0.7) {
        segment = on;
    }
    if (local.y > 0.1 && local.y < 0.9 && local.x > 0.3 && local.x < 0.7) {
        segment = max(segment, on * random_float(cellSeed, 43u));
    }
    
    return segment;
}

// Generate ticker row pattern
fn ticker_row(x : f32, y : f32, rowSeed : f32, t : f32) -> f32 {
    // Horizontal scrolling
    let scrollSpeed = 0.1 + random_float(u32(rowSeed), 17u) * 0.2;
    let scrollX = x + t * scrollSpeed * 50.0;
    
    // Glyph width varies per row
    let glyphWidth = 8.0 + floor(random_float(u32(rowSeed), 23u) * 16.0);
    
    // Which glyph are we in?
    let glyphIndex = floor(scrollX / glyphWidth);
    let localX = (scrollX % glyphWidth) / glyphWidth;
    
    // Each glyph has its own seed
    let glyphSeed = hash_mix(u32(glyphIndex) + u32(rowSeed) * 1000u);
    
    // Flickering: some glyphs randomly turn off
    let flicker = step(0.3, random_float(glyphSeed, u32(t * 10.0)));
    
    // Generate the segment pattern
    let pattern = segment_pattern(vec2<f32>(localX, y), glyphSeed);
    
    return pattern * flicker;
}

@fragment
fn main(@builtin(position) position : vec4<f32>) -> @location(0) vec4<f32> {
    let dims = vec2<f32>(textureDimensions(inputTex, 0));
    let uv = position.xy / dims;
    let src = textureLoad(inputTex, vec2<i32>(position.xy), 0);
    
    // Time factor
    let t = time * speed;
    
    // Base seed from dimensions
    let baseSeed = hash_mix(u32(dims.x) * 31u + u32(dims.y) * 17u);
    
    // Divide into rows
    let numRows = 3.0;
    let rowHeight = 1.0 / numRows;
    
    // Which row are we in? (flip Y so rows scroll from bottom)
    let flippedY = 1.0 - uv.y;
    let rowIndex = floor(flippedY / rowHeight);
    var localY = (flippedY % rowHeight) / rowHeight;
    
    // Only draw in the row area (leave gaps)
    let inRow = step(0.1, localY) * step(localY, 0.9);
    localY = (localY - 0.1) / 0.8;  // Remap to 0-1 within row
    
    // Get ticker pattern
    let rowSeed = f32(hash_mix(u32(rowIndex) + baseSeed));
    let mask = ticker_row(uv.x * dims.x, localY, rowSeed, t) * inRow;
    
    // Blend with source
    let alpha = 0.5 + random_float(baseSeed, 197u) * 0.25;
    
    // Shadow offset
    let shadowOffset = vec2<f32>(-1.0, 1.0) / dims;
    let shadowCoord = vec2<i32>(position.xy + shadowOffset * dims);
    let shadowSrc = textureLoad(inputTex, clamp(shadowCoord, vec2<i32>(0), vec2<i32>(dims) - vec2<i32>(1)), 0);
    let shadowMask = ticker_row((uv.x + shadowOffset.x) * dims.x, localY, rowSeed, t) * inRow;
    
    // Apply blending
    var result = src.rgb;
    
    // Shadow effect
    let shadowAlpha = alpha * 0.33;
    result = mix(result, shadowSrc.rgb - shadowMask, shadowAlpha);
    
    // Highlight
    result = mix(result, max(result, vec3<f32>(mask)), alpha);
    
    return vec4<f32>(clamp(result, vec3<f32>(0.0), vec3<f32>(1.0)), src.a);
}
