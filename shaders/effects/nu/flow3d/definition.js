import { Effect } from '../../../src/runtime/effect.js';

/**
 * Flow3D - 3D agent-based flow field effect with volume accumulation
 * 
 * Direct and faithful port of nu/flow to 3D.
 * 
 * Architecture:
 * - Agent state stored in 2D textures (position, color, age) with MRT
 * - Agents sample from input 3D volume (inputTex3d) for color AND flow direction
 * - Trail accumulation stored in 3D volume atlas
 * - Blend pass combines input 3D volume with trail → blended volume
 * - Render pass raymarches blended volume to screen (like noise3d, cell3d)
 * - Multi-pass: agent -> diffuse -> deposit -> blend -> render
 * 
 * Agent format (matching 2D flow):
 * - state1: [x, y, z, rotRand]        - 3D position + per-agent rotation random
 * - state2: [r, g, b, seed]           - color + seed
 * - state3: [age, initialized, strideRand, 0] - age, init flag, stride random
 */
export default class Flow3D extends Effect {
  name = "Flow3D";
  namespace = "nu";
  func = "flow3d";

  // Textures for agent state and trail accumulation
  textures = {
    // Agent state buffers (2D, for agent grid)
    globalFlow3dState1: {
      width: 512,
      height: 512,
      format: "rgba16f"
    },
    globalFlow3dState2: {
      width: 512,
      height: 512,
      format: "rgba16f"
    },
    globalFlow3dState3: {
      width: 512,
      height: 512,
      format: "rgba16f"
    },
    // 3D trail volume as 2D atlas (volumeSize x volumeSize²)
    globalFlow3dTrail: {
      width: { param: 'volumeSize', default: 32 },
      height: { param: 'volumeSize', power: 2, default: 1024 },
      format: "rgba16f"
    },
    // Blended volume (input + trail)
    globalFlow3dBlended: {
      width: { param: 'volumeSize', default: 32 },
      height: { param: 'volumeSize', power: 2, default: 1024 },
      format: "rgba16f"
    }
  };

  globals = {
    "volumeSize": {
      "type": "int",
      "default": 32,
      "uniform": "volumeSize",
      "choices": {
        "16³": 16,
        "32³": 32,
        "64³": 64
      },
      "ui": {
        "label": "volume resolution",
        "control": "dropdown"
      }
    },
    "behavior": {
      "type": "int",
      "default": 1,
      "uniform": "behavior",
      "choices": {
        "None": 0,
        "Obedient": 1,
        "Crosshatch": 2,
        "Unruly": 3,
        "Chaotic": 4,
        "Random Mix": 5,
        "Meandering": 10
      },
      "ui": {
        "label": "Behavior",
        "control": "dropdown"
      }
    },
    "density": {
      "type": "float",
      "default": 20,
      "uniform": "density",
      "min": 1,
      "max": 100,
      "step": 1,
      "ui": {
        "label": "Density",
        "control": "slider"
      }
    },
    "stride": {
      "type": "float",
      "default": 1,
      "uniform": "stride",
      "min": 0.1,
      "max": 10,
      "step": 0.1,
      "ui": {
        "label": "Stride",
        "control": "slider"
      }
    },
    "strideDeviation": {
      "type": "float",
      "default": 0.05,
      "uniform": "strideDeviation",
      "min": 0,
      "max": 0.5,
      "step": 0.01,
      "ui": {
        "label": "Stride Deviation",
        "control": "slider"
      }
    },
    "kink": {
      "type": "float",
      "default": 1,
      "uniform": "kink",
      "min": 0,
      "max": 10,
      "step": 0.1,
      "ui": {
        "label": "Kink",
        "control": "slider"
      }
    },
    "intensity": {
      "type": "float",
      "default": 90,
      "uniform": "intensity",
      "min": 0,
      "max": 100,
      "step": 1,
      "ui": {
        "label": "Trail Persistence",
        "control": "slider"
      }
    },
    "inputIntensity": {
      "type": "float",
      "default": 50,
      "uniform": "inputIntensity",
      "min": 0,
      "max": 100,
      "step": 1,
      "ui": {
        "label": "Input Intensity",
        "control": "slider"
      }
    },
    "lifetime": {
      "type": "float",
      "default": 30,
      "uniform": "lifetime",
      "min": 0,
      "max": 60,
      "step": 1,
      "ui": {
        "label": "Lifetime",
        "control": "slider"
      }
    },
    "threshold": {
      "type": "float",
      "default": 0.1,
      "min": 0,
      "max": 1,
      "uniform": "threshold",
      "ui": {
        "label": "surface threshold"
      }
    },
    "invert": {
      "type": "boolean",
      "default": false,
      "uniform": "invert",
      "ui": {
        "label": "invert threshold"
      }
    },
    "orbitSpeed": {
      "type": "int",
      "default": 1,
      "min": -5,
      "max": 5,
      "uniform": "orbitSpeed",
      "ui": {
        "label": "orbit speed"
      }
    },
    "bgColor": {
      "type": "vec3",
      "default": [0.02, 0.02, 0.02],
      "uniform": "bgColor",
      "ui": {
        "label": "background color",
        "control": "color"
      }
    },
    "bgAlpha": {
      "type": "float",
      "default": 1.0,
      "min": 0,
      "max": 1,
      "uniform": "bgAlpha",
      "ui": {
        "label": "background alpha"
      }
    }
  };

