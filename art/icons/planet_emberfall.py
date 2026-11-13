"""Emblem for Emberfall: a dark volcanic world with glowing rifts."""

import fl


def build():
    root = fl.root("planet_emberfall")
    body = fl.Part("body", root)
    body.sphere(2.0, (0, 0, 2.2), "black", segments=24)
    body.cyl(2.02, 0.16, (0, 0, 2.6), "glow_orange", segments=24, radius_top=1.98)
    body.cyl(1.82, 0.12, (0, 0, 1.4), "glow_orange", segments=24, radius_top=1.9)
    body.cyl(1.4, 0.3, (0, 0, 3.6), "graphite", segments=24, radius_top=1.15)
    body.cyl(0.5, 0.2, (0, 0, 4.15), "glow_red", segments=12, radius_top=0.3)
    body.cyl(0.05, 1.3, (2.35, 0.3, 3.5), "steel", rot=(0, 50, 0), segments=6)
    body.sphere(0.26, (2.85, 0.3, 3.95), "orange", segments=8)
    body.finish(bevel=0.0)
    return root
