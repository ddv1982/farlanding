"""Rich Flux vent of Emberfall: a wide basalt throat, white-hot at the centre. Erupts."""

import random

import fl


def build():
    root = fl.root("emberfall_resource_flux_vent_rich")
    rng = random.Random(17)
    body = fl.Part("body", root)
    body.cyl(3.4, 0.5, (0, 0, 0.1), "black", segments=12, radius_top=2.5)
    body.cyl(1.9, 0.24, (0, 0, 0.4), "glow_orange", segments=12)
    body.cyl(1.0, 0.3, (0, 0, 0.44), "glow_white", segments=10)
    # a crown of basalt columns, tallest on one side
    for index in range(11):
        angle = index / 11.0 * 6.283 + rng.uniform(-0.15, 0.15)
        reach = rng.uniform(2.0, 2.5)
        tall = 0.7 + 1.5 * max(0.0, fl.math.cos(angle - 0.8)) + rng.uniform(0.0, 0.5)
        body.cyl(0.5, tall, (reach * fl.math.cos(angle), reach * fl.math.sin(angle), tall / 2.0),
                 "black" if index % 3 else "graphite",
                 rot=(rng.uniform(-10, 10), rng.uniform(-10, 10), rng.uniform(0, 60)),
                 segments=6, radius_top=0.4)
    # glowing cracks running out from the throat
    for index in range(5):
        angle = index / 5.0 * 6.283 + 0.4
        body.box((0.16, 1.5, 0.1), (2.9 * fl.math.cos(angle), 2.9 * fl.math.sin(angle), 0.3),
                 "glow_orange", rot=(0, 0, fl.math.degrees(angle) + 90))
    body.finish(bevel=0.0)
    return root
