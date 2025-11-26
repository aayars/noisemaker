import { Effect } from '../../../src/runtime/effect.js';

export default class Physarum extends Effect {
  name = "Physarum";
  namespace = "nd";
  func = "physarum";

  globals = {
    zoom: {
      type: "int",
      default: 1,
      uniform: "zoom",
      choices: {
        "1x": 1,
        "2x": 2,
        "4x": 4,
        "8x": 8,
        "16x": 16,
        "32x": 32,
        "64x": 64
      },
      ui: {
        label: "zoom",
        type: "option",
        category: "transform"
      }
    },
    deltaTime: {
      type: "float",
      default: 0.016,
      uniform: "deltaTime",
      ui: {
        control: false
      }
    },
    moveSpeed: {
      type: "float",
      default: 1.7800000000000011,
      uniform: "moveSpeed",
      min: 0.05,
      max: 3,
      ui: {
        label: "move speed",
        type: "float",
        step: 0.01,
        category: "agents"
      }
    },
    turnSpeed: {
      type: "float",
      default: 1,
      uniform: "turnSpeed",
      min: 0,
      max: 3.14159,
      ui: {
        label: "turn speed",
        type: "float",
        step: 0.01,
        category: "agents"
      }
    },
    sensorAngle: {
      type: "float",
      default: 1.2599999999999971,
      uniform: "sensorAngle",
      min: 0.1,
      max: 1.5,
      ui: {
        label: "sensor angle",
        type: "float",
        step: 0.01,
        category: "agents"
      }
    },
    sensorDistance: {
      type: "float",
      default: 30.700000000000003,
      uniform: "sensorDistance",
      min: 2,
      max: 32,
      ui: {
        label: "sensor distance",
        type: "float",
        step: 0.1,
        category: "agents"
      }
    },
    decay: {
      type: "float",
      default: 0.1,
      uniform: "decay",
      min: 0,
      max: 0.1,
      ui: {
        label: "decay",
        type: "float",
        step: 0.001,
        category: "chemistry"
      }
    },
    diffusion: {
      type: "float",
      default: 0.25,
      uniform: "diffusion",
      min: 0,
      max: 1,
      ui: {
        label: "diffusion",
        type: "float",
        step: 0.01,
        category: "chemistry"
      }
    },
    intensity: {
      type: "float",
      default: 75,
      uniform: "intensity",
      min: 0,
      max: 100,
      step: 1,
      ui: {
        label: "intensity",
        type: "float",
        category: "input"
      }
    },
    depositAmount: {
      type: "float",
      default: 0.05,
      uniform: "depositAmount",
      min: 0,
      max: 0.05,
      ui: {
        label: "deposit",
        type: "float",
        step: 0.001,
        category: "chemistry"
      }
    },
    lifetime: {
      type: "float",
      default: 10.998912608250976,
      uniform: "lifetime",
      min: 0,
      max: 60,
      ui: {
        label: "lifetime",
        type: "float",
        step: 1,
        category: "agents"
      }
    },
    weight: {
      type: "float",
      default: 0,
      uniform: "weight",
      min: 0,
      max: 100,
      ui: {
        label: "input weight",
        type: "float",
        category: "input"
      }
    },
    source: {
      type: "int",
      default: 0,
      uniform: "source",
      choices: {
        "none": 0,
        "pipeline": 1
      },
      ui: {
        label: "input source",
        type: "option",
        category: "input"
      }
    },
    inputIntensity: {
      type: "float",
      default: 0,
      uniform: "inputIntensity",
      min: 0,
      max: 100,
      step: 1,
      ui: {
        label: "input intensity",
        type: "float",
        category: "input"
      }
    },
    colorMode: {
      type: "int",
      default: 0,
      uniform: "colorMode",
      choices: {
        "grayscale": 0,
        "palette": 1
      },
      ui: {
        label: "color mode",
        type: "option",
        category: "color"
      }
    },
    palette: {
      type: "palette",
      default: "sproingtime",
      uniform: "palette",
      requires: {
        "colorMode": 1
      },
      ui: {
        label: "palette",
        type: "palette",
        category: "palette",
        requires: {
          "colorMode": 1
        }
      }
    },
    paletteMode: {
      type: "int",
      default: 3,
      uniform: "paletteMode",
      choices: {
        "hsv": 1,
        "oklab": 2,
        "rgb": 3,
        "off": 4
      },
      ui: {
        control: false
      }
    },
    paletteOffset: {
      type: "vec3",
      default: [0.56, 0.69, 0.32],
      uniform: "paletteOffset",
      ui: {
        control: false
      }
    },
    paletteAmp: {
      type: "vec3",
      default: [0.9, 0.43, 0.34],
      uniform: "paletteAmp",
      ui: {
        control: false
      }
    },
    paletteFreq: {
      type: "vec3",
      default: [1, 1, 1],
      uniform: "paletteFreq",
      ui: {
        control: false
      }
    },
    palettePhase: {
      type: "vec3",
      default: [0.03, 0.8, 0.4],
      uniform: "palettePhase",
      ui: {
        control: false
      }
    },
    cyclePalette: {
      type: "int",
      default: -1,
      uniform: "cyclePalette",
      choices: {
        "off": 0,
        "forward": 1,
        "backward": -1
      },
      requires: {
        "colorMode": 1
      },
      ui: {
        label: "cycle palette",
        type: "option",
        category: "palette",
        requires: {
          "colorMode": 1
        }
      }
    },
    rotatePalette: {
      type: "float",
      default: 34.168161218985915,
      uniform: "rotatePalette",
      min: 0,
      max: 100,
      requires: {
        "colorMode": 1
      },
      ui: {
        label: "rotate palette",
        type: "float",
        category: "palette",
        requires: {
          "colorMode": 1
        }
      }
    },
    repeatPalette: {
      type: "int",
      default: 1,
      uniform: "repeatPalette",
      min: 1,
      max: 5,
      requires: {
        "colorMode": 1
      },
      ui: {
        label: "repeat palette",
        type: "int",
        category: "palette",
        requires: {
          "colorMode": 1
        }
      }
    },
    spawnPattern: {
      type: "int",
      default: 1,
      uniform: "spawnPattern",
      choices: {
        "random": 0,
        "clusters": 1,
        "ring": 2,
        "spiral": 3
      },
      ui: {
        label: "pattern",
        type: "option",
        category: "state"
      }
    },
    resetState: {
      type: "button",
      default: false,
      uniform: "resetState",
      ui: {
        label: "state",
        type: "button",
        buttonLabel: "reset",
        category: "util"
      }
    }
  };

