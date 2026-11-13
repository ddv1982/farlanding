"""Emblem for Kessel Reach: a banded dust world with a survey probe overhead."""

import fl


def build():
    root = fl.root("planet_kessel_reach")
    body = fl.Part("body", root)
    body.sphere(2.0, (0, 0, 2.2), "kessel_rock", segments=24)
    body.cyl(2.02, 0.5, (0, 0, 2.5), "kessel_rock_pale", segments=24, radius_top=1.94)
    body.cyl(1.74, 0.3, (0, 0, 1.25), "kessel_rock_pale", segments=24, radius_top=1.9)
    body.cyl(1.5, 0.22, (0, 0, 3.55), "kessel_rock_pale", segments=24, radius_top=1.3)
    body.cyl(0.05, 1.3, (2.35, 0.3, 3.5), "steel", rot=(0, 50, 0), segments=6)
    body.sphere(0.26, (2.85, 0.3, 3.95), "orange", segments=8)
    body.finish(bevel=0.0)
    return root
