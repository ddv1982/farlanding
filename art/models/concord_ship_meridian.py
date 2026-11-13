"""Concord Meridian: the expedition carrier. A long spine, a turning habitat ring,
a survey dish at the bow, four engine bells aft and a Lander docked underneath."""

import math

import fl


def build():
    root = fl.root("concord_ship_meridian")

    hull = fl.Part("body", root)
    # spine, bow to stern along -Y .. +Y
    hull.box((2.6, 30.0, 2.2), (0, 0, 0), "ceramic_shade", taper=(0.8, 0.8))
    hull.box((3.4, 9.0, 3.0), (0, -9.5, 0.2), "ceramic")
    hull.box((3.5, 1.0, 3.1), (0, -6.0, 0.2), "orange")
    hull.box((2.2, 3.0, 1.2), (0, -11.0, 2.0), "ceramic_shade", taper=(0.7, 0.8))
    hull.box((1.9, 1.2, 0.5), (0, -12.2, 2.1), "glow_cyan")
    # bow: sensor boom and prow
    hull.box((2.4, 3.0, 2.0), (0, -15.5, 0.1), "ceramic", taper=(0.55, 0.55), rot=(90, 0, 0))
    hull.cyl(0.18, 6.0, (0, -19.0, 0.1), "steel", rot=(90, 0, 0), segments=6)
    hull.sphere(0.3, (0, -22.0, 0.1), "glow_cyan", segments=8)
    # cargo and hangar block amidships, with lit bay
    hull.box((5.2, 8.0, 3.6), (0, 3.0, -0.4), "ceramic")
    hull.box((5.3, 0.8, 3.7), (0, 0.2, -0.4), "team")
    hull.box((5.3, 0.5, 3.7), (0, 6.2, -0.4), "orange")
    hull.box((3.6, 5.0, 0.3), (0, 3.2, -2.3), "glow_cyan")
    for x in (-1.0, 1.0):
        hull.box((0.5, 7.0, 1.2), (x * 2.9, 3.0, 0.6), "graphite")
        hull.box((0.2, 5.0, 0.3), (x * 3.05, 3.0, 0.6), "glow_cyan")
        # radiator fins
        hull.box((6.0, 5.0, 0.12), (x * 5.6, 9.5, 0.4), "graphite", rot=(0, x * 14, 0))
        hull.box((5.6, 0.3, 0.16), (x * 5.6, 8.0, 0.4), "glow_orange", rot=(0, x * 14, 0))
    # docked Lander under the hangar
    hull.cyl(1.7, 1.0, (0, 3.2, -3.0), "ceramic", segments=8, radius_top=1.4)
    hull.cyl(1.72, 0.2, (0, 3.2, -2.8), "orange", segments=8)
    # engine block and four bells
    hull.box((4.4, 4.0, 3.6), (0, 14.0, 0), "graphite", taper=(1.15, 1.15), rot=(90, 0, 0))
    for x in (-1.0, 1.0):
        for z in (-1.0, 1.0):
            hull.cyl(0.9, 2.2, (x * 1.3, 16.6, z * 1.0), "gunmetal", rot=(90, 0, 0),
                     segments=10, radius_top=1.25)
            hull.cyl(1.0, 0.2, (x * 1.3, 17.75, z * 1.0), "glow_orange", rot=(90, 0, 0),
                     segments=10)
    # running lights
    hull.sphere(0.2, (0, -13.0, 2.9), "glow_red", segments=8)
    hull.sphere(0.2, (0, 12.5, 2.2), "glow_red", segments=8)
    hull.finish(bevel=0.08)

    # habitat ring around the spine; turns about the ship's long axis (Y)
    ring = fl.Part("ring", root, pivot=(0.0, -3.0, 0.0))
    count = 16
    radius = 6.4
    for i in range(count):
        angle = 2.0 * math.pi * i / count
        x, z = math.cos(angle) * radius, math.sin(angle) * radius
        deg = -math.degrees(angle)
        ring.box((1.3, 2.4, 2.65), (x, -3.0, z), "ceramic", rot=(0, deg, 0))
        if i % 2 == 0:
            ring.box((0.2, 1.6, 1.4), (x * 1.11, -3.0, z * 1.11), "glow_cyan", rot=(0, deg, 0))
        else:
            ring.box((0.2, 2.5, 2.0), (x * 1.1, -3.0, z * 1.1), "team", rot=(0, deg, 0))
    for i in range(4):
        angle = math.radians(45 + 90 * i)
        x, z = math.cos(angle) * radius * 0.5, math.sin(angle) * radius * 0.5
        ring.box((radius - 1.6, 0.5, 0.5), (x, -3.0, z), "steel", rot=(0, -math.degrees(angle), 0))
    ring.cyl(1.9, 2.8, (0, -3.0, 0), "graphite", rot=(90, 0, 0), segments=12)
    ring.finish(bevel=0.05)

    # survey dish on a mast above the bow
    dish = fl.Part("dish", root, pivot=(0.0, -9.0, 2.6))
    dish.cyl(0.2, 2.0, (0, -9.0, 3.0), "steel", segments=6)
    dish.cyl(2.2, 0.4, (0, -9.6, 4.6), "ceramic", rot=(50, 0, 0), radius_top=1.3, segments=14)
    dish.cyl(1.3, 0.1, (0, -9.72, 4.7), "graphite", rot=(50, 0, 0), segments=14)
    dish.sphere(0.2, (0, -10.6, 5.5), "glow_cyan", segments=8)
    dish.finish(bevel=0.04)
    return root
