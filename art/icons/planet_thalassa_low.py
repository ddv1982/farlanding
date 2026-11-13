"""Emblem for Thalassa Low: a tidal water world with pale shoals."""

import fl


def build():
    root = fl.root("planet_thalassa_low")
    body = fl.Part("body", root)
    body.sphere(2.0, (0, 0, 2.2), "glass", segments=24)
    body.cyl(2.03, 0.7, (0, 0, 2.2), "glow_cyan", segments=24, radius_top=2.03)
    body.cyl(2.04, 0.3, (0, 0, 2.2), "glass", segments=24, radius_top=2.04)
    body.cyl(1.6, 0.3, (0, 0, 3.4), "ceramic", segments=24, radius_top=1.3)
    body.cyl(1.2, 0.3, (0, 0, 0.75), "ceramic_shade", segments=24, radius_top=1.5)
    body.cyl(0.05, 1.3, (2.35, 0.3, 3.5), "steel", rot=(0, 50, 0), segments=6)
    body.sphere(0.26, (2.85, 0.3, 3.95), "orange", segments=8)
    body.finish(bevel=0.0)
    return root
