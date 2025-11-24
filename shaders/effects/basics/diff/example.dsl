// Do a differential blend between
// sources 1 and 2

noise(seed: 1)
  .out(o0)

noise(seed: 2)
  .diff(src(o0))
  .out(o1)
