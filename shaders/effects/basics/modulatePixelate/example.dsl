// Animate pixelation by modulating the
// pixel grid with another texture

noise(seed: 1)
  .out(o0)

noise(seed: 2)
  .modPixelate(src(o0), 10, 30)
  .out(o1)
