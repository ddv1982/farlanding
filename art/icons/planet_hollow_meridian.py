"""Emblem for Hollow Meridian: a built world, a dark shell split by a lit seam."""

import fl


def build():
    root = fl.root("planet_hollow_meridian")
    body = fl.Part("body", root)
    body.sphere(2.0, (0, 0, 2.2), "stone_dark", segments=24)
    body.cyl(2.03, 0.14, (0, 0, 2.2), "glow_white", segments=24)
    body.cyl(1.76, 0.1, (0, 0, 3.2), "brass", segments=24, radius_top=1.68)
    body.cyl(1.68, 0.1, (0, 0, 1.2), "brass", segments=24, radius_top=1.76)
    body.cyl(0.5, 0.3, (0, 0, 4.2), "brass", segments=8, radius_top=0.3)
    body.cyl(0.05, 1.3, (2.35, 0.3, 3.5), "steel", rot=(0, 50, 0), segments=6)
    body.sphere(0.26, (2.85, 0.3, 3.95), "orange", segments=8)
    body.finish(bevel=0.0)
    return root
