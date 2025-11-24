#version 300 es

precision highp float;
precision highp int;

// Spooky ticker effect - flickering segmented glyphs crawling across the image

uniform sampler2D inputTex;
uniform float time;
uniform float speed;

in vec2 v_texCoord;
out vec4 fragColor;

const float INV_U32_MAX = 1.0 / 4294967295.0;

// Hash functions
uint hash_mix(uint v) {
    v = v ^ (v >> 16u);
    v = v * 0x7feb352du;
    v = v ^ (v >> 15u);
    v = v * 0x846ca68bu;
    v = v ^ (v >> 16u);
    return v;
}

float random_float(uint seed, uint salt) {
    return float(hash_mix(seed ^ salt)) * INV_U32_MAX;
}

// Simple digital segment pattern (7-segment-like display)
float segment_pattern(vec2 uv, uint seed) {
    // Create a grid of segments
    vec2 cell = floor(uv * 4.0);
    vec2 local = fract(uv * 4.0);
    
    uint cellSeed = hash_mix(uint(cell.x) + uint(cell.y) * 100u + seed);
    float on = step(0.5, random_float(cellSeed, 42u));
    
    // Segment shape: thin rectangles
    float segment = 0.0;
    if (local.x > 0.1 && local.x < 0.9 && local.y > 0.3 && local.y < 0.7) {
        segment = on;
    }
    if (local.y > 0.1 && local.y < 0.9 && local.x > 0.3 && local.x < 0.7) {
        segment = max(segment, on * random_float(cellSeed, 43u));
    }
    
    return segment;
}

// Generate ticker row pattern
float ticker_row(float x, float y, float rowSeed, float t) {
    // Horizontal scrolling
    float scrollSpeed = 0.1 + random_float(uint(rowSeed), 17u) * 0.2;
    float scrollX = x + t * scrollSpeed * 50.0;
    
    // Glyph width varies per row
    float glyphWidth = 8.0 + floor(random_float(uint(rowSeed), 23u) * 16.0);
    
    // Which glyph are we in?
    float glyphIndex = floor(scrollX / glyphWidth);
    float localX = mod(scrollX, glyphWidth) / glyphWidth;
    
    // Each glyph has its own seed
    uint glyphSeed = hash_mix(uint(glyphIndex) + uint(rowSeed) * 1000u);
    
    // Flickering: some glyphs randomly turn off
    float flicker = step(0.3, random_float(glyphSeed, uint(t * 10.0)));
    
    // Generate the segment pattern
    float pattern = segment_pattern(vec2(localX, y), glyphSeed);
    
    return pattern * flicker;
}

void main() {
    vec2 dims = vec2(textureSize(inputTex, 0));
    vec4 src = texture(inputTex, v_texCoord);
    
    // Time factor
    float t = time * speed;
    
    // Base seed from dimensions
    uint baseSeed = hash_mix(uint(dims.x) * 31u + uint(dims.y) * 17u);
    
    // Divide into rows
    float numRows = 3.0;
    float rowHeight = 1.0 / numRows;
    
    // Which row are we in? (flip Y so rows scroll from bottom)
    float flippedY = 1.0 - v_texCoord.y;
    float rowIndex = floor(flippedY / rowHeight);
    float localY = mod(flippedY, rowHeight) / rowHeight;
    
    // Only draw in the row area (leave gaps)
    float inRow = step(0.1, localY) * step(localY, 0.9);
    localY = (localY - 0.1) / 0.8;  // Remap to 0-1 within row
    
    // Get ticker pattern
    float rowSeed = float(hash_mix(uint(rowIndex) + baseSeed));
    float mask = ticker_row(v_texCoord.x * dims.x, localY, rowSeed, t) * inRow;
    
    // Blend with source
    float alpha = 0.5 + random_float(baseSeed, 197u) * 0.25;
    
    // Shadow offset
    vec2 shadowOffset = vec2(-1.0, 1.0) / dims;
    vec4 shadowSrc = texture(inputTex, v_texCoord + shadowOffset);
    float shadowMask = ticker_row((v_texCoord.x + shadowOffset.x) * dims.x, 
                                   localY, rowSeed, t) * inRow;
    
    // Apply blending
    vec3 result = src.rgb;
    
    // Shadow effect
    float shadowAlpha = alpha * 0.33;
    result = mix(result, shadowSrc.rgb - shadowMask, shadowAlpha);
    
    // Highlight
    result = mix(result, max(result, vec3(mask)), alpha);
    
    fragColor = vec4(clamp(result, 0.0, 1.0), src.a);
}
