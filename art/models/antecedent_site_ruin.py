"""Antecedent ruin: broken arches around a sunken dais. A site to scan."""

import random

import fl


def build():
    root = fl.root("antecedent_site_ruin")
    rng = random.Random(21)
    body = fl.Part("body", root)
    body.cyl(5.6, 0.4, (0, 0, 0.1), "stone_dark", segments=8, radius_top=5.2)
    body.cyl(2.4, 0.5, (0, 0, 0.45), "stone", segments=8, radius_top=2.0)
    body.cyl(1.2, 0.12, (0, 0, 0.75), "glow_white", segments=8)
    # ring of pillars, some broken, two joined by a lintel
    heights = []
    for i in range(8):
        angle = fl.math.radians(45 * i)
        x, y = 4.3 * fl.math.cos(angle), 4.3 * fl.math.sin(angle)
        height = rng.choice((4.4, 4.4, 2.2, 1.2, 3.4))
        heights.append(height)
        body.box((0.9, 0.9, height), (x, y, 0.3 + height / 2), "stone",
                 rot=(0, 0, 45 * i), taper=(0.82, 0.82))
        body.box((1.1, 1.1, 0.3), (x, y, 0.45), "stone_dark", rot=(0, 0, 45 * i))
        if height > 4.0:
            body.box((0.5, 0.5, 0.2), (x, y, 0.4 + height), "brass", rot=(0, 0, 45 * i))
    body.box((0.8, 3.9, 0.7), (4.0, 1.66, 4.9), "stone", rot=(0, 0, 22.5))
    # fallen blocks
    for _ in range(7):
        angle = rng.uniform(0, 6.283)
        reach = rng.uniform(2.6, 5.4)
        body.box((rng.uniform(0.6, 1.3), rng.uniform(0.6, 1.1), rng.uniform(0.4, 0.8)),
                 (reach * fl.math.cos(angle), reach * fl.math.sin(angle), 0.45),
                 "stone" if rng.random() < 0.6 else "stone_dark",
                 rot=(rng.uniform(-14, 14), rng.uniform(-14, 14), rng.uniform(0, 90)))
    body.finish(bevel=0.05)
    return root