  passes = [
    {
      name: "agent",
      program: "agent",
      drawBuffers: 3,
      inputs: {
        stateTex1: "globalFlow3dState1",
        stateTex2: "globalFlow3dState2",
        stateTex3: "globalFlow3dState3",
        mixerTex: "inputTex3d"
      },
      uniforms: {
        behavior: "behavior",
        density: "density",
        stride: "stride",
        strideDeviation: "strideDeviation",
        kink: "kink",
        lifetime: "lifetime",
        volumeSize: "volumeSize"
      },
      outputs: {
        outState1: "globalFlow3dState1",
        outState2: "globalFlow3dState2",
        outState3: "globalFlow3dState3"
      }
    },
    {
      name: "diffuse",
      program: "diffuse",
      viewport: { 
        width: { param: 'volumeSize', default: 32 },
        height: { param: 'volumeSize', power: 2, default: 1024 }
      },
      inputs: {
        sourceTex: "globalFlow3dTrail"
      },
      uniforms: {
        intensity: "intensity"
      },
      outputs: {
        fragColor: "globalFlow3dTrail"
      }
    },
    {
      name: "deposit",
      program: "deposit",
      drawMode: "points",
      count: 262144,
      blend: true,
      viewport: { 
        width: { param: 'volumeSize', default: 32 },
        height: { param: 'volumeSize', power: 2, default: 1024 }
      },
      inputs: {
        stateTex1: "globalFlow3dState1",
        stateTex2: "globalFlow3dState2"
      },
      uniforms: {
        density: "density",
        volumeSize: "volumeSize"
      },
      outputs: {
        fragColor: "globalFlow3dTrail"
      }
    },
    {
      name: "blend",
      program: "blend",
      viewport: { 
        width: { param: 'volumeSize', default: 32 },
        height: { param: 'volumeSize', power: 2, default: 1024 }
      },
      inputs: {
        mixerTex: "inputTex3d",
        trailTex: "globalFlow3dTrail"
      },
      uniforms: {
        inputIntensity: "inputIntensity"
      },
      outputs: {
        fragColor: "globalFlow3dBlended"
      }
    },
    {
      name: "render",
      program: "flow3d",
      inputs: {
        volumeCache: "globalFlow3dBlended"
      },
      uniforms: {
        threshold: "threshold",
        invert: "invert",
        volumeSize: "volumeSize",
        orbitSpeed: "orbitSpeed",
        bgColor: "bgColor",
        bgAlpha: "bgAlpha"
      },
      outputs: {
        fragColor: "outputTex"
      }
    }
  ];

  // Expose the blended volume as the 3D output
  outputTex3d = "globalFlow3dBlended";
}
