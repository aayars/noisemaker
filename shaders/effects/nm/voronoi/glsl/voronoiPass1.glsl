#version 300 es

precision highp float;
precision highp int;

// Voronoi Pass 1: Compute distances and find min/max
// This pass computes voronoi distances for each pixel and outputs them,
// while also accumulating min/max values for normalization

const float PI = 3.14159265358979323846;
const float TAU = 6.28318530717958647692;

const uint MAX_POINTS = 256u;
const float EPSILON = 1e-6;

const int PD_RANDOM = 1000000;
const int PD_SQUARE = 1000001;
const int PD_WAFFLE = 1000002;
const int PD_CHESS = 1000003;
const int PD_H_HEX = 1000010;
const int PD_V_HEX = 1000011;
const int PD_SPIRAL = 1000050;
const int PD_CIRCULAR = 1000100;
const int PD_CONCENTRIC = 1000101;
const int PD_ROTATING = 1000102;


uniform sampler2D inputTex;
uniform vec4 dims;
uniform vec4 nthMetricSdfAlpha;
uniform vec4 refractInverseXy;
uniform vec4 ridgeRefractTimeSpeed;
uniform vec4 freqGenDistribDrift;
uniform vec4 cornersDownsamplePad;

// Include all the helper functions from the main shader (point generation, distance metrics, etc.)
// ... [Copy all helper functions here]

void pass1_compute_distances(uvec3 @builtin(global_invocation_id) global_id) {
    uvec2 dims = uvec2(textureSize(inputTex, 0));
    uint width = select(as_u32(dims.x), dims.x, dims.x > 0u);
    uint height = select(as_u32(dims.y), dims.y, dims.y > 0u);
    if (global_id.x >= width || global_id.y >= height) {
        return;
    }

    // Generate point cloud and compute distances (same as main shader)
    // ... [Point cloud generation and distance calculation code]
    
    // Select the Nth distance
    float selected_distance = select_nth_distance(&sorted_distances, sorted_count, nth_param);
    
    // Write distance to buffer
    distance_buffer[pixel_index] = selected_distance;
    
    // Atomically update min/max using bitcast trick
    uint dist_bits = floatBitsToUint(selected_distance);
    atomicMin(minmax_buffer[0], dist_bits);
    atomicMax(minmax_buffer[1], dist_bits);
}
