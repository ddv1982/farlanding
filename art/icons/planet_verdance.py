"""Emblem for Verdance: a green world wrapped in a broken canopy band."""

import fl


def build():
    root = fl.root("planet_verdance")
    body = fl.Part("body", root)
    body.sphere(2.0, (0, 0, 2.2), "olive", segments=24)
    body.cyl(2.04, 0.5, (0, 0, 2.5), "acid", segments=24, radius_top=1.94)
    body.cyl(1.72, 0.3, (0, 0, 1.2), "acid", segments=24, radius_top=1.86)
    body.cyl(1.3, 0.3, (0, 0, 3.7), "ceramic", segments=24, radius_top=1.0)
    body.cyl(0.05, 1.3, (2.35, 0.3, 3.5), "steel", rot=(0, 50, 0), segments=6)
    body.sphere(0.26, (2.85, 0.3, 3.95), "orange", segments=8)
    body.finish(bevel=0.0)
    return root
