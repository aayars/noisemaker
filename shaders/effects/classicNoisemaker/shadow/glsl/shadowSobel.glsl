#version 300 es

precision highp float;
precision highp int;

uniform sampler2D valueTexture;

out vec4 fragColor;

const float SOBEL_X[9] = float[9](
    1.0, 0.0, -1.0,
    2.0, 0.0, -2.0,
    1.0, 0.0, -1.0
);

const float SOBEL_Y[9] = float[9](
    1.0, 2.0, 1.0,
    0.0, 0.0, 0.0,
    -1.0, -2.0, -1.0
);

const float SOBEL_NORMALIZATION = 5.657;

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
    ivec2 dimensions = textureSize(valueTexture, 0);
    if (dimensions.x == 0 || dimensions.y == 0) {
        fragColor = vec4(0.0);
        return;
    }

    ivec2 coord = ivec2(gl_FragCoord.xy);

    float gx = 0.0;
    float gy = 0.0;
    int kernelIndex = 0;

    for (int ky = -1; ky <= 1; ++ky) {
        for (int kx = -1; kx <= 1; ++kx) {
            int sampleX = wrapCoord(coord.x + kx, dimensions.x);
            int sampleY = wrapCoord(coord.y + ky, dimensions.y);
            float sampleValue = texelFetch(valueTexture, ivec2(sampleX, sampleY), 0).r;
            gx += sampleValue * SOBEL_X[kernelIndex];
            gy += sampleValue * SOBEL_Y[kernelIndex];
            kernelIndex++;
        }
    }

    float magnitude = length(vec2(gx, gy));
    float normalized = clamp(magnitude / SOBEL_NORMALIZATION, 0.0, 1.0);
    fragColor = vec4(normalized, normalized, normalized, 1.0);
}
