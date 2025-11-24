# modulateKaleid

Kaleidoscopic modulation (alias: modKaleid).

## Arguments

### `tex`
- **Type:** Texture.
- **Default:** None (required).
- **Description:** Texture or generator to sample or mix with.
### `n`
- **Type:** Number.
- **Default:** `3`.
- **Range:** 1–20.
- **Description:** Number of kaleidoscope segments.
### `amount`
- **Type:** Number.
- **Default:** `0.1`.
- **Range:** 0–1.
- **Description:** Blend amount contributed by the secondary input.

## Examples

### Positional

```dsl
noise().modKaleid(noise(), 5, 0.2).out()
```

### Keyword

```dsl
noise().modKaleid(tex: noise(), n: 5, amount: 0.2).out()
```
