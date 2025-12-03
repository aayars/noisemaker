// Shadow Sobel pass - edge detection
// Matches shadowSobel.glsl (GPGPU fragment shader)

const SOBEL_X: array<f32, 9> = array<f32, 9>(
    1.0, 0.0, -1.0,
    2.0, 0.0, -2.0,
    1.0, 0.0, -1.0
);

const SOBEL_Y: array<f32, 9> = array<f32, 9>(
    1.0, 2.0, 1.0,
    0.0, 0.0, 0.0,
    -1.0, -2.0, -1.0
);

const SOBEL_NORMALIZATION: f32 = 5.657;

@group(0) @binding(0) var valueTexture: texture_2d<f32>;

fn wrapCoord(value: i32, size: i32) -> i32 {
    if (size <= 0) {
        return 0;
    }
    var wrapped = value % size;
    if (wrapped < 0) {
        wrapped += size;
    }
    return wrapped;
}

@fragment
fn main(@builtin(position) fragCoord: vec4<f32>) -> @location(0) vec4<f32> {
    let dimensions = textureDimensions(valueTexture);
    if (dimensions.x == 0u || dimensions.y == 0u) {
        return vec4<f32>(0.0);
    }

    let coord = vec2<i32>(fragCoord.xy);

    var gx: f32 = 0.0;
    var gy: f32 = 0.0;
    var kernelIndex: i32 = 0;

    for (var ky = -1; ky <= 1; ky++) {
        for (var kx = -1; kx <= 1; kx++) {
            let sampleX = wrapCoord(coord.x + kx, i32(dimensions.x));
            let sampleY = wrapCoord(coord.y + ky, i32(dimensions.y));
            let sampleValue = textureLoad(valueTexture, vec2<i32>(sampleX, sampleY), 0).r;
            gx += sampleValue * SOBEL_X[kernelIndex];
            gy += sampleValue * SOBEL_Y[kernelIndex];
            kernelIndex++;
        }
    }

    let magnitude = length(vec2<f32>(gx, gy));
    let normalized = clamp(magnitude / SOBEL_NORMALIZATION, 0.0, 1.0);
    return vec4<f32>(normalized, normalized, normalized, 1.0);
}
