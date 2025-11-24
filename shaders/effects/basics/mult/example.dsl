// Multiply pixel values from a base
// layer by another source

noise(seed: 1)
  .out(o0)

noise(seed: 2)
  .mult(src(o0), 0.8)
  .out(o1)
