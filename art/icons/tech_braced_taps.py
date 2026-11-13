"""Tech emblem: a Flux Tap's column braced with heavy struts."""

import math

import fl


def build():
    root = fl.root("tech_braced_taps")
    body = fl.Part("body", root)
    body.cyl(1.7, 0.3, (0, 0, 0.15), "graphite", segments=8)
    body.cyl(0.8, 2.6, (0, 0, 1.6), "ceramic", segments=8, radius_top=0.6)
    body.cyl(0.84, 0.3, (0, 0, 2.2), "orange", segments=8)
    body.cyl(0.5, 0.4, (0, 0, 3.1), "glow_cyan", segments=8)
    for i in range(4):
        angle = math.radians(45 + 90 * i)
        x, y = math.cos(angle), math.sin(angle)
        body.box((0.26, 0.26, 2.6), (x * 1.05, y * 1.05, 1.3), "steel", rot=(-y * 28, x * 28, 0))
        body.box((0.6, 0.6, 0.2), (x * 1.6, y * 1.6, 0.35), "hazard")
    body.finish(bevel=0.04)
    return root
