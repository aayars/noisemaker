# colorparty

Animated color shifts driven by the input texture.

## Arguments

### `amount`
- **Type:** Number.
- **Default:** `0.005`.
- **Range:** -10–10.
- **Description:** Blend amount contributed by the secondary input.

## Examples

### Positional

```dsl
noise().colorparty(0.01).out()
```

### Keyword

```dsl
noise().colorparty(amount: 0.01).out()
```
