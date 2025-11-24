#version 300 es

precision highp float;
precision highp int;

// Voronoi diagram effect converted from Noisemaker's Python reference implementation.
// Supports range, region, and flow diagram variants with optional refract blending.

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



uniform sampler2D input_texture;
uniform vec4 dims;
uniform vec4 nth_metric_sdf_alpha;
uniform vec4 refract_inverse_xy;
uniform vec4 ridge_refract_time_speed;
uniform vec4 freq_gen_distrib_drift;
uniform vec4 corners_downsample_pad;

uint as_u32(float value) {
    return uint(max(round(value), 0.0));
}

bool bool_from(float value) {
    return value > 0.5;
}

float clamp01(float value) {
    return clamp(value, 0.0, 1.0);
}

vec4 clamp_color(vec4 color) {
    return vec4(
        clamp01(color.x),
        clamp01(color.y),
        clamp01(color.z),
        clamp01(color.w)
    );
}

float wrap_float(float value, float limit) {
    if (limit <= 0.0) {
        return 0.0;
    }
    float wrapped = value - floor(value / limit) * limit;
    if (wrapped < 0.0) {
        wrapped = wrapped + limit;
    }
    return wrapped;
}

int wrap_index(int value, int limit) {
    if (limit <= 0) {
        return 0;
    }
    int wrapped = value % limit;
    if (wrapped < 0) {
        wrapped = wrapped + limit;
    }
    return wrapped;
}


void append_point(
    inout vec2 points[MAX_POINTS],
    inout uint point_count,
    vec2 point
) {
    if (point_count >= MAX_POINTS) {
        return;
    }
    uint index = point_count;
    points[index] = point;
    point_count = index + 1u;
}

float hash31(vec3 p) {
    float h = dot(p, vec3(127.1, 311.7, 74.7));
    return fract(sin(h) * 43758.5453);
}

float random_scalar(vec3 seed) {
    return hash31(seed);
}

vec2 random_vec2(vec3 seed) {
    float x = hash31(seed);
    float y = hash31(seed + vec3(19.19, 73.73, 37.37));
    return vec2(x, y);
}

float width_value() {
    uvec2 dims = uvec2(textureSize(input_texture, 0));
    return float(select(as_u32(dims.x), dims.x, dims.x > 0u));
}

float height_value() {
    uvec2 dims = uvec2(textureSize(input_texture, 0));
    return float(select(as_u32(dims.y), dims.y, dims.y > 0u));
}

int diagram_type() {
    return int(round(diagram_nth_inverse_x.x));
}

int nth_value() {
    return int(round(diagram_nth_inverse_x.y));
}

int distance_metric_id() {
    return int(round(diagram_nth_inverse_x.z));
}

float sdf_sides() {
    return diagram_nth_inverse_x.w;
}

float alpha_value() {
    return alpha_refract_ridges_y.x;
}

float with_refract_amount() {
    return alpha_refract_ridges_y.y;
}

bool inverse_flag() {
    return alpha_refract_ridges_y.z > 0.5;
}

bool ridges_hint_flag() {
    return alpha_refract_ridges_y.w > 0.5;
}

bool refract_y_from_offset_flag() {
    return time_speed_freq_gen.z > 0.5;
}

float current_time() {
    return time_speed_freq_gen.x;
}

float current_speed() {
    return time_speed_freq_gen.y;
}

int point_frequency() {
    return int(round(time_speed_freq_gen.z));
}

int point_generations() {
    return int(round(time_speed_freq_gen.w));
}

int point_distribution() {
    return int(round(dist_drift_corners_ds.x));
}

float point_drift() {
    return dist_drift_corners_ds.y;
}

bool point_corners_flag() {
    return dist_drift_corners_ds.z > 0.5;
}

bool downsample_flag() {
    return dist_drift_corners_ds.w > 0.5;
}

bool lowpoly_pack_enabled() {
    return packlow_xy_pad.x > 0.5;
}

float distance_with_metric(vec2 a, vec2 b, int metric_id, float sides) {
    float dx = a.x - b.x;
    float dy = a.y - b.y;
    
    if (metric_id == 1) {
        return abs(dx) + abs(dy);
    } else if (metric_id == 2) {
        return max(abs(dx), abs(dy));
    } else if (metric_id == 3) {
        float angle = atan(dy, dx);
        float r = TAU / max(sides, 3.0);
        float k = floor(0.5 + angle / r) * r - angle;
        float base = sqrt(dx * dx + dy * dy);
        return cos(k) * base;
    } else {
        float sum = dx * dx + dy * dy;
        return sqrt(max(sum, 0.0));
    }
}

float blend_cosine(float a, float b, float t) {
    float smooth_t = (1.0 - cos(t * PI)) * 0.5;
    return a * (1.0 - smooth_t) + b * smooth_t;
}

