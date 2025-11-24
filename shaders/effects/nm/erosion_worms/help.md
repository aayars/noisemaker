# Erosion Worms

Toggle the erosion worms effect on or off.

## Parameters

- **Density**: Agent density relative to the frame dimensions.
- **Stride**: Gradient step length applied to each agent.
- **Quantize**: Floor gradient samples before steering agents.
- **Trail Persistence**: Percent of the previous frame preserved each step.
- **Inverse**: Invert the gradient direction to climb instead of descend.
- **XY Blend**: Reserved for parity; currently unused in the shader.
- **Lifetime**: Seconds before an agent respawns at a new location.
- **Input Intensity**: Percent of the source texture retained in the final blend.
