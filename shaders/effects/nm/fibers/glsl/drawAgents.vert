#version 300 es
precision highp float;
uniform sampler2D agentTex;
uniform vec2 resolution;

void main() {
    int id = gl_VertexID;
    int width = int(resolution.x);
    int height = int(resolution.y);
    
    int x = id % width;
    int y = id / width;
    
    if (y >= height) {
        gl_Position = vec4(-2.0, -2.0, 0.0, 1.0);
        return;
    }
    
    vec4 agent = texelFetch(agentTex, ivec2(x, y), 0);
    vec2 pos = agent.xy;
    
    gl_Position = vec4(pos * 2.0 - 1.0, 0.0, 1.0);
    gl_PointSize = 1.0;
}
