/*
 * Physarum deposit shader (WGSL port).
 * Vertex shader reads agent positions from state texture.
 * Fragment shader writes deposit amount to trail texture.
 * Uses textureLoad for exact texel sampling (no interpolation).
 */

@group(0) @binding(0) var stateTex: texture_2d<f32>;
@group(0) @binding(1) var inputTex: texture_2d<f32>;
@group(0) @binding(2) var<uniform> u: Uniforms;

struct Uniforms {
    time: f32,
    deltaTime: f32,
    frame: i32,
    _pad0: f32,
    resolution: vec2f,
    aspect: f32,
    depositAmount: f32,
    weight: f32,
    source: i32,
}

struct VertexOutput {
    @builtin(position) position: vec4f,
    @location(0) vUV: vec2f,
}

@vertex
fn vertexMain(@builtin(vertex_index) vertexID: u32) -> VertexOutput {
    let size = vec2<i32>(textureDimensions(stateTex, 0));
    let w = size.x;
    let h = size.y;
    let x = i32(vertexID) % w;
    let y = i32(vertexID) / w;

    // Use textureLoad for exact texel value (no interpolation)
    let agent = textureLoad(stateTex, vec2<i32>(x, y), 0);
    let clip = agent.xy / u.resolution * 2.0 - 1.0;
    
    var out: VertexOutput;
    out.position = vec4f(clip, 0.0, 1.0);
    out.vUV = agent.xy / u.resolution;
    return out;
}

fn wrap_int(value: i32, size: i32) -> i32 {
    if (size <= 0) { return 0; }
    var result = value % size;
    if (result < 0) { result = result + size; }
    return result;
}

fn luminance(color: vec3f) -> f32 {
    return dot(color, vec3f(0.2126, 0.7152, 0.0722));
}

fn sampleInputAt(x: i32, y: i32, width: i32, height: i32) -> vec3f {
    let wx = wrap_int(x, width);
    let wy = wrap_int(height - 1 - y, height);
    return textureLoad(inputTex, vec2<i32>(wx, wy), 0).rgb;
}

fn sampleInputLuminance(uv: vec2f, width: i32, height: i32) -> f32 {
    if (u.source <= 0) {
        return 0.0;
    }
    let x = i32(uv.x * f32(width));
    let y = i32(uv.y * f32(height));
    return luminance(sampleInputAt(x, y, width, height));
}

@fragment
fn fragmentMain(in: VertexOutput) -> @location(0) vec4f {
    let width = i32(u.resolution.x);
    let height = i32(u.resolution.y);
    
    let blend = clamp(u.weight * 0.01, 0.0, 1.0);
    var deposit = u.depositAmount;
    if (u.source > 0 && blend > 0.0) {
        let inputValue = sampleInputLuminance(in.vUV, width, height);
        let gain = mix(1.0, mix(0.25, 2.0, inputValue), blend);
        deposit *= gain;
    }
    return vec4f(deposit, 0.0, 0.0, 1.0);
}
