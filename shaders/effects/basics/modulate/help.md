# modulate

Warp image with another texture (alias: mod).

## Arguments

### `tex`
- **Type:** Texture.
- **Default:** None (required).
- **Description:** Texture or generator to sample or mix with.
### `amount`
- **Type:** Number.
- **Default:** `0.1`.
- **Range:** 0–1.
- **Description:** Blend amount contributed by the secondary input.

## Examples

### Positional

```dsl
noise().mod(noise(), 0.3).out()
```

### Keyword

```dsl
noise().mod(tex: noise(), amount: 0.3).out()
```
