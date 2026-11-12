"""Concord Refinery: Haulers unload Alloy here. Hall, silos and a marked dock."""

import fl


def build():
    root = fl.root("concord_building_refinery")
    body = fl.Part("body", root)
    body.box((9.0, 10.0, 0.4), (0, 0, 0.2), "graphite")
    # processing hall
    body.box((5.4, 6.4, 3.4), (-1.5, 1.2, 2.1), "ceramic", taper=(0.9, 0.92))
    body.box((5.5, 6.5, 0.5), (-1.5, 1.2, 1.6), "orange")
    body.box((3.0, 3.6, 0.2), (-1.5, 1.2, 3.9), "team")
    body.box((2.0, 1.6, 1.2), (-1.5, 3.2, 4.3), "ceramic_shade", taper=(0.8, 0.8))
    # unloading dock at the front (-Y) with hazard markings and a lit hopper
    body.box((5.0, 3.2, 0.5), (-1.5, -3.4, 0.65), "ceramic_shade")
    body.box((3.6, 2.2, 0.3), (-1.5, -3.4, 0.95), "glow_orange")
    for x in (-3.8, 0.8):
        body.box((0.4, 3.2, 0.2), (x, -3.4, 0.95), "hazard")
    body.box((4.4, 0.5, 2.0), (-1.5, -1.9, 1.9), "graphite")
    # storage silos and pipework
    for y in (-2.4, 1.0):
        body.cyl(1.4, 4.6, (2.7, y, 2.7), "ceramic", segments=14)
        body.cyl(1.46, 0.5, (2.7, y, 3.6), "team", segments=14)
        body.cyl(1.2, 0.6, (2.7, y, 5.2), "ceramic_shade", segments=14, radius_top=0.5)
    body.cyl(0.25, 3.6, (1.1, -0.7, 3.4), "copper", rot=(0, 90, 0), segments=8)
    body.cyl(0.25, 3.4, (2.7, -0.7, 4.6), "copper", rot=(90, 0, 0), segments=8)
    # stack with beacon
    body.cyl(0.55, 5.0, (-3.4, 3.4, 4.3), "graphite", segments=10, radius_top=0.4)
    body.cyl(0.46, 0.3, (-3.4, 3.4, 6.7), "glow_orange", segments=10)
    body.finish(bevel=0.07)
    return root
