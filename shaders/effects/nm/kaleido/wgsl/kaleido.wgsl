// Kaleido - creates kaleidoscope mirror effect by reflecting the source texture into wedge slices.

const PI : f32 = 3.14159265358979323846;
const TAU : f32 = 6.28318530717958647692;

struct KaleidoParams {
    sides : f32,
    sdfSides : f32,
    blendEdges : f32,
    _pad : f32,
}

@group(0) @binding(0) var inputTex : texture_2d<f32>;
@group(0) @binding(1) var inputSampler : sampler;
@group(0) @binding(2) var<uniform> params : KaleidoParams;

fn positive_mod(value : f32, modulus : f32) -> f32 {
    if (modulus == 0.0) {
        return 0.0;
    }
    var result : f32 = value - floor(value / modulus) * modulus;
    if (result < 0.0) {
        result = result + modulus;
    }
    return result;
}

struct VertexOutput {
    @builtin(position) position : vec4<f32>,
    @location(0) texCoord : vec2<f32>,
}

@fragment
fn main(input : VertexOutput) -> @location(0) vec4<f32> {
    let uv = input.texCoord;
    
    // Convert to centered coordinates (-0.5 to 0.5)
    let centered = uv - 0.5;
    
    // Compute polar coordinates
    let radius = length(centered) * 2.0;  // Scale so edge is at 1.0
    var angle = atan2(centered.y, centered.x) + PI;  // 0 to TAU
    
    // Number of sides for the kaleidoscope
    let numSides = max(params.sides, 2.0);
    let angleStep = TAU / numSides;
    
    // Fold the angle into one wedge
    var wedgeAngle = positive_mod(angle, angleStep);
    
    // Mirror within the wedge (reflect at half-wedge boundary)
    if (wedgeAngle > angleStep * 0.5) {
        wedgeAngle = angleStep - wedgeAngle;
    }
    
    // Reconstruct UV from modified polar coordinates
    let newAngle = wedgeAngle - angleStep * 0.5;
    let newCentered = vec2<f32>(cos(newAngle), sin(newAngle)) * radius * 0.5;
    var newUV = newCentered + 0.5;
    
    // Optional edge blending
    if (params.blendEdges > 0.5) {
        let edge = max(abs(centered.x), abs(centered.y)) * 2.0;
        let fade = pow(clamp(edge, 0.0, 1.0), 5.0);
        newUV = mix(newUV, uv, fade);
    }
    
    // Clamp UV to valid range
    newUV = clamp(newUV, vec2<f32>(0.0), vec2<f32>(1.0));
    
    let color = textureSample(inputTex, inputSampler, newUV);
    return color;
}
