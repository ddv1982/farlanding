"""Kessel geological site: a wind-cut stone arch with exposed mineral veins."""

import random

import fl


def build():
    root = fl.root("kessel_site_formation")
    rng = random.Random(33)
    body = fl.Part("body", root)
    body.cyl(5.0, 0.4, (0, 0, 0.1), "kessel_rock", segments=9, radius_top=4.2)
    # two leaning pillars joined by a slab: the arch
    body.cyl(1.5, 5.4, (-2.6, 0, 2.8), "kessel_rock", rot=(4, 12, 20), segments=6, radius_top=1.0)
    body.cyl(1.3, 4.8, (2.6, 0.3, 2.5), "kessel_rock_pale", rot=(-5, -14, 50), segments=6, radius_top=0.9)
    body.box((7.4, 1.9, 1.3), (0, 0.1, 5.5), "kessel_rock", rot=(3, 4, 6), taper=(0.9, 0.8))
    body.box((3.0, 1.5, 0.7), (0.4, 0.1, 6.3), "kessel_rock_pale", rot=(0, -6, 12), taper=(0.7, 0.7))
    # mineral veins: copper seams and a glowing core at the foot
    body.box((0.25, 0.5, 3.6), (-2.2, -0.9, 2.6), "copper", rot=(4, 12, 0))
    body.box((0.25, 0.5, 2.8), (2.3, -0.7, 2.2), "copper", rot=(-5, -14, 0))
    body.cyl(0.7, 0.5, (0, -0.4, 0.5), "glow_orange", segments=6, radius_top=0.3)
    for _ in range(8):
        angle = rng.uniform(0, 6.283)
        reach = rng.uniform(2.6, 4.4)
        body.cyl(rng.uniform(0.4, 0.9), rng.uniform(0.5, 1.2),
                 (reach * fl.math.cos(angle), reach * fl.math.sin(angle), 0.5),
                 "kessel_rock" if rng.random() < 0.6 else "kessel_rock_pale",
                 rot=(rng.uniform(-25, 25), rng.uniform(-25, 25), rng.uniform(0, 90)),
                 segments=5, radius_top=0.2)
    body.finish(bevel=0.0)
    return root
