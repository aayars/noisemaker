# osc

Oscillator pattern; pass index for built-in oscillators.

## Arguments

### `freq`
- **Type:** Number.
- **Default:** `10`.
- **Range:** 0–1000.
- **Description:** Oscillator frequency in Hertz-like units.
### `sync`
- **Type:** Number.
- **Default:** `0.1`.
- **Range:** 0–10.
- **Description:** Synchronization amount for oscillations.
### `amp`
- **Type:** Number.
- **Default:** `1`.
- **Range:** 0–10.
- **Description:** Oscillator amplitude that controls waveform contrast.

## Examples

### Positional

```dsl
osc(5, 0.2, 0.5).out()
```

### Keyword

```dsl
osc(freq: 5, sync: 0.2, amp: 0.5).out()
```
