#version 300 es
precision highp float;
uniform sampler2D stateTex1;
uniform sampler2D stateTex2;
uniform vec2 resolution;
out vec3 vColor;

void main() {
    ivec2 size = textureSize(stateTex1, 0);
    int w = size.x;
    int h = size.y;
    int x = gl_VertexID % w;
    int y = gl_VertexID / w;
    vec2 aIndex = (vec2(x, y) + 0.5) / vec2(w, h);

    vec4 state1 = texture(stateTex1, aIndex);
    vec4 state2 = texture(stateTex2, aIndex);
    vec2 pos = state1.xy;
    vColor = state2.rgb;
    
    vec2 clip = pos / resolution * 2.0 - 1.0;
    gl_Position = vec4(clip, 0.0, 1.0);
    gl_PointSize = 1.0;
}
