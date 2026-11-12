"""Antecedent data cache: a sealed pod half buried in the dust."""

import fl


def build():
    root = fl.root("antecedent_site_cache")
    body = fl.Part("body", root)
    body.cyl(1.5, 0.3, (0, 0, 0.1), "stone_dark", segments=6, radius_top=1.3)
    body.cyl(1.0, 1.3, (0, 0, 0.85), "stone", segments=6, radius_top=0.7)
    body.cyl(0.74, 0.12, (0, 0, 1.56), "brass", segments=6)
    body.cyl(0.45, 0.5, (0, 0, 1.85), "stone", segments=6, radius_top=0.2)
    body.cyl(1.04, 0.14, (0, 0, 0.7), "brass", segments=6)
    for i in range(3):
        angle = fl.math.radians(120 * i + 30)
        body.box((0.12, 0.3, 0.8), (0.86 * fl.math.cos(angle), 0.86 * fl.math.sin(angle), 0.95),
                 "glow_white", rot=(0, 0, 120 * i + 30 + 90))
    body.finish(bevel=0.03)
    return root
