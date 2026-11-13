"""Antecedent artefact: a small sealed core in a stone cradle, light enough to carry."""

import math

import fl


def build():
    root = fl.root("antecedent_prop_artefact")
    cradle = fl.Part("body", root)
    cradle.cyl(0.62, 0.22, (0, 0, 0.11), "stone_dark", segments=8, radius_top=0.5)
    for i in range(4):
        angle = math.radians(45 + 90 * i)
        x, y = math.cos(angle) * 0.42, math.sin(angle) * 0.42
        cradle.box((0.16, 0.16, 0.7), (x, y, 0.5), "stone", rot=(-y * 30, x * 30, 0),
                   taper=(0.6, 0.6))
        cradle.box((0.1, 0.1, 0.12), (x * 0.86, y * 0.86, 0.86), "brass")
    cradle.finish(bevel=0.02)

    # The core turns slowly; the game spins this part.
    core = fl.Part("core", root, pivot=(0.0, 0.0, 0.62))
    core.sphere(0.3, (0, 0, 0.62), "glow_white", scale=(1, 1, 1.25), segments=10)
    core.cyl(0.36, 0.07, (0, 0, 0.62), "brass", segments=10)
    core.cyl(0.33, 0.05, (0, 0, 0.84), "brass", segments=10, radius_top=0.2)
    core.cyl(0.2, 0.05, (0, 0, 0.4), "brass", segments=10, radius_top=0.33)
    core.finish(bevel=0.01)
    return root
