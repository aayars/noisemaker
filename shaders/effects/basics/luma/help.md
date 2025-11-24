````markdown
# luma

Luminance key that promotes bright pixels while suppressing darker tones. Alias: `lum`.

## Arguments

### `threshold`
- **Type:** Number.
- **Default:** `0.5`.
- **Range:** 0–1.
- **Description:** Threshold value.
### `tolerance`
- **Type:** Number.
- **Default:** `0.1`.
- **Range:** 0–1.
- **Description:** Tolerance value for luminance extraction.

## Examples

### Positional

```dsl
noise().luma(0.4, 0.2).out()
```

### Keyword

```dsl
noise().luma(threshold: 0.4, tolerance: 0.2).out()
```

````
