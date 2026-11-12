"""Concord Muster Bay: trains walkers. A hangar with one big lit door."""

import fl


def build():
    root = fl.root("concord_building_muster_bay")
    body = fl.Part("body", root)
    body.box((8.6, 8.6, 0.4), (0, 0, 0.2), "graphite")
    body.box((7.4, 7.0, 3.6), (0, 0.4, 2.2), "ceramic", taper=(0.86, 0.9))
    body.box((7.5, 7.1, 0.5), (0, 0.4, 1.3), "orange")
    body.box((4.4, 4.0, 0.2), (0, 0.6, 4.1), "team")
    # door facing forward (-Y) with ramp
    body.box((4.2, 0.5, 3.0), (0, -3.2, 1.9), "ceramic_shade")
    body.box((3.4, 0.3, 2.4), (0, -3.42, 1.7), "glow_cyan")
    body.box((3.8, 2.0, 0.2), (0, -4.3, 0.42), "graphite", rot=(-7, 0, 0))
    for x in (-1.7, 1.7):
        body.box((0.3, 2.0, 0.1), (x, -4.3, 0.56), "hazard", rot=(-7, 0, 0))
        body.box((0.6, 0.6, 3.4), (x * 1.42, -3.2, 2.1), "ceramic")
        body.box((0.3, 0.1, 0.5), (x * 1.42, -3.52, 3.2), "glow_orange")
    # roof plant and mast
    body.box((2.0, 1.6, 0.8), (-2.0, 2.4, 4.5), "ceramic_shade")
    body.cyl(0.5, 0.5, (2.2, 2.4, 4.3), "graphite", segments=10)
    body.cyl(0.07, 2.6, (2.2, 2.4, 5.8), "steel", segments=6)
    body.sphere(0.13, (2.2, 2.4, 7.1), "glow_red", segments=8)
    for x in (-3.5, 3.5):
        body.box((0.3, 3.0, 1.4), (x, 0.6, 2.3), "team")
    body.finish(bevel=0.07)
    return root
