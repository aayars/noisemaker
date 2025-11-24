// Modulate horizontal scrolling speed
// with another texture

noise(seed: 1)
  .out(o0)

noise(seed: 2)
  .modScrollX(src(o0), 0.2)
  .out(o1)
