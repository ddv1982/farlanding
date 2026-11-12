"""Flux vent: a glowing fissure. A Flux Tap is built on top of it."""

import random

import fl


def build():
    root = fl.root("kessel_resource_flux_vent")
    rng = random.Random(9)
    body = fl.Part("body", root)
    body.cyl(2.6, 0.35, (0, 0, 0.08), "kessel_rock", segments=10, radius_top=1.9)
    body.cyl(1.3, 0.2, (0, 0, 0.3), "glow_orange", segments=10)
    # broken rim of rock teeth around the glow
    for index in range(9):
        angle = index / 9.0 * 6.283 + rng.uniform(-0.2, 0.2)
        reach = rng.uniform(1.4, 1.8)
        body.cyl(0.55, rng.uniform(0.5, 1.2), (reach * fl.math.cos(angle), reach * fl.math.sin(angle), 0.45),
                 "kessel_rock" if index % 2 else "kessel_rock_pale",
                 rot=(rng.uniform(-20, 20), rng.uniform(-20, 20), rng.uniform(0, 90)),
                 segments=5, radius_top=0.2)
    body.finish(bevel=0.0)
    return root
