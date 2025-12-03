// Stray Hair effect - generates sparse, long hair-like strands over the image.
// Self-contained single-pass implementation.

@group(0) @binding(0) var inputSampler : sampler;
@group(0) @binding(1) var inputTex : texture_2d<f32>;

struct Uniforms {
    time : f32,
    seed : f32,
}
@group(0) @binding(2) var<uniform> uniforms : Uniforms;

// Hash functions
fn hash21(p : vec2<f32>) -> f32 {
    let h = dot(p, vec2<f32>(127.1, 311.7));
    return fract(sin(h) * 43758.5453123);
}

fn hash11(p : f32) -> f32 {
    return fract(sin(p * 127.1) * 43758.5453123);
}

// Value noise
fn noise(p : vec2<f32>) -> f32 {
    let i = floor(p);
    var f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    
    let a = hash21(i);
    let b = hash21(i + vec2<f32>(1.0, 0.0));
    let c = hash21(i + vec2<f32>(0.0, 1.0));
    let d = hash21(i + vec2<f32>(1.0, 1.0));
    
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Generate hair strand pattern
fn hairStrand(uv : vec2<f32>, hairSeed : f32, hairLength : f32, hairThickness : f32) -> f32 {
    // Hair parameters seeded by hairSeed
    let startX = hash11(hairSeed * 17.3);
    let startY = hash11(hairSeed * 31.7);
    let angle = hash11(hairSeed * 43.1) * 6.28318;
    let kink = (hash11(hairSeed * 59.3) - 0.5) * 4.0;
    
    // Starting point
    let start = vec2<f32>(startX, startY);
    
    // Distance along hair axis
    let dir = vec2<f32>(cos(angle), sin(angle));
    let toPoint = uv - start;
    let along = dot(toPoint, dir);
    
    // Only draw if we're within the hair length
    if (along < 0.0 || along > hairLength) {
        return 0.0;
    }
    
    // Perpendicular distance with kink
    let perp = vec2<f32>(-dir.y, dir.x);
    let perpDist = abs(dot(toPoint, perp) - sin(along * kink * 20.0) * 0.01);
    
    // Hair thickness falloff
    let thickness = hairThickness * (1.0 - along / hairLength);
    
    // Smooth edge
    return smoothstep(thickness, thickness * 0.3, perpDist);
}

@fragment
fn main(@location(0) v_texCoord : vec2<f32>) -> @location(0) vec4<f32> {
    let baseColor = textureSample(inputTex, inputSampler, v_texCoord);
    let dims = vec2<f32>(textureDimensions(inputTex, 0));
    let aspect = dims.x / dims.y;
    var uv = v_texCoord;
    uv.x = uv.x * aspect;
    
    // Generate multiple hair strands
    var hairMask : f32 = 0.0;
    var brightness : f32 = 0.0;
    
    // Use seed more directly - multiply by large number to ensure different values
    let baseSeed = uniforms.seed * 1000.0 + floor(uniforms.time * 0.1) * 100.0;
    
    // Number of hairs based on image size
    let numHairs : i32 = 15;
    
    for (var i : i32 = 0; i < numHairs; i = i + 1) {
        let hairSeed = baseSeed + f32(i) * 127.3;
        let hairLength = 0.3 + hash11(hairSeed * 73.7) * 0.4;
        let hairThickness = 0.001 + hash11(hairSeed * 91.3) * 0.002;
        
        let strand = hairStrand(uv, hairSeed, hairLength, hairThickness);
        hairMask = max(hairMask, strand);
        
        // Brightness variation per hair
        let hairBrightness = 0.1 + hash11(hairSeed * 113.7) * 0.4;
        brightness = max(brightness, strand * hairBrightness);
    }
    
    // Blend hair over base image
    let blendFactor = clamp(hairMask * 0.666, 0.0, 1.0);
    let hairColor = vec3<f32>(brightness * 0.333);
    
    let baseComponent = baseColor.rgb * (1.0 - blendFactor);
    let hairComponent = hairColor * blendFactor;
    let result = clamp(baseComponent + hairComponent, vec3<f32>(0.0), vec3<f32>(1.0));
    
    return vec4<f32>(result, baseColor.a);
}

