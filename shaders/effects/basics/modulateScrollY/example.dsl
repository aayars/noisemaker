// Modulate vertical scrolling speed
// with another texture

noise(seed: 1)
  .out(o0)

noise(seed: 2)
  .modScrollY(src(o0), 0.2)
  .out(o1)
