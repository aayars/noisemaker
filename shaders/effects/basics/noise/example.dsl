// Generate animated simplex noise with
// custom scale and octave settings

noise(scale: 4, offset: 0.1, octaves: 2)
  .out()

// Using enum values for color mode:
// - Shorthand: colorMode: mono, rgb, or hsv
// - Full path: colorMode: color.mono

// noise(scale: 5, colorMode: hsv).out()
