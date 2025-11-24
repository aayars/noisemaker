// Use another texture to modulate the
// horizontal repeat spacing

noise(seed: 1)
  .out(o0)

noise(seed: 2)
  .modRepeatX(src(o0), 5)
  .out(o1)
