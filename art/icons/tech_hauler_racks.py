"""Tech emblem: taller cargo racks, stacked full."""

import fl


def build():
    root = fl.root("tech_hauler_racks")
    body = fl.Part("body", root)
    body.box((3.0, 2.0, 0.25), (0, 0, 0.3), "graphite")
    for x in (-1.4, 1.4):
        for y in (-0.9, 0.9):
            body.box((0.14, 0.14, 3.2), (x, y, 1.9), "steel")
    for i, swatch in enumerate(("ceramic", "orange", "ceramic_shade")):
        body.box((2.5, 1.6, 0.8), (0, 0, 0.85 + i * 0.95), swatch)
        body.box((2.54, 0.3, 0.12), (0, -0.7, 0.85 + i * 0.95), "graphite")
    body.box((3.0, 2.0, 0.12), (0, 0, 3.5), "steel")
    body.box((0.5, 0.1, 0.3), (0, -0.82, 2.75), "glow_cyan")
    body.finish(bevel=0.04)
    return root
