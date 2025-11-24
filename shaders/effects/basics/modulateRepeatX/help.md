# modulateRepeatX

Tile the modulating texture horizontally before warping the base surface (alias: modRepeatX).

## Arguments

### `tex`
- **Type:** Texture.
- **Default:** None (required).
- **Description:** Texture or generator to sample or mix with.
### `repeatX`
- **Type:** Number.
- **Default:** `3`.
- **Range:** 1–20.
- **Description:** Number of horizontal repeats.
### `offsetX`
- **Type:** Number.
- **Default:** `0`.
- **Range:** -1–1.
- **Description:** Horizontal offset applied to the effect.
### `amount`
- **Type:** Number.
- **Default:** `0.1`.
- **Range:** 0–1.
- **Description:** Blend amount contributed by the secondary input.

## Examples

### Positional

```dsl
noise().modRepeatX(noise(), 5).out()
```

### Keyword

```dsl
noise().modRepeatX(tex: noise(), repeatX: 5).out()
```
