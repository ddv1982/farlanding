"""Concord Foundry: builds vehicles. A long factory with a gantry and exit ramp."""

import fl


def build():
    root = fl.root("concord_building_foundry")
    body = fl.Part("body", root)
    body.box((11.0, 12.6, 0.4), (0, 0, 0.2), "graphite")
    # main assembly hall with stepped roof
    body.box((9.4, 9.6, 4.0), (0, 1.2, 2.4), "ceramic", taper=(0.9, 0.94))
    body.box((9.5, 9.7, 0.6), (0, 1.2, 1.4), "orange")
    body.box((6.0, 7.0, 1.0), (0, 1.6, 4.9), "ceramic_shade", taper=(0.8, 0.9))
    body.box((3.6, 4.6, 0.2), (0, 1.6, 5.5), "team")
    # vehicle door (-Y) with wide ramp
    body.box((6.0, 0.6, 3.4), (0, -3.5, 2.1), "ceramic_shade")
    body.box((5.0, 0.3, 2.8), (0, -3.75, 1.9), "glow_cyan")
    body.box((5.4, 2.6, 0.24), (0, -5.0, 0.44), "graphite", rot=(-6, 0, 0))
    for x in (-2.4, 2.4):
        body.box((0.4, 2.6, 0.1), (x, -5.0, 0.6), "hazard", rot=(-6, 0, 0))
    # gantry crane over the door
    for x in (-3.6, 3.6):
        body.box((0.5, 0.5, 5.6), (x, -4.4, 3.0), "steel")
    body.box((7.8, 0.6, 0.6), (0, -4.4, 5.6), "orange")
    body.box((0.9, 0.9, 0.7), (1.2, -4.4, 5.1), "graphite")
    # side plant: exhaust stacks, tanks, team panels
    for y in (0.0, 2.6):
        body.cyl(0.5, 3.0, (-3.6, y + 2.0, 5.6), "graphite", segments=10, radius_top=0.4)
        body.cyl(0.42, 0.2, (-3.6, y + 2.0, 7.15), "glow_orange", segments=10)
    body.cyl(1.2, 2.6, (4.3, 4.6, 1.7), "ceramic", rot=(90, 0, 0), segments=12)
    body.cyl(1.24, 0.5, (4.3, 4.6, 1.7), "team", rot=(90, 0, 0), segments=12)
    for x in (-4.5, 4.5):
        body.box((0.3, 4.0, 1.6), (x, 0.4, 2.6), "team")
    body.finish(bevel=0.08)
    return root
