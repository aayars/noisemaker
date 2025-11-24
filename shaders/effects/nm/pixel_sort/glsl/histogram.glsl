#version 300 es
precision highp float;
precision highp int;

uniform int channel;

out vec4 fragColor;

void main() {
    if (channel == 0) {
        fragColor = vec4(1.0, 0.0, 0.0, 0.0);
    } else if (channel == 1) {
        fragColor = vec4(0.0, 1.0, 0.0, 0.0);
    } else if (channel == 2) {
        fragColor = vec4(0.0, 0.0, 1.0, 0.0);
    } else {
        fragColor = vec4(0.0, 0.0, 0.0, 1.0);
    }
}
