# Noisemaker Rendering Pipeline

The Noisemaker Rendering Pipeline is a high-performance, backend-agnostic system designed to execute complex, multi-pass visual effects on the GPU. It supports both WebGL 2 and WebGPU, allowing for declarative effect definitions and a powerful live-coding experience via the Polymorphic DSL that powers the Noisemaker Shader Effects Collection.

## Core Philosophy

- **Declarative Effects**: Effects are defined as data (JSON graphs), enabling easy composition and modification.
- **Graph-Based Execution**: The pipeline treats the entire frame as a Directed Acyclic Graph (DAG) of passes, optimizing execution order and resource usage.
- **Backend Agnostic**: The runtime abstracts away the differences between WebGL 2 and WebGPU.
- **Zero CPU Readback**: All data flow happens on the GPU to maximize performance.
- **Compute First**: First-class support for compute shaders.

## Compute Passes and GPGPU Fallback

Effects that perform state updates, simulations, or multi-output operations use `type: "compute"` in their pass definitions for **semantic correctness**. This clearly communicates the intent of the pass.

### Backend Handling

- **WebGPU (WGSL)**: Native compute shaders with `@compute` entry points
- **WebGL2 (GLSL)**: Graceful fallback to GPGPU render passes

The WebGL2 backend automatically converts compute passes to render passes using a GPGPU pattern:
- Fragment shaders perform the "compute" work
- Multiple Render Targets (MRT) handle multi-output passes via `gl.drawBuffers()`
- Points draw mode enables scatter operations for agent-based effects

### Example

```javascript
// Effect definition uses semantic type: "compute"
{
  id: "agent-update",
  type: "compute",  // Semantically correct - this updates state
  outputs: ["state1", "state2"],  // Multi-output
  shader: { glsl: agentShaderGLSL, wgsl: agentShaderWGSL }
}
```

On WebGPU, this dispatches a compute shader. On WebGL2, the runtime converts it to a render pass with MRT, achieving the same result with maximum compatibility.

### Agent-Based Effects

Effects like `erosion_worms` and `physarum` use agents that:
1. Read state from textures
2. Update positions/velocities via compute/GPGPU passes
3. Deposit trails using points draw mode (scatter)
4. Diffuse/blur accumulated trails

This pattern requires MRT for multi-output state updates and careful texture management.

## Live Demo

Explore the pipeline's effects with the interactive demo:

- **[index.html](index.html)**: Live demo showcasing all effects with a two-column interface featuring real-time parameter controls and GLSL/WGSL backend selection.

## Documentation

- **[Effects Specification](../docs/shaders/effects.rst)**: The schema and format for defining effects as JSON graphs.
- **[Language Specification](../docs/shaders/language.rst)**: Specification for the Polymorphic DSL used to chain effects.
- **[Pipeline Specification](../docs/shaders/pipeline.rst)**: Detailed overview of the pipeline architecture, including graph compilation, resource allocation, and execution phases.
- **[Compiler Specification](../docs/shaders/compiler.rst)**: Detailed breakdown of how the DSL is compiled into an executable GPU Render Graph.

## Architecture

The pipeline operates in three main phases:

1.  **Graph Compilation**: Parses the DSL, expands effects into constituent passes, and performs topological sorting.
2.  **Resource Allocation**: Manages a shared pool of textures and allocates them to graph nodes efficiently.
3.  **Execution**: Dispatches the render passes to the GPU driver.
