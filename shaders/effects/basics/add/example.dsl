// Additively blend the pixel values
// from source 1 with source 2:

noise(seed: 1)
  .out(o0)

noise(seed: 2)
  .add(src(o0), 0.5)
  .out(o1)
