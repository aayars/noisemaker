# modulateHue

Hue warp based on another texture (alias: modHue).

## Arguments

### `tex`
- **Type:** Texture.
- **Default:** None (required).
- **Description:** Texture or generator to sample or mix with.
### `amount`
- **Type:** Number.
- **Default:** `0.1`.
- **Range:** -1–1.
- **Description:** Blend amount contributed by the secondary input.

## Examples

### Positional

```dsl
noise().modHue(noise(), 0.2).out()
```

### Keyword

```dsl
noise().modHue(tex: noise(), amount: 0.2).out()
```
