````markdown
# kaleid

Kaleidoscope by n slices.

## Arguments

### `n`
- **Type:** Number.
- **Default:** `3`.
- **Range:** 1–20.
- **Description:** Number of kaleidoscope segments.

## Examples

### Positional

```dsl
noise().kaleid(5).out()
```

### Keyword

```dsl
noise().kaleid(n: 5).out()
```

````
