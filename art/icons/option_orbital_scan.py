"""Field option emblem: the Meridian's survey satellite sweeping the ground."""

import fl


def build():
    root = fl.root("option_orbital_scan")
    body = fl.Part("body", root)
    body.box((0.7, 0.7, 0.8), (0, 0, 2.6), "ceramic")
    body.box((0.74, 0.74, 0.16), (0, 0, 2.75), "orange")
    for x in (-1.0, 1.0):
        body.box((1.3, 0.06, 0.6), (x * 1.1, 0, 2.6), "glass")
        body.box((0.2, 0.1, 0.1), (x * 0.4, 0, 2.6), "steel")
    body.cyl(0.3, 0.2, (0, 0, 2.1), "steel", segments=8, radius_top=0.18)
    body.cyl(1.5, 1.9, (0, 0, 1.0), "glow_cyan", segments=12, radius_top=0.1)
    body.cyl(1.6, 0.06, (0, 0, 0.03), "glow_cyan", segments=12)
    body.finish(bevel=0.02)
    return root
