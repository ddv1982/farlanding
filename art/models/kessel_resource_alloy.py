"""Alloy deposit: an outcrop of metallic ore that Haulers mine."""

import random

import fl


def build():
    root = fl.root("kessel_resource_alloy")
    rng = random.Random(4)
    body = fl.Part("body", root)
    body.cyl(3.0, 0.5, (0, 0, 0.1), "kessel_rock", segments=9, radius_top=2.2)
    # leaning faceted ore shards, tallest in the middle
    for index in range(11):
        angle = rng.uniform(0, 6.283)
        reach = 0.0 if index == 0 else rng.uniform(0.6, 2.0)
        height = rng.uniform(1.0, 2.2) * (1.5 if index == 0 else 1.0) * (1.0 - reach * 0.22)
        width = rng.uniform(0.45, 0.8)
        x, y = reach * rng.uniform(0.9, 1.1) * fl.math.cos(angle), reach * fl.math.sin(angle)
        body.cyl(width, height, (x, y, height * 0.5 + 0.15), "copper" if index % 3 else "steel",
                 rot=(rng.uniform(-24, 24), rng.uniform(-24, 24), rng.uniform(0, 90)),
                 segments=5, radius_top=width * 0.25)
    for _ in range(6):
        angle = rng.uniform(0, 6.283)
        body.cyl(0.4, 0.45, (2.4 * fl.math.cos(angle), 2.4 * fl.math.sin(angle), 0.3),
                 "kessel_rock_pale", rot=(rng.uniform(-30, 30), 0, rng.uniform(0, 90)),
                 segments=5, radius_top=0.2)
    body.finish(bevel=0.0)
    return root
