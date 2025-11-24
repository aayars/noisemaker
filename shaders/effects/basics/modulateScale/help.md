# modulateScale

Scale the modulating texture before applying (alias: modScale).

## Arguments

### `tex`
- **Type:** Texture.
- **Default:** None (required).
- **Description:** Texture or generator to sample or mix with.
### `multiple`
- **Type:** Number.
- **Default:** `1`.
- **Range:** 0.1–20.
- **Description:** Multiplicative factor applied to the modulation source.
### `offset`
- **Type:** Number.
- **Default:** `0`.
- **Range:** -1–1.
- **Description:** Offset amount applied to the effect.
### `amount`
- **Type:** Number.
- **Default:** `0.1`.
- **Range:** 0–1.
- **Description:** Blend amount contributed by the secondary input.

## Examples

### Positional

```dsl
noise().modScale(noise(), 1.5).out()
```

### Keyword

```dsl
noise().modScale(tex: noise(), multiple: 1.5).out()
```
