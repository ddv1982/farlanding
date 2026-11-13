"""Combine relay: an unmanned listening mast with a tilted dish, left running."""

import fl


def build():
    root = fl.root("combine_site_relay")
    body = fl.Part("body", root)
    body.cyl(1.5, 0.3, (0, 0, 0.15), "gunmetal", segments=6, radius_top=1.3)
    body.box((1.3, 1.0, 0.9), (0.2, 0.3, 0.75), "hull", taper=(0.85, 0.85))
    body.box((0.5, 0.06, 0.4), (0.2, -0.22, 0.8), "acid")
    body.box((0.6, 0.5, 0.5), (-0.75, -0.5, 0.55), "olive")
    body.cyl(0.2, 3.4, (0, 0, 2.0), "hull_light", segments=6, radius_top=0.12)
    body.cyl(0.3, 0.2, (0, 0, 1.3), "rust", segments=6)
    body.cyl(0.26, 0.16, (0, 0, 2.6), "rust", segments=6)
    for i in range(3):
        angle = fl.math.radians(90 + 120 * i)
        x, y = fl.math.cos(angle), fl.math.sin(angle)
        body.box((0.12, 0.12, 2.3), (x * 0.75, y * 0.75, 1.1), "gunmetal",
                 rot=(-y * 32, x * 32, 0))
        body.box((0.4, 0.4, 0.14), (x * 1.35, y * 1.35, 0.3), "hull_light")
    body.cyl(0.9, 0.16, (0, -0.35, 3.3), "hull_light", rot=(62, 0, 0), segments=8,
             radius_top=0.55)
    body.cyl(0.07, 0.7, (0, -0.6, 3.45), "gunmetal", rot=(62, 0, 0), segments=6)
    body.box((0.16, 0.16, 0.16), (0, -0.92, 3.62), "acid")
    body.box((0.14, 0.14, 0.3), (0, 0, 3.85), "acid")
    body.finish(bevel=0.03)
    return root
