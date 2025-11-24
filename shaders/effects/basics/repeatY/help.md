# repeatY

Repeat the source vertically.

## Arguments

### `y`
- **Type:** Number.
- **Default:** `3`.
- **Range:** 1–20.
- **Description:** Vertical factor or coordinate.
### `offset`
- **Type:** Number.
- **Default:** `0`.
- **Range:** -1–1.
- **Description:** Offset amount applied to the effect.

## Examples

### Positional

```dsl
noise().repeatY(5).out()
```

### Keyword

```dsl
noise().repeatY(y: 5).out()
```
