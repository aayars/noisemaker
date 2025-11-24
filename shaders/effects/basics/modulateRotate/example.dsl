// Drive rotational offsets by sampling
// from another modulation texture

noise(seed: 1)
  .out(o0)

noise(seed: 2)
  .modRotate(src(o0), 2)
  .out(o1)
