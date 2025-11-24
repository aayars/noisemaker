# repeatX

Repeat the source horizontally.

## Arguments

### `x`
- **Type:** Number.
- **Default:** `3`.
- **Range:** 1–20.
- **Description:** Horizontal factor or coordinate.
### `offset`
- **Type:** Number.
- **Default:** `0`.
- **Range:** -1–1.
- **Description:** Offset amount applied to the effect.

## Examples

### Positional

```dsl
noise().repeatX(5).out()
```

### Keyword

```dsl
noise().repeatX(x: 5).out()
```