void generate_random_points(
    inout vec2 points[MAX_POINTS],
    inout uint point_count,
    int freq,
    float width,
    float height,
    float drift,
    float time,
    float speed,
    vec3 seed
) {
    if (freq <= 0) {
        return;
    }
    int total = freq * freq;
    vec2 center = vec2(width * 0.5, height * 0.5);
    vec2 range = vec2(width * 0.5, height * 0.5);
    
    float time_floor = floor(time * speed);
    float time_fract = fract(time * speed);
    
    for (int i = 0; i < total; i = i + 1) {
        if (point_count >= MAX_POINTS) {
            return;
        }
        
        vec2 jitter0 = random_vec2(seed + vec3(float(i), time_floor, 0.0));
        float px0 = center.x + (jitter0.x * range.x * 2.0 - range.x);
        float py0 = center.y + (jitter0.y * range.y * 2.0 - range.y);
        
        vec2 jitter1 = random_vec2(seed + vec3(float(i), time_floor + 1.0, 0.0));
        float px1 = center.x + (jitter1.x * range.x * 2.0 - range.x);
        float py1 = center.y + (jitter1.y * range.y * 2.0 - range.y);
        
        float px = blend_cosine(px0, px1, time_fract);
        float py = blend_cosine(py0, py1, time_fract);
        
        if (drift > 0.0) {
            float drift_x = random_scalar(seed + vec3(float(i), time, 1.0)) * drift * width;
            float drift_y = random_scalar(seed + vec3(float(i), time, 2.0)) * drift * height;
            px += drift_x;
            py += drift_y;
        }
        
        px = wrap_float(px, width);
        py = wrap_float(py, height);
        
        append_point(points, point_count, vec2(px, py));
    }
}

void generate_grid_points(
    inout vec2 points[MAX_POINTS],
    inout uint point_count,
    int freq,
    float width,
    float height,
    float time,
    float speed
) {
    if (freq <= 0) {
        return;
    }
    
    float time_floor = floor(time * speed);
    float time_fract = fract(time * speed);
    
    float cell_width = width / float(freq);
    float cell_height = height / float(freq);
    
    for (int row = 0; row < freq; row = row + 1) {
        for (int col = 0; col < freq; col = col + 1) {
            if (point_count >= MAX_POINTS) {
                return;
            }
            
            float px0 = (float(col) + 0.5) * cell_width;
            float py0 = (float(row) + 0.5) * cell_height;
            
            float px1 = (float(col) + 0.5) * cell_width;
            float py1 = (float(row) + 0.5) * cell_height;
            
            float px = blend_cosine(px0, px1, time_fract);
            float py = blend_cosine(py0, py1, time_fract);
            
            append_point(points, point_count, vec2(px, py));
        }
    }
}

void generate_spiral_points(
    inout vec2 points[MAX_POINTS],
    inout uint point_count,
    int freq,
    float width,
    float height,
    float time,
    float speed
) {
    if (freq <= 0) {
        return;
    }
    
    int total = freq * freq;
    vec2 center = vec2(width * 0.5, height * 0.5);
    float max_radius = min(width, height) * 0.45;
    
    float time_floor = floor(time * speed);
    float time_fract = fract(time * speed);
    
    for (int i = 0; i < total; i = i + 1) {
        if (point_count >= MAX_POINTS) {
            return;
        }
        
        float t = float(i) / float(max(total - 1, 1));
        float angle0 = t * TAU * 3.0 + time_floor * 0.1;
        float radius0 = t * max_radius;
        
        float angle1 = t * TAU * 3.0 + (time_floor + 1.0) * 0.1;
        float radius1 = t * max_radius;
        
        float angle = blend_cosine(angle0, angle1, time_fract);
        float radius = blend_cosine(radius0, radius1, time_fract);
        
        float px = center.x + cos(angle) * radius;
        float py = center.y + sin(angle) * radius;
        
        append_point(points, point_count, vec2(px, py));
    }
}

void generate_circular_points(
    inout vec2 points[MAX_POINTS],
    inout uint point_count,
    int freq,
    float width,
    float height,
    float time,
    float speed
) {
    if (freq <= 0) {
        return;
    }
    
    vec2 center = vec2(width * 0.5, height * 0.5);
    float radius = min(width, height) * 0.4;
    
    float time_floor = floor(time * speed);
    float time_fract = fract(time * speed);
    
    for (int i = 0; i < freq; i = i + 1) {
        if (point_count >= MAX_POINTS) {
            return;
        }
        
        float angle_step = TAU / float(max(freq, 1));
        float angle0 = float(i) * angle_step + time_floor * 0.2;
        float angle1 = float(i) * angle_step + (time_floor + 1.0) * 0.2;
        
        float angle = blend_cosine(angle0, angle1, time_fract);
        
        float px = center.x + cos(angle) * radius;
        float py = center.y + sin(angle) * radius;
        
        append_point(points, point_count, vec2(px, py));
    }
}

