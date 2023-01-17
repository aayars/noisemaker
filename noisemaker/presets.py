import functools
import random

from noisemaker.composer import Effect, Preset, coin_flip, enum_range, random_member, stash
from noisemaker.constants import (
    ColorSpace as color,
    DistanceMetric as distance,
    InterpolationType as interp,
    OctaveBlending as blend,
    PointDistribution as point,
    ValueDistribution as distrib,
    ValueMask as mask,
    VoronoiDiagramType as voronoi,
    WormBehavior as worms,
)
from noisemaker.palettes import PALETTES

import noisemaker.masks as masks

#: A dictionary of presets for use with the "noisemaker generator" and "noisemaker effect" commands.
PRESETS = lambda: {  # noqa E731
    "1969": {
        "layers": ["symmetry", "voronoi", "posterize-outline", "distressed"],
        "settings": lambda: {
            "dist_metric": distance.euclidean,
            "palette_on": False,
            "voronoi_alpha": .5 + random.random() * .5,
            "voronoi_diagram_type": voronoi.color_range,
            "voronoi_point_corners": True,
            "voronoi_point_distrib": point.circular,
            "voronoi_point_freq": random.randint(3, 5) * 2,
            "voronoi_nth": random.randint(1, 3),
        },
        "generator": lambda settings: {
            "color_space": color.rgb,
        },
    },

    "1976": {
        "layers": ["voronoi"],
        "settings": lambda: {
            "dist_metric": distance.triangular,
            "voronoi_diagram_type": voronoi.color_regions,
            "voronoi_nth": 0,
            "voronoi_point_distrib": point.random,
            "voronoi_point_freq": 2,
        },
        "post": lambda settings: [
            Preset("dither"),
            Effect("adjust_saturation", amount=.25 + random.random() * .125)
        ]
    },

    "1985": {
        "layers": ["reindex-post", "voronoi"],
        "settings": lambda: {
            "dist_metric": distance.chebyshev,
            "reindex_range": .2 + random.random() * .1,
            "voronoi_diagram_type": voronoi.range,
            "voronoi_nth": 0,
            "voronoi_point_distrib": point.random,
            "voronoi_refract": .2 + random.random() * .1
        },
        "generator": lambda settings: {
            "freq": random.randint(10, 15),
            "spline_order": interp.constant
        },
        "post": lambda settings: [
            Effect("palette", name="neon"),
            Preset("random-hue"),
            Effect("spatter"),
            Preset("be-kind-rewind")
        ]
    },

    "2001": {
        "layers": ["analog-glitch", "invert", "posterize", "vignette-bright", "aberration"],
        "settings": lambda: {
            "mask": mask.bank_ocr,
            "mask_repeat": random.randint(9, 12),
            "vignette_alpha": .75 + random.random() * .25,
            "posterize_levels": random.randint(1, 2),
        },
        "generator": lambda settings: {
            "spline_order": interp.cosine,
        }
    },

    "2d-chess": {
        "layers": ["value-mask", "voronoi", "rotate"],
        "settings": lambda: {
            "dist_metric": random_member(distance.absolute_members()),
            "voronoi_alpha": 0.5 + random.random() * .5,
            "voronoi_diagram_type": voronoi.color_range if coin_flip() \
                else random_member([m for m in voronoi if not voronoi.is_flow_member(m) and m != voronoi.none]),  # noqa E131
            "voronoi_nth": random.randint(0, 1) * random.randint(0, 63),
            "voronoi_point_corners": True,
            "voronoi_point_distrib": point.square,
            "voronoi_point_freq": 8,
        },
        "generator": lambda settings: {
            "corners": True,
            "freq": 8,
            "mask": mask.chess,
            "spline_order": interp.constant,
        }
    },

    "aberration": {
        "settings": lambda: {
            "aberration_displacement": .025 + random.random() * .00125
        },
        "post": lambda settings: [Effect("aberration", displacement=settings["aberration_displacement"])]
    },

    "abyssal-echoes": {
        "layers": ["multires-alpha", "saturation", "random-hue"],
        "generator": lambda settings: {
            "color_space": color.rgb,
        },
        "octaves": lambda settings: [
            Effect("refract",
                   displacement=random.randint(20, 30),
                   from_derivative=True,
                   y_from_offset=False)
        ],
    },

    "acid": {
        "layers": ["reindex-post", "normalize"],
        "settings": lambda: {
            "reindex_range": 1.25 + random.random() * 1.25,
        },
        "generator": lambda settings: {
            "color_space": color.rgb,
            "freq": random.randint(10, 15),
            "octaves": 8,
        },
    },

    "acid-droplets": {
        "layers": ["multires", "reflect-octaves", "density-map", "random-hue", "bloom", "shadow", "saturation"],
        "settings": lambda: {
            "palette_on": False,
            "reflect_range": 7.5 + random.random() * 3.5
        },
        "generator": lambda settings: {
            "freq": random.randint(8, 12),
            "hue_range": 0,
            "lattice_drift": 1.0,
            "mask": mask.sparse,
            "mask_static": True,
        },
    },

    "acid-grid": {
        "layers": ["voronoi-refract", "sobel", "funhouse", "bloom"],
        "settings": lambda: {
            "dist_metric": distance.euclidean,
            "voronoi_alpha": .333 + random.random() * .333,
            "voronoi_diagram_type": voronoi.color_range,
            "voronoi_point_distrib": random_member(point.grid_members()),
            "voronoi_point_freq": 4,
            "voronoi_point_generations": 2,
        },
        "generator": lambda settings: {
            "lattice_drift": coin_flip(),
        },
    },

    "acid-wash": {
        "layers": ["funhouse", "ridge", "shadow", "saturation"],
        "settings": lambda: {
            "warp_octaves": 8,
        },
        "generator": lambda settings: {
            "freq": random.randint(4, 6),
            "hue_range": 1.0,
            "ridges": True,
        },
    },

    "activation-signal": {
        "layers": ["value-mask", "maybe-palette", "glitchin-out"],
        "generator": lambda settings: {
            "color_space": random_member(color.color_members()),
            "freq": 4,
            "mask": mask.white_bear,
            "spline_order": interp.constant,
        }
    },

    "aesthetic": {
        "layers": ["maybe-derivative-post", "spatter", "maybe-invert", "be-kind-rewind", "spatter"],
        "generator": lambda settings: {
            "corners": True,
            "distrib": random_member([distrib.column_index, distrib.ones, distrib.row_index]),
            "freq": random.randint(3, 5) * 2,
            "mask": mask.chess,
            "spline_order": interp.constant,
        },
    },

    "alien-terrain-multires": {
        "layers": ["multires-ridged", "derivative-octaves", "maybe-invert", "bloom", "shadow", "saturation"],
        "settings": lambda: {
            "deriv_alpha": .333 + random.random() * .333,
            "dist_metric": distance.euclidean,
            "palette_on": False,
        },
        "generator": lambda settings: {
            "freq": random.randint(5, 9),
            "lattice_drift": 1.0,
            "octaves": 8,
        }
    },

    "alien-terrain-worms": {
        "layers": ["multires-ridged", "invert", "voronoi", "derivative-octaves", "invert",
                   "erosion-worms", "bloom", "shadow", "dither", "contrast", "saturation"],
        "settings": lambda: {
            "contrast": 2.0,
            "deriv_alpha": .25 + random.random() * .125,
            "dist_metric": distance.euclidean,
            "erosion_worms_alpha": .05 + random.random() * .025,
            "erosion_worms_density": random.randint(150, 200),
            "erosion_worms_inverse": True,
            "erosion_worms_xy_blend": .333 + random.random() * .16667,
            "palette_on": False,
            "voronoi_alpha": .5 + random.random() * .25,
            "voronoi_diagram_type": voronoi.flow,
            "voronoi_point_freq": 10,
            "voronoi_point_distrib": point.random,
            "voronoi_refract": .25 + random.random() * .125,
        },
        "generator": lambda settings: {
            "freq": random.randint(3, 5),
            "hue_rotation": .875,
            "hue_range": .25 + random.random() * .25,
        },
    },

    "alien-transmission": {
        "layers": ["analog-glitch", "sobel", "glitchin-out"],
        "settings": lambda: {
            "mask": random_member(mask.procedural_members()),
        }
    },

    "analog-glitch": {
        "layers": ["value-mask"],
        "settings": lambda: {
            "mask": random_member([mask.alphanum_hex, mask.lcd, mask.fat_lcd]),
            "mask_repeat": random.randint(20, 30),
        },
        "generator": lambda settings: {
            # offset by i * .5 for glitched texture lookup
            "freq": [int(i * .5 + i * settings["mask_repeat"]) for i in masks.mask_shape(settings["mask"])[0:2]],
            "mask": settings["mask"],
        }
    },

    "arcade-carpet": {
        "layers": ["basic", "funhouse", "posterize", "nudge-hue", "contrast", "dither"],
        "settings": lambda: {
            "palette_on": False,
            "posterize_levels": 3,
            "warp_freq": random.randint(75, 125),
            "warp_range": .02 + random.random() * .01,
            "warp_octaves": 1,
        },
        "generator": lambda settings: {
            "color_space": color.rgb,
            "distrib": distrib.exp,
            "freq": settings["warp_freq"],
            "hue_range": 1,
            "mask": mask.sparser,
            "mask_static": True,
        }
    },

    "are-you-human": {
        "layers": ["multires", "value-mask", "funhouse", "density-map", "saturation", "maybe-invert", "aberration", "snow"],
        "generator": lambda settings: {
            "freq": 15,
            "hue_range": random.random() * .25,
            "hue_rotation": random.random(),
            "mask": mask.truetype,
        },
    },

    "aztec-waffles": {
        "layers": ["symmetry", "voronoi", "maybe-invert", "reflect-post"],
        "settings": lambda: {
            "dist_metric": random_member([distance.manhattan, distance.chebyshev]),
            "reflect_range": random.randint(12, 25),
            "voronoi_diagram_type": voronoi.color_range,
            "voronoi_nth": random.randint(2, 4),
            "voronoi_point_distrib": point.circular,
            "voronoi_point_freq": 4,
            "voronoi_point_generations": 2,
        },
    },

    "basic": {
        "layers": ["maybe-palette", "normalize"],
        "generator": lambda settings: {
            "color_space": random_member(color.color_members()),
            "freq": [random.randint(2, 4), random.randint(2, 4)],
        },
    },

    "basic-lowpoly": {
        "layers": ["basic", "lowpoly"],
    },

    "basic-voronoi": {
        "layers": ["basic", "voronoi"],
        "settings": lambda: {
            "voronoi_diagram_type": random_member([voronoi.color_range, voronoi.color_regions,
                                                   voronoi.range_regions, voronoi.color_flow])
        }
    },

    "basic-voronoi-refract": {
        "layers": ["basic", "voronoi"],
        "settings": lambda: {
            "dist_metric": random_member(distance.absolute_members()),
            "voronoi_diagram_type": voronoi.range,
            "voronoi_nth": 0,
            "voronoi_refract": 1.0 + random.random() * .5,
        },
        "generator": lambda settings: {
            "hue_range": .25 + random.random() * .5,
        },
    },

    "basic-water": {
        "layers": ["refract-octaves", "reflect-octaves", "ripple"],
        "settings": lambda: {
            "reflect_range": .16667 + random.random() * .16667,
            "refract_range": .25 + random.random() * .125,
            "refract_y_from_offset": True,
            "ripple_range": .005 + random.random() * .0025,
            "ripple_kink": random.randint(2, 4),
            "ripple_freq": random.randint(2, 4),
        },
        "generator": lambda settings: {
            "distrib": distrib.uniform,
            "freq": random.randint(7, 10),
            "hue_range": .05 + random.random() * .05,
            "hue_rotation": .5125 + random.random() * .025,
            "lattice_drift": 1.0,
            "octaves": 4,
        }
    },

    "band-together": {
        "layers": ["reindex-post", "funhouse", "shadow", "normalize"],
        "settings": lambda: {
            "reindex_range": random.randint(8, 12),
            "warp_range": .333 + random.random() * .16667,
            "warp_octaves": 8,
            "warp_freq": random.randint(2, 3),
        },
        "generator": lambda settings: {
            "freq": random.randint(6, 12),
        },
    },

    "be-kind-rewind": {
        "post": lambda settings: [Effect("vhs"), Preset("crt")]
    },

    "beneath-the-surface": {
        "layers": ["multires-alpha", "reflect-octaves", "bloom", "shadow"],
        "settings": lambda: {
            "reflect_range": 10.0 + random.random() * 5.0,
        },
        "generator": lambda settings: {
            "freq": 3,
            "hue_range": 2.0 + random.random() * 2.0,
            "octaves": 5,
            "ridges": True,
        },
    },

    "benny-lava": {
        "layers": ["posterize", "maybe-palette", "funhouse", "distressed"],
        "settings": lambda: {
            "posterize_levels": 1,
            "warp_range": 1 + random.random() * .5,
        },
        "generator": lambda settings: {
            "distrib": distrib.column_index,
        },
    },

    "berkeley": {
        "layers": ["multires-ridged", "reindex-octaves", "sine-octaves", "ridge", "shadow", "contrast"],
        "settings": lambda: {
            "palette_on": False,
            "reindex_range": .75 + random.random() * .25,
            "sine_range": 2.0 + random.random() * 2.0,
        },
        "generator": lambda settings: {
            "freq": random.randint(12, 16)
        },
    },

    "big-data-startup": {
        "layers": ["glyphic", "dither", "saturation"],
        "settings": lambda: {
            "posterize_levels": random.randint(2, 4),
        },
        "generator": lambda settings: {
            "mask": mask.script,
            "hue_rotation": random.random(),
            "hue_range": .06125 + random.random() * .5,
            "saturation": 1.0,
        }
    },

    "bit-by-bit": {
        "layers": ["value-mask", "bloom", "crt"],
        "settings": lambda: {
            "mask": random_member([mask.alphanum_binary, mask.alphanum_hex, mask.alphanum_numeric]),
            "mask_repeat": random.randint(30, 60)
        }
    },

    "bitmask": {
        "layers": ["multires-low", "value-mask", "bloom"],
        "settings": lambda: {
            "mask": random_member(mask.procedural_members()),
            "mask_repeat": random.randint(7, 15),
        },
        "generator": lambda settings: {
            "ridges": True,
        }
    },

    "blacklight-fantasy": {
        "layers": ["voronoi", "funhouse", "posterize", "sobel", "invert", "bloom", "dither", "nudge-hue"],
        "settings": lambda: {
            "dist_metric": random_member(distance.absolute_members()),
            "posterize_levels": 3,
            "voronoi_refract": .5 + random.random() * 1.25,
            "warp_octaves": random.randint(1, 4),
            "warp_range": random.randint(0, 1) * random.random(),
        },
        "generator": lambda settings: {
            "color_space": color.rgb,
        },
    },

    "blockchain-stock-photo-background": {
        "layers": ["value-mask", "glitchin-out", "skew", "vignette-dark"],
        "settings": lambda: {
            "mask": random_member([mask.alphanum_binary, mask.alphanum_hex,
                                   mask.alphanum_numeric, mask.bank_ocr]),
            "mask_repeat": random.randint(20, 40),
        },
    },

    "bloom": {
        "settings": lambda: {
            "bloom_alpha": .075 + random.random() * .0375,
        },
        "post": lambda settings: [
            Effect("bloom", alpha=settings["bloom_alpha"])
        ]
    },

    "blotto": {
        "generator": lambda settings: {
            "color_space": random_member(color.color_members()),
            "distrib": distrib.ones,
        },
        "post": lambda settings: [Effect("spatter", color=False), Preset("maybe-palette")]
    },

    "branemelt": {
        "layers": ["multires", "sine-octaves", "reflect-octaves",  "bloom", "shadow", "brightness", "lens"],
        "settings": lambda: {
            "brightness": .125,
            "contrast": 1.5,
            "palette_on": False,
            "reflect_range": .025 + random.random() * .0125,
            "shadow_alpha": .666 + random.random() * .333,
            "sine_range": random.randint(48, 64),
        },
        "generator": lambda settings: {
            "freq": random.randint(6, 12),
        },
    },

    "branewaves": {
        "layers": ["value-mask", "ripple", "bloom"],
        "settings": lambda: {
            "mask": random_member(mask.grid_members()),
            "mask_repeat": random.randint(5, 10),
            "ripple_freq": 2,
            "ripple_kink": 1.5 + random.random() * 2,
            "ripple_range": .15 + random.random() * .15,
        },
        "generator": lambda settings: {
            "ridges": True,
            "spline_order": random_member([m for m in interp if m != interp.constant]),
        },
    },

    "brightness": {
        "settings": lambda: {
            "brightness": .125 + random.random() * .06125
        },
        "post": lambda settings: [Effect("adjust_brightness", amount=settings["brightness"])]
    },

    "bringing-hexy-back": {
        "layers": ["voronoi", "funhouse", "maybe-invert", "bloom"],
        "settings": lambda: {
            "dist_metric": distance.euclidean,
            "voronoi_alpha": .333 + random.random() * .333,
            "voronoi_diagram_type": voronoi.range_regions,
            "voronoi_nth": 0,
            "voronoi_point_distrib": point.v_hex if coin_flip() else point.h_hex,
            "voronoi_point_freq": random.randint(4, 7) * 2,
            "warp_range": .05 + random.random() * .25,
            "warp_octaves": random.randint(1, 4),
        },
        "generator": lambda settings: {
            "color_space": random_member(color.color_members()),
            "freq": settings["voronoi_point_freq"],
            "hue_range": .25 + random.random() * .75,
        }
    },

    "broken": {
        "layers": ["multires-low", "reindex-octaves", "posterize", "glowing-edges", "dither", "saturation"],
        "settings": lambda: {
            "posterize_levels": 3,
            "reindex_range": random.randint(3, 4),
            "speed": .025,
        },
        "generator": lambda settings: {
            "color_space": color.rgb,
            "freq": random.randint(3, 4),
            "lattice_drift": 2,
        },
    },

    "bubble-machine": {
        "layers": ["posterize", "wormhole", "reverb", "outline", "maybe-invert"],
        "settings": lambda: {
            "posterize_levels": random.randint(8, 16),
            "reverb_iterations": random.randint(1, 3),
            "reverb_octaves": random.randint(3, 5),
            "wormhole_stride": .1 + random.random() * .05,
            "wormhole_kink": .5 + random.random() * 4,
        },
        "generator": lambda settings: {
            "corners": True,
            "distrib": distrib.uniform,
            "freq": random.randint(3, 6) * 2,
            "mask": random_member([mask.h_hex, mask.v_hex]),
            "spline_order": random_member([m for m in interp if m != interp.constant]),
        }
    },

    "bubble-multiverse": {
        "layers": ["voronoi", "refract-post", "density-map", "random-hue", "bloom", "shadow"],
        "settings": lambda: {
            "dist_metric": distance.euclidean,
            "refract_range": .125 + random.random() * .05,
            "speed": .05,
            "voronoi_alpha": 1.0,
            "voronoi_diagram_type": voronoi.flow,
            "voronoi_point_freq": 10,
            "voronoi_refract": .625 + random.random() * .25,
        },
    },

    "carpet": {
        "layers": ["worms", "grime"],
        "settings": lambda: {
            "worms_alpha": .25 + random.random() * .25,
            "worms_behavior": worms.chaotic,
            "worms_stride": .333 + random.random() * .333,
            "worms_stride_deviation": .25
        },
    },

    "celebrate": {
        "layers": ["posterize", "maybe-palette", "distressed"],
        "settings": lambda: {
            "posterize_levels": random.randint(3, 5),
            "speed": .025,
        },
        "generator": lambda settings: {
            "brightness_distrib": distrib.ones,
            "hue_range": 1,
        }
    },

    "cell-reflect": {
        "layers": ["voronoi", "reflect-post", "derivative-post", "density-map", "maybe-invert",
                   "bloom", "dither", "saturation"],
        "settings": lambda: {
            "dist_metric": random_member(distance.absolute_members()),
            "palette_name": None,
            "reflect_range": random.randint(2, 4) * 5,
            "saturation": .5 + random.random() * .25,
            "voronoi_alpha": .333 + random.random() * .333,
            "voronoi_diagram_type": voronoi.color_range,
            "voronoi_nth": coin_flip(),
            "voronoi_point_distrib": random_member([m for m in point if m not in point.grid_members()]),
            "voronoi_point_freq": random.randint(2, 3),
        },
    },

    "cell-refract": {
        "layers": ["voronoi", "ridge"],
        "settings": lambda: {
            "dist_metric": random_member(distance.absolute_members()),
            "voronoi_diagram_type": voronoi.range,
            "voronoi_point_freq": random.randint(3, 4),
            "voronoi_refract": random.randint(8, 12) * .5,
        },
        "generator": lambda settings: {
            "color_space": random_member(color.color_members()),
            "ridges": True,
        },
    },

    "cell-refract-2": {
        "layers": ["voronoi", "refract-post", "derivative-post", "density-map", "saturation"],
        "settings": lambda: {
            "dist_metric": random_member(distance.absolute_members()),
            "refract_range": random.randint(1, 3) * .25,
            "voronoi_alpha": .333 + random.random() * .333,
            "voronoi_diagram_type": voronoi.color_range,
            "voronoi_point_distrib": random_member([m for m in point if m not in point.grid_members()]),
            "voronoi_point_freq": random.randint(2, 3),
        }
    },

    "cell-worms": {
        "layers": ["multires-low", "voronoi", "worms", "density-map", "random-hue", "saturation"],
        "settings": lambda: {
            "voronoi_alpha": .75,
            "voronoi_point_distrib": random_member(point, mask.nonprocedural_members()),
            "voronoi_point_freq": random.randint(2, 4),
            "worms_density": 1500,
            "worms_kink": random.randint(16, 32),
            "worms_stride_deviation": 0,
        },
        "generator": lambda settings: {
            "freq": random.randint(3, 7),
            "hue_range": .125 + random.random() * .875,
        }
    },

    "chalky": {
        "layers": ["refract-post", "octave-warp-post", "outline", "dither", "lens"],
        "settings": lambda: {
            "outline_invert": True,
            "refract_range": .1 + random.random() * .05,
            "warp_octaves": 8,
            "warp_range": .0333 + random.random() * .016667,
        },
        "generator": lambda settings: {
            "color_space": color.oklab,
            "freq": random.randint(2, 3),
            "octaves": random.randint(2, 3),
            "ridges": True,
        },
    },

    "chunky-knit": {
        "layers": ["jorts", "random-hue", "contrast"],
        "settings": lambda: {
            "angle": random.random() * 360.0,
            "glyph_map_alpha": .333 + random.random() * .16667,
            "glyph_map_mask": mask.waffle,
            "glyph_map_zoom": 16.0,
        },
    },

    "classic-desktop": {
        "layers": ["basic", "lens-warp"],
        "generator": lambda settings: {
            "hue_range": .333 + random.random() * .333,
            "lattice_drift": random.random(),
        }
    },

    "cloudburst": {
        "layers": ["multires", "reflect-octaves", "octave-warp-octaves", "refract-post",
                   "bloom", "brightness", "contrast", "invert", "saturation"],
        "settings": lambda: {
            "brightness": .125,
            "contrast": 1.5 + random.random() * .5,
            "palette_on": False,
            "reflect_range": .125 + random.random() * .06125,
            "refract_range": .1 + random.random() * .05,
            "saturation": .625,
            "speed": .075,
        },
        "generator": lambda settings: {
            "color_space": color.hsv,
            "distrib": distrib.exp,
            "freq": 2,
            "hue_range": .05 - random.random() * .025,
            "hue_rotation": .1 - random.random() * .025,
            "lattice_drift": .75,
            "saturation_distrib": distrib.ones,
        },
    },

    "clouds": {
        "post": lambda settings: [Effect("clouds"), Preset("bloom"), Preset("dither")]
    },

    "color-flow": {
        "layers": ["basic-voronoi"],
        "settings": lambda: {
            "voronoi_diagram_type": voronoi.color_flow,
        },
        "generator": lambda settings: {
            "freq": 64,
            "hue_range": 5,
        }
    },

    "concentric": {
        "layers": ["wobble", "voronoi", "contrast", "maybe-palette"],
        "settings": lambda: {
            "dist_metric": random_member(distance.absolute_members()),
            "speed": .75,
            "voronoi_diagram_type": voronoi.range,
            "voronoi_refract": random.randint(8, 16),
            "voronoi_point_drift": 0,
            "voronoi_point_freq": random.randint(1, 2),
        },
        "generator": lambda settings: {
            "color_space": color.rgb,
            "distrib": distrib.ones,
            "freq": 2,
            "mask": mask.h_bar,
            "spline_order": interp.constant,
        }
    },

    "conference": {
        "layers": ["value-mask", "sobel"],
        "generator": lambda settings: {
            "freq": 4 * random.randint(6, 12),
            "mask": mask.halftone,
            "spline_order": interp.cosine,
        }
    },

    "contrast": {
        "settings": lambda: {
            "contrast": 1.25 + random.random() * .25
        },
        "post": lambda settings: [Effect("adjust_contrast", amount=settings["contrast"])]
    },

    "cool-water": {
        "layers": ["basic-water", "funhouse", "bloom", "lens"],
        "settings": lambda: {
            "warp_range": .06125 + random.random() * .06125,
            "warp_freq": random.randint(2, 3),
        },
    },

    "corner-case": {
        "layers": ["multires-ridged", "saturation", "rotate", "dither", "vignette-dark"],
        "generator": lambda settings: {
            "corners": True,
            "lattice_drift": coin_flip(),
            "spline_order": interp.constant,
        },
    },

    "corduroy": {
        "layers": ["jorts", "random-hue", "contrast"],
        "settings": lambda: {
            "saturation": .625 + random.random() * .125,
            "glyph_map_zoom": 8.0,
        },
    },

    "cosmic-thread": {
        "layers": ["worms", "brightness", "contrast", "bloom"],
        "settings": lambda: {
            "brightness": .1,
            "contrast": 2.5,
            "worms_alpha": .875,
            "worms_behavior": random_member(worms.all()),
            "worms_density": .125,
            "worms_drunkenness": .125 + random.random() * .25,
            "worms_duration": 125,
            "worms_kink": 1.0,
            "worms_stride": .75,
            "worms_stride_deviation": 0.0
        },
        "generator": lambda setings: {
            "color_space": color.rgb,
        },
    },

    "cobblestone": {
        "layers": ["bringing-hexy-back", "saturation"],
        "settings": lambda: {
            "saturation": .0 + random.random() * .05,
            "shadow_alpha": 1.0,
            "voronoi_point_freq": random.randint(3, 4) * 2,
            "warp_freq": [random.randint(3, 4), random.randint(3, 4)],
            "warp_range": .125,
            "warp_octaves": 8
        },
        "generator": lambda settings: {
            "hue_range": .1 + random.random() * .05,
        },
        "post": lambda settings: [
            Effect("texture"),
            Preset("shadow", settings={"shadow_alpha": settings["shadow_alpha"]}),
            Effect("adjust_brightness", amount=-.125),
            Preset("contrast"),
            Effect("bloom", alpha=1.0)
        ],
    },

    "convolution-feedback": {
        "post": lambda settings: [
            Effect("conv_feedback",
                   alpha=.5 * random.random() * .25,
                   iterations=random.randint(250, 500)),
        ]
    },

    "corrupt": {
        "post": lambda settings: [
            Effect("warp",
                   displacement=.025 + random.random() * .1,
                   freq=[random.randint(2, 4), random.randint(1, 3)],
                   octaves=random.randint(2, 4),
                   spline_order=interp.constant),
        ]
    },

    "crime-scene": {
        "layers": ["value-mask", "rotate", "dither", "dexter", "dexter", "grime", "grime", "lens"],
        "settings": lambda: {
            "mask": mask.chess,
            "mask_repeat": random.randint(2, 3),
        },
        "generator": lambda settings: {
            "saturation": 0 if coin_flip() else .125,
            "spline_order": interp.constant,
        },
    },

    "crooked": {
        "layers": ["starfield", "pixel-sort", "glitchin-out"],
        "settings": lambda: {
            "pixel_sort_angled": True,
            "pixel_sort_darkest": False
        }
    },

    "crt": {
        "layers": ["scanline-error", "snow"],
        "post": lambda settings: [Effect("crt")]
    },

    "crystallize": {
        "layers": ["voronoi", "vignette-bright", "bloom", "saturation"],
        "settings": lambda: {
            "dist_metric": distance.triangular,
            "voronoi_point_freq": 4,
            "voronoi_alpha": .5,
            "voronoi_diagram_type": voronoi.color_range,
            "voronoi_nth": 4,
        }
    },

    "cubert": {
        "layers": ["voronoi", "crt", "bloom"],
        "settings": lambda: {
            "dist_metric": distance.triangular,
            "voronoi_diagram_type": voronoi.color_range,
            "voronoi_inverse": True,
            "voronoi_point_distrib": point.h_hex,
            "voronoi_point_freq": random.randint(4, 6),
        },
        "generator": lambda settings: {
            "freq": random.randint(4, 6),
            "hue_range": .5 + random.random(),
        }
    },

    "cubic": {
        "layers": ["basic-voronoi", "outline", "bloom"],
        "settings": lambda: {
            "voronoi_alpha": 0.25 + random.random() * .5,
            "voronoi_nth": random.randint(2, 8),
            "voronoi_point_distrib": point.concentric,
            "voronoi_point_freq": random.randint(3, 5),
            "voronoi_diagram_type": random_member([voronoi.range, voronoi.color_range]),
        }
    },

    "cyclic-dilation": {
        "layers": ["voronoi", "reindex-post"],
        "settings": lambda: {
            "reindex_range": random.randint(4, 6),
            "voronoi_diagram_type": voronoi.color_range,
            "voronoi_point_corners": True,
        },
        "generator": lambda settings: {
            "freq": random.randint(24, 48),
            "hue_range": .25 + random.random() * 1.25,
        }
    },

    "dark-matter": {
        "layers": ["multires-alpha", "reflect-octaves"],
        "settings": lambda: {
            "reflect_range": random.randint(20, 30),
        },
        "generator": lambda settings: {
            "octaves": 5,
        },
    },

    "deadbeef": {
        "layers": ["value-mask", "corrupt", "bloom", "crt", "vignette-dark"],
        "generator": lambda settings: {
            "freq": 6 * random.randint(9, 24),
            "mask": mask.alphanum_hex,
        }
    },

    "death-star-plans": {
        "layers": ["voronoi", "refract-post", "rotate", "posterize", "sobel", "invert", "crt", "vignette-dark"],
        "settings": lambda: {
            "dist_metric": random_member([distance.chebyshev, distance.manhattan]),
            "posterize_levels": random.randint(3, 4),
            "refract_range": .5 + random.random() * .25,
            "refract_y_from_offset": True,
            "voronoi_alpha": 1,
            "voronoi_diagram_type": voronoi.range,
            "voronoi_nth": random.randint(1, 3),
            "voronoi_point_distrib": point.random,
            "voronoi_point_freq": random.randint(2, 3),
        },
    },

    "deep-field": {
        "layers": ["multires", "refract-octaves", "octave-warp-octaves", "bloom", "lens"],
        "settings": lambda: {
            "palette_on": False,
            "speed": .05,
            "refract_range": .2 + random.random() * .1,
            "warp_freq": 2,
            "warp_signed_range": True,
        },
        "generator": lambda settings: {
            "distrib": distrib.uniform,
            "freq": random.randint(8, 10),
            "hue_range": 1,
            "mask": mask.sparser,
            "mask_static": True,
            "lattice_drift": 1,
            "octave_blending": blend.alpha,
            "octaves": 5,
        }
    },

    "deeper": {
        "layers": ["multires-alpha"],
        "generator": lambda settings: {
            "hue_range": 1.0,
            "octaves": 8,
        }
    },

    "degauss": {
        "post": lambda settings: [
            Effect("degauss", displacement=.06 + random.random() * .03),
            Preset("crt"),
        ]
    },

    "density-map": {
        "post": lambda settings: [Effect("density_map"), Effect("convolve", kernel=mask.conv2d_invert), Preset("dither")]
    },

    "density-wave": {
        "layers": [random_member(["basic", "symmetry"]), "reflect-post", "density-map", "invert", "bloom"],
        "settings": lambda: {
            "reflect_range": random.randint(3, 8),
        },
        "generator": lambda settings: {
            "saturation": random.randint(0, 1),
        }
    },

    "derivative-octaves": {
        "settings": lambda: {
            "deriv_alpha": 1.0,
            "dist_metric": random_member(distance.absolute_members())
        },
        "octaves": lambda settings: [Effect("derivative", dist_metric=settings["dist_metric"], alpha=settings["deriv_alpha"])]
    },

    "derivative-post": {
        "settings": lambda: {
            "deriv_alpha": 1.0,
            "dist_metric": random_member(distance.absolute_members())
        },
        "post": lambda settings: [Effect("derivative", dist_metric=settings["dist_metric"], alpha=settings["deriv_alpha"])]
    },

    "dexter": {
        "layers": ["spatter"],
        "settings": lambda: {
            "spatter_color": [.35 + random.random() * .15,
                              .025 + random.random() * .0125,
                              .075 + random.random() * .0375],
        },
    },

    "different": {
        "layers": ["multires", "sine-octaves", "reflect-octaves", "reindex-octaves", "funhouse", "lens"],
        "settings": lambda: {
            "reflect_range": 7.5 + random.random() * 5.0,
            "reindex_range": .25 + random.random() * .25,
            "sine_range": random.randint(7, 12),
            "speed": .025,
            "warp_range": .0375 * random.random() * .0375,
        },
        "generator": lambda settings: {
            "freq": [random.randint(4, 6), random.randint(4, 6)]
        },
    },

    "distressed": {
        "layers": ["dither", "filthy"],
        "post": lambda settings: [Preset("saturation")]
    },

    "distance": {
        "layers": ["multires", "derivative-octaves", "bloom", "shadow", "contrast", "rotate", "lens"],
        "settings": lambda: {
            "dist_metric": random_member(distance.absolute_members()),
        },
        "generator": lambda settings: {
            "freq": [random.randint(4, 5), random.randint(2, 3)],
            "distrib": distrib.exp,
            "lattice_drift": 1,
            "saturation": .06125 + random.random() * .125,
        },
    },

    "dither": {
        "settings": lambda: {
            "dither_alpha": .1 + random.random() * .05
        },
        "post": lambda settings: [Effect("dither", alpha=settings["dither_alpha"])]
    },

    # "dla-cells": {
    # extend "bloom"
    # "dla_padding": random.randint(2, 8),
    # "hue_range": random.random() * 1.5,
    # "point_distrib": random_member(point, mask.nonprocedural_members()),
    # "point_freq": random.randint(2, 8),
    # "voronoi_alpha": random.random(),
    # "with_dla": .5 + random.random() * .5,
    # "with_voronoi": random_member(voronoi),
    # },

    "dla": {
        "settings": lambda: {
            "dla_alpha": .666 + random.random() * .333,
            "dla_padding": random.randint(2, 8),
            "dla_seed_density": .2 + random.random() * .1,
            "dla_density": .1 + random.random() * .05,
        },
        "post": lambda settings: [
            Effect("dla",
                   alpha=settings["dla_alpha"],
                   padding=settings["dla_padding"],
                   seed_density=settings["dla_seed_density"],
                   density=settings["dla_density"])
        ]
    },

    "dla-forest": {
        "layers": ["dla", "reverb", "contrast", "bloom"],
        "settings": lambda: {
            "dla_padding": random.randint(2, 8),
            "reverb_iterations": random.randint(2, 4),
        }
    },

    "dmt": {
        "layers": ["voronoi", "kaleido", "refract-post", "bloom", "vignette-dark", "contrast", "normalize"],
        "settings": lambda: {
            "contrast": 2.5,
            "dist_metric": random_member(distance.absolute_members()),
            "kaleido_point_freq": 4,
            "kaleido_point_distrib": random_member([point.square, point.waffle]),
            "kaleido_sides": 4,
            "refract_range": .075 + random.random() * .075,
            "speed": .025,
            "voronoi_diagram_type": voronoi.range,
            "voronoi_point_distrib": random_member([point.square, point.waffle]),
            "voronoi_point_freq": 4,
            "voronoi_refract": .075 + random.random() * .075,
        },
        "generator": lambda settings: {
            "brightness_distrib": random_member([distrib.ones, distrib.uniform]),
            "mask": None if coin_flip() else mask.dropout,
            "mask_static": True,
            "freq": 4,
            "hue_range": 2.5 + random.random() * 1.25,
        },
    },

    "domain-warp": {
        "layers": ["multires-ridged", "refract-post", "vaseline", "dither", "vignette-dark", "saturation"],
        "settings": lambda: {
            "refract_range": .25 + random.random() * .25,
        }
    },

    "dropout": {
        "layers": ["derivative-post", "maybe-invert"],
        "generator": lambda settings: {
            "color_space": random_member(color.color_members()),
            "distrib": distrib.ones,
            "freq": [random.randint(4, 6), random.randint(2, 4)],
            "mask": mask.dropout,
            "octave_blending": blend.reduce_max,
            "octaves": random.randint(5, 6),
            "spline_order": interp.constant,
        }
    },

    "eat-static": {
        "layers": ["be-kind-rewind", "scanline-error", "crt"],
        "settings": lambda: {
            "speed": 2.0,
        },
        "generator": lambda settings: {
            "freq": 512,
            "saturation": 0,
        }
    },

    "educational-video-film": {
        "layers": ["be-kind-rewind"],
        "generator": lambda settings: {
            "color_space": color.oklab,
            "ridges": True,
        },
    },

    "electric-worms": {
        "layers": ["voronoi", "worms", "density-map", "glowing-edges", "bloom"],
        "settings": lambda: {
            "dist_metric": random_member([distance.manhattan, distance.octagram, distance.triangular]),
            "voronoi_alpha": .25 + random.random() * .25,
            "voronoi_diagram_type": voronoi.color_range,
            "voronoi_nth": random.randint(0, 3),
            "voronoi_point_freq": random.randint(3, 6),
            "voronoi_point_distrib": point.random,
            "worms_alpha": .666 + random.random() * .333,
            "worms_behavior": worms.random,
            "worms_density": 1000,
            "worms_duration": 1,
            "worms_kink": random.randint(7, 9),
            "worms_stride_deviation": 16,
        },
        "generator": lambda settings: {
            "freq": random.randint(3, 6),
            "lattice_drift": 1,
        },
    },

    "emboss": {
        "post": lambda settings: [Effect("convolve", kernel=mask.conv2d_emboss)]
    },

    "emo": {
        "layers": ["value-mask", "voronoi", "contrast", "rotate", "saturation", "tint", "lens"],
        "settings": lambda: {
            "contrast": 4.0,
            "dist_metric": random_member([distance.manhattan, distance.chebyshev]),
            "mask": mask.emoji,
            "voronoi_diagram_type": voronoi.range,
            "voronoi_refract": .125 + random.random() * .25,
        },
        "generator": lambda settings: {
            "spline_order": interp.cosine,
        }
    },

    "emu": {
        "layers": ["value-mask", "maybe-palette", "voronoi", "saturation", "distressed"],
        "settings": lambda: {
            "dist_metric": random_member(distance.all()),
            "mask": stash("mask", random_member(enum_range(mask.emoji_00, mask.emoji_26))),
            "mask_repeat": 1,
            "voronoi_alpha": 1.0,
            "voronoi_diagram_type": voronoi.range,
            "voronoi_point_distrib": stash("mask"),
            "voronoi_refract": .125 + random.random() * .125,
            "voronoi_refract_y_from_offset": False,
        },
        "generator": lambda settings: {
            "distrib": distrib.ones,
            "spline_order": interp.constant,
        },
    },

    "entities": {
        "layers": ["value-mask", "refract-octaves", "normalize"],
        "settings": lambda: {
            "refract_range": .1 + random.random() * .05,
            "refract_signed_range": False,
            "refract_y_from_offset": True,
            "mask": mask.invaders_square,
            "mask_repeat": random.randint(3, 4) * 2,
        },
        "generator": lambda settings: {
            "hue_range": 2.0 + random.random() * 2.0,
            "spline_order": interp.cosine,
        },
    },

    "entity": {
        "layers": ["entities", "sobel", "invert", "bloom", "random-hue", "lens"],
        "settings": lambda: {
            "refract_range": .025 + random.random() * .0125,
            "refract_signed_range": True,
            "refract_y_from_offset": False,
            "speed": .05,
        },
        "generator": lambda settings: {
            "corners": True,
            "distrib": distrib.ones,
            "freq": 6,
            "hue_range": 1.0 + random.random() * .5,
        }
    },

    "erosion-worms": {
        "settings": lambda: {
            "erosion_worms_alpha": .5 + random.random() * .5,
            "erosion_worms_contraction": .5 + random.random() * .5,
            "erosion_worms_density": random.randint(25, 100),
            "erosion_worms_inverse": False,
            "erosion_worms_iterations": random.randint(25, 100),
            "erosion_worms_xy_blend": .75 + random.random() * .25
        },
        "post": lambda settings: [
            Effect("erosion_worms",
                   alpha=settings["erosion_worms_alpha"],
                   contraction=settings["erosion_worms_contraction"],
                   density=settings["erosion_worms_density"],
                   inverse=settings["erosion_worms_inverse"],
                   iterations=settings["erosion_worms_iterations"],
                   xy_blend=settings["erosion_worms_xy_blend"]),
            Effect("normalize")
        ]
    },

    "escape-velocity": {
        "layers": ["multires-low", "erosion-worms", "lens"],
        "settings": lambda: {
            "erosion_worms_contraction": .2 + random.random() * .1,
            "erosion_worms_iterations": random.randint(625, 1125),
        },
        "generator": lambda settings: {
            "color_space": random_member(color.color_members()),
            "distrib": random_member([distrib.exp, distrib.uniform]),
        }
    },

    "explore": {
        "layers": ["dmt", "kaleido", "bloom", "contrast", "lens"],
        "settings": lambda: {
            "refract_range": .75 + random.random() * .75,
            "kaleido_sides": random.randint(3, 18),
        },
        "generator": lambda settings: {
            "hue_range": .75 + random.random() * .75,
            "brightness_distrib": None,
        }
    },

    "falsetto": {
        "post": lambda settings: [Effect("false_color")]
    },

    "fargate": {
        "layers": ["serene", "saturation", "contrast", "crt"],
        "settings": lambda: {
            "refract_range": .015 + random.random() * .0075,
            "speed": -.25,
            "value_distrib": distrib.center_circle,
            "value_freq": 3,
            "value_refract_range": .015 + random.random() * .0075,
        },
        "generator": lambda settings: {
            "brightness_distrib": distrib.uniform,
            "freq": 3,
            "octaves": 3,
            "saturation_distrib": distrib.uniform,
        }
    },

    "fast-eddies": {
        "layers": ["basic", "voronoi", "worms", "contrast", "saturation"],
        "settings": lambda: {
            "dist_metric": distance.euclidean,
            "palette_on": False,
            "voronoi_alpha": .5 + random.random() * .5,
            "voronoi_diagram_type": voronoi.flow,
            "voronoi_point_freq": random.randint(2, 6),
            "voronoi_refract": 1.0,
            "worms_alpha": .5 + random.random() * .5,
            "worms_behavior": worms.chaotic,
            "worms_density": 1000,
            "worms_duration": 6,
            "worms_kink": random.randint(125, 375),
            "worms_stride": 1.0,
            "worms_stride_deviation": 0.0,
        },
        "generator": lambda settings: {
            "hue_range": .25 + random.random() * .75,
            "hue_rotation": random.random(),
            "octaves": random.randint(1, 3),
            "ridges": coin_flip(),
        },
    },

    "fibers": {
        "post": lambda settings: [Effect("fibers")]
    },

    "figments": {
        "layers": ["multires-low", "voronoi", "funhouse", "wormhole", "bloom", "contrast", "lens"],
        "settings": lambda: {
            "speed": .025,
            "voronoi_diagram_type": voronoi.flow,
            "voronoi_refract": .333 + random.random() * .333,
            "wormhole_stride": .02 + random.random() * .01,
            "wormhole_kink": 4,
        },
        "generator": lambda settings: {
            "freq": 2,
            "hue_range": 2,
            "lattice_drift": 1,
        }
    },

    "filthy": {
        "layers": ["grime", "scratches", "stray-hair"],
    },

    "fireball": {
        "layers": ["periodic-refract", "refract-post", "refract-post", "bloom", "lens", "contrast"],
        "settings": lambda: {
            "contrast": 2.5,
            "refract_range": .025 + random.random() * .0125,
            "refract_y_from_offset": False,
            "value_distrib": distrib.center_circle,
            "value_freq": 1,
            "value_refract_range": .05 + random.random() * .025,
            "speed": .05,
        },
        "generator": lambda settings: {
            "distrib": distrib.center_circle,
            "hue_rotation": .925,
            "freq": 1,
        }
    },

    "financial-district": {
        "layers": ["voronoi", "bloom", "contrast", "saturation"],
        "settings": lambda: {
            "dist_metric": distance.manhattan,
            "voronoi_diagram_type": voronoi.range_regions,
            "voronoi_point_distrib": point.random,
            "voronoi_nth": random.randint(1, 3),
            "voronoi_point_freq": 2,
        }
    },

    "fossil-hunt": {
        "layers": ["voronoi", "refract-octaves", "posterize-outline", "saturation", "dither"],
        "settings": lambda: {
            "posterize_levels": random.randint(3, 5),
            "refract_range": random.randint(2, 4) * .5,
            "refract_y_from_offset": True,
            "voronoi_alpha": .5,
            "voronoi_diagram_type": voronoi.color_range,
            "voronoi_point_freq": 10,
        },
        "generator": lambda settings: {
            "freq": random.randint(3, 5),
            "lattice_drift": 1.0,
        }
    },

    "fractal-forms": {
        "layers": ["fractal-seed"],
        "settings": lambda: {
            "worms_kink": random.randint(256, 512),
        }
    },

    "fractal-seed": {
        "layers": ["multires-low", "worms", "density-map", "random-hue", "bloom", "shadow",
                   "contrast", "saturation", "aberration"],
        "settings": lambda: {
            "speed": .05,
            "palette_on": False,
            "worms_behavior": random_member([worms.chaotic, worms.random]),
            "worms_alpha": .9 + random.random() * .1,
            "worms_density": random.randint(750, 1250),
            "worms_duration": random.randint(2, 3),
            "worms_kink": 1.0,
            "worms_stride": 1.0,
            "worms_stride_deviation": 0.0,
        },
        "generator": lambda settings: {
            "freq": random.randint(2, 3),
            "hue_range": 1.0 + random.random() * 3.0,
            "ridges": coin_flip(),
        }
    },

    "fractal-smoke": {
        "layers": ["fractal-seed"],
        "settings": lambda: {
            "worms_behavior": worms.random,
            "worms_stride": random.randint(96, 192),
        }
    },

    "fractile": {
        "layers": ["symmetry", "voronoi", "reverb", "contrast", "palette", "random-hue",
                   "rotate", "lens"],
        "settings": lambda: {
            "dist_metric": random_member(distance.absolute_members()),
            "reverb_iterations": random.randint(2, 4),
            "reverb_octaves": random.randint(2, 4),
            "voronoi_alpha": .5 + random.random() * .5,
            "voronoi_diagram_type": voronoi.color_range,
            "voronoi_nth": random.randint(0, 2),
            "voronoi_point_distrib": random_member(point.grid_members()),
            "voronoi_point_freq": random.randint(2, 3),
        },
    },

    "fundamentals": {
        "layers": ["voronoi", "derivative-post", "density-map", "saturation", "dither"],
        "settings": lambda: {
            "dist_metric": random_member([distance.manhattan, distance.chebyshev]),
            "voronoi_diagram_type": voronoi.color_range,
            "voronoi_nth": random.randint(3, 5),
            "voronoi_point_freq": random.randint(3, 5),
            "voronoi_refract": .125 + random.random() * .06125,
        },
        "generator": lambda settings: {
            "freq": random.randint(3, 5),
        }
    },

    "funhouse": {
        "settings": lambda: {
            "warp_freq": [random.randint(2, 4), random.randint(2, 4)],
            "warp_octaves": random.randint(1, 4),
            "warp_range": .25 + random.random() * .125,
            "warp_signed_range": False,
            "warp_spline_order": interp.bicubic
        },
        "post": lambda settings: [
            Effect("warp",
                   displacement=settings["warp_range"],
                   freq=settings["warp_freq"],
                   octaves=settings["warp_octaves"],
                   signed_range=settings["warp_signed_range"],
                   spline_order=settings["warp_spline_order"])
        ]
    },

    "funky-glyphs": {
        "layers": ["value-mask", "refract-post", "contrast", "saturation", "rotate", "lens", "dither"],
        "settings": lambda: {
            "mask": random_member([
                mask.alphanum_binary, mask.alphanum_numeric, mask.alphanum_hex,
                mask.lcd, mask.lcd_binary,
                mask.fat_lcd, mask.fat_lcd_binary, mask.fat_lcd_numeric, mask.fat_lcd_hex
            ]),
            "mask_repeat": random.randint(1, 6),
            "refract_range": .125 + random.random() * .125,
            "refract_signed_range": False,
            "refract_y_from_offset": True,
        },
        "generator": lambda settings: {
            "distrib": random_member([distrib.ones, distrib.uniform]),
            "octaves": random.randint(1, 2),
            "spline_order": random_member([m for m in interp if m != interp.constant]),
        }
    },

    "galalaga": {
        "layers": ["value-mask"],
        "settings": lambda: {
            "mask": mask.invaders_square,
            "mask_repeat": 4,
        },
        "generator": lambda settings: {
            "distrib": distrib.uniform,
            "hue_range": random.random() * 2.5,
            "spline_order": interp.constant,
        },
        "post": lambda settings: [
            Effect("glyph_map",
                   colorize=True,
                   mask=mask.invaders_square,
                   zoom=32.0),
            Effect("glyph_map",
                   colorize=True,
                   mask=random_member([mask.invaders_square, mask.rgb]),
                   zoom=4.0),
            Effect("normalize"),
            Preset("glitchin-out"),
            Preset("contrast"),
            Preset("crt"),
            Preset("lens"),
        ],
    },

    "game-show": {
        "layers": ["maybe-palette", "posterize", "be-kind-rewind"],
        "settings": lambda: {
            "posterize_levels": random.randint(2, 5),
        },
        "generator": lambda settings: {
            "freq": random.randint(8, 16) * 2,
            "mask": random_member([mask.h_tri, mask.v_tri]),
            "spline_order": interp.cosine,
        }
    },

    "glacial": {
        "layers": ["fractal-smoke"],
        "settings": lambda: {
            "worms_quantize": True,
        }
    },

    "glitchin-out": {
        "layers": ["corrupt"],
        "post": lambda settings: [Effect("glitch"), Preset("crt"), Preset("bloom")]
    },

    "globules": {
        "layers": ["multires-low", "reflect-octaves", "density-map", "shadow", "lens"],
        "settings": lambda: {
            "palette_on": False,
            "reflect_range": 2.5,
            "speed": .125,
        },
        "generator": lambda settings: {
            "distrib": distrib.ones,
            "freq": random.randint(3, 6),
            "hue_range": .25 + random.random() * .5,
            "lattice_drift": 1,
            "mask": mask.sparse,
            "mask_static": True,
            "octaves": random.randint(3, 6),
            "saturation": .175 + random.random() * .175,
        }
    },

    "glom": {
        "layers": ["refract-octaves", "reflect-octaves", "refract-post", "reflect-post", "funhouse",
                   "bloom", "shadow", "contrast", "lens"],
        "settings": lambda: {
            "reflect_range": .625 + random.random() * .375,
            "refract_range": .333 + random.random() * .16667,
            "refract_signed_range": False,
            "refract_y_from_offset": True,
            "speed": .025,
            "warp_range": .06125 + random.random() * .030625,
            "warp_octaves": 1,
        },
        "generator": lambda settings: {
            "distrib": distrib.uniform,
            "freq": [2, 2],
            "hue_range": .25 + random.random() * .125,
            "lattice_drift": 1,
            "octaves": 2,
        }
    },

    "glowing-edges": {
        "post": lambda settings: [Effect("glowing_edges")]
    },

    "glyph-map": {
        "settings": lambda: {
            "glyph_map_alpha": 1.0,
            "glyph_map_colorize": coin_flip(),
            "glyph_map_spline_order": interp.constant,
            "glyph_map_mask": random_member(set(mask.procedural_members()).intersection(masks.square_masks())),
            "glyph_map_zoom": random.randint(1, 3),
        },
        "post": lambda settings: [
            Effect("glyph_map",
                   alpha=settings["glyph_map_alpha"],
                   colorize=settings["glyph_map_colorize"],
                   mask=settings["glyph_map_mask"],
                   spline_order=settings["glyph_map_spline_order"],
                   zoom=settings["glyph_map_zoom"])
        ]
    },

    "glyphic": {
        "layers": ["value-mask", "posterize", "palette", "saturation", "maybe-invert", "dither", "distressed"],
        "settings": lambda: {
            "mask": random_member(mask.procedural_members()),
            "posterize_levels": 1,
        },
        "generator": lambda settings: {
            "corners": True,
            "mask": settings["mask"],
            "freq": masks.mask_shape(settings["mask"])[0:2],
            "octave_blending": blend.reduce_max,
            "octaves": random.randint(3, 5),
            "saturation": 0,
            "spline_order": interp.cosine,
        },
    },

    "graph-paper": {
        "layers": ["wobble", "voronoi", "derivative-post", "rotate", "lens", "crt", "bloom", "contrast"],
        "settings": lambda: {
            "dist_metric": distance.euclidean,
            "voronoi_alpha": .5 + random.random() * .25,
            "voronoi_refract": .75 + random.random() * .375,
            "voronoi_refract_y_from_offset": True,
            "voronoi_diagram_type": voronoi.flow,
        },
        "generator": lambda settings: {
            "color_space": color.rgb,
            "corners": True,
            "distrib": distrib.ones,
            "freq": random.randint(3, 4) * 2,
            "mask": mask.chess,
            "spline_order": interp.constant,
        }
    },

    "grass": {
        "layers": ["multires", "worms", "dither", "lens"],
        "settings": lambda: {
            "worms_behavior": random_member([worms.chaotic, worms.meandering]),
            "worms_alpha": .9,
            "worms_density": 50 + random.random() * 25,
            "worms_drunkenness": .125,
            "worms_duration": 1.125,
            "worms_stride": .875,
            "worms_stride_deviation": .125,
            "worms_kink": .125 + random.random() * .5,
        },
        "generator": lambda settings: {
            "freq": random.randint(6, 12),
            "hue_rotation": .25 + random.random() * .05,
            "lattice_drift": 1,
            "saturation": .625 + random.random() * .25,
        }
    },

    "grayscale": {
        "post": lambda settings: [Effect("adjust_saturation", amount=0)]
    },

    "griddy": {
        "layers": ["basic", "sobel", "invert", "bloom"],
        "generator": lambda settings: {
            "freq": random.randint(3, 9),
            "mask": mask.chess,
            "octaves": random.randint(3, 8),
            "spline_order": interp.constant
        },
    },

    "grime": {
        "post": lambda settings: [Effect("grime")]
    },

    "groove-is-stored-in-the-heart": {
        "layers": ["posterize", "ripple", "distressed"],
        "settings": lambda: {
            "posterize_levels": random.randint(1, 2),
            "ripple_range": .75 + random.random() * .375,
        },
        "generator": lambda settings: {
            "distrib": distrib.column_index,
        },
    },

    "halt-catch-fire": {
        "layers": ["multires-low"],
        "generator": lambda settings: {
            "freq": 2,
            "hue_range": .05,
            "lattice_drift": 1,
            "spline_order": interp.constant,
        },
        "post": lambda settings: [
            Effect("glitch"),
            Preset("pixel-sort"),
            Preset("rotate"),
            Preset("crt"),
            Preset("vignette-dark"),
            Preset("contrast")
        ]
    },

    "hearts": {
        "layers": ["value-mask", "wobble", "skew", "posterize", "snow", "crt", "lens"],
        "settings": lambda: {
            "mask": mask.mcpaint_19,
            "mask_repeat": random.randint(8, 12),
            "posterize_levels": random.randint(1, 2),
        },
        "generator": lambda settings: {
            "distrib": distrib.ones,
            "hue_distrib": None if coin_flip() else random_member([distrib.column_index, distrib.row_index]),
            "hue_rotation": .925
        }
    },

    "heartburn": {
        "layers": ["voronoi", "bloom", "vignette-dark", "contrast"],
        "settings": lambda: {
            "contrast": 10 + random.random() * 5.0,
            "dist_metric": random_member(distance.all()),
            "voronoi_alpha": 0.9625,
            "voronoi_diagram_type": 42,
            "voronoi_inverse": True,
            "voronoi_point_freq": 1,
        },
        "generator": lambda settings: {
            "freq": random.randint(12, 18),
            "octaves": random.randint(1, 3),
            "ridges": True,
        },
    },

    "hotel-carpet": {
        "layers": ["basic", "ripple", "carpet", "dither"],
        "settings": lambda: {
            "ripple_kink": .5 + random.random() * .25,
            "ripple_range": .666 + random.random() * .333,
        },
        "generator": lambda settings: {
            "spline_order": interp.constant,
        },
    },

    "hsv-gradient": {
        "layers": ["basic", "rotate", "lens"],
        "settings": lambda: {
            "palette_on": False,
        },
        "generator": lambda settings: {
            "hue_range": .5 + random.random() * 2.0,
            "lattice_drift": 1.0,
        }
    },

    "hydraulic-flow": {
        "layers": ["multires", "derivative-octaves", "refract-octaves", "erosion-worms", "density-map",
                   "maybe-invert", "shadow", "bloom", "rotate", "dither", "lens"],
        "settings": lambda: {
            "deriv_alpha": .25 + random.random() * .25,
            "erosion_worms_alpha": .125 + random.random() * .125,
            "erosion_worms_contraction": .75 + random.random() * .5,
            "erosion_worms_density": random.randint(5, 250),
            "erosion_worms_iterations": random.randint(50, 250),
            "palette_on": False,
            "refract_range": random.random(),
        },
        "generator": lambda settings: {
            "freq": 2,
            "hue_range": random.random(),
            "ridges": coin_flip(),
            "saturation": random.random(),
        }
    },

    "i-made-an-art": {
        "layers": ["basic", "outline", "saturation", "distressed", "contrast"],
        "generator": lambda settings: {
            "spline_order": interp.constant,
            "lattice_drift": random.randint(5, 10),
            "hue_range": random.random() * 4,
            "hue_rotation": random.random(),
        }
    },

    "inkling": {
        "layers": ["voronoi", "refract-post", "funhouse", "grayscale", "density-map", "contrast",
                   "fibers", "grime", "scratches"],
        "settings": lambda: {
            "dist_metric": distance.euclidean,
            "contrast": 2.5,
            "refract_range": .25 + random.random() * .125,
            "voronoi_diagram_type": voronoi.flow,
            "voronoi_point_freq": random.randint(3, 5),
            "voronoi_refract": .25 + random.random() * .125,
            "warp_range": .125 + random.random() * .06125,
        },
        "generator": lambda settings: {
            "distrib": distrib.ones,
            "freq": random.randint(2, 4),
            "lattice_drift": 1.0,
            "mask": mask.dropout,
            "mask_static": True,
        },
    },

    "invert": {
        "post": lambda settings: [Effect("convolve", kernel=mask.conv2d_invert)]
    },

    "is-this-anything": {
        "layers": ["soup"],
        "settings": lambda: {
            "refract_range": 2.5 + random.random() * 1.25,
            "voronoi_point_freq": 1,
        }
    },

    "its-the-fuzz": {
        "layers": ["multires-low", "muppet-skin"],
        "settings": lambda: {
            "worms_behavior": worms.unruly,
            "worms_drunkenness": .5 + random.random() * .25,
            "worms_duration": 2.0 + random.random(),
        }
    },

    "jorts": {
        "layers": ["glyph-map", "funhouse", "skew", "shadow", "brightness", "contrast", "saturation", "dither", "vignette-dark"],
        "settings": lambda: {
            "glyph_map_alpha": .5 + random.random() * .25,
            "glyph_map_colorize": True,
            "glyph_map_mask": mask.v_bar,
            "glyph_map_spline_order": interp.linear,
            "glyph_map_zoom": 4.0,
            "angle": 0,
            "warp_freq": [random.randint(2, 3), random.randint(2, 3)],
            "warp_range": .0125 + random.random() * .006125,
            "warp_octaves": 1,
        },
        "generator": lambda settings: {
            "freq": [128, 512],
            "hue_rotation": .5 + random.random() * .05,
            "hue_range": .06125 + random.random() * .06125,
        }
    },

    "jovian-clouds": {
        "layers": ["voronoi", "worms", "brightness", "contrast", "saturation", "shadow", "dither", "lens"],
        "settings": lambda: {
            "contrast": 2.0,
            "dist_metric": distance.euclidean,
            "voronoi_alpha": .175 + random.random() * .25,
            "voronoi_diagram_type": voronoi.flow,
            "voronoi_point_distrib": point.random,
            "voronoi_point_freq": random.randint(8, 10),
            "voronoi_refract": 5.0 + random.random() * 3.0,
            "worms_behavior": worms.chaotic,
            "worms_alpha": .175 + random.random() * .25,
            "worms_density": 500,
            "worms_duration": 2.0,
            "worms_kink": 192,
            "worms_stride": 1.0,
            "worms_stride_deviation": .06125,
        },
        "generator": lambda settings: {
            "freq": [random.randint(4, 7), random.randint(1, 3)],
            "hue_range": .333 + random.random() * .16667,
            "hue_rotation": .5,
        },
    },

    "just-refracts-maam": {
        "layers": ["refract-octaves", "refract-post", "shadow", "lens"],
        "settings": lambda: {
            "refract_range": .5 + random.random() * .5
        },
        "generator": lambda settings: {
            "corners": True,
            "ridges": coin_flip(),
        },
    },

    "kaleido": {
        "layers": ["wobble"],
        "settings": lambda: {
            "kaleido_point_corners": False,
            "kaleido_point_distrib": point.random,
            "kaleido_point_freq": 1,
            "kaleido_sdf_sides": random.randint(0, 10),
            "kaleido_sides": random.randint(5, 32),
            "kaleido_blend_edges": coin_flip(),
        },
        "post": lambda settings: [
            Effect("kaleido",
                   blend_edges=settings["kaleido_blend_edges"],
                   point_corners=settings["kaleido_point_corners"],
                   point_distrib=settings["kaleido_point_distrib"],
                   point_freq=settings["kaleido_point_freq"],
                   sdf_sides=settings["kaleido_sdf_sides"],
                   sides=settings["kaleido_sides"]),
        ]
    },

    "knotty-clouds": {
        "layers": ["voronoi", "worms"],
        "settings": lambda: {
            "voronoi_alpha": .125 + random.random() * .25,
            "voronoi_diagram_type": voronoi.color_range,
            "voronoi_point_freq": random.randint(6, 10),
            "worms_alpha": .666 + random.random() * .333,
            "worms_behavior": worms.obedient,
            "worms_density": 1000,
            "worms_duration": 1,
            "worms_kink": 4,
        },
    },

    "later": {
        "layers": ["value-mask", "multires", "wobble", "voronoi", "funhouse", "glowing-edges", "crt", "vignette-dark"],
        "settings": lambda: {
            "dist_metric": distance.euclidean,
            "mask": random_member(mask.procedural_members()),
            "voronoi_diagram_type": voronoi.flow,
            "voronoi_point_distrib": point.random,
            "voronoi_point_freq": random.randint(4, 8),
            "voronoi_refract": 2.0 + random.random(),
            "warp_freq": random.randint(2, 4),
            "warp_spline_order": interp.bicubic,
            "warp_octaves": 2,
            "warp_range": .05 + random.random() * .025,
        },
        "generator": lambda settings: {
            "freq": random.randint(4, 8),
            "spline_order": interp.constant,
        },
    },

    "lattice-noise": {
        "layers": ["derivative-octaves", "derivative-post", "density-map", "shadow",
                   "dither", "saturation", "vignette-dark"],
        "settings": lambda: {
            "dist_metric": random_member(distance.absolute_members()),
        },
        "generator": lambda settings: {
            "freq": random.randint(2, 5),
            "lattice_drift": 1.0,
            "octaves": random.randint(2, 3),
            "ridges": coin_flip(),
        },
    },

    "lcd": {
        "layers": ["value-mask", "invert", "skew", "shadow", "vignette-bright", "brightness", "dither"],
        "settings": lambda: {
            "mask": random_member([mask.lcd, mask.lcd_binary]),
            "mask_repeat": random.randint(8, 12),
        },
        "generator": lambda settings: {
            "saturation": 0.0,
        },
    },

    "lens": {
        "layers": ["lens-distortion", "aberration", "vaseline", "tint", "vignette-dark", "contrast"],
    },

    "lens-distortion": {
        "post": lambda settings: [
            Effect("lens_distortion", displacement=(.25 + random.random() * .125) * (1 if coin_flip() else -1)),
        ]
    },

    "lens-warp": {
        "post": lambda settings: [
            Effect("lens_warp", displacement=.125 + random.random() * .06125),
            Effect("lens_distortion", displacement=.25 + random.random() * .125 * (1 if coin_flip() else -1)),
        ]
    },

    "light-leak": {
        "layers": ["vignette-bright"],
        "post": lambda settings: [Effect("light_leak", alpha=.125 + random.random() * .06125), Preset("bloom")]
    },

    "look-up": {
        "layers": ["multires-alpha", "bloom", "brightness", "contrast", "saturation"],
        "settings": lambda: {
            "brightness": -.125,
            "contrast": 1.5,
            "saturation": .5,
            "speed": .025,
        },
        "generator": lambda settings: {
            "color_space": color.hsv,
            "distrib": distrib.exp,
            "hue_range": .333 + random.random() * .333,
            "lattice_drift": 0,
            "mask": mask.sparser,
            "octaves": 8,
            "ridges": True,
        },
    },

    "lost-in-it": {
        "layers": ["basic", "ripple", "brightness", "contrast"],
        "settings": lambda: {
            "ripple_freq": random.randint(2, 4),
            "ripple_range": .5 + random.random() * .25,
        },
        "generator": lambda settings: {
            "distrib": distrib.ones,
            "freq": random.randint(4, 6),
            "mask": random_member([mask.h_bar, mask.v_bar]),
            "spline_order": interp.constant,
            "octaves": 3,
        },
    },

    "lotus": {
        "layers": ["reflect-post", "dmt", "kaleido"],
        "settings": lambda: {
            "kaleido_blend_edges": False,
            "reflect_range": 10.0 + random.random() * 5.0,
        },
        "generator": lambda settings: {
            "brightness_distrib": None,
            "hue_range": .75 + random.random() * .75,
        },
    },

    "lowpoly": {
        "settings": lambda: {
            "lowpoly_distrib": random_member(point.circular_members()),
            "lowpoly_freq": random.randint(10, 20),
        },
        "post": lambda settings: [
            Effect("lowpoly",
                   distrib=settings["lowpoly_distrib"],
                   freq=settings["lowpoly_freq"])
        ]
    },

    "lowpoly-regions": {
        "layers": ["voronoi", "lowpoly"],
        "settings": lambda: {
            "voronoi_diagram_type": voronoi.color_regions,
            "voronoi_point_freq": random.randint(2, 3),
        },
    },

    "lsd": {
        "layers": ["refract-post", "invert", "random-hue", "lens"],
        "settings": lambda: {
            "speed": .025,
        },
        "generator": lambda settings: {
            "brightness_distrib": distrib.ones,
            "freq": random.randint(3, 4),
            "hue_range": random.randint(3, 4),
        },
    },

    "mad-multiverse": {
        "layers": ["kaleido"],
        "settings": lambda: {
            "kaleido_point_freq": random.randint(3, 6),
        },
    },

    "magic-smoke": {
        "layers": ["worms"],
        "settings": lambda: {
            "worms_alpha": 1,
            "worms_behavior": random_member([worms.obedient, worms.crosshatch]),
            "worms_density": 750,
            "worms_duration": .25,
            "worms_kink": random.randint(1, 3),
            "worms_stride": random.randint(64, 256),
        },
        "generator": lambda settings: {
            "octaves": random.randint(2, 3),
        },
    },

    "maybe-derivative-post": {
        "post": lambda settings: [] if coin_flip() else [Preset("derivative-post")]
    },

    "maybe-invert": {
        "post": lambda settings: [] if coin_flip() else [Preset("invert")]
    },

    "maybe-palette": {
        "settings": lambda: {
            "palette_name": random_member(PALETTES),
            "palette_on": coin_flip(),
        },
        "post": lambda settings: [] if not settings["palette_on"] else [
            Effect("palette", name=settings["palette_name"])
        ]
    },

    "mcpaint": {
        "layers": ["glyph-map", "maybe-palette", "skew", "dither", "saturation", "vignette-dark"],
        "settings": lambda: {
            "glyph_map_colorize": coin_flip(),
            "glyph_map_mask": mask.mcpaint,
            "glyph_map_zoom": random.randint(2, 3),
        },
        "generator": lambda settings: {
            "corners": True,
            "freq": random.randint(2, 3),
            "spline_order": interp.cosine,
        },
    },

    "metaballs": {
        "layers": ["voronoi", "posterize"],
        "settings": lambda: {
            "dist_metric": distance.euclidean,
            "posterize_levels": 1,
            "voronoi_diagram_type": voronoi.flow,
            "voronoi_point_drift": 4,
            "voronoi_point_freq": 10,
        },
    },

    "moire-than-a-feeling": {
        "layers": ["wormhole", "density-map", "invert", "contrast"],
        "settings": lambda: {
            "wormhole_kink": 128,
            "wormhole_stride": .0005,
        },
        "generator": lambda settings: {
            "octaves": random.randint(1, 2),
            "saturation": 0,
        },
    },

    "molded-plastic": {
        "layers": ["color-flow", "refract-post"],
        "settings": lambda: {
            "dist_metric": distance.euclidean,
            "refract_range": 1.0 + random.random() * .5,
            "voronoi_inverse": True,
            "voronoi_point_distrib": point.random,
        },
    },

    "molten-glass": {
        "layers": ["sine-octaves", "octave-warp-post", "brightness", "contrast",
                   "bloom", "shadow", "normalize", "lens"],
        "generator": lambda settings: {
            "hue_range": random.random() * 3.0,
        },
    },

    "mosaic": {
        "layers": ["voronoi"],
        "settings": lambda: {
            "voronoi_alpha": .75 + random.random() * .25
        },
        "post": lambda settings: [Preset("bloom")]
    },

    "multires": {
        "layers": ["basic"],
        "generator": lambda settings: {
            "octaves": random.randint(4, 8)
        }
    },

    "multires-alpha": {
        "layers": ["multires"],
        "settings": lambda: {
            "palette_on": False,
        },
        "generator": lambda settings: {
            "distrib": distrib.exp,
            "lattice_drift": 1,
            "octave_blending": blend.alpha,
            "octaves": 5,
        }
    },

    "multires-low": {
        "layers": ["basic"],
        "generator": lambda settings: {
            "octaves": random.randint(2, 4)
        }
    },

    "multires-ridged": {
        "layers": ["multires"],
        "generator": lambda settings: {
            "lattice_drift": 1,
            "ridges": True
        }
    },

    "muppet-skin": {
        "layers": ["basic", "worms", "bloom", "lens"],
        "settings": lambda: {
            "palette_on": False,
            "worms_alpha": .625 + random.random() * .125,
            "worms_behavior": worms.unruly if coin_flip() else worms.obedient,
            "worms_density": 250,
            "worms_stride": .75,
            "worms_stride_deviation": .25,
        },
        "generator": lambda settings: {
            "hue_range": random.random() * .5,
            "lattice_drift": 1.0,
        }
    },

    "mycelium": {
        "layers": ["multires", "grayscale", "octave-warp-octaves", "derivative-post",
                   "normalize", "fractal-seed", "vignette-dark", "contrast"],
        "settings": lambda: {
            "speed": .05,
            "warp_freq": [random.randint(2, 3), random.randint(2, 3)],
            "warp_range": 2.5 + random.random() * 1.25,
            "worms_behavior": worms.random,
        },
        "generator": lambda settings: {
            "color_space": color.grayscale,
            "distrib": distrib.ones,
            "freq": [random.randint(3, 4), random.randint(3, 4)],
            "lattice_drift": 1.0,
            "mask": mask.h_tri,
            "mask_static": True,
        }
    },

    "nausea": {
        "layers": ["value-mask", "ripple", "normalize", "maybe-palette", "aberration"],
        "settings": lambda: {
            "mask": random_member([mask.h_bar, mask.v_bar]),
            "mask_repeat": random.randint(5, 8),
            "ripple_kink": 1.25 + random.random() * 1.25,
            "ripple_freq": random.randint(2, 3),
            "ripple_range": 1.25 + random.random(),
        },
        "generator": lambda settings: {
            "color_space": color.rgb,
            "spline_order": interp.constant,
        },
    },

    "nebula": {
        "post": lambda settings: [Effect("nebula")]
    },

    "nerdvana": {
        "layers": ["symmetry", "voronoi", "density-map", "reverb", "bloom"],
        "settings": lambda: {
            "dist_metric": distance.euclidean,
            "palette_on": False,
            "reverb_octaves": 2,
            "reverb_ridges": False,
            "voronoi_diagram_type": voronoi.color_range,
            "voronoi_point_distrib": random_member(point.circular_members()),
            "voronoi_point_freq": random.randint(5, 10),
            "voronoi_nth": 1,
        },
    },

    "neon-cambrian": {
        "layers": ["voronoi", "posterize", "wormhole", "derivative-post", "brightness", "bloom", "contrast", "aberration"],
        "settings": lambda: {
            "contrast": 4,
            "dist_metric": distance.euclidean,
            "posterize_levels": random.randint(20, 25),
            "voronoi_diagram_type": voronoi.color_flow,
            "voronoi_point_distrib": point.random,
            "wormhole_stride": .2 + random.random() * .1,
        },
        "generator": lambda settings: {
            "freq": 12,
            "hue_range": 4,
        },
    },

    "noise-blaster": {
        "layers": ["multires", "reindex-octaves", "reindex-post"],
        "settings": lambda: {
            "reindex_range": 3,
            "speed": .025,
        },
        "generator": lambda settings: {
            "freq": random.randint(3, 4),
            "lattice_drift": 1,
        },
    },

    "noise-lake": {
        "layers": ["multires-low", "value-refract", "snow", "lens"],
        "settings": lambda: {
            "value_freq": random.randint(4, 6),
            "value_refract_range": .25 + random.random() * .125,
        },
        "generator": lambda settings: {
            "hue_range": .75 + random.random() * 0.375,
            "freq": random.randint(4, 6),
            "lattice_drift": 1.0,
            "ridges": True,
        },
    },

    "noise-tunnel": {
        "layers": ["periodic-distance", "periodic-refract", "snow", "lens"],
        "settings": lambda: {
            "speed": 1.0,
        },
        "generator": lambda settings: {
            "hue_range": 2.0 + random.random()
        },
    },

    "noirmaker": {
        "layers": ["dither", "grayscale"],
        "post": lambda settings: [
            Effect("light_leak", alpha=.333 + random.random() * .333),
            Preset("bloom"),
            Preset("vignette-dark"),
            Effect("adjust_contrast", amount=5)
        ]
    },

    "normals": {
        "post": lambda settings: [Effect("normal_map")]
    },

    "normalize": {
        "post": lambda settings: [Effect("normalize")]
    },

    "now": {
        "layers": ["multires-low", "normalize", "wobble", "voronoi", "funhouse", "outline", "dither", "saturation"],
        "settings": lambda: {
            "dist_metric": distance.euclidean,
            "voronoi_diagram_type": voronoi.flow,
            "voronoi_point_distrib": point.random,
            "voronoi_point_freq": random.randint(3, 10),
            "voronoi_refract": 2.0 + random.random(),
            "warp_freq": random.randint(2, 4),
            "warp_octaves": 1,
            "warp_range": .0375 + random.random() * .0375,
            "warp_spline_order": interp.bicubic,
        },
        "generator": lambda settings: {
            "freq": random.randint(3, 10),
            "hue_range": random.random(),
            "saturation": .5 + random.random() * .5,
            "lattice_drift": coin_flip(),
            "spline_order": interp.constant,
        }
    },

    "nudge-hue": {
        "post": lambda settings: [Effect("adjust_hue", amount=-.125)]
    },

    "numberwang": {
        "layers": ["value-mask", "funhouse", "posterize", "palette", "maybe-invert",
                   "random-hue", "dither", "saturation"],
        "settings": lambda: {
            "mask": mask.alphanum_numeric,
            "mask_repeat": random.randint(5, 10),
            "posterize_levels": 2,
            "warp_range": .25 + random.random() * .75,
            "warp_freq": random.randint(2, 4),
            "warp_octaves": 1,
            "warp_spline_order": interp.bicubic,
        },
        "generator": lambda settings: {
            "spline_order": interp.cosine,
        },
    },

    "octave-blend": {
        "layers": ["multires-alpha"],
        "generator": lambda settings: {
            "corners": True,
            "distrib": random_member([distrib.ones, distrib.uniform]),
            "freq": random.randint(2, 5),
            "lattice_drift": 0,
            "mask": random_member(mask.procedural_members()),
            "spline_order": interp.constant,
        }
    },

    "octave-warp-octaves": {
        "settings": lambda: {
            "warp_freq": [random.randint(2, 4), random.randint(2, 4)],
            "warp_octaves": random.randint(1, 4),
            "warp_range": .5 + random.random() * .25,
            "warp_signed_range": False,
            "warp_spline_order": interp.bicubic
        },
        "octaves": lambda settings: [
            Effect("warp",
                   displacement=settings["warp_range"],
                   freq=settings["warp_freq"],
                   octaves=settings["warp_octaves"],
                   signed_range=settings["warp_signed_range"],
                   spline_order=settings["warp_spline_order"])
        ]
    },

    "octave-warp-post": {
        "settings": lambda: {
            "speed": .025 + random.random() * .0125,
            "warp_freq": random.randint(2, 3),
            "warp_octaves": random.randint(2, 4),
            "warp_range": 2.0 + random.random(),
            "warp_spline_order": interp.bicubic,
        },
        "post": lambda settings: [
            Effect("warp",
                   displacement=settings["warp_range"],
                   freq=settings["warp_freq"],
                   octaves=settings["warp_octaves"],
                   spline_order=settings["warp_spline_order"])
        ]
    },

    "oklab-color-space": {
        "layers": ["basic"],
        "settings": lambda: {
            "palette_on": False,
        },
        "generator": lambda settings: {
            "color_space": color.oklab,
            "octaves": random.randint(1, 8),
            "ridges": coin_flip(),
        }
    },

    "oldschool": {
        "layers": ["voronoi", "normalize", "maybe-palette", "random-hue", "saturation", "distressed"],
        "settings": lambda: {
            "dist_metric": distance.euclidean,
            "speed": .05,
            "voronoi_diagram_type": voronoi.flow,
            "voronoi_point_distrib": point.random,
            "voronoi_point_freq": random.randint(4, 8),
            "voronoi_refract": random.randint(8, 12) * .5,
        },
        "generator": lambda settings: {
            "color_space": color.rgb,
            "corners": True,
            "distrib": distrib.ones,
            "freq": random.randint(2, 5) * 2,
            "mask": mask.chess,
            "spline_order": interp.constant,
        },
    },

    "one-art-please": {
        "layers": ["dither", "light-leak", "contrast"],
        "post": lambda settings: [
            Effect("adjust_saturation", amount=.75),
            Effect("texture")
        ]
    },

    "oracle": {
        "layers": ["value-mask", "maybe-palette", "random-hue", "maybe-invert", "snow", "crt"],
        "generator": lambda settings: {
            "corners": True,
            "freq": [14, 8],
            "mask": mask.iching,
            "spline_order": interp.constant,
        },
    },

    "outer-limits": {
        "layers": ["symmetry", "reindex-post", "normalize", "dither", "be-kind-rewind", "vignette-dark", "contrast"],
        "settings": lambda: {
            "palette_on": False,
            "reindex_range": random.randint(8, 16),
        },
        "generator": lambda settings: {
            "saturation": 0,
        },
    },

    "outline": {
        "settings": lambda: {
            "dist_metric": distance.euclidean,
            "outline_invert": False,
        },
        "post": lambda settings: [
            Effect("outline",
                sobel_metric=settings["dist_metric"],
                invert=settings["outline_invert"],
            )
        ]
    },

    "oxidize": {
        "layers": ["refract-post", "contrast", "bloom", "shadow", "saturation", "lens"],
        "settings": lambda: {
            "refract_range": .1 + random.random() * .05,
            "saturation": .5,
            "speed": .05,
        },
        "generator": lambda settings: {
            "distrib": distrib.exp,
            "freq": 4,
            "hue_range": .875 + random.random() * .25,
            "lattice_drift": 1,
            "octave_blending": blend.reduce_max,
            "octaves": 8,
        },
    },

    "paintball-party": {
        "layers": ["spatter"] * random.randint(5, 7) + ["bloom"],
        "generator": lambda settings: {
            "distrib": distrib.zeros,
        }
    },

    "painterly": {
        "layers": ["value-mask", "ripple", "funhouse", "rotate", "saturation", "dither", "lens"],
        "settings": lambda: {
            "mask": random_member(mask.grid_members()),
            "mask_repeat": 1,
            "ripple_freq": random.randint(4, 6),
            "ripple_kink": .06125 + random.random() * .125,
            "ripple_range": .06125 + random.random() * .125,
            "warp_freq": random.randint(5, 7),
            "warp_octaves": 8,
            "warp_range": .06125 + random.random() * .125,
        },
        "generator": lambda settings: {
            "distrib": distrib.uniform,
            "hue_range": .333 + random.random() * .333,
            "octaves": 8,
            "ridges": True,
            "spline_order": interp.linear,
        },
    },

    "palette": {
        "layers": ["maybe-palette"],
        "settings": lambda: {
            "palette_name": random_member(PALETTES),
            "palette_on": True,
        },
    },

    "pearlescent": {
        "layers": ["voronoi", "normalize", "refract-post", "bloom", "shadow", "lens", "brightness", "contrast"],
        "settings": lambda: {
            "brightness": .05,
            "dist_metric": distance.euclidean,
            "refract_range": .5 + random.random() * .25,
            "tint_alpha": .0125 + random.random() * .06125,
            "voronoi_alpha": .333 + random.random() * .333,
            "voronoi_diagram_type": voronoi.flow,
            "voronoi_point_freq": random.randint(3, 5),
            "voronoi_refract": .25 + random.random() * .125,
        },
        "generator": lambda settings: {
            "freq": [2, 2],
            "hue_range": random.randint(3, 5),
            "octaves": random.randint(3, 5),
            "ridges": coin_flip(),
            "saturation": .175 + random.random() * .25,
        },
    },

    "periodic-distance": {
        "generator": lambda settings: {
            "freq": random.randint(1, 6),
            "distrib": random_member([m for m in distrib if distrib.is_center_distance(m)]),
            "hue_range": .25 + random.random() * .125,
        },
        "post": lambda settings: [Effect("normalize")]
    },

    "periodic-refract": {
        "layers": ["value-refract"],
        "settings": lambda: {
            "value_distrib": random_member([m for m in distrib if distrib.is_center_distance(m) or distrib.is_scan(m)]),
        },
    },

    "pink-diamond": {
        "layers": ["periodic-distance", "periodic-refract", "refract-octaves", "refract-post", "nudge-hue", "bloom", "lens"],
        "settings": lambda: {
            "bloom_alpha": .333 + random.random() * .16667,
            "refract_range": .0125 + random.random() * .006125,
            "refract_y_from_offset": False,
            "value_distrib": random_member([m for m in distrib if distrib.is_center_distance(m)]),
            "vaseline_alpha": .125 + random.random() * .06125,
            "speed": -.125,
        },
        "generator": lambda settings: {
            "brightness_distrib": distrib.uniform,
            "distrib": settings["value_distrib"],
            "hue_range": .2 + random.random() * .1,
            "hue_rotation": .9 + random.random() * .05,
            "freq": 2,
            "ridges": True,
            "saturation_distrib": distrib.ones,
        }
    },

    "pixel-sort": {
        "settings": lambda: {
            "pixel_sort_angled": coin_flip(),
            "pixel_sort_darkest": coin_flip(),
        },
        "post": lambda settings: [
            Effect("pixel_sort",
                   angled=settings["pixel_sort_angled"],
                   darkest=settings["pixel_sort_darkest"])
        ]
    },

    "plaid": {
        "layers": ["multires-low", "derivative-octaves", "funhouse", "rotate", "dither",
                   "vignette-dark", "contrast"],
        "settings": lambda: {
            "dist_metric": distance.chebyshev,
            "vignette_alpha": .25 + random.random() * .125,
            "warp_freq": random.randint(2, 3),
            "warp_range": random.random() * .06125,
            "warp_octaves": 1,
        },
        "generator": lambda settings: {
            "distrib": distrib.ones,
            "hue_range": random.random() * .5,
            "freq": random.randint(1, 3) * 2,
            "mask": mask.chess,
            "spline_order": random.randint(1, 3),
        },
    },

    "pluto": {
        "layers": ["multires-ridged", "derivative-octaves", "voronoi", "refract-post",
                   "bloom", "shadow", "contrast", "dither", "lens"],
        "settings": lambda: {
            "deriv_alpha": .333 + random.random() * .16667,
            "dist_metric": distance.euclidean,
            "palette_on": False,
            "refract_range": .01 + random.random() * .005,
            "shadow_alpha": 1.0,
            "tint_alpha": .0125 + random.random() * .006125,
            "vignette_alpha": .125 + random.random() * .06125,
            "voronoi_alpha": .925 + random.random() * .075,
            "voronoi_diagram_type": voronoi.color_range,
            "voronoi_nth": 2,
            "voronoi_point_distrib": point.random,
        },
        "generator": lambda settings: {
            "distrib": distrib.exp,
            "freq": random.randint(4, 8),
            "hue_rotation": .575,
            "octave_blending": blend.reduce_max,
            "saturation": .75 + random.random() * .25,
        },
    },

    "polar": {
        "layers": ["kaleido"],
        "settings": lambda: {
            "kaleido_sides": 1
        },
    },

    "posterize": {
        "layers": ["normalize"],
        "settings": lambda: {
            "posterize_levels": random.randint(3, 7)
        },
        "post": lambda settings: [Effect("posterize", levels=settings["posterize_levels"])]
    },

    "posterize-outline": {
        "layers": ["posterize", "outline"]
    },

    "precision-error": {
        "layers": ["symmetry", "derivative-octaves", "reflect-octaves", "derivative-post",
                   "density-map", "invert", "shadows", "contrast"],
        "settings": lambda: {
            "palette_on": False,
            "reflect_range": .75 + random.random() * 2.0,
        }
    },

    "procedural-mask": {
        "layers": ["value-mask", "skew", "bloom", "crt", "vignette-dark", "contrast"],
        "settings": lambda: {
            "mask": random_member(mask.procedural_members()),
            "mask_repeat": random.randint(10, 20)
        },
        "generator": lambda settings: {
            "spline_order": interp.cosine
        }
    },

    "prophesy": {
        "layers": ["value-mask", "refract-octaves", "posterize", "emboss", "brightness", "contrast",
                   "maybe-invert", "skew", "dexter", "tint", "dither", "shadows", "contrast"],
        "settings": lambda: {
            "brightness": -.125,
            "contrast": 1.5,
            "mask": mask.invaders_square,
            "refract_range": .06125 + random.random() * .06125,
            "refract_signed_range": False,
            "refract_y_from_offset": True,
            "posterize_levels": random.randint(3, 6),
            "tint_alpha": .01 + random.random() * .005,
            "vignette_alpha": .25 + random.random() * .125,
        },
        "generator": lambda settings: {
            "freq": 24,
            "octaves": 2,
            "saturation": .125 + random.random() * .075,
            "spline_order": interp.cosine,
        },
        "post": lambda settings: [Effect("texture")]
    },

    "pseudoprematism": {
        "layers": ["value-mask", "funhouse", "rotate"],
        "settings": lambda: {
            "warp_range": .5 + random.random() * .25,
            "warp_octaves": 1,
        },
        "generator": lambda settings: {
            "freq": [random.randint(8, 16), random.randint(48, 64)],
            "mask": mask.sparser,
            "octave_blending": blend.alpha,
            "octaves": 2,
            "spline_order": interp.constant,
        },
    },

    "pull": {
        "layers": ["basic-voronoi", "erosion-worms"],
        "settings": lambda: {
            "voronoi_alpha": 0.25 + random.random() * 0.5,
            "voronoi_diagram_type": random_member([voronoi.range, voronoi.color_range, voronoi.range_regions]),
        }
    },

    "puzzler": {
        "layers": ["basic-voronoi", "maybe-invert", "wormhole"],
        "settings": lambda: {
            "speed": .025,
            "voronoi_diagram_type": voronoi.color_regions,
            "voronoi_point_distrib": random_member(point, mask.nonprocedural_members()),
            "voronoi_point_freq": 10,
        },
    },

    "quadrants": {
        "layers": ["basic", "reindex-post"],
        "settings": lambda: {
            "reindex_range": 2,
        },
        "generator": lambda settings: {
            "color_space": color.rgb,
            "freq": [2, 2],
            "spline_order": random_member([interp.cosine, interp.bicubic]),
        },
    },

    "quilty": {
        "layers": ["voronoi", "bloom", "dither"],
        "settings": lambda: {
            "dist_metric": random_member([distance.manhattan, distance.chebyshev]),
            "voronoi_diagram_type": random_member([voronoi.range, voronoi.color_range]),
            "voronoi_nth": random.randint(0, 4),
            "voronoi_point_distrib": random_member(point.grid_members()),
            "voronoi_point_freq": random.randint(2, 4),
            "voronoi_refract": random.randint(1, 3) * .5,
            "voronoi_refract_y_from_offset": True,
        },
        "generator": lambda settings: {
            "spline_order": interp.constant,
            "freq": random.randint(2, 6),
            "saturation": random.random() * .5,
        },
    },

    "random-hue": {
        "post": lambda settings: [Effect("adjust_hue", amount=random.random())]
    },

    "rasteroids": {
        "layers": ["funhouse", "sobel", "invert", "pixel-sort", "bloom", "crt", "vignette-dark"],
        "settings": lambda: {
            "pixel_sort_angled": False,
            "pixel_sort_darkest": False,
            "vignette_alpha": .125 + random.random() * .06125,
            "warp_freq": random.randint(3, 5),
            "warp_octaves": random.randint(3, 5),
            "warp_range": .125 + random.random() * .06125,
            "warp_spline_order": interp.constant,
        },
        "generator": lambda settings: {
            "distrib": random_member([distrib.uniform, distrib.ones]),
            "freq": 6 * random.randint(2, 3),
            "mask": random_member(mask),
            "spline_order": interp.constant,
        },
    },

    "reflect-octaves": {
        "settings": lambda: {
            "reflect_range": 5 + random.random() * .25,
        },
        "octaves": lambda settings: [
            Effect("refract",
                   displacement=settings["reflect_range"],
                   from_derivative=True)
        ]
    },

    "reflect-post": {
        "settings": lambda: {
            "reflect_range": .5 + random.random() * 12.5,
        },
        "post": lambda settings: [
            Effect("refract",
                   displacement=settings["reflect_range"],
                   from_derivative=True)
        ]
    },

    "reflecto": {
        "layers": ["basic", "reflect-octaves", "reflect-post"]
    },

    "refract-octaves": {
        "settings": lambda: {
            "refract_range": .5 + random.random() * .25,
            "refract_signed_range": True,
            "refract_y_from_offset": False,
        },
        "octaves": lambda settings: [
            Effect("refract",
                   displacement=settings["refract_range"],
                   signed_range=settings["refract_signed_range"],
                   y_from_offset=settings["refract_y_from_offset"])
        ]
    },

    "refract-post": {
        "settings": lambda: {
            "refract_range": .125 + random.random() * 1.25,
            "refract_signed_range": True,
            "refract_y_from_offset": True,
        },
        "post": lambda settings: [
            Effect("refract",
                   displacement=settings["refract_range"],
                   signed_range=settings["refract_signed_range"],
                   y_from_offset=settings["refract_y_from_offset"])
        ]
    },

    "regional": {
        "layers": ["voronoi", "glyph-map", "bloom", "crt", "contrast"],
        "settings": lambda: {
            "glyph_map_colorize": True,
            "glyph_map_zoom": random.randint(4, 8),
            "voronoi_diagram_type": voronoi.color_regions,
            "voronoi_nth": 0,
        },
        "generator": lambda settings: {
            "hue_range": .25 + random.random(),
        },
    },

    "reindex-octaves": {
        "settings": lambda: {
            "reindex_range": .125 + random.random() * 2.5
        },
        "octaves": lambda settings: [Effect("reindex", displacement=settings["reindex_range"])]
    },

    "reindex-post": {
        "settings": lambda: {
            "reindex_range": .125 + random.random() * 2.5
        },
        "post": lambda settings: [Effect("reindex", displacement=settings["reindex_range"])]
    },

    "remember-logo": {
        "layers": ["symmetry", "voronoi", "derivative-post", "density-map", "crt", "vignette-dark"],
        "settings": lambda: {
            "voronoi_alpha": 1.0,
            "voronoi_diagram_type": voronoi.regions,
            "voronoi_nth": random.randint(0, 4),
            "voronoi_point_distrib": random_member(point.circular_members()),
            "voronoi_point_freq": random.randint(3, 7),
        },
    },

    "reverb": {
        "layers": ["normalize"],
        "settings": lambda: {
            "reverb_iterations": 1,
            "reverb_ridges": coin_flip(),
            "reverb_octaves": random.randint(3, 6)
        },
        "post": lambda settings: [
            Effect("reverb",
                   iterations=settings["reverb_iterations"],
                   octaves=settings["reverb_octaves"],
                   ridges=settings["reverb_ridges"])
        ]
    },

    "ride-the-rainbow": {
        "layers": ["swerve-v", "scuff", "distressed", "contrast"],
        "generator": lambda settings: {
            "brightness_distrib": distrib.ones,
            "corners": True,
            "distrib": distrib.column_index,
            "freq": random.randint(6, 12),
            "hue_range": .9,
            "saturation_distrib": distrib.ones,
            "spline_order": interp.constant,
        },
    },

    "ridge": {
        "post": lambda settings: [Effect("ridge")]
    },

    "ripple": {
        "settings": lambda: {
            "ripple_range": .025 + random.random() * .1,
            "ripple_freq": random.randint(2, 3),
            "ripple_kink": random.randint(3, 18)
        },
        "post": lambda settings: [
            Effect("ripple",
                   displacement=settings["ripple_range"],
                   freq=settings["ripple_freq"],
                   kink=settings["ripple_kink"])
        ]
    },

    "rotate": {
        "settings": lambda: {
            "angle": random.random() * 360.0
        },
        "post": lambda settings: [Effect("rotate", angle=settings["angle"])]
    },

    "runes-of-arecibo": {
        "layers": ["value-mask", "grayscale", "posterize", "snow", "dither", "dither", "normalize",
                   "emboss", "maybe-invert", "contrast", "skew", "lens", "brightness", "contrast"],
        "settings": lambda: {
            "brightness": -.1,
            "mask": random_member([mask.arecibo_num, mask.arecibo_bignum, mask.arecibo_nucleotide]),
            "mask_repeat": random.randint(8, 12),
            "posterize_levels": 1,
            "vignette_alpha": .333 + random.random() * .16667,
        },
        "generator": lambda settings: {
            "corners": True,
            "spline_order": random_member([interp.linear, interp.cosine]),
        },
    },

    "sands-of-time": {
        "layers": ["worms", "lens"],
        "settings": lambda: {
            "worms_behavior": worms.unruly,
            "worms_alpha": 1,
            "worms_density": 750,
            "worms_duration": .25,
            "worms_kink": random.randint(1, 2),
            "worms_stride": random.randint(128, 256),
        },
        "generator": lambda settings: {
            "freq": random.randint(3, 5),
            "octaves": random.randint(1, 3),
        },
    },

    "satori": {
        "layers": ["multires-low", "sine-octaves", "voronoi", "contrast"],
        "settings": lambda: {
            "dist_metric": random_member(distance.absolute_members()),
            "speed": .05,
            "voronoi_alpha": 1.0,
            "voronoi_diagram_type": voronoi.flow,
            "voronoi_refract": random.randint(6, 12) * .25,
            "voronoi_point_distrib": random_member([point.random] + point.circular_members()),
            "voronoi_point_freq": random.randint(2, 8),
        },
        "generator": lambda settings: {
            "color_space": random_member(color.color_members()),
            "freq": random.randint(3, 4),
            "hue_range": random.random(),
            "lattice_drift": 1,
            "ridges": True,
        },
    },

    "saturation": {
        "settings": lambda: {
            "saturation": .333 + random.random() * .16667
        },
        "post": lambda settings: [Effect("adjust_saturation", amount=settings["saturation"])]
    },

    "sblorp": {
        "layers": ["posterize", "invert", "maybe-palette", "saturation", "dither"],
        "settings": lambda: {
            "posterize_levels": 1,
        },
        "generator": lambda settings: {
            "color_space": color.rgb,
            "distrib": distrib.ones,
            "freq": random.randint(5, 9),
            "lattice_drift": 1.25 + random.random() * 1.25,
            "mask": mask.sparse,
            "octave_blending": blend.reduce_max,
            "octaves": random.randint(2, 3),
        },
    },

    "sbup": {
        "layers": ["posterize", "funhouse", "falsetto", "palette", "distressed"],
        "settings": lambda: {
            "posterize_levels": random.randint(1, 2),
            "warp_range": 1.5 + random.random(),
        },
        "generator": lambda settings: {
            "distrib": distrib.ones,
            "freq": [2, 2],
            "mask": mask.square,
        },
    },

    "scanline-error": {
        "post": lambda settings: [Effect("scanline_error")]
    },

    "scratches": {
        "post": lambda settings: [Effect("scratches")]
    },

    "scribbles": {
        "layers": ["derivative-octaves", "derivative-post", "sobel"],
        "settings": lambda: {
            "dist_metric": random_member(distance.absolute_members()),
        },
        "generator": lambda settings: {
            "freq": random.randint(2, 3),
            "lattice_drift": 1.0,
            "octaves": 3,
            "ridges": True,
            "saturation": 0,
        },
        "post": lambda settings: [
            Effect("fibers"),
            Effect("grime"),
            Preset("vignette-bright"),
            Preset("contrast"),
            Preset("dither"),
        ]
    },

    "scuff": {
        "post": lambda settings: [Effect("scratches")]
    },

    "serene": {
        "layers": ["basic-water", "periodic-refract", "refract-post", "lens"],
        "settings": lambda: {
            "refract_range": .0025 + random.random() * .00125,
            "refract_y_from_offset": False,
            "value_distrib": distrib.center_circle,
            "value_freq": random.randint(2, 3),
            "value_refract_range": .025 + random.random() * .0125,
            "speed": 0.25,
        },
        "generator": lambda settings: {
            "freq": random.randint(2, 3),
            "octaves": 3,
        }
    },

    "shadow": {
        "settings": lambda: {
            "shadow_alpha": .5 + random.random() * .25
        },
        "post": lambda settings: [Effect("shadow", alpha=settings["shadow_alpha"])]
    },

    "shadows": {
        "layers": ["shadow", "vignette-dark"]
    },

    "shake-it-like": {
        "post": lambda settings: [Effect("frame")]
    },

    "shape-party": {
        "layers": ["voronoi", "posterize", "invert", "aberration", "bloom"],
        "settings": lambda: {
            "aberration_displacement": .125 + random.random() * .06125,
            "dist_metric": distance.manhattan,
            "posterize_levels": 1,
            "voronoi_point_freq": 2,
            "voronoi_nth": 1,
            "voronoi_refract": .125 + random.random() * .25,
        },
        "generator": lambda settings: {
            "color_space": color.rgb,
            "distrib": distrib.ones,
            "freq": 11,
            "mask": random_member(mask.procedural_members()),
            "spline_order": interp.cosine,
        },
    },

    "shatter": {
        "layers": ["basic-voronoi", "refract-post", "maybe-invert", "posterize-outline", "normalize", "dither", "lens"],
        "settings": lambda: {
            "dist_metric": random_member(distance.absolute_members()),
            "posterize_levels": random.randint(4, 6),
            "refract_range": .75 + random.random() * .375,
            "refract_y_from_offset": True,
            "speed": .05,
            "voronoi_inverse": coin_flip(),
            "voronoi_point_freq": random.randint(3, 5),
            "voronoi_diagram_type": voronoi.range_regions,
        },
        "generator": lambda settings: {
            "color_space": random_member(color.color_members()),
        },
    },

    "shimmer": {
        "layers": ["derivative-octaves", "voronoi", "refract-post", "lens"],
        "settings": lambda: {
            "dist_metric": distance.euclidean,
            "refract_range": 1.25 * random.random() * .625,
            "voronoi_alpha": .25 + random.random() * .125,
            "voronoi_diagram_type": voronoi.color_flow,
            "voronoi_point_freq": 10,
        },
        "generator": lambda settings: {
            "freq": random.randint(2, 3),
            "hue_range": 3.0 + random.random() * 1.5,
            "lattice_drift": 1.0,
            "ridges": True,
        },
    },

    "shmoo": {
        "layers": ["basic", "posterize", "invert", "outline", "distressed"],
        "settings": lambda: {
            "palette_on": False,
            "posterize_levels": random.randint(1, 4),
            "speed": .025,
        },
        "generator": lambda settings: {
            "freq": random.randint(3, 4),
            "hue_range": 1.5 + random.random() * .75,
        },
    },

    "sideways": {
        "layers": ["multires-low", "reflect-octaves", "pixel-sort", "lens", "crt"],
        "settings": lambda: {
            "palette_on": False,
            "pixel_sort_angled": False,
        },
        "generator": lambda settings: {
            "freq": random.randint(6, 12),
            "distrib": distrib.ones,
            "mask": mask.script,
            "saturation": .06125 + random.random() * .125,
            "spline_order": random_member([m for m in interp if m != interp.constant]),
        },
    },

    "simple-frame": {
        "post": lambda settings: [Effect("simple_frame")]
    },

    "sined-multifractal": {
        "layers": ["multires-ridged", "sine-octaves", "bloom", "lens"],
        "settings": lambda: {
            "palette_on": False,
            "sine_range": random.randint(10, 15),
        },
        "generator": lambda settings: {
            "distrib": distrib.uniform,
            "freq": random.randint(2, 3),
            "hue_range": random.random(),
            "hue_rotation": random.random(),
            "lattice_drift": .75,
        },
    },

    "sine-octaves": {
        "settings": lambda: {
            "sine_range": random.randint(8, 12),
            "sine_rgb": False,
        },
        "octaves": lambda settings: [
            Effect("sine", amount=settings["sine_range"], rgb=settings["sine_rgb"])
        ]
    },

    "sine-post": {
        "settings": lambda: {
            "sine_range": random.randint(8, 20),
            "sine_rgb": True,
        },
        "post": lambda settings: [
            Effect("sine", amount=settings["sine_range"], rgb=settings["sine_rgb"])
        ]
    },

    "singularity": {
        "layers": ["basic-voronoi"],
        "settings": lambda: {
            "voronoi_point_freq": 1,
            "voronoi_diagram_type": random_member([voronoi.color_range, voronoi.range, voronoi.range_regions]),
        },
    },

    "sketch": {
        "post": lambda settings: [Effect("sketch"), Effect("fibers"), Effect("grime"), Effect("texture")]
    },

    "skew": {
        "layers": ["rotate"],
        "settings": lambda: {
            "angle": random.randint(5, 35),
        },
    },

    "snow": {
        "settings": lambda: {
            "snow_alpha": .25 + random.random() * .125
        },
        "post": lambda settings: [Effect("snow", alpha=settings["snow_alpha"])]
    },

    "sobel": {
        "settings": lambda: {
            "dist_metric": random_member(distance.all()),
        },
        "post": lambda settings: [Effect("sobel", dist_metric=settings["dist_metric"])]
    },

    "soft-cells": {
        "layers": ["voronoi", "rotate", "soften"],
        "settings": lambda: {
            "voronoi_alpha": .5 + random.random() * .5,
            "voronoi_diagram_type": voronoi.range_regions,
            "voronoi_point_distrib": random_member(point, mask.nonprocedural_members()),
            "voronoi_point_freq": random.randint(4, 8),
        },
    },

    "soften": {
        "layers": ["bloom", "lens"],
        "settings": lambda: {
        },
        "generator": lambda settings: {
            "color_space": random_member(color.color_members()),
            "freq": 2,
            "hue_range": .25 + random.random() * .25,
            "hue_rotation": random.random(),
            "lattice_drift": 1,
            "octaves": random.randint(1, 4),
        },
    },

    "soup": {
        "layers": ["voronoi", "normalize", "refract-post", "worms",
                   "grayscale", "density-map", "bloom", "shadow", "lens"],
        "settings": lambda: {
            "dist_metric": distance.euclidean,
            "refract_range": 2.5 + random.random() * 1.25,
            "refract_y_from_offset": True,
            "speed": .025,
            "voronoi_alpha": .333 + random.random() * .333,
            "voronoi_diagram_type": voronoi.flow,
            "voronoi_inverse": True,
            "voronoi_point_freq": random.randint(2, 3),
            "worms_alpha": .75 + random.random() * .25,
            "worms_behavior": worms.random,
            "worms_density": 500,
            "worms_kink": 4.0 + random.random() * 2.0,
            "worms_stride": 1.0,
            "worms_stride_deviation": 0.0,
        },
        "generator": lambda settings: {
            "freq": random.randint(2, 3),
        }
    },

    "spaghettification": {
        "layers": ["multires-low", "voronoi", "worms", "funhouse", "contrast", "density-map", "lens"],
        "settings": lambda: {
            "palette_on": False,
            "voronoi_diagram_type": voronoi.flow,
            "voronoi_inverse": True,
            "voronoi_point_freq": 1,
            "warp_range": .5 + random.random() * .25,
            "warp_octaves": 1,
            "worms_alpha": .875,
            "worms_behavior": worms.chaotic,
            "worms_density": 1000,
            "worms_kink": 1.0,
            "worms_stride": random.randint(150, 250),
            "worms_stride_deviation": 0.0,
        },
        "generator": lambda settings: {
            "freq": 2
        }
    },

    "spectrogram": {
        "layers": ["dither", "filthy"],
        "generator": lambda settings: {
            "distrib": distrib.row_index,
            "freq": random.randint(256, 512),
            "hue_range": .5 + random.random() * .5,
            "mask": mask.bar_code,
            "spline_order": interp.constant,
        }
    },

    "spatter": {
        "settings": lambda: {
            "speed": .0333 + random.random() * .016667,
            "spatter_color": True,
        },
        "post": lambda settings: [Effect("spatter", color=settings["spatter_color"])]
    },


    "splork": {
        "layers": ["voronoi", "posterize"],
        "settings": lambda: {
            "dist_metric": distance.chebyshev,
            "posterize_levels": 1,
            "voronoi_diagram_type": voronoi.color_range,
            "voronoi_nth": 1,
            "voronoi_point_freq": 2,
            "voronoi_refract": .125,
        },
        "generator": lambda settings: {
            "color_space": color.rgb,
            "distrib": distrib.ones,
            "freq": 33,
            "mask": mask.bank_ocr,
            "spline_order": interp.cosine,
        },
    },

    "spooky-ticker": {
        "post": lambda settings: [Effect("spooky_ticker")]
    },

    "stackin-bricks": {
        "layers": ["voronoi"],
        "settings": lambda: {
            "dist_metric": distance.triangular,
            "voronoi_diagram_type": voronoi.color_range,
            "voronoi_inverse": True,
            "voronoi_point_freq": 10,
        },
    },

    "starfield": {
        "layers": ["multires-low", "brightness", "nebula", "contrast", "lens", "dither", "vignette-dark"],
        "settings": lambda: {
            "brightness": -.075,
            "contrast": 2.0,
            "palette_on": False,
        },
        "generator": lambda settings: {
            "color_space": color.hsv,
            "distrib": distrib.exp,
            "freq": random.randint(400, 500),
            "hue_range": 1.0,
            "saturation": .75,
            "mask": mask.sparser,
            "mask_static": True,
            "spline_order": interp.linear,
        },
    },

    "stray-hair": {
        "post": lambda settings: [Effect("stray_hair")]
    },

    "string-theory": {
        "layers": ["multires-low", "erosion-worms", "bloom", "lens"],
        "settings": lambda: {
            "erosion_worms_alpha": .875 + random.random() * .125,
            "erosion_worms_contraction": 4.0 + random.random() * 2.0,
            "erosion_worms_density": .25 + random.random() * .125,
            "erosion_worms_iterations": random.randint(1250, 2500),
            "palette_on": False,
        },
        "generator": lambda settings: {
            "color_space": color.rgb,
            "octaves": random.randint(2, 4),
            "ridges": False,
        },
    },

    "subpixelator": {
        "layers": ["basic", "subpixels", "funhouse"],
    },

    "subpixels": {
        "post": lambda settings: [Effect("glyph_map", mask=random_member(mask.rgb_members()), zoom=random_member([2, 4, 8]))]
    },

    "symmetry": {
        "layers": ["maybe-palette"],
        "generator": lambda settings: {
            "corners": True,
            "freq": [2, 2],
        },
    },

    "swerve-h": {
        "post": lambda settings: [
            Effect("warp",
                   displacement=.5 + random.random() * .5,
                   freq=[random.randint(2, 5), 1],
                   octaves=1,
                   spline_order=interp.bicubic)
        ]
    },

    "swerve-v": {
        "post": lambda settings: [
            Effect("warp",
                   displacement=.5 + random.random() * .5,
                   freq=[1, random.randint(2, 5)],
                   octaves=1,
                   spline_order=interp.bicubic)
        ]
    },

    "teh-matrex-haz-u": {
        "layers": ["glyph-map", "bloom", "contrast", "lens", "crt"],
        "settings": lambda: {
            "contrast": 2.0,
            "glyph_map_colorize": True,
            "glyph_map_mask": random_member([
                random_member([mask.alphanum_binary, mask.alphanum_numeric, mask.alphanum_hex]),
                mask.truetype,
                mask.ideogram,
                mask.invaders_square,
                random_member([mask.fat_lcd, mask.fat_lcd_binary, mask.fat_lcd_numeric, mask.fat_lcd_hex]),
                mask.emoji,
            ]),
            "glyph_map_zoom": random.randint(4, 8),
        },
        "generator": lambda settings: {
            "freq": (random.randint(2, 3), random.randint(24, 48)),
            "hue_rotation": .4 + random.random() * .2,
            "hue_range": .25,
            "lattice_drift": 1,
            "mask": mask.dropout,
            "spline_order": interp.cosine,
        },
    },

    "tensor-tone": {
        "post": lambda settings: [
            Effect("glyph_map",
                   mask=mask.halftone,
                   colorize=coin_flip())
        ]
    },

    "tensorflower": {
        "layers": ["symmetry", "voronoi", "vortex", "bloom", "lens"],
        "settings": lambda: {
            "dist_metric": distance.euclidean,
            "palette_on": False,
            "voronoi_diagram_type": voronoi.range_regions,
            "voronoi_nth": 0,
            "voronoi_point_corners": True,
            "voronoi_point_distrib": point.square,
            "voronoi_point_freq": 2,
            "vortex_range": random.randint(8, 25),
        },
        "generator": lambda settings: {
            "color_space": color.rgb,
        },
    },

    "terra-terribili": {
        "layers": ["multires-ridged", "shadow", "lens"],
        "settings": lambda: {
            "palette_on": True
        },
        "generator": lambda settings: {
            "hue_range": .5 + random.random() * .5,
            "lattice_drift": 1.0,
        },
    },

    "test-pattern": {
        "layers": ["posterize", "swerve-h", "pixel-sort", "snow", "be-kind-rewind", "lens"],
        "settings": lambda: {
            "pixel_sort_angled": False,
            "pixel_sort_darkest": False,
            "posterize_levels": random.randint(2, 4),
            "vignette_alpha": .05 + random.random() * .025,
        },
        "generator": lambda settings: {
            "brightness_distrib": distrib.ones,
            "distrib": random_member([m for m in distrib if distrib.is_center_distance(m) or distrib.is_scan(m)]),
            "freq": 1,
            "hue_range": .25 + random.random() * 1.25,
            "saturation_distrib": distrib.ones,
        },
    },

    "the-arecibo-response": {
        "layers": ["value-mask", "snow", "crt"],
        "settings": lambda: {
        },
        "generator": lambda settings: {
            "freq": random.randint(42, 210),
            "mask": mask.arecibo,
        },
    },

    "the-data-must-flow": {
        "layers": ["worms", "derivative-post", "brightness", "contrast", "glowing-edges", "bloom", "lens"],
        "settings": lambda: {
            "contrast": 2.0,
            "worms_alpha": .95 + random.random() * .125,
            "worms_behavior": worms.obedient,
            "worms_density": 2.0 + random.random(),
            "worms_duration": 1,
            "worms_stride": 8,
            "worms_stride_deviation": 6,
        },
        "generator": lambda settings: {
            "color_space": color.rgb,
            "freq": [3, 1],
        },
    },

    "the-inward-spiral": {
        "layers": ["voronoi", "worms", "brightness", "contrast", "bloom", "lens"],
        "settings": lambda: {
            "dist_metric": random_member(distance.all()),
            "voronoi_alpha": 1.0 - (random.randint(0, 1) * random.random() * .125),
            "voronoi_diagram_type": voronoi.color_range,
            "voronoi_nth": 0,
            "voronoi_point_freq": 1,
            "worms_alpha": 1,
            "worms_behavior": random_member([worms.obedient, worms.unruly, worms.crosshatch]),
            "worms_duration": random.randint(1, 4),
            "worms_density": 500,
            "worms_kink": random.randint(6, 24),
        },
        "generator": lambda settings: {
            "freq": random.randint(12, 24),
        },
    },

    "time-crystal": {
        "layers": ["periodic-distance", "reflect-post", "saturation", "dither", "crt"],
        "settings": lambda: {
            "reflect_range": 2.0 + random.random(),
        },
        "generator": lambda settings: {
            "distrib": random_member([distrib.center_triangle, distrib.center_hexagon]),
            "hue_range": 2.0 + random.random(),
            "freq": 1,
        }
    },

    "time-doughnuts": {
        "layers": ["periodic-distance", "funhouse", "posterize", "saturation", "dither", "scanline-error", "crt"],
        "settings": lambda: {
            "posterize_levels": 2,
            "speed": .05,
            "warp_octaves": 2,
            "warp_range": .1 + random.random() * .05,
            "warp_signed_range": True,
        },
        "generator": lambda settings: {
            "distrib": distrib.center_circle,
            "freq": random.randint(2, 3)
        }
    },

    "timeworms": {
        "layers": ["reflect-octaves", "worms", "density-map", "bloom", "lens"],
        "settings": lambda: {
            "reflect_range": random.randint(0, 1) * random.random() * 2,
            "worms_alpha": 1,
            "worms_behavior": worms.obedient,
            "worms_density": .25,
            "worms_duration": 10,
            "worms_stride": 2,
            "worms_kink": .25 + random.random() * 2.5,
        },
        "generator": lambda settings: {
            "freq": random.randint(4, 18),
            "saturation": 0,
            "mask": mask.sparse,
            "mask_static": True,
            "octaves": random.randint(1, 3),
            "spline_order": random_member([m for m in interp if m != interp.bicubic]),
        },
    },

    "tint": {
        "settings": lambda: {
            "tint_alpha": .25 + random.random() * .125
        },
        "post": lambda settings: [Effect("tint", alpha=settings["tint_alpha"])]
    },

    "trench-run": {
        "layers": ["periodic-distance", "posterize", "sobel", "invert", "scanline-error", "crt"],
        "settings": lambda: {
            "posterize_levels": 1,
            "speed": 1.0,
        },
        "generator": lambda settings: {
            "distrib": distrib.center_square,
            "hue_range": .1,
            "hue_rotation": random.random(),
        },
    },

    "tri-hard": {
        "layers": ["voronoi", "posterize-outline", "rotate", "lens"],
        "settings": lambda: {
            "dist_metric": random_member([distance.octagram, distance.triangular, distance.hexagram]),
            "posterize_levels": 6,
            "voronoi_alpha": .333 + random.random() * .333,
            "voronoi_diagram_type": voronoi.color_range,
            "voronoi_point_freq": random.randint(8, 10),
            "voronoi_refract": .333 + random.random() * .333,
            "voronoi_refract_y_from_offset": False,
        },
        "generator": lambda settings: {
            "hue_range": .125 + random.random(),
        },
    },

    "tribbles": {
        "layers": ["voronoi", "funhouse", "normalize", "invert", "worms", "rotate", "lens"],
        "settings": lambda: {
            "dist_metric": distance.euclidean,
            "voronoi_alpha": 0.5 + random.random() * .25,
            "voronoi_diagram_type": voronoi.range_regions,
            "voronoi_point_distrib": point.h_hex,
            "voronoi_point_drift": .25,
            "voronoi_point_freq": random.randint(2, 3) * 2,
            "voronoi_nth": 0,
            "warp_freq": random.randint(2, 4),
            "warp_octaves": random.randint(2, 4),
            "warp_range": 0.025 + random.random() * .005,
            "worms_alpha": .75 + random.random() * .25,
            "worms_behavior": worms.unruly,
            "worms_density": 750,
            "worms_drunkenness": random.random() * .125,
            "worms_duration": 1.0,
            "worms_kink": 1.0,
            "worms_stride": .5,
            "worms_stride_deviation": .5,
        },
        "generator": lambda settings: {
            "freq": [settings["voronoi_point_freq"]] * 2,
            "hue_range": 0.25 + random.random() * 2.5,
            "saturation": .375 + random.random() * .15,
            "ridges": True,
        },
    },

    "trominos": {
        "layers": ["value-mask", "posterize", "sobel", "rotate", "invert", "bloom", "crt", "lens"],
        "settings": lambda: {
            "mask": mask.tromino,
            "mask_repeat": random.randint(6, 12),
            "posterize_levels": random.randint(1, 2),
        },
        "generator": lambda settings: {
            "spline_order": random_member([interp.constant, interp.cosine]),
        },
    },

    "truchet-maze": {
        "layers": ["value-mask", "posterize", "rotate", "bloom", "lens"],
        "settings": lambda: {
            "angle": random_member([0, 45, random.randint(0, 360)]),
            "mask": random_member([mask.truchet_lines, mask.truchet_curves]),
            "mask_repeat": random.randint(15, 25),
            "posterize_levels": 1,
        },
    },

    "truffula-spore": {
        "layers": ["multires-alpha", "worms", "lens"],
        "settings": lambda: {
            "palette_on": False,
            "worms_alpha": .5,
            "worms_behavior": worms.unruly,
        },
        "generator": lambda settings: {
            "hue_range": 1.0 + random.random() * .5,
            "distrib": distrib.exp,
            "octaves": 8,
        }
    },

    "turbulence": {
        "layers": ["basic-water", "periodic-refract", "refract-post", "lens", "contrast"],
        "settings": lambda: {
            "refract_range": .025 + random.random() * .0125,
            "refract_y_from_offset": False,
            "value_distrib": distrib.center_circle,
            "value_freq": 1,
            "value_refract_range": .05 + random.random() * .025,
            "speed": -.05,
        },
        "generator": lambda settings: {
            "freq": random.randint(2, 3),
            "hue_range": 2.0,
            "hue_rotation": random.random(),
            "octaves": 3,
        }
    },

    "twisted": {
        "layers": ["worms"],
        "settings": lambda: {
            "worms_density": random.randint(125, 250),
            "worms_duration": 1.0 + random.random() * 0.5,
            "worms_quantize": True,
            "worms_stride": 1.0,
            "worms_stride_deviation": 0.5,
        },
        "generator": lambda settings: {
            "freq": random.randint(6, 12),
            "hue_range": 0.0,
            "ridges": True,
            "saturation": 0.0,
        }
    },

    "unicorn-puddle": {
        "layers": ["multires", "reflect-octaves", "refract-post", "random-hue", "bloom", "lens"],
        "settings": lambda: {
            "palette_on": False,
            "reflect_range": .5 + random.random() * .25,
            "refract_range": .5 + random.random() * .25,
        },
        "generator": lambda settings: {
            "color_space": color.oklab,
            "distrib": distrib.uniform,
            "freq": 2,
            "hue_range": 2.0 + random.random(),
            "lattice_drift": 1.0,
        },
    },

    "unmasked": {
        "layers": ["sobel", "invert", "reindex-octaves", "rotate", "bloom", "lens"],
        "settings": lambda: {
            "reindex_range": 1 + random.random() * 1.5,
        },
        "generator": lambda settings: {
            "distrib": distrib.uniform,
            "freq": random.randint(3, 5),
            "mask": random_member(mask.procedural_members()),
            "octave_blending": blend.alpha,
            "octaves": random.randint(2, 4),
        },
    },

    "value-mask": {
        "settings": lambda: {
            "mask": random_member(mask),
            "mask_repeat": random.randint(2, 8)
        },
        "generator": lambda settings: {
            "distrib": distrib.ones,
            "freq": [int(i * settings["mask_repeat"]) for i in masks.mask_shape(settings["mask"])[0:2]],
            "mask": settings["mask"],
            "spline_order": random_member([m for m in interp if m != interp.bicubic])
        },
    },

    "value-refract": {
        "settings": lambda: {
            "value_freq": random.randint(2, 4),
            "value_refract_range": .125 + random.random() * .06125,
        },
        "post": lambda settings: [
            Effect("value_refract",
                   displacement=settings["value_refract_range"],
                   distrib=settings.get("value_distrib", distrib.uniform),
                   freq=settings["value_freq"])
        ]
    },

    "vaseline": {
        "settings": lambda: {
            "vaseline_alpha": .375 + random.random() * .1875
        },
        "post": lambda settings: [Effect("vaseline", alpha=settings["vaseline_alpha"])]
    },

    "vectoroids": {
        "layers": ["voronoi", "derivative-post", "glowing-edges", "bloom", "crt", "lens"],
        "settings": lambda: {
            "dist_metric": distance.euclidean,
            "voronoi_diagram_type": voronoi.color_regions,
            "voronoi_nth": 0,
            "voronoi_point_freq": 15,
            "voronoi_point_drift": .25 + random.random() * .75,
        },
        "generator": lambda settings: {
            "freq": 40,
            "distrib": distrib.ones,
            "mask": mask.sparse,
            "mask_static": True,
            "spline_order": interp.constant,
        },
    },

    "veil": {
        "layers": ["voronoi", "fractal-seed"],
        "settings": lambda: {
            "dist_metric": random_member([distance.manhattan, distance.octagram, distance.triangular]),
            "voronoi_diagram_type": random_member([voronoi.color_range, voronoi.range]),
            "voronoi_inverse": True,
            "voronoi_point_distrib": random_member(point.grid_members()),
            "voronoi_point_freq": random.randint(2, 3),
            "worms_behavior": worms.random,
            "worms_kink": .5 + random.random(),
            "worms_stride": random.randint(48, 96),
        },
    },

    "vibe": {
        "layers": ["reflect-post", "lens"],
        "settings": lambda: {
            "reflect_range": 1.0 + random.random() * .5,
        },
        "generator": lambda settings: {
            "brightness_distrib": None,
            "hue_range": .75 + random.random() * .75,
        },
    },

    "vignette-bright": {
        "settings": lambda: {
            "vignette_alpha": .333 + random.random() * .333,
            "vignette_brightness": 1.0,
        },
        "post": lambda settings: [
            Effect("vignette",
                   alpha=settings["vignette_alpha"],
                   brightness=settings["vignette_brightness"])
        ]
    },

    "vignette-dark": {
        "settings": lambda: {
            "vignette_alpha": .5 + random.random() * .25,
            "vignette_brightness": 0.0,
        },
        "post": lambda settings: [
            Effect("vignette",
                   alpha=settings["vignette_alpha"],
                   brightness=settings["vignette_brightness"])
        ]
    },

    "voronoi": {
        "settings": lambda: {
            "dist_metric": random_member(distance.all()),
            "voronoi_alpha": 1.0,
            "voronoi_diagram_type": random_member([t for t in voronoi if t != voronoi.none]),
            "voronoi_sdf_sides": random.randint(1, 4) * 2 + 1,
            "voronoi_inverse": False,
            "voronoi_nth": random.randint(0, 2),
            "voronoi_point_corners": False,
            "voronoi_point_distrib": point.random if coin_flip() else random_member(point, mask.nonprocedural_members()),
            "voronoi_point_drift": 0.0,
            "voronoi_point_freq": random.randint(4, 10),
            "voronoi_point_generations": 1,
            "voronoi_refract": 0,
            "voronoi_refract_y_from_offset": True,
        },
        "post": lambda settings: [
            Effect("voronoi",
                   alpha=settings["voronoi_alpha"],
                   diagram_type=settings["voronoi_diagram_type"],
                   dist_metric=settings["dist_metric"],
                   inverse=settings["voronoi_inverse"],
                   nth=settings["voronoi_nth"],
                   point_corners=settings["voronoi_point_corners"],
                   point_distrib=settings["voronoi_point_distrib"],
                   point_drift=settings["voronoi_point_drift"],
                   point_freq=settings["voronoi_point_freq"],
                   point_generations=settings["voronoi_point_generations"],
                   with_refract=settings["voronoi_refract"],
                   refract_y_from_offset=settings["voronoi_refract_y_from_offset"],
                   sdf_sides=settings["voronoi_sdf_sides"])
        ]
    },

    "voronoi-refract": {
        "layers": ["voronoi"],
        "settings": lambda: {
            "voronoi_refract": .25 + random.random() * .25
        }
    },

    "vortex": {
        "settings": lambda: {
            "vortex_range": random.randint(16, 48)
        },
        "post": lambda settings: [Effect("vortex", displacement=settings["vortex_range"])]
    },

    "warped-cells": {
        "layers": ["voronoi", "ridge", "funhouse", "bloom", "dither", "lens"],
        "settings": lambda: {
            "dist_metric": random_member(distance.absolute_members()),
            "voronoi_alpha": .333 + random.random() * .333,
            "voronoi_diagram_type": voronoi.color_range,
            "voronoi_nth": 0,
            "voronoi_point_distrib": random_member(point, mask.nonprocedural_members()),
            "voronoi_point_freq": random.randint(6, 10),
            "warp_range": .25 + random.random() * .25,
        },
    },

    "what-do-they-want": {
        "layers": ["value-mask", "sobel", "invert", "skew", "bloom", "lens"],
        "settings": lambda: {
            "dist_metric": distance.triangular,
            "mask": random_member([mask.invaders_square, mask.matrix]),
            "mask_repeat": random.randint(4, 6),
        },
        "generator": lambda settings: {
            "corners": True,
            "distrib": distrib.ones,
            "octave_blending": blend.alpha,
            "octaves": 2,
        },
    },

    "whatami": {
        "layers": ["voronoi", "reindex-octaves", "reindex-post", "lens"],
        "settings": lambda: {
            "reindex_range": 2,
            "voronoi_alpha": .75 + random.random() * .125,
            "voronoi_diagram_type": voronoi.color_range,
        },
        "generator": lambda settings: {
            "freq": random.randint(7, 9),
            "hue_range": 3,
        },
    },

    "wild-kingdom": {
        "layers": ["funhouse", "posterize-outline", "shadow", "maybe-invert", "dither", "nudge-hue", "lens"],
        "settings": lambda: {
            "posterize_levels": 3,
            "vaseline_alpha": .1 + random.random() * .05,
            "vignette_alpha": .1 + random.random() * .05,
            "warp_octaves": 3,
            "warp_range": .0333,
        },
        "generator": lambda settings: {
            "color_space": color.rgb,
            "freq": 20,
            "lattice_drift": 0.333,
            "mask": mask.sparse,
            "mask_static": True,
            "ridges": True,
            "spline_order": interp.cosine,
        },
    },

    "woahdude": {
        "layers": ["wobble", "voronoi", "sine-octaves", "refract-post", "bloom", "saturation", "lens"],
        "settings": lambda: {
            "dist_metric": distance.euclidean,
            "refract_range": .0005 + random.random() * .00025,
            "saturation": 1.5,
            "sine_range": random.randint(40, 60),
            "speed": .025,
            "tint_alpha": .05 + random.random() * .025,
            "voronoi_refract": .333 + random.random() * .333,
            "voronoi_diagram_type": voronoi.range,
            "voronoi_nth": 0,
            "voronoi_point_distrib": random_member(point.circular_members()),
            "voronoi_point_freq": 6,
        },
        "generator": lambda settings: {
            "freq": random.randint(3, 5),
            "hue_range": 2,
            "lattice_drift": 1,
        },
    },

    "wobble": {
        "post": lambda settings: [Effect("wobble")]
    },

    "wormhole": {
        "settings": lambda: {
            "wormhole_kink": 1.0 + random.random() * .5,
            "wormhole_stride": .05 + random.random() * .025
        },
        "post": lambda settings: [
            Effect("wormhole",
                   kink=settings["wormhole_kink"],
                   input_stride=settings["wormhole_stride"])
        ]
    },

    "worms": {
        "settings": lambda: {
            "worms_alpha": .75 + random.random() * .25,
            "worms_behavior": random_member(worms.all()),
            "worms_density": random.randint(250, 500),
            "worms_drunkenness": 0.0,
            "worms_duration": 1.0 + random.random() * .5,
            "worms_kink": 1.0 + random.random() * .5,
            "worms_quantize": False,
            "worms_stride": .75 + random.random() * .5,
            "worms_stride_deviation": random.random() + .5
        },
        "post": lambda settings: [
            Effect("worms",
                   alpha=settings["worms_alpha"],
                   behavior=settings["worms_behavior"],
                   density=settings["worms_density"],
                   drunkenness=settings["worms_drunkenness"],
                   duration=settings["worms_duration"],
                   kink=settings["worms_kink"],
                   quantize=settings["worms_quantize"],
                   stride=settings["worms_stride"],
                   stride_deviation=settings["worms_stride_deviation"])
        ]
    },

    "wormstep": {
        "layers": ["worms"],
        "settings": lambda: {
            "palette_name": None,
            "worms_alpha": .5 + random.random() * .5,
            "worms_behavior": worms.chaotic,
            "worms_density": 500,
            "worms_kink": 1.0 + random.random() * 4.0,
            "worms_stride": 8.0 + random.random() * 4.0,
        },
        "generator": lambda settings: {
            "corners": True,
            "lattice_drift": coin_flip(),
            "octaves": random.randint(1, 3),
        },
    },

    "writhe": {
        "layers": ["multires-alpha", "octave-warp-octaves", "brightness", "shadow", "dither", "lens"],
        "settings": lambda: {
            "speed": .025,
            "warp_freq": [random.randint(2, 3), random.randint(2, 3)],
            "warp_range": 5.0 + random.random() * 2.5,
        },
        "generator": lambda settings: {
            "color_space": color.oklab,
            "ridges": True,
        },
    },
}

Preset = functools.partial(Preset, presets=PRESETS())
