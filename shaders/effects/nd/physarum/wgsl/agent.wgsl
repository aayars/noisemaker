/*
 * Physarum agent update shader (WGSL port).
 * Updates agent state: position, heading, and age.
 */

@group(0) @binding(0) var samp: sampler;
@group(0) @binding(1) var stateTex: texture_2d<f32>;
@group(0) @binding(2) var bufTex: texture_2d<f32>;
@group(0) @binding(3) var inputTex: texture_2d<f32>;
@group(0) @binding(4) var<uniform> u: Uniforms;

struct Uniforms {
    time: f32,
    deltaTime: f32,
    frame: i32,
    _pad0: f32,
    resolution: vec2f,
    aspect: f32,
    moveSpeed: f32,
    turnSpeed: f32,
    sensorAngle: f32,
    sensorDistance: f32,
    lifetime: f32,
    weight: f32,
    source: i32,
    resetState: i32,
    spawnPattern: i32,
}

const TAU: f32 = 6.28318530718;

fn hash(n: f32) -> f32 {
    return fract(sin(n) * 43758.5453123);
}

fn wrapPosition(position: vec2f, bounds: vec2f) -> vec2f {
    return (position % bounds + bounds) % bounds;
}

fn luminance(color: vec3f) -> f32 {
    return dot(color, vec3f(0.2126, 0.7152, 0.0722));
}

@fragment
fn main(@builtin(position) fragCoord: vec4f) -> @location(0) vec4f {
    let stateSize = textureDimensions(stateTex);
    let uv = (fragCoord.xy + vec2f(0.5)) / vec2f(f32(stateSize.x), f32(stateSize.y));
    
    // Sample state texture unconditionally (WGSL uniform control flow requirement)
    let agent = textureSample(stateTex, samp, uv);
    var pos = agent.xy;
    var heading = agent.z;
    var age = agent.w;

    // Pre-compute sensor positions (used after reset check)
    let forwardDir = vec2f(cos(heading), sin(heading));
    let leftDir = vec2f(cos(heading - u.sensorAngle), sin(heading - u.sensorAngle));
    let rightDir = vec2f(cos(heading + u.sensorAngle), sin(heading + u.sensorAngle));
    let sensorPosF = wrapPosition(pos + forwardDir * u.sensorDistance, u.resolution);
    let sensorPosL = wrapPosition(pos + leftDir * u.sensorDistance, u.resolution);
    let sensorPosR = wrapPosition(pos + rightDir * u.sensorDistance, u.resolution);

    // Sample ALL textures unconditionally upfront (WGSL uniform control flow requirement)
    let bufF = textureSample(bufTex, samp, sensorPosF / u.resolution).r;
    let bufL = textureSample(bufTex, samp, sensorPosL / u.resolution).r;
    let bufR = textureSample(bufTex, samp, sensorPosR / u.resolution).r;
    
    // Sample input texture for external field
    let inputSampleF = textureSample(inputTex, samp, vec2f(sensorPosF.x / u.resolution.x, 1.0 - sensorPosF.y / u.resolution.y)).rgb;
    let inputSampleL = textureSample(inputTex, samp, vec2f(sensorPosL.x / u.resolution.x, 1.0 - sensorPosL.y / u.resolution.y)).rgb;
    let inputSampleR = textureSample(inputTex, samp, vec2f(sensorPosR.x / u.resolution.x, 1.0 - sensorPosR.y / u.resolution.y)).rgb;
    let inputSampleLocal = textureSample(inputTex, samp, vec2f(pos.x / u.resolution.x, 1.0 - pos.y / u.resolution.y)).rgb;
    
    // Compute external field values (use source uniform to decide if active)
    let sourceActive = select(0.0, 1.0, u.source > 0);
    let extF = luminance(inputSampleF) * sourceActive;
    let extL = luminance(inputSampleL) * sourceActive;
    let extR = luminance(inputSampleR) * sourceActive;
    let extLocal = luminance(inputSampleLocal) * sourceActive;

    // Combined sensor values
    let valF = bufF + extF;
    let valL = bufL + extL;
    let valR = bufR + extR;

    let blend = clamp(u.weight * 0.01, 0.0, 1.0);

    // Initialization / Reset
    let needsInit = u.resetState != 0 || (pos.x == 0.0 && pos.y == 0.0 && age == 0.0);
    if (needsInit) {
        let agentIndex = fragCoord.y * f32(stateSize.x) + fragCoord.x;
        let seed = u.time + agentIndex;
        
        if (u.spawnPattern == 1) { // Clusters
            let clusterId = floor(hash(seed) * 5.0);
            let center = vec2f(hash(clusterId), hash(clusterId + 0.5)) * u.resolution;
            let r = hash(seed + 1.0) * min(u.resolution.x, u.resolution.y) * 0.15;
            let a = hash(seed + 2.0) * TAU;
            pos = center + vec2f(cos(a), sin(a)) * r;
            heading = hash(seed + 3.0) * TAU;
        } else if (u.spawnPattern == 2) { // Ring
            let center = u.resolution * 0.5;
            let r = min(u.resolution.x, u.resolution.y) * 0.35 + (hash(seed) - 0.5) * 20.0;
            let a = hash(seed + 1.0) * TAU;
            pos = center + vec2f(cos(a), sin(a)) * r;
            heading = a + 1.5708; // Tangent
        } else if (u.spawnPattern == 3) { // Spiral
            let center = u.resolution * 0.5;
            let t = hash(seed) * 20.0; 
            let r = t * min(u.resolution.x, u.resolution.y) * 0.02;
            let a = t * TAU;
            pos = center + vec2f(cos(a), sin(a)) * r;
            heading = a + 1.5708;
        } else { // Random (0)
            pos.x = hash(seed) * u.resolution.x;
            pos.y = hash(seed + 1.0) * u.resolution.y;
            heading = hash(seed + 2.0) * TAU;
        }
        
        pos = wrapPosition(pos, u.resolution);
        age = hash(seed + 3.0) * u.lifetime;
        return vec4f(pos, heading, age);
    }

    // Lifetime respawn logic (0 = disabled)
    if (u.lifetime > 0.0) {
        let agentIndex = fragCoord.y * f32(stateSize.x) + fragCoord.x;
        let agentFraction = agentIndex / f32(stateSize.x * stateSize.y);
        let spawnOffset = agentFraction * u.lifetime;
        
        if (age > u.lifetime) {
            let seed = u.time * agentIndex;
            pos.x = hash(seed) * u.resolution.x;
            pos.y = hash(seed + 1.0) * u.resolution.y;
            heading = hash(seed + 2.0) * TAU;
            age = spawnOffset;
        }
    }

    // Steering
    if (valF > valL && valF > valR) {
        // Keep going forward
    } else if (valF < valL && valF < valR) {
        // Rotate randomly
        heading += (hash(u.time + pos.x) - 0.5) * 2.0 * u.turnSpeed * u.moveSpeed;
    } else if (valL > valR) {
        heading -= u.turnSpeed * u.moveSpeed;
    } else if (valR > valL) {
        heading += u.turnSpeed * u.moveSpeed;
    }

    // Move
    let dir = vec2f(cos(heading), sin(heading));
    var speedScale = 1.0;
    if (u.source > 0 && blend > 0.0) {
        speedScale = mix(1.0, mix(1.8, 0.35, extLocal), blend);
    }
    pos += dir * (u.moveSpeed * speedScale);
    pos = wrapPosition(pos, u.resolution);

    // Update age
    age += 0.016;

    return vec4f(pos, heading, age);
}
