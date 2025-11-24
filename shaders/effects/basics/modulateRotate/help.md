# modulateRotate

Rotate the base coordinates using a modulating texture (alias: modRotate).

## Arguments

### `tex`
- **Type:** Texture.
- **Default:** None (required).
- **Description:** Texture or generator to sample or mix with.
### `multiple`
- **Type:** Number.
- **Default:** `1`.
- **Range:** -10–10.
- **Description:** Multiplicative factor applied to the modulation source.
### `offset`
- **Type:** Number.
- **Default:** `0`.
- **Range:** -3.14159–3.14159.
- **Description:** Offset amount applied to the effect.

## Examples

### Positional

```dsl
noise().modRotate(noise(), 2).out()
```

### Keyword

```dsl
noise().modRotate(tex: noise(), multiple: 2).out()
```
