# modulateScrollX

Scroll the modulating texture horizontally before applying it (alias: modScrollX).

## Arguments

### `tex`
- **Type:** Texture.
- **Default:** None (required).
- **Description:** Texture or generator to sample or mix with.
### `scrollX`
- **Type:** Number.
- **Default:** `0.5`.
- **Range:** -10–10.
- **Description:** Horizontal scroll modulation.
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
noise().modScrollX(noise(), 0.2).out()
```

### Keyword

```dsl
noise().modScrollX(tex: noise(), scrollX: 0.2).out()
```
