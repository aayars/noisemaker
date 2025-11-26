#version 300 es
precision highp float;
uniform sampler2D stateTex;
uniform vec2 resolution;
out vec2 vUV;

void main() {
    ivec2 size = textureSize(stateTex, 0);
    int w = size.x;
    int h = size.y;
    int x = gl_VertexID % w;
    int y = gl_VertexID / w;
    vec2 aIndex = (vec2(x, y) + 0.5) / vec2(w, h);

    vec4 agent = texture(stateTex, aIndex);
    vec2 clip = agent.xy / resolution * 2.0 - 1.0;
    gl_Position = vec4(clip, 0.0, 1.0);
    gl_PointSize = 1.0;
    vUV = agent.xy / resolution;
}
