#version 300 es

precision highp float;
precision highp int;

// Diffusion-limited aggregation effect.
// Mirrors the behavior of noisemaker.effects.dla with WebGPU-friendly data structures.

const SMALL_OFFSETS : array<i32, 3> = array<i32, 3>(-1, 0, 1);
const int EXPANDED_RANGE = 8;
const int EXPANDED_WIDTH = EXPANDED_RANGE * 2 + 1;

// Keep MAX_OUTPUT_VALUES very small to reduce stack pressure on Metal.
const uint MAX_IMAGE_WIDTH = 32u;
const uint MAX_IMAGE_HEIGHT = 32u;
const uint MAX_CHANNELS = 4u;
// Keep MAX_CELLS small to reduce large temporary arrays
const uint MAX_HALF_WIDTH = 32u;
const uint MAX_HALF_HEIGHT = 32u;
const uint MAX_CELLS = MAX_HALF_WIDTH * MAX_HALF_HEIGHT;
const uint MAX_WALKERS = MAX_CELLS;
const uint MAX_OUTPUT_VALUES = MAX_IMAGE_WIDTH * MAX_IMAGE_HEIGHT * MAX_CHANNELS;

const uint BLUR_KERNEL_SIZE = 5u;
const int BLUR_KERNEL_RADIUS = 2;
const BLUR_KERNEL : array<f32, 25> = array<f32, 25>(


uniform sampler2D input_texture;
uniform vec4 size_padding;
uniform vec4 density_time;
uniform vec4 speed_padding;
// Previous frame accumulation (temporal coherence)
uniform sampler2D prev_texture;
// Persistent agents (walkers)

int wrap_int(int v, int s) {
    if (s <= 0) { return 0; }
    int w = v % s;
    if (w < 0) { w = w + s; }
    return w;
}

float luminance(vec3 rgb) {
    return (rgb.x + rgb.y + rgb.z) * (1.0 / 3.0);
}

float fract(float v) {

// Very cheap deterministic pseudo RNG on [0,1). Stores/returns a seed in [0,1).
float next_seed(float seed) {
    // Weyl sequence step (irrational increment)
    return fract(seed * 1.3247179572447458 + 0.123456789);
}

float rand01(inout float seed) {
    float r = seed;
    seed = next_seed(seed);
    return r;
}

uint clamp_dimension(float value, uint limit) {
    float clamped = max(value, 0.0);
    uint floored = uint(floor(clamped));
    if (floored > limit) {
        return limit;
    }
    return floored;
}

uint sanitize_dimension(float value, uint maximum, uint fallback) {
    uint dimension = clamp_dimension(value, maximum);
    if (dimension == 0u) {
        return fallback;
    }
    return dimension;
}

uint sanitize_channel_count(float value) {
    int clamped = int(round(value));
    if (clamped < 1) {
        return 1u;
    }
    if (clamped > int(MAX_CHANNELS)) {
        return MAX_CHANNELS;
    }
    return uint(clamped);
}

int wrap_coord(int value, int limit) {
    if (limit <= 0) {
        return 0;
    }
    int wrapped = value % limit;
    if (wrapped < 0) {
        wrapped = wrapped + limit;
    }
    return wrapped;
}

uint wrap_index(int value, uint limit) {
    if (limit == 0u) {
        return 0u;
    }
    int wrapped = wrap_coord(value, int(limit));
    return uint(wrapped);
}

uint mix_seed(uint a, uint b, uint c, uint time_seed, uint speed_seed) {
    uint state = ((a * 747796405u) ^ (b * 2891336453u) ^ (c * 277803737u) ^ time_seed ^ speed_seed);
    state ^= state >> 17;
    state *= 0xED5AD4BBu;
    state ^= state >> 11;
    state *= 0xAC4C1B51u;
    state ^= state >> 15;
    state *= 0x31848BAFu;
    state ^= state >> 14;
    return state;
}

float random_value(uint a, uint b, uint c, uint time_seed, uint speed_seed) {
    uint bits = mix_seed(a, b, c, time_seed, speed_seed);
    return float(bits) * (1.0 / 4294967295.0);
}

int select_small_offset(float value) {
    float scaled = clamp(value, 0.0, 0.9999999) * 3.0;
    uint index = uint(floor(scaled));
    return SMALL_OFFSETS[index];
}

int select_expanded_offset(float value) {
    float scaled = clamp(value, 0.0, 0.9999999) * float(EXPANDED_WIDTH);
    int index = int(floor(scaled)) - EXPANDED_RANGE;
    return index;
}

float kernel_value(uint index) {
    return BLUR_KERNEL[index];
}

float clamp01(float value) {
    return clamp(value, 0.0, 1.0);
}

vec2 initialize_seed(uint seed_index, uint half_width, uint half_height, uint time_seed, uint speed_seed, ) {
    float rand_y = random_value(seed_index, 0u, 1u, time_seed, speed_seed);
    float rand_x = random_value(seed_index, 1u, 0u, time_seed, speed_seed);
    uint node_y = uint(floor(rand_y * float(half_height)));
    uint node_x = uint(floor(rand_x * float(half_width)));
    if (node_y >= half_height) {
        node_y = half_height - 1u;
    }
    if (node_x >= half_width) {
        node_x = half_width - 1u;
    }
    return vec2(node_x, node_y);
}

void append_walker(inout vec2 walkers[MAX_WALKERS], inout uint walker_active[MAX_WALKERS], inout uint walker_length, vec2 position) {
    if (walker_length >= MAX_WALKERS) {
        return;
    }
    walkers[walker_length] = position;
    walker_active[walker_length] = 1u;
    walker_length = walker_length + 1u;
}

void append_cluster_node(inout uint cluster_list[MAX_CELLS], inout uint cluster_length, uint cell_index, ) {
    if (cluster_length >= MAX_CELLS) {
        return;
    }
    (cluster_list)[cluster_length] = cell_index;
    cluster_length = cluster_length + 1u;
}

void mark_neighborhood(inout uint dst[MAX_CELLS], uint half_width, uint half_height, uint node_x, uint node_y, int range_radius, bool should_wrap, ) {
    int min_offset = -range_radius;
    int max_offset = range_radius;
    for (int dy = min_offset; dy <= max_offset; dy = dy + 1) {
        int sample_y = int(node_y) + dy;
        if (should_wrap) {
            sample_y = wrap_coord(sample_y, int(half_height));
        }
        if (!should_wrap && (sample_y < 0 || sample_y >= int(half_height))) {
            continue;
        }
        uint wrapped_y = uint(sample_y);
        for (int dx = min_offset; dx <= max_offset; dx = dx + 1) {
            int sample_x = int(node_x) + dx;
            if (should_wrap) {
                sample_x = wrap_coord(sample_x, int(half_width));
            }
            if (!should_wrap && (sample_x < 0 || sample_x >= int(half_width))) {
                continue;
            }
            uint wrapped_x = uint(sample_x);
            uint idx = wrapped_y * half_width + wrapped_x;
            (dst)[idx] = 1u;
        }
    }
}

float normalized_value(float value, float minimum, float inv_range) {
    return clamp01((value - minimum) * inv_range);
}

void main(@builtin(global_invocation_id) global_id : vec3) {
    // Use actual input texture dimensions; avoid large local arrays
    uvec2 dims = uvec2(textureSize(input_texture, 0));
    uint width = dims.x;
    uint height = dims.y;
    if (width == 0u || height == 0u) { return; }

    uint channels = 4u;
    uint pixel_count = width * height;
    uint total_values = pixel_count * channels;
    if (arrayLength(output_buffer) < total_values) { return; }

    float alpha = clamp01(density_time.z);
    float seed_density = max(density_time.x, 0.0);

    // Parallelize prev_texture copy: each thread handles one pixel
    if (global_id.x < width && global_id.y < height) {
        uint pixel_idx = global_id.y * width + global_id.x;
        uint base = pixel_idx * 4u;
        vec4 pcol = textureLoad(prev_texture, vec2(int(global_id.x), int(global_id.y)), 0);
    }
    
    // Only thread 0 handles seed initialization and agent processing
    if (global_id.x == 0u && global_id.y == 0u) {

    // Quick occupancy check (any non-black in prev_texture?)
    uint occupied = 0u;
    for (uint y1 = 0u; y1 < height; y1 = y1 + 1u) {
        for (uint x1 = 0u; x1 < width; x1 = x1 + 1u) {
            vec4 c = textureLoad(prev_texture, vec2(int(x1), int(y1)), 0);
            if (luminance(vec3(c.x, c.y, c.z)) > 0.01) {
                occupied = 1u; break;
            }
        }
        if (occupied == 1u) { break; }
    }

    // If empty, initialize a few seeds
    if (occupied == 0u) {
        float min_dim = float(min(width, height));
        uint seeds = max(1u, uint(floor(min_dim * seed_density * 0.25)));
        float s = 0.37;
        for (uint i = 0u; i < seeds; i = i + 1u) {
            uint rx = uint(floor(rand01(&s) * float(width)));
            uint ry = uint(floor(rand01(&s) * float(height)));
            int cx = int(rx);
            int cy = int(ry);
            // Stamp a small 5x5 kernel
            for (uint ky = 0u; ky < BLUR_KERNEL_SIZE; ky = ky + 1u) {
                for (uint kx = 0u; kx < BLUR_KERNEL_SIZE; kx = kx + 1u) {
                    int oy = int(ky) - BLUR_KERNEL_RADIUS;
                    int ox = int(kx) - BLUR_KERNEL_RADIUS;
                    uint yy = uint(wrap_int(cy + oy, int(height)));
                    uint xx = uint(wrap_int(cx + ox, int(width)));
                    uint p = yy * width + xx;
                    uint base = p * 4u;
                    float w = kernel_value(ky * BLUR_KERNEL_SIZE + kx) * alpha;
                }
            }
        }
    }

    // Agents: 8 floats per agent
    uint floats_len = arrayLength(&agent_state_in);
    if (floats_len < 8u) { return; }
    uint agent_count = floats_len / 8u;

    // Step each agent once per frame (one iteration of Python loop)
    for (uint ai = 0u; ai < agent_count; ai = ai + 1u) {
        uint base_state = ai * 8u;
        float x = agent_state_in[base_state + 0u];
        float y = agent_state_in[base_state + 1u];
        float seed = agent_state_in[base_state + 7u];

        int current_xi = wrap_int(int(floor(x)), int(width));
        int current_yi = wrap_int(int(floor(y)), int(height));

        // Check if in expanded_neighborhoods (within 8 pixels of cluster)
        bool in_expanded = false;
        for (int ey = -EXPANDED_RANGE; ey <= EXPANDED_RANGE; ey = ey + 1) {
            for (int ex = -EXPANDED_RANGE; ex <= EXPANDED_RANGE; ex = ex + 1) {
                int sx = wrap_int(current_xi + ex, int(width));
                int sy = wrap_int(current_yi + ey, int(height));
                vec4 c = textureLoad(prev_texture, vec2(sx, sy), 0);
                if (luminance(vec3(c.x, c.y, c.z)) > 0.05) {
                    in_expanded = true;
                    break;
                }
            }
            if (in_expanded) { break; }
        }

        // Movement step size depends on proximity to cluster
        int dx = 0;
        int dy = 0;
        
        if (in_expanded) {
            // Near cluster: small random walk from 3x3 grid
            // Python: offsets[random] for both x and y independently
            float rx = rand01(&seed) * 3.0;
            float ry = rand01(&seed) * 3.0;
            dx = SMALL_OFFSETS[uint(floor(rx))];
            dy = SMALL_OFFSETS[uint(floor(ry))];
        } else {
            // Far from cluster: large random walk from 17x17 grid
            // Python: expanded_offsets[random] for both x and y independently
            float rx = rand01(&seed) * float(EXPANDED_WIDTH);
            float ry = rand01(&seed) * float(EXPANDED_WIDTH);
            dx = int(floor(rx)) - EXPANDED_RANGE;
            dy = int(floor(ry)) - EXPANDED_RANGE;
        }

        int xi = wrap_int(current_xi + dx, int(width));
        int yi = wrap_int(current_yi + dy, int(height));

        // Stick if near existing cluster in prev_texture
        bool should_stick = false;
        for (int oy = -1; oy <= 1; oy = oy + 1) {
            for (int ox = -1; ox <= 1; ox = ox + 1) {
                int sx = wrap_int(xi + ox, int(width));
                int sy = wrap_int(yi + oy, int(height));
                vec4 c = textureLoad(prev_texture, vec2(sx, sy), 0);
                if (luminance(vec3(c.x, c.y, c.z)) > 0.05) { should_stick = true; break; }
            }
            if (should_stick) { break; }
        }

        if (should_stick) {
            // Stamp kernel and respawn
            for (uint ky = 0u; ky < BLUR_KERNEL_SIZE; ky = ky + 1u) {
                for (uint kx = 0u; kx < BLUR_KERNEL_SIZE; kx = kx + 1u) {
                    int oy2 = int(ky) - BLUR_KERNEL_RADIUS;
                    int ox2 = int(kx) - BLUR_KERNEL_RADIUS;
                    uint yy = uint(wrap_int(yi + oy2, int(height)));
                    uint xx = uint(wrap_int(xi + ox2, int(width)));
                    uint p = yy * width + xx;
                    uint base = p * 4u;
                    float w = kernel_value(ky * BLUR_KERNEL_SIZE + kx) * alpha;
                }
            }
            // Respawn at random location
            uint rx = uint(floor(rand01(&seed) * float(width)));
            uint ry = uint(floor(rand01(&seed) * float(height)));
            x = float(rx);
            y = float(ry);
        } else {
            // Continue walking
            x = float(xi);
            y = float(yi);
        }

        // Persist agent state
        agent_state_out[base_state + 0u] = x;
        agent_state_out[base_state + 1u] = y;
        agent_state_out[base_state + 2u] = 0.0;
        agent_state_out[base_state + 3u] = 1.0;
        agent_state_out[base_state + 4u] = 1.0;
        agent_state_out[base_state + 5u] = 1.0;
        agent_state_out[base_state + 6u] = 1.0;
        agent_state_out[base_state + 7u] = seed;
    }
    } // End of thread 0 seed/agent processing block
    
    // Final blend (all threads participate)
    // Python: return value.blend(tensor, out * tensor, alpha)
    if (global_id.x < width && global_id.y < height) {
        uint pixel_idx = global_id.y * width + global_id.x;
        uint base = pixel_idx * 4u;
        
        vec4 input_color = textureLoad(input_texture, vec2(int(global_id.x), int(global_id.y)), 0);
        vec4 trail_color = vec4(
        );
        
        // DLA uses: blend(tensor, out * tensor, alpha)
        vec4 multiplied = trail_color * input_color;
        vec4 blended = input_color * (1.0 - alpha) + multiplied * alpha;
        
    }
}

