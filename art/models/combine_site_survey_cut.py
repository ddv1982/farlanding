"""Combine survey cut: a test bore sunk into the rock, drill frame still standing."""

import fl


def build():
    root = fl.root("combine_site_survey_cut")
    body = fl.Part("body", root)
    body.cyl(1.7, 0.24, (0, 0, 0.12), "kessel_rock", segments=7, radius_top=1.4)
    body.cyl(0.9, 0.2, (0, 0, 0.26), "black", segments=7)
    body.cyl(1.0, 0.16, (0, 0, 0.3), "gunmetal", segments=7, radius_top=0.95)
    for x in (-1.0, 1.0):
        body.box((0.2, 0.2, 2.6), (x * 0.72, 0, 1.45), "hull_light", rot=(0, -x * 14, 0))
        body.box((0.5, 0.6, 0.16), (x * 1.05, 0, 0.3), "hull")
    body.box((1.3, 0.34, 0.3), (0, 0, 2.7), "hull")
    body.box((0.4, 0.4, 0.5), (0, 0, 2.35), "olive")
    body.cyl(0.1, 2.0, (0, 0, 1.25), "rust", segments=6)
    body.cyl(0.22, 0.4, (0, 0, 0.45), "rust", segments=6, radius_top=0.1)
    body.box((0.3, 0.06, 0.16), (0, -0.19, 2.72), "acid")
    body.box((0.9, 0.7, 0.6), (1.5, 0.9, 0.3), "olive", rot=(0, 0, 24))
    body.box((0.5, 0.06, 0.2), (1.38, 0.57, 0.4), "acid", rot=(0, 0, 24))
    body.box((0.7, 0.5, 0.3), (-1.4, 0.8, 0.2), "kessel_rock_pale", rot=(8, 0, -30))
    body.box((0.5, 0.4, 0.24), (-1.1, -1.1, 0.16), "kessel_rock", rot=(0, 6, 50))
    for x, y in ((-1.9, -0.3), (1.8, -0.9), (0.3, 1.9)):
        body.box((0.08, 0.08, 0.9), (x, y, 0.45), "hazard")
    body.finish(bevel=0.03)
    return root
