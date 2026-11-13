"""Concord dropship: the extraction craft. Four tilting fans, a wide ramp aft.

Modelled sitting on its skids at the origin; the game flies it in and lands it.
Parts `fan_fl`, `fan_fr`, `fan_rl`, `fan_rr` spin about their vertical axis.
"""

import fl


def build():
    root = fl.root("concord_ship_dropship")
    body = fl.Part("body", root)
    # hull: a long box cabin with a glazed nose
    body.box((3.4, 8.0, 2.4), (0, 0, 2.2), "ceramic", taper=(0.85, 0.9))
    body.box((2.8, 2.4, 1.8), (0, -4.6, 2.0), "ceramic", rot=(8, 0, 0), taper=(0.6, 0.6))
    body.box((2.2, 1.6, 0.9), (0, -4.4, 2.9), "glass", rot=(-14, 0, 0), taper=(0.7, 0.6))
    body.box((3.5, 1.0, 2.5), (0, -1.6, 2.2), "orange")
    body.box((3.5, 0.7, 2.5), (0, 2.4, 2.2), "team")
    body.box((2.0, 5.0, 0.3), (0, 0.2, 3.5), "ceramic_shade")
    body.box((2.4, 4.6, 0.1), (0, 0.2, 0.96), "glow_cyan")
    # open ramp aft
    body.box((2.6, 3.0, 0.16), (0, 5.2, 0.7), "graphite", rot=(-16, 0, 0))
    body.box((2.4, 0.2, 1.7), (0, 4.0, 2.1), "glow_cyan")
    # tail fins
    for x in (-1.0, 1.0):
        body.box((0.14, 1.8, 1.6), (x * 1.5, 3.6, 3.9), "ceramic", rot=(0, x * 14, 0), taper=(1.0, 0.5))
        body.box((0.16, 0.6, 0.4), (x * 1.6, 3.8, 4.4), "team", rot=(0, x * 14, 0))
        # skids
        body.box((0.3, 6.0, 0.2), (x * 1.5, 0, 0.1), "graphite")
        body.box((0.2, 0.2, 1.0), (x * 1.5, -2.2, 0.6), "steel")
        body.box((0.2, 0.2, 1.0), (x * 1.5, 2.2, 0.6), "steel")
        # fan booms and rings
        for y in (-2.6, 2.6):
            body.box((2.6, 0.6, 0.3), (x * 2.9, y, 3.0), "ceramic")
            body.cyl(1.7, 0.5, (x * 4.6, y, 3.0), "ceramic", segments=16)
            body.cyl(1.74, 0.16, (x * 4.6, y, 2.9), "team", segments=16)
            body.cyl(1.5, 0.04, (x * 4.6, y, 3.27), "black", segments=16)
    body.sphere(0.14, (0, -5.9, 2.0), "glow_red", segments=8)
    body.finish(bevel=0.05)

    for name, x, y in (("fan_fl", -4.6, -2.6), ("fan_fr", 4.6, -2.6),
                       ("fan_rl", -4.6, 2.6), ("fan_rr", 4.6, 2.6)):
        fan = fl.Part(name, root, pivot=(x, y, 3.3))
        fan.cyl(0.26, 0.4, (x, y, 3.2), "steel", segments=8)
        for i in range(3):
            fan.box((2.8, 0.28, 0.04), (x, y, 3.32), "ceramic", rot=(8, 0, 60 * i))
        fan.finish(bevel=0.01)
    return root
