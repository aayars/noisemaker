# Noisemaker Rendering Pipeline

The Noisemaker Rendering Pipeline is a high-performance, backend-agnostic system designed to execute complex, multi-pass visual effects on the GPU. It supports both WebGL 2 and WebGPU, allowing for declarative effect definitions and a powerful live-coding experience via the Polymorphic DSL that powers the Noisemaker Shader Effects Collection.

## Core Philosophy

- **Declarative Effects**: Effects are defined as data (JSON graphs), enabling easy composition and modification.
- **Graph-Based Execution**: The pipeline treats the entire frame as a Directed Acyclic Graph (DAG) of passes, optimizing execution order and resource usage.
- **Backend Agnostic**: The runtime abstracts away the differences between WebGL 2 and WebGPU.
- **Zero CPU Readback**: All data flow happens on the GPU to maximize performance.
- **Compute First**: First-class support for compute shaders.

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
