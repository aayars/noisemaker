// Shift hue values by sampling from
// another texture as the modulation
// source

noise(seed: 1)
  .out(o0)

noise(seed: 2)
  .modHue(src(o0), 0.2)
  .out(o1)
