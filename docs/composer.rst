Noisemaker Composer
===================

Noisemaker Composer is a high-level interface for creating generative art with noise. The design is informed by lessons learned from the previous incarnation of presets in Noisemaker.

Composer Presets
----------------

"Composer" Presets expose Noisemaker's lower-level `generator <api.html#module-noisemaker.generators>`_ and `effect <api.html#module-noisemaker.effects>`_ APIs, and are modeled using terse syntax which can be finely tailored per-preset. The intent behind this design was to provide a compact and maintainable interface which answers five key questions for each preset:

1) Which presets are being built on?
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Effects and presets are intended to be combined with and riff off each other, but repetition in code is distateful, especially when we have to copy settings around. To minimize copied settings, Composer Presets may "layer" parent presets, and/or refer to other presets inline.

Layering in this way means inheriting from those presets as a starting point, without needing to copy-paste everything in. A preset with no layers defined will be starting from a blank slate, with all default generator parameters and no effects.

The lineage of ancestor presets is modeled in each preset's ``layers`` list, which is a flat list of preset names. The presets should be listed in the order to be applied.

.. code-block:: python

    PRESETS = lambda: {
        "just-an-example": {
            # A list of parent preset names, if any:
            "layers": ["first-parent", "second-parent", ...]
        },

        # ...
    }

2) What are the meaningful variables?
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Each preset may need to reuse values, or tweak a value which was already set by a parent. To facilitate this, presets have an optional bank of settings which may be plugged in and overridden as needed.

Reusable settings are modeled in each preset's ``settings`` dictionary. Layering inherits this dictionary, allowing preset authors to override or add key/value pairs. This is a free-form dictionary, and authors may stash any arbitrary values they need here.

.. code-block:: python

    # The whole dictionary is wrapped in a lambda to ensure deterministic results when the
    # random number generator seed is changed.
    PRESETS = lambda: {
        "just-an-example": {
            # "settings" is a free-form dictionary of global args which may be
            # referenced throughout the preset and its descendants.
            "settings": lambda: {
                "your-special-variable": random.random(),
                "another-special-variable": random.randint(2, 4),
                # ...
            }
        },

        # ...
    }

3) What are the noise generation parameters?
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Noisemaker's noise generator has several parameters, and these simply need to live somewhere. Noise generator parameters are modeled in each preset's ``generator`` dictionary. Generator parameters may be defined in this dictionary, or can be fed in from settings. Just as with ``settings``, layering inherits this dictionary, enabling preset authors to override or add key/value pairs. Unlike ``settings``, the keys found in this dictionary are not free-form, but must be valid parameters to `noisemaker.generators.multires <api.html#noisemaker.generators.multires>`_.

.. code-block:: python

    PRESETS = lambda: {
        "just-an-example": {
            # A strictly validated dictionary of keyword args to send to
            # noisemaker.generators.multires():
            "generator": lambda settings: {
                "freq": settings["base_freq"],
                "octaves": random.randint(4, 8),
                "ridges": True,
                # ...
            },

        },

        # ...
    }

4) Which effects should be applied to each octave?
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Preset authors should be able to specify a list of effects which get applied to each octave of noise. Historically, the per-octave effects in Noisemaker were constrained by hard-coded logic. In Composer Presets, authors may specify an arbitrary list of effects.

Per-octave effects are modeled in each preset's ``octaves`` list, which specifies parameterized effects functions. Per-octave effect parameters may be defined in this list, or can be fed in from settings. Layering inherits this list, allowing authors to append additional effects. Effects should be listed in the order to be applied.

.. code-block:: python

    PRESETS = lambda: {
        "just-an-example": {
            # A list of per-octave effects, to apply in order:
            "octaves": lambda settings: [
                Effect("your-effect-name", **args),  # Effect() returns a callable
                                                     # effect function
                # ...
            ],

        },

        # ...
    }

5) Which effects should be applied after flattening layers?
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Similar to how per-octave effects were originally implemented, post effects in Noisemaker were hard-coded and inflexible. Composer Presets aim to break this pattern by enabling preset authors to specify an ordered list of "final pass" effects.

Post-reduce effects are modeled in each preset's ``post`` section, which is a flat list of parameterized effects functions and presets. Post-processing effect parameters may be defined in this list, or can be fed in from settings. Layering inherits this list, allowing authors to append additional effects and inline presets. A preset's post-processing list can contain effects as well as links to other presets, enabling powerful expression of nested macros. Effects and referenced presets should be listed in the order to be applied.

.. code-block:: python

    PRESETS = lambda: {
        "just-an-example": {
            # A list of post-reduce effects, to apply in order:
            "post": lambda settings: [
                Effect("your-other-effect-name", **args),
                Effect("your-other-effect-name-2", **args),
                Preset("another-preset-entirely")  # Unroll the "post" steps from
                                                   # another preset entirely
                # ...
            ]
        },

        # ...
    }

Putting It All Together
-----------------------

The following contrived example illustrates a preset containing each of the above described sections. For concrete examples, see noisemaker/presets.py and test/test_composer.py.

Note that ``settings``, ``generator``, ``octaves``, and ``post`` are wrapped inside ``lambda``. This enables re-evaluation of presets if/when the random number generator seed is changed.

.. code-block:: python

    PRESETS = lambda: {
        "just-an-example": {
            # A list of parent preset names, if any:
            "layers": ["first-parent", "second-parent", ...],

            # A free-form dictionary of global args which may be referenced throughout
            # the preset and its descendants:
            "settings": lambda: {
                "your-special-variable": random.random(),
                "another-special-variable": random.randint(2, 4),
                # ...
            },

            # A strictly validated dictionary of keyword args to send to
            # noisemaker.generators.multires():
            "generator": lambda settings: {
                "freq": settings["base_freq"],
                "octaves": random.randint(4, 8),
                "ridges": True,
                # ...
            },

            # A list of per-octave effects, to apply in order:
            "octaves": lambda settings: [
                Effect("your-effect-name", **args),  # Effect() returns a callable
                                                     # effect function
                # ...
            ],

            # A list of post-reduce effects, to apply in order:
            "post": lambda settings: [
                Effect("your-other-effect-name", **args),
                Effect("your-other-effect-name-2", **args),
                Preset("another-preset-entirely")  # Unroll the "post" steps from
                                                   # another preset entirely
                # ...
            ]
        },

        # ...
    }