  shaders = {
    agent: {
      fragment: `#version 300 es
precision highp float;
precision highp int;

uniform vec2 resolution;
uniform sampler2D stateTex;
uniform sampler2D bufTex;
uniform float moveSpeed;
uniform float turnSpeed;
uniform float sensorAngle;
uniform float sensorDistance;
uniform float time;
uniform float lifetime;
uniform float weight;
uniform int source;
uniform sampler2D inputTex;
uniform bool resetState;
uniform int spawnPattern;

out vec4 fragColor;

// Simple hash function for pseudo-random numbers
float hash(float n) {
    return fract(sin(n) * 43758.5453123);
}

vec2 wrapPosition(vec2 position, vec2 bounds) {
    return mod(position + bounds, bounds);
}

float luminance(vec3 color) {
    return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

vec3 sampleInputColor(vec2 uv) {
    vec2 flippedUV = vec2(uv.x, 1.0 - uv.y);
    vec3 sampleColor = vec3(0.0);
  if (source == 1) {
        sampleColor = texture(inputTex, flippedUV).rgb;
    }
    return sampleColor;
}

float sampleExternalField(vec2 uv) {
    if (source <= 0) {
        return 0.0;
    }
    return luminance(sampleInputColor(uv));
}

void main() {
    ivec2 stateSize = textureSize(stateTex, 0);
    vec2 uv = (gl_FragCoord.xy + vec2(0.5)) / vec2(stateSize);
    vec4 agent = texture(stateTex, uv);
    vec2 pos = agent.xy;
    float heading = agent.z;
    float age = agent.w;

    // Initialization / Reset
    if (resetState || (pos.x == 0.0 && pos.y == 0.0 && age == 0.0)) {
        float agentIndex = gl_FragCoord.y * float(stateSize.x) + gl_FragCoord.x;
        float seed = time + agentIndex;
        
        if (spawnPattern == 1) { // Clusters
            float clusterId = floor(hash(seed) * 5.0);
            vec2 center = vec2(hash(clusterId), hash(clusterId + 0.5)) * resolution;
            float r = hash(seed + 1.0) * min(resolution.x, resolution.y) * 0.15;
            float a = hash(seed + 2.0) * 6.28318530718;
            pos = center + vec2(cos(a), sin(a)) * r;
            heading = hash(seed + 3.0) * 6.28318530718;
        } else if (spawnPattern == 2) { // Ring
            vec2 center = resolution * 0.5;
            float r = min(resolution.x, resolution.y) * 0.35 + (hash(seed) - 0.5) * 20.0;
            float a = hash(seed + 1.0) * 6.28318530718;
            pos = center + vec2(cos(a), sin(a)) * r;
            heading = a + 1.5708; // Tangent
        } else if (spawnPattern == 3) { // Spiral
            vec2 center = resolution * 0.5;
            float t = hash(seed) * 20.0; 
            float r = t * min(resolution.x, resolution.y) * 0.02;
            float a = t * 6.28;
            pos = center + vec2(cos(a), sin(a)) * r;
            heading = a + 1.5708;
        } else { // Random (0)
            pos.x = hash(seed) * resolution.x;
            pos.y = hash(seed + 1.0) * resolution.y;
            heading = hash(seed + 2.0) * 6.28318530718;
        }
        
        pos = wrapPosition(pos, resolution);
        age = hash(seed + 3.0) * lifetime;
        fragColor = vec4(pos, heading, age);
        return;
    }

    // Lifetime respawn logic (0 = disabled)
    if (lifetime > 0.0) {
        // Calculate unique offset for this agent based on position in texture
        float agentIndex = gl_FragCoord.y * float(stateSize.x) + gl_FragCoord.x;
        float agentFraction = agentIndex / float(stateSize.x * stateSize.y);
        float spawnOffset = agentFraction * lifetime;
        
        // Check if this agent should respawn
        if (age > lifetime) {
            // Respawn at random position
            float seed = time * agentIndex;
            pos.x = hash(seed) * resolution.x;
            pos.y = hash(seed + 1.0) * resolution.y;
            heading = hash(seed + 2.0) * 6.28318530718;
            age = spawnOffset;
        }
    }

    float blend = clamp(weight * 0.01, 0.0, 1.0);

    vec2 forwardDir = vec2(cos(heading), sin(heading));
    vec2 leftDir = vec2(cos(heading - sensorAngle), sin(heading - sensorAngle));
    vec2 rightDir = vec2(cos(heading + sensorAngle), sin(heading + sensorAngle));

    vec2 sensorPosF = pos + forwardDir * sensorDistance;
    vec2 sensorPosL = pos + leftDir * sensorDistance;
    vec2 sensorPosR = pos + rightDir * sensorDistance;

    // Wrap sensor positions
    sensorPosF = wrapPosition(sensorPosF, resolution);
    sensorPosL = wrapPosition(sensorPosL, resolution);
    sensorPosR = wrapPosition(sensorPosR, resolution);

    // Sample trail map + external field
    float valF = texture(bufTex, sensorPosF / resolution).r + sampleExternalField(sensorPosF / resolution);
    float valL = texture(bufTex, sensorPosL / resolution).r + sampleExternalField(sensorPosL / resolution);
    float valR = texture(bufTex, sensorPosR / resolution).r + sampleExternalField(sensorPosR / resolution);

    // Steering
    if (valF > valL && valF > valR) {
        // Keep going forward
    } else if (valF < valL && valF < valR) {
        // Rotate randomly
        heading += (hash(time + pos.x) - 0.5) * 2.0 * turnSpeed * moveSpeed;
    } else if (valL > valR) {
        heading -= turnSpeed * moveSpeed;
    } else if (valR > valL) {
        heading += turnSpeed * moveSpeed;
    }

    // Move
    vec2 dir = vec2(cos(heading), sin(heading));
    float speedScale = 1.0;
    if (source > 0 && blend > 0.0) {
        float localInput = sampleExternalField(pos / resolution);
        // Invert: slow down in bright areas, speed up in dark areas
        speedScale = mix(1.0, mix(1.8, 0.35, localInput), blend);
    }
    pos += dir * (moveSpeed * speedScale);
    pos = wrapPosition(pos, resolution);

    // Update age
    age += 0.016;

    fragColor = vec4(pos, heading, age);
}`
    },
    deposit: {
      vertex: `#version 300 es
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
}`,
      fragment: `#version 300 es
precision highp float;
uniform float depositAmount;
uniform float weight;
uniform int source;
uniform sampler2D inputTex;
in vec2 vUV;
out vec4 fragColor;

float luminance(vec3 color) {
    return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

vec3 sampleInputColor(vec2 uv) {
    vec2 flippedUV = vec2(uv.x, 1.0 - uv.y);
    vec3 sampleColor = vec3(0.0);
  if (source == 1) {
        sampleColor = texture(inputTex, flippedUV).rgb;
    }
    return sampleColor;
}

float sampleInputLuminance(vec2 uv) {
    if (source <= 0) {
        return 0.0;
    }
    return luminance(sampleInputColor(uv));
}

void main() {
    float blend = clamp(weight * 0.01, 0.0, 1.0);
    float deposit = depositAmount;
    if (source > 0 && blend > 0.0) {
        float inputValue = sampleInputLuminance(vUV);
        float gain = mix(1.0, mix(0.25, 2.0, inputValue), blend);
        deposit *= gain;
    }
    fragColor = vec4(deposit, 0.0, 0.0, 1.0);
}`
    },
    diffuse: {
      fragment: `#version 300 es
precision highp float;
precision highp int;

uniform sampler2D sourceTex;
uniform vec2 resolution;
uniform float decay;
uniform float diffusion;
uniform float intensity;

out vec4 fragColor;

void main() {
    vec2 texel = 1.0 / resolution;
    vec2 uv = gl_FragCoord.xy * texel;

    float sum = 0.0;
    for (int x = -1; x <= 1; ++x) {
        for (int y = -1; y <= 1; ++y) {
            vec2 offset = vec2(float(x), float(y)) * texel;
            sum += texture(sourceTex, uv + offset).r;
        }
    }

    float current = texture(sourceTex, uv).r;
    float blurred = mix(current, sum / 9.0, clamp(diffusion, 0.0, 1.0));
    float value = max(blurred - max(decay, 0.0), 0.0);
    
    fragColor = vec4(value, 0.0, 0.0, 1.0);
}`
    }
  };

  passes = [
    {
      name: "agent",
      type: "render",
      program: "agent",
      inputs: {
        stateTex: "global_physarum_state",
        bufTex: "global_physarum_trail",
        inputTex: "inputTex"
      },
      outputs: {
        fragColor: "global_physarum_state"
      },
      uniforms: {
        spawnPattern: "spawnPattern"
      }
    },
    {
      name: "diffuse",
      type: "render",
      program: "diffuse",
      inputs: {
        sourceTex: "global_physarum_trail"
      },
      outputs: {
        fragColor: "global_physarum_trail"
      }
    },
    {
      name: "deposit",
      type: "render",
      program: "deposit",
      drawMode: "points",
      count: 1000000,
      blend: true,
      inputs: {
        stateTex: "global_physarum_state",
        inputTex: "inputTex"
      },
      outputs: {
        fragColor: "global_physarum_trail"
      }
    },
    {
      name: "render",
      type: "render",
      program: "physarum",
      inputs: {
              bufTex: "global_physarum_trail",
              inputTex: "inputTex"
            },
      outputs: {
        fragColor: "outputColor"
      }
    }
  ];
}
