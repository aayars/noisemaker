import json
import random

import click
import tensorflow as tf

from noisemaker.util import save, load

import noisemaker.constants as constants
import noisemaker.effects as effects
import noisemaker.generators as generators
import noisemaker.presets as presets
import noisemaker.recipes as recipes

SMALL_X = 512
SMALL_Y = 256

LARGE_X = 1024
LARGE_Y = 512

FREQ = 3
SATURATION = .333
OCTAVES = 8

CONTROL_FILENAME = "worldmaker/control.png"
LOW_FILENAME = "worldmaker/lowland.png"
MID_FILENAME = "worldmaker/midland.png"
HIGH_FILENAME = "worldmaker/highland.png"

BLENDED_FILENAME = "worldmaker/blended.png"

FINAL_FILENAME = "worldmaker/worldmaker.png"


presets.bake_presets(None)


@click.group()
def main():
    pass


@main.command()
def lowland():
    names = [
        'alien-terrain-multires',
        'alien-terrain-worms',
        'lowland',
    ]

    run_preset(presets.random_member(names), [LARGE_Y, LARGE_X, 3], LOW_FILENAME)


@main.command()
def midland():
    names = [
        'alien-terrain-multires',
        'alien-terrain-worms',
        'midland',
    ]

    run_preset(presets.random_member(names), [LARGE_Y, LARGE_X, 3], MID_FILENAME)


@main.command()
def highland():
    names = [
        'alien-terrain-multires',
        'alien-terrain-worms',
        'highland',
        'pluto',
    ]

    run_preset(presets.random_member(names), [LARGE_Y, LARGE_X, 3], HIGH_FILENAME)


@main.command("control")
def _control():
    shape = [SMALL_Y, SMALL_X, 1]

    control = generators.multires(shape=shape, freq=FREQ, octaves=OCTAVES, refract_range=.5)

    erode_kwargs = {
        "alpha": .025,
        "density": 40,
        "iterations": 20,
        "inverse": True,
    }

    iterations = 5
    for i in range(iterations):
        control = effects.erode(control, shape, **erode_kwargs)
        control = effects.convolve(constants.ValueMask.conv2d_blur, control, shape)

    post_shape = [LARGE_Y, LARGE_X, 1]
    control = effects.resample(control, post_shape)

    iterations = 2
    for i in range(iterations):
        control = effects.erode(control, post_shape, **erode_kwargs)
        control = effects.convolve(constants.ValueMask.conv2d_blur, control, post_shape)

    control = effects.convolve(constants.ValueMask.conv2d_sharpen, control, post_shape)
    control = effects.normalize(control)

    with tf.compat.v1.Session().as_default():
        save(control, CONTROL_FILENAME)


@main.command()
def blended():
    shape = [LARGE_Y, LARGE_X, 3]

    erode_kwargs = {
        "alpha": .025,
        "density": 250,
        "iterations": 50,
        "inverse": True,
    }

    control = tf.image.convert_image_dtype(load(CONTROL_FILENAME), tf.float32)

    water = tf.ones(shape) * tf.stack([.05, .175, .625])
    water = effects.blend(water, water + control, .125)

    low = tf.image.convert_image_dtype(load(LOW_FILENAME), tf.float32)
    mid = tf.image.convert_image_dtype(load(MID_FILENAME), tf.float32)
    high = tf.image.convert_image_dtype(load(HIGH_FILENAME), tf.float32)

    # blend_control = generators.multires(shape=shape, freq=FREQ * 4, ridges=True, octaves=4)
    # blend_control = 1.0 - effects.value_map(blend_control, shape, keep_dims=True) * .5

    combined_land = effects.blend_layers(control, shape, 1.0, low, low, mid, high)
    combined_land = effects.erode(combined_land, shape, xy_blend=.5, **erode_kwargs)
    combined_land = tf.image.adjust_brightness(combined_land, .15)
    combined_land = tf.image.adjust_contrast(combined_land, 1.5)
    combined_land = effects.erode(combined_land, shape, **erode_kwargs)

    combined_land_0 = effects.shadow(combined_land, shape, alpha=0.5)
    combined_land_1 = effects.shadow(combined_land, shape, alpha=0.5, reference=control)

    combined_land = effects.blend(combined_land_0, combined_land_1, .5)

    combined = effects.blend_layers(control, shape, .01, water, combined_land, combined_land, combined_land)
    combined = effects.blend(combined_land, combined, .625)

    combined = tf.image.adjust_contrast(combined, .75)
    combined = tf.image.adjust_saturation(combined, .625)

    with tf.compat.v1.Session().as_default():
        save(combined, BLENDED_FILENAME)


@main.command()
@click.argument('input_filename', default=BLENDED_FILENAME)
def clouds(input_filename):
    tensor = tf.image.convert_image_dtype(load(input_filename), tf.float32)

    run_preset("clouds", [LARGE_Y, LARGE_X, 3], FINAL_FILENAME, tensor=tensor)


def run_preset(preset_name, shape, filename, tensor=None):
    kwargs = presets.preset(preset_name)

    kwargs['shape'] = shape

    if 'freq' not in kwargs:
        kwargs['freq'] = 3

    if 'octaves' not in kwargs:
        kwargs['octaves'] = 1

    if 'ridges' not in kwargs:
        kwargs['ridges'] = False

    kwargs['post_brightness'] = .125

    if tensor is None:
        tensor = generators.multires(**kwargs)

    tensor = recipes.post_process(tensor, **kwargs)

    with tf.compat.v1.Session().as_default():
        save(tensor, filename)
