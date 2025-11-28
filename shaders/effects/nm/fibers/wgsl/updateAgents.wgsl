// Update agents pass for fibers
// Matches updateAgents.glsl (GPGPU fragment shader)

struct Uniforms {
    resolution: vec2<f32>,
    time: f32,
    frame: i32,
    density: f32,
    stride: f32,
    wormLifetime: f32,
    _pad: f32,
};

@group(0) @binding(0) var agentTex: texture_2d<f32>;
@group(0) @binding(1) var inputTex: texture_2d<f32>;
@group(0) @binding(2) var inputSampler: sampler;
@group(0) @binding(3) var<uniform> uniforms: Uniforms;

fn hash12(p: vec2<f32>) -> f32 {
    var p3 = fract(vec3<f32>(p.x, p.y, p.x) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

@fragment
fn main(@builtin(position) fragCoord: vec4<f32>) -> @location(0) vec4<f32> {
    let agentDims = vec2<f32>(textureDimensions(agentTex));
    let uv = (fragCoord.xy - 0.5) / agentDims;
    var agent = textureSampleLevel(agentTex, inputSampler, uv, 0.0);
    var pos = agent.xy;
    var dir = agent.zw; // Direction
    
    if (uniforms.frame == 0) {
        // Initialize
        let seed = hash12(uv * 100.0 + vec2<f32>(uniforms.time, 0.0));
        pos = vec2<f32>(hash12(vec2<f32>(seed, 1.0)), hash12(vec2<f32>(seed, 2.0)));
        let angle = hash12(vec2<f32>(seed, 3.0)) * 6.283185;
        dir = vec2<f32>(cos(angle), sin(angle));
    } else {
        // Move
        let texel = 1.0 / uniforms.resolution;
        let l = textureSampleLevel(inputTex, inputSampler, pos, 0.0).r;
        let lx = textureSampleLevel(inputTex, inputSampler, pos + vec2<f32>(texel.x, 0.0), 0.0).r;
        let ly = textureSampleLevel(inputTex, inputSampler, pos + vec2<f32>(0.0, texel.y), 0.0).r;
        let grad = vec2<f32>(lx - l, ly - l);
        
        var angle = atan2(dir.y, dir.x);
        // Add some noise
        let noise = hash12(pos * 100.0 + vec2<f32>(uniforms.time, 0.0)) - 0.5;
        angle += noise * 0.5;
        
        dir = vec2<f32>(cos(angle), sin(angle));
        
        let speed = uniforms.stride / max(uniforms.resolution.x, uniforms.resolution.y);
        pos += dir * speed;
        
        // Wrap
        pos = fract(pos);
    }

    return vec4<f32>(pos, dir);
}
