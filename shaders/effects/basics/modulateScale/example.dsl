// Scale a texture using another source
// to modulate the zoom amount

noise(seed: 1)
  .out(o0)

noise(seed: 2)
  .modScale(src(o0), 1.5)
  .out(o1)
