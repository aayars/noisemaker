// Use a secondary texture as an alpha
// mask for the base layer

noise(seed: 1)
  .out(o0)

noise(seed: 2)
  .mask(src(o0))
  .out(o1)
