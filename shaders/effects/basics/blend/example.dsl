// Blend pixel values between source 1
// and source 2:

noise(seed: 1)
  .out(o0)

noise(seed: 2)
  .blend(src(o0), 0.3)
  .out(o1)
