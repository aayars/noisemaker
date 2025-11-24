// Isolate the brightest regions of a
// texture using luminance keying

noise()
  .luma(threshold: 0.4, tolerance: 0.2)
  .out()
