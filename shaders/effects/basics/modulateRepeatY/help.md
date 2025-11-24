# modulateRepeatY

Repeat the modulating texture along the Y axis before displacement (alias: modRepeatY).

## Arguments

### `tex`
- **Type:** Texture.
- **Default:** None (required).
- **Description:** Texture or generator to sample or mix with.
### `repeatY`
- **Type:** Number.
- **Default:** `3`.
- **Range:** 1–20.
- **Description:** Number of vertical repeats.
### `offsetY`
- **Type:** Number.
- **Default:** `0`.
- **Range:** -1–1.
- **Description:** Vertical offset applied to the effect.
### `amount`
- **Type:** Number.
- **Default:** `0.1`.
- **Range:** 0–1.
- **Description:** Blend amount contributed by the secondary input.

## Examples

### Positional

```dsl
noise().modRepeatY(noise(), 5).out()
```

### Keyword

```dsl
noise().modRepeatY(tex: noise(), repeatY: 5).out()
```
