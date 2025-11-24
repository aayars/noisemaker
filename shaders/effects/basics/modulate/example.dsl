// Warp a base texture using another
// source as the modulation map

noise(seed: 1)
  .out(o0)

noise(seed: 2)
  .mod(src(o0), 0.3)
  .out(o1)
