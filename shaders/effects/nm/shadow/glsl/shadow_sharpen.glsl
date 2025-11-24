#version 300 es

precision highp float;
precision highp int;

uniform sampler2D gradient_texture;

out vec4 fragColor;

const float SHARPEN_KERNEL[9] = float[9](
    0.0, -1.0, 0.0,
    -1.0, 5.0, -1.0,
    0.0, -1.0, 0.0
);

int wrapCoord(int value, int size) {
    if (size <= 0) {
        return 0;
    }
    int wrapped = value % size;
    if (wrapped < 0) {
        wrapped += size;
    }
    return wrapped;
}

void main() {
    ivec2 dimensions = textureSize(gradient_texture, 0);
    if (dimensions.x == 0 || dimensions.y == 0) {
        fragColor = vec4(0.0);
        return;
    }

    ivec2 coord = ivec2(gl_FragCoord.xy);

    float accum = 0.0;
    int kernelIndex = 0;
    for (int ky = -1; ky <= 1; ++ky) {
        for (int kx = -1; kx <= 1; ++kx) {
            int sampleX = wrapCoord(coord.x + kx, dimensions.x);
            int sampleY = wrapCoord(coord.y + ky, dimensions.y);
            float sampleValue = texelFetch(gradient_texture, ivec2(sampleX, sampleY), 0).r;
            accum += sampleValue * SHARPEN_KERNEL[kernelIndex];
            kernelIndex++;
        }
    }

    float normalized = clamp(accum * 0.5 + 0.5, 0.0, 1.0);
    fragColor = vec4(normalized, normalized, normalized, 1.0);
}
