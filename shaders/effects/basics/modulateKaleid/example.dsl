// Distort kaleidoscope reflections with
// a secondary modulation texture

noise(seed: 1)
  .out(o0)

noise(seed: 2)
  .modKaleid(src(o0), 5, 0.2)
  .out(o1)
