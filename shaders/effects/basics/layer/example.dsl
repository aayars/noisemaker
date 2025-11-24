// Layer another texture on top of an
// existing surface in the chain

noise(seed: 1)
  .out(o0)

noise(seed: 2)
  .layer(src(o0))
  .out(o1)
