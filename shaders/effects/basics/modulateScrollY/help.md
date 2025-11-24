# modulateScrollY

Scroll the modulating texture vertically before applying it (alias: modScrollY).

## Arguments

### `tex`
- **Type:** Texture.
- **Default:** None (required).
- **Description:** Texture or generator to sample or mix with.
### `scrollY`
- **Type:** Number.
- **Default:** `0.5`.
- **Range:** -10–10.
- **Description:** Vertical scroll modulation.
### `speed`
- **Type:** Number.
- **Default:** `0`.
- **Range:** -10–10.
- **Description:** Animation speed.
### `amount`
- **Type:** Number.
- **Default:** `0.1`.
- **Range:** 0–1.
- **Description:** Blend amount contributed by the secondary input.

## Examples

### Positional

```dsl
noise().modScrollY(noise(), 0.2).out()
```

### Keyword

```dsl
noise().modScrollY(tex: noise(), scrollY: 0.2).out()
```
