// Hydraulic Flow - Pass 2: Deposit agents as point sprites
// Vertex shader: reads agent position from state texture, outputs to clip space
// Fragment shader: outputs agent color

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) color: vec3<f32>,
}

@group(0) @binding(0) var stateTex1: texture_2d<f32>;
@group(0) @binding(1) var stateTex2: texture_2d<f32>;
@group(0) @binding(2) var<uniform> resolution: vec2<f32>;

@vertex
fn vs_main(@builtin(vertex_index) vertexIndex: u32) -> VertexOutput {
    let size = textureDimensions(stateTex1, 0);
    let w = i32(size.x);
    let h = i32(size.y);
    let x = i32(vertexIndex) % w;
    let y = i32(vertexIndex) / w;
    
    let state1 = textureLoad(stateTex1, vec2<i32>(x, y), 0);
    let state2 = textureLoad(stateTex2, vec2<i32>(x, y), 0);
    let pos = state1.xy;
    let color = state2.rgb;
    
    let clip = pos / resolution * 2.0 - 1.0;
    
    var output: VertexOutput;
    output.position = vec4<f32>(clip, 0.0, 1.0);
    output.color = color;
    return output;
}

@fragment
fn fs_main(input: VertexOutput) -> @location(0) vec4<f32> {
    return vec4<f32>(input.color, 1.0);
}
