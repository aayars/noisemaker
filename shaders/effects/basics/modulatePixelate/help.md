# modulatePixelate

Pixelate the modulator before displacement (alias: modPixelate).

## Arguments

### `tex`
- **Type:** Texture.
- **Default:** None (required).
- **Description:** Texture or generator to sample or mix with.
### `pixelX`
- **Type:** Number.
- **Default:** `20`.
- **Range:** 1–1000.
- **Description:** Horizontal pixel block size.
### `pixelY`
- **Type:** Number.
- **Default:** `20`.
- **Range:** 1–1000.
- **Description:** Vertical pixel block size.
### `amount`
- **Type:** Number.
- **Default:** `0.1`.
- **Range:** 0–1.
- **Description:** Blend amount contributed by the secondary input.

## Examples

### Positional

```dsl
noise().modPixelate(noise(), 10, 30).out()
```

### Keyword

```dsl
noise().modPixelate(tex: noise(), pixelX: 10, pixelY: 30).out()
```
