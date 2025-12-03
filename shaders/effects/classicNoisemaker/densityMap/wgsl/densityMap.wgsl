// Density map apply pass - normalize values based on min/max
// Matches densityMap.glsl (fragment shader)

@group(0) @binding(0) var inputTex: texture_2d<f32>;
@group(0) @binding(1) var minmaxTexture: texture_2d<f32>;

fn clamp01(value: f32) -> f32 {
    return clamp(value, 0.0, 1.0);
}

@fragment
fn main(@builtin(position) fragCoord: vec4<f32>) -> @location(0) vec4<f32> {
    let coord = vec2<i32>(fragCoord.xy);
    let original = textureLoad(inputTex, coord, 0);
    
    // Read global min/max from the 1x1 reduction texture
    let minmax = textureLoad(minmaxTexture, vec2<i32>(0, 0), 0);
    let min_val = minmax.x;
    let max_val = minmax.y;
    
    let delta = max_val - min_val;
    var normalized = original;
    
    if (delta > 0.0) {
        normalized = (original - min_val) / delta;
    } else {
        normalized = clamp(original, vec4<f32>(0.0), vec4<f32>(1.0));
    }
    
    return vec4<f32>(clamp01(normalized.r), clamp01(normalized.g), clamp01(normalized.b), original.a);
}
