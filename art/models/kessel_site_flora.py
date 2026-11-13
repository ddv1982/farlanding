"""Kessel biological site: a colony of dust-feeding stalks with glowing caps."""

import random

import fl


def build():
    root = fl.root("kessel_site_flora")
    rng = random.Random(8)
    body = fl.Part("body", root)
    body.cyl(3.6, 0.3, (0, 0, 0.08), "kessel_rock", segments=9, radius_top=3.0)
    for index in range(9):
        angle = rng.uniform(0, 6.283)
        reach = 0.0 if index == 0 else rng.uniform(0.8, 2.6)
        height = rng.uniform(1.4, 3.2) * (1.5 if index == 0 else 1.0)
        x, y = reach * fl.math.cos(angle), reach * fl.math.sin(angle)
        lean = (rng.uniform(-9, 9), rng.uniform(-9, 9), 0)
        body.cyl(0.16, height, (x, y, height * 0.5 + 0.15), "olive", rot=lean, segments=6,
                 radius_top=0.10)
        body.cyl(0.55, 0.3, (x, y, height + 0.2), "rust", rot=lean, segments=7, radius_top=0.2)
        body.cyl(0.38, 0.1, (x, y, height + 0.04), "acid", rot=lean, segments=7)
    for _ in range(6):
        angle = rng.uniform(0, 6.283)
        body.sphere(rng.uniform(0.18, 0.34),
                    (2.4 * fl.math.cos(angle), 2.4 * fl.math.sin(angle), 0.3), "acid", segments=8)
    body.finish(bevel=0.0)
    return root
