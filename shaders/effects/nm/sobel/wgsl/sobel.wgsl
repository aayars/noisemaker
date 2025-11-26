// Sobel edge detection shader
// Computes gradient magnitude using Sobel kernels

struct SobelParams {
    width : f32,
    height : f32,
    distMetric : f32,
    alpha : f32,
    time : f32,
    _pad0 : f32,
    _pad1 : f32,
    _pad2 : f32,
};

@group(0) @binding(0) var inputTex : texture_2d<f32>;
@group(0) @binding(1) var inputSampler : sampler;
@group(0) @binding(2) var<uniform> params : SobelParams;

fn distance_metric(gx : f32, gy : f32, metric : i32) -> f32 {
    let abs_gx = abs(gx);
    let abs_gy = abs(gy);
    
    if (metric == 2) {
        // Manhattan
        return abs_gx + abs_gy;
    } else if (metric == 3) {
        // Chebyshev
        return max(abs_gx, abs_gy);
    } else if (metric == 4) {
        // Octagram
        let cross = (abs_gx + abs_gy) / 1.414;
        return max(cross, max(abs_gx, abs_gy));
    } else {
        // Euclidean (default)
        return sqrt(gx * gx + gy * gy);
    }
}

struct VertexOutput {
    @builtin(position) position : vec4<f32>,
    @location(0) texCoord : vec2<f32>,
};

@vertex
fn vs_main(@builtin(vertex_index) vertexIndex : u32) -> VertexOutput {
    // Full-screen triangle
    var pos = array<vec2<f32>, 3>(
        vec2<f32>(-1.0, -1.0),
        vec2<f32>(3.0, -1.0),
        vec2<f32>(-1.0, 3.0)
    );
    var uv = array<vec2<f32>, 3>(
        vec2<f32>(0.0, 1.0),
        vec2<f32>(2.0, 1.0),
        vec2<f32>(0.0, -1.0)
    );
    var output : VertexOutput;
    output.position = vec4<f32>(pos[vertexIndex], 0.0, 1.0);
    output.texCoord = uv[vertexIndex];
    return output;
}

@fragment
fn fs_main(@location(0) texCoord : vec2<f32>) -> @location(0) vec4<f32> {
    let dims = vec2<f32>(params.width, params.height);
    let texel = 1.0 / dims;
    
    // Sample 3x3 neighborhood
    let tl = textureSample(inputTex, inputSampler, texCoord + vec2<f32>(-texel.x, -texel.y));
    let tc = textureSample(inputTex, inputSampler, texCoord + vec2<f32>(0.0, -texel.y));
    let tr = textureSample(inputTex, inputSampler, texCoord + vec2<f32>(texel.x, -texel.y));
    let ml = textureSample(inputTex, inputSampler, texCoord + vec2<f32>(-texel.x, 0.0));
    let mr = textureSample(inputTex, inputSampler, texCoord + vec2<f32>(texel.x, 0.0));
    let bl = textureSample(inputTex, inputSampler, texCoord + vec2<f32>(-texel.x, texel.y));
    let bc = textureSample(inputTex, inputSampler, texCoord + vec2<f32>(0.0, texel.y));
    let br = textureSample(inputTex, inputSampler, texCoord + vec2<f32>(texel.x, texel.y));
    
    // Sobel X kernel: [-1 0 1; -2 0 2; -1 0 1]
    let gx = -tl - 2.0*ml - bl + tr + 2.0*mr + br;
    
    // Sobel Y kernel: [-1 -2 -1; 0 0 0; 1 2 1]
    let gy = -tl - 2.0*tc - tr + bl + 2.0*bc + br;
    
    let metric = i32(params.distMetric);
    
    var result : vec4<f32>;
    result.r = distance_metric(gx.r, gy.r, metric);
    result.g = distance_metric(gx.g, gy.g, metric);
    result.b = distance_metric(gx.b, gy.b, metric);
    result.a = 1.0;
    
    // Normalize to reasonable range (Sobel max is about 4*sqrt(2) ≈ 5.66 per channel)
    result = vec4<f32>(clamp(result.rgb / 4.0, vec3<f32>(0.0), vec3<f32>(1.0)), result.a);
    
    return result;
}
