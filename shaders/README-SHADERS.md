# Noisemaker Shaders

WebGPU/WGSL implementations of selected Noisemaker effects. This directory is a distinct, standalone track separate from the Python and JavaScript implementations—changes here do not affect the Python/JS pipelines, and vice‑versa.

## Current status

- Effects should load and run in the viewer without console errors.
- Many effects are still prototypes; quality and parameters may evolve.
- Visual parity with the Python reference is an active work in progress.
- PROTO marks shaders where a rough first pass is already in place. TODO flags effects that still need significant work or are only partially explored.

### Effect checklist

- [[ TODO ]] **clouds**
- [[ TODO ]] **dla**
- [[ TODO ]] **frame**
- [[ TODO ]] **jpeg_decimate**
- [[ TODO ]] **kaleido**
- [[ TODO ]] **lowpoly**
- [[ TODO ]] **shadow**
- [[ TODO ]] **sketch**
- [[ TODO ]] **texture**
- [[ TODO ]] **value_refract**
- [[ PROTO ]] **aberration**
- [[ PROTO ]] **adjust_brightness**
- [[ PROTO ]] **adjust_contrast**
- [[ PROTO ]] **adjust_hue**
- [[ PROTO ]] **adjust_saturation**
- [[ PROTO ]] **bloom**
- [[ PROTO ]] **blur**
- [[ PROTO ]] **color_map**
- [[ PROTO ]] **conv_feedback**
- [[ PROTO ]] **convolve**
- [[ PROTO ]] **crt**
- [[ PROTO ]] **degauss**
- [[ PROTO ]] **density_map**
- [[ PROTO ]] **derivative**
- [[ PROTO ]] **erosion_worms**
- [[ PROTO ]] **false_color**
- [[ PROTO ]] **fibers**
- [[ PROTO ]] **fxaa**
- [[ PROTO ]] **glowing_edges**
- [[ PROTO ]] **glyph_map**
- [[ PROTO ]] **grain**
- [[ PROTO ]] **grime**
- [[ PROTO ]] **lens_distortion**
- [[ PROTO ]] **lens_warp**
- [[ PROTO ]] **light_leak**
- [[ PROTO ]] **nebula**
- [[ PROTO ]] **normalize**
- [[ PROTO ]] **normal_map**
- [[ PROTO ]] **on_screen_display**
- [[ PROTO ]] **outline**
- [[ PROTO ]] **palette**
- [[ PROTO ]] **pixel_sort**
- [[ PROTO ]] **posterize**
- [[ PROTO ]] **refract**
- [[ PROTO ]] **reindex**
- [[ PROTO ]] **reverb**
- [[ PROTO ]] **ridge**
- [[ PROTO ]] **ripple**
- [[ PROTO ]] **rotate**
- [[ PROTO ]] **scanline_error**
- [[ PROTO ]] **scratches**
- [[ PROTO ]] **simple_frame**
- [[ PROTO ]] **sine**
- [[ PROTO ]] **snow**
- [[ PROTO ]] **sobel_operator**
- [[ PROTO ]] **spatter**
- [[ PROTO ]] **spooky_ticker**
- [[ PROTO ]] **stray_hair**
- [[ PROTO ]] **tint**
- [[ PROTO ]] **vaseline**
- [[ PROTO ]] **vhs**
- [[ PROTO ]] **vignette**
- [[ PROTO ]] **voronoi**
- [[ PROTO ]] **vortex**
- [[ PROTO ]] **warp**
- [[ PROTO ]] **wobble**
- [[ PROTO ]] **wormhole**
- [[ PROTO ]] **worms**

## Using the viewer

Open `demo/gpu-effects/index.html` with the project’s development server and select an effect from the menu. Each effect exposes parameters that mirror the Python reference where practical.

## Development notes

- This shader collection is independent from the Python and JS pipelines. Keep implementations and controls consistent, but do not couple code across directories.
- All textures/buffers are treated as 4‑channel RGBA. Do not branch on channel count.
- WGSL struct members end with a trailing comma, not a semicolon.
- Controls in the demo should strive to match Python effect params (except "shape").
- See `shaders/IMPLEMENTATION_GUIDE.md` for architecture, binding layouts, and tutorials.
