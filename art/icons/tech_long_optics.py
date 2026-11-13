"""Tech emblem: a long-range optic on its mount."""

import fl


def build():
    root = fl.root("tech_long_optics")
    body = fl.Part("body", root)
    body.cyl(0.55, 2.6, (0, 0, 2.6), "ceramic", rot=(72, 0, 0), segments=12, radius_top=0.8)
    body.cyl(0.84, 0.3, (0, -1.2, 3.0), "orange", rot=(72, 0, 0), segments=12)
    body.cyl(0.7, 0.12, (0, -1.38, 3.06), "glow_cyan", rot=(72, 0, 0), segments=12)
    body.cyl(0.4, 0.5, (0, 1.4, 2.15), "graphite", rot=(72, 0, 0), segments=12)
    body.box((0.5, 0.5, 0.6), (0, 0.2, 1.9), "steel")
    for x, y in ((-0.9, -0.6), (0.9, -0.6), (0, 1.0)):
        body.box((0.14, 0.14, 2.0), (x * 0.55, 0.2 + y * 0.55, 0.9), "graphite",
                 rot=(-y * 22, x * 22, 0))
    body.cyl(0.25, 0.1, (0.6, -0.2, 3.3), "glow_red", segments=8)
    body.finish(bevel=0.03)
    return root
