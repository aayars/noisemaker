# shift

Offset individual RGBA channels before compositing.

## Arguments

### `r`
- **Type:** Number.
- **Default:** `0.5`.
- **Range:** -1–1.
- **Description:** Red channel multiplier or base value.
### `g`
- **Type:** Number.
- **Default:** `0`.
- **Range:** -1–1.
- **Description:** Green channel multiplier or base value.
### `b`
- **Type:** Number.
- **Default:** `0`.
- **Range:** -1–1.
- **Description:** Blue channel multiplier or base value.
### `a`
- **Type:** Number.
- **Default:** `0`.
- **Range:** -1–1.
- **Description:** Scalar multiplier applied to the effect.

## Examples

### Positional

```dsl
noise().shift(0.25).out()
```

### Keyword

```dsl
noise().shift(r: 0.25).out()
```
