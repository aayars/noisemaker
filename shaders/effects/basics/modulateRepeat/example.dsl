// Modulate the repeat tiling using
// another texture as displacement

noise(seed: 1)
  .out(o0)

noise(seed: 2)
  .modRepeat(src(o0), 4, 2)
  .out(o1)
