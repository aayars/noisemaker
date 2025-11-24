# src

Sample an existing surface without modifying it. Pass a generator or named surface

to the `tex` argument to reuse that image elsewhere in the chain.

## Arguments

### `tex`
- **Type:** Texture.
- **Default:** None (required).
- **Description:** Texture or generator to sample or mix with.

## Examples

### Positional

```dsl
src(noise()).out()
```

### Keyword

```dsl
src(tex: noise()).out()
```
