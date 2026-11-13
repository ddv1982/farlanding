"""Tech emblem: engine bracing, an engine core held in a ceramic and steel frame."""

import fl


def build():
    root = fl.root("tech_engine_bracing")
    body = fl.Part("body", root)
    body.cyl(1.1, 2.6, (0, 0, 1.9), "stone", segments=8, radius_top=0.9)
    body.cyl(1.16, 0.2, (0, 0, 1.3), "brass", segments=8)
    body.sphere(0.6, (0, 0, 3.6), "glow_white", segments=10)
    body.cyl(2.2, 0.4, (0, 0, 0.2), "stone_dark", segments=8)
    for i in range(4):
        angle = fl.math.radians(90 * i + 45)
        x, y = 1.7 * fl.math.cos(angle), 1.7 * fl.math.sin(angle)
        body.box((0.36, 0.36, 3.4), (x, y, 1.9), "ceramic", rot=(0, 0, 90 * i + 45))
        body.box((0.4, 0.4, 0.3), (x, y, 2.8), "orange", rot=(0, 0, 90 * i + 45))
    body.cyl(1.9, 0.16, (0, 0, 3.5), "steel", segments=8)
    body.cyl(1.6, 0.2, (0, 0, 3.5), "black", segments=8)
    body.finish(bevel=0.03)
    return root
