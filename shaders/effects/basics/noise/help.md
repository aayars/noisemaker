# noise

Animated simplex noise.

## Arguments

### `scale`
- **Type:** Number.
- **Default:** `3`.
- **Range:** 0–100.
- **Description:** Overall scale of the effect.
### `offset`
- **Type:** Number.
- **Default:** `0`.
- **Range:** -100–100.
- **Description:** Offset amount applied to the effect.
### `octaves`
- **Type:** Number.
- **Default:** `1`.
- **Range:** 1–6.
- **Description:** Number of noise octaves sampled.
### `colorMode`
- **Type:** Enum (`color`).
- **Allowed values:** `mono`, `rgb`, `hsv` (can be specified as identifiers or full paths like `color.rgb`).
- **Default:** `rgb`.
- **Description:** Color space or gradient mode selection.
### `hueRot`
- **Type:** Number.
- **Default:** `0`.
- **Range:** 0–360.
- **Description:** Base hue rotation.
### `hueRange`
- **Type:** Number.
- **Default:** `100`.
- **Range:** 0–100.
- **Description:** Span of hues to cycle through.
### `ridged`
- **Type:** Boolean.
- **Default:** `false`.
- **Description:** Enables ridged multifractal noise.
### `seed`
- **Type:** Number.
- **Default:** `0`.
- **Range:** 0–100.
- **Description:** Random seed used to initialize the effect.

## Examples

### Positional

```dsl
noise(4, 0.1, 2).out()
```

### Keyword

```dsl
noise(scale: 4, offset: 0.1, octaves: 2).out()
```
