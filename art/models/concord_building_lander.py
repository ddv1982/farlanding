"""Concord Lander: the dropship that lands and becomes the expedition HQ."""

import math

import fl


def build():
    root = fl.root("concord_building_lander")

    hull = fl.Part("body", root)
    # landing skirt and octagonal main hull
    hull.cyl(5.2, 0.5, (0, 0, 1.45), "graphite", segments=8, radius_top=4.9)
    hull.cyl(5.0, 2.6, (0, 0, 2.9), "ceramic", segments=8, radius_top=4.3)
    hull.cyl(4.34, 0.5, (0, 0, 4.3), "orange", segments=8, radius_top=4.1)
    hull.cyl(4.0, 1.6, (0, 0, 5.2), "ceramic", segments=8, radius_top=3.0)
    hull.cyl(3.04, 0.3, (0, 0, 6.1), "team", segments=8, radius_top=2.9)
    # command tower
    hull.cyl(2.0, 2.2, (0, 0.6, 7.2), "ceramic_shade", segments=8, radius_top=1.6)
    hull.cyl(1.72, 0.5, (0, 0.6, 7.7), "glow_cyan", segments=8, radius_top=1.66)
    hull.cyl(1.5, 0.5, (0, 0.6, 8.5), "ceramic", segments=8, radius_top=1.0)
    hull.cyl(0.08, 2.6, (0.5, 0.9, 9.9), "steel", segments=6)
    hull.cyl(0.05, 1.6, (-0.6, 0.4, 9.4), "steel", segments=6)
    hull.sphere(0.14, (0.5, 0.9, 11.2), "glow_red", segments=8)
    # bay door, ramp and lit doorway facing forward (-Y)
    hull.box((3.0, 0.5, 2.2), (0, -4.55, 2.5), "ceramic_shade")
    hull.box((2.2, 0.3, 1.7), (0, -4.75, 2.3), "glow_cyan")
    hull.box((2.6, 3.6, 0.25), (0, -6.1, 0.72), "graphite", rot=(-22, 0, 0))
    hull.box((0.5, 3.4, 0.12), (-0.8, -6.1, 0.88), "hazard", rot=(-22, 0, 0))
    hull.box((0.5, 3.4, 0.12), (0.8, -6.1, 0.88), "hazard", rot=(-22, 0, 0))
    # four legs, engine nacelles and team panels between them
    for i in range(4):
        angle = math.radians(45 + 90 * i)
        cx, cy = math.cos(angle), math.sin(angle)
        deg = math.degrees(angle)
        hull.box((1.1, 2.8, 0.6), (cx * 5.2, cy * 5.2, 1.5), "ceramic_shade", rot=(0, 0, deg + 90))
        hull.box((0.5, 0.5, 1.5), (cx * 6.3, cy * 6.3, 0.85), "steel", rot=(0, 0, deg))
        hull.cyl(0.95, 0.24, (cx * 6.3, cy * 6.3, 0.12), "graphite", segments=10)
        hull.cyl(0.9, 2.4, (cx * 3.5, cy * 3.5, 5.6), "graphite", segments=10, radius_top=0.7)
        hull.cyl(0.6, 0.2, (cx * 3.5, cy * 3.5, 6.85), "glow_orange", segments=10)
        side = math.radians(90 * i)
        if i != 3:  # 270 deg is the bay door side
            sx, sy = math.cos(side), math.sin(side)
            hull.box((0.3, 2.4, 1.2), (sx * 4.55, sy * 4.55, 3.0), "team",
                     rot=(0, 0, math.degrees(side)))
            hull.box((0.3, 1.6, 0.4), (sx * 4.62, sy * 4.62, 2.2), "glow_cyan",
                     rot=(0, 0, math.degrees(side)))
    hull.finish(bevel=0.08)

    dish = fl.Part("dish", root, pivot=(0.0, 0.6, 8.75))
    dish.cyl(0.12, 0.7, (0, 0.6, 9.1), "steel", segments=8)
    dish.cyl(1.1, 0.25, (0, 0.2, 9.6), "ceramic", rot=(58, 0, 0), radius_top=0.7, segments=14)
    dish.cyl(0.6, 0.08, (0, 0.12, 9.66), "graphite", rot=(58, 0, 0), segments=14)
    dish.sphere(0.12, (0, -0.4, 10.0), "glow_cyan", segments=8)
    dish.finish(bevel=0.03)
    return root
