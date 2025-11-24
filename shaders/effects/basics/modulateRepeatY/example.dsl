// Use another texture to modulate the
// vertical repeat spacing

noise(seed: 1)
  .out(o0)

noise(seed: 2)
  .modRepeatY(src(o0), 5)
  .out(o1)
