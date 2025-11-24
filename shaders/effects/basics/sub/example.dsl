// Subtract pixel values from a base
// layer using another source

noise(seed: 1)
  .out(o0)

noise(seed: 2)
  .sub(src(o0), 0.5)
  .out(o1)
