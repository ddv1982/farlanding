"""Concord Reactor: supplies Power. Octagonal pad around a glowing core."""

import math

import fl


def build():
    root = fl.root("concord_building_reactor")
    body = fl.Part("body", root)
    body.cyl(3.4, 0.5, (0, 0, 0.25), "graphite", segments=8, radius_top=3.2)
    body.cyl(2.9, 1.3, (0, 0, 1.15), "ceramic", segments=8, radius_top=2.4)
    body.cyl(2.44, 0.3, (0, 0, 1.9), "orange", segments=8, radius_top=2.36)
    # containment core with glowing bands
    body.cyl(1.25, 3.4, (0, 0, 3.5), "ceramic_shade", segments=12)
    for z in (2.5, 3.5, 4.5):
        body.cyl(1.32, 0.34, (0, 0, z), "glow_cyan", segments=12)
    body.cyl(1.5, 0.4, (0, 0, 5.35), "ceramic", segments=12, radius_top=1.1)
    body.cyl(0.75, 0.12, (0, 0, 5.6), "team", segments=12)
    # four cooling fins with team panels, pipes between them
    for i in range(4):
        angle = math.radians(45 + 90 * i)
        cx, cy = math.cos(angle), math.sin(angle)
        deg = math.degrees(angle)
        body.box((2.0, 0.34, 2.6), (cx * 2.0, cy * 2.0, 2.9), "ceramic", rot=(0, 0, deg),
                 taper=(0.55, 1.0))
        body.box((1.0, 0.40, 0.7), (cx * 2.5, cy * 2.5, 2.2), "team", rot=(0, 0, deg))
        side = math.radians(90 * i)
        sx, sy = math.cos(side), math.sin(side)
        body.cyl(0.2, 1.7, (sx * 1.9, sy * 1.9, 2.4), "copper", segments=8)
        body.box((0.7, 0.7, 0.5), (sx * 2.7, sy * 2.7, 0.75), "graphite", rot=(0, 0, math.degrees(side)))
    body.finish(bevel=0.06)
    return root
