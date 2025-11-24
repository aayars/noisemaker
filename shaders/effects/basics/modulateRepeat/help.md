# modulateRepeat

Tile the modulating texture before warping the base surface (alias: modRepeat).

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
### `repeatY`
- **Type:** Number.
- **Default:** `3`.
- **Range:** 1–20.
- **Description:** Number of vertical repeats.
### `offsetX`
- **Type:** Number.
- **Default:** `0`.
- **Range:** -1–1.
- **Description:** Horizontal offset applied to the effect.
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
noise().modRepeat(noise(), 4, 2).out()
```

### Keyword

```dsl
noise().modRepeat(tex: noise(), repeatX: 4, repeatY: 2).out()
```