void build_point_cloud(
    inout vec2 points[MAX_POINTS],
    inout uint point_count,
    int distribution,
    int freq,
    float width,
    float height,
    float drift,
    bool corners,
    float time,
    float speed
) {
    vec3 seed = vec3(13.37, 42.42, 99.99);
    
    if (distribution == 0) {
        generate_random_points(points, point_count, freq, width, height, drift, time, speed, seed);
    } else if (distribution == 1) {
        generate_grid_points(points, point_count, freq, width, height, time, speed);
    } else if (distribution == 2) {
        generate_spiral_points(points, point_count, freq, width, height, time, speed);
    } else if (distribution == 3) {
        generate_circular_points(points, point_count, freq, width, height, time, speed);
    }
    
    if (corners) {
        append_point(points, point_count, vec2(0.0, 0.0));
        append_point(points, point_count, vec2(width, 0.0));
        append_point(points, point_count, vec2(0.0, height));
        append_point(points, point_count, vec2(width, height));
    }
}

uint select_nth_index(
    vec2 sample_pos,
    vec2 points[MAX_POINTS],
    uint point_count,
    int nth,
    int metric_id,
    float sides
) {
    float distances[MAX_POINTS];
    
    for (uint i = 0u; i < point_count; i = i + 1u) {
        distances[i] = distance_with_metric(sample_pos, points[i], metric_id, sides);
    }
    
    for (int pass = 0; pass < nth; pass = pass + 1) {
        uint min_idx = 0u;
        float min_dist = 1e10;
        
        for (uint i = 0u; i < point_count; i = i + 1u) {
            if (distances[i] < min_dist) {
                min_dist = distances[i];
                min_idx = i;
            }
        }
        
        if (pass == nth - 1) {
            return min_idx;
        }
        
        distances[min_idx] = 1e10;
    }
    
    return 0u;
}

float select_nth_distance(
    vec2 sample_pos,
    vec2 points[MAX_POINTS],
    uint point_count,
    int nth,
    int metric_id,
    float sides
) {
    float distances[MAX_POINTS];
    
    for (uint i = 0u; i < point_count; i = i + 1u) {
        distances[i] = distance_with_metric(sample_pos, points[i], metric_id, sides);
    }
    
    for (int pass = 0; pass < nth; pass = pass + 1) {
        uint min_idx = 0u;
        float min_dist = 1e10;
        
        for (uint i = 0u; i < point_count; i = i + 1u) {
            if (distances[i] < min_dist) {
                min_dist = distances[i];
                min_idx = i;
            }
        }
        
        if (pass == nth - 1) {
            return min_dist;
        }
        
        distances[min_idx] = 1e10;
    }
    
    return 0.0;
}

bool is_flow_diagram(int diagram) {
    return diagram == 41 || diagram == 42;
}

bool needs_color_regions(int diagram) {
    return diagram == 22 || diagram == 31 || diagram == 42;
}

bool needs_range_slice(int diagram) {
    return diagram == 11 || diagram == 12 || diagram == 31 || diagram == 41;
}

float luminance_from(vec4 color) {
    return dot(color.xyz, vec3(0.299, 0.587, 0.114));
}

vec4 refract_color(
    vec2 sample_pos,
    vec2 points[MAX_POINTS],
    uint point_count,
    int nth,
    int metric_id,
    float sides,
    float refract_amount,
    bool use_y_offset,
    float width,
    float height
) {
    uint nearest_idx = select_nth_index(sample_pos, points, point_count, nth, metric_id, sides);
    vec2 nearest_point = points[nearest_idx];
    
    vec2 offset_vec = sample_pos - nearest_point;
    float offset_x = offset_vec.x * refract_amount;
    float offset_y = use_y_offset ? offset_vec.y * refract_amount : offset_vec.x * refract_amount;
    
    vec2 refract_pos = sample_pos + vec2(offset_x, offset_y);
    refract_pos.x = wrap_float(refract_pos.x, width);
    refract_pos.y = wrap_float(refract_pos.y, height);
    
    vec2 uv = refract_pos / vec2(width, height);
    return texture(input_texture, uv);
}

out vec4 fragColor;

void main() {
    // Placeholder main - this needs to be extracted from WGSL
    uvec3 global_id = uvec3(uint(gl_FragCoord.x), uint(gl_FragCoord.y), 0u);
    fragColor = vec4(1.0, 0.0, 1.0, 1.0);
}
