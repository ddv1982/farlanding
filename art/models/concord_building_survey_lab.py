"""Concord Survey Lab: turns discoveries into Intel and field options."""

import fl


def build():
    root = fl.root("concord_building_survey_lab")
    body = fl.Part("body", root)
    body.cyl(4.2, 0.4, (0, 0, 0.2), "graphite", segments=8, radius_top=4.0)
    body.cyl(3.4, 2.2, (0, 0, 1.5), "ceramic", segments=8, radius_top=2.9)
    body.cyl(3.44, 0.4, (0, 0, 0.9), "orange", segments=8, radius_top=3.4)
    # observation dome
    body.sphere(2.3, (0, 0, 2.6), "glass", scale=(1, 1, 0.75), segments=16)
    body.cyl(2.5, 0.3, (0, 0, 2.7), "ceramic_shade", segments=16)
    body.cyl(0.9, 0.12, (0, 0, 4.3), "team", segments=10)
    # entrance (-Y) and two instrument wings
    body.box((2.2, 1.6, 1.8), (0, -3.4, 1.3), "ceramic_shade", taper=(0.85, 0.9))
    body.box((1.4, 0.2, 1.2), (0, -4.22, 1.1), "glow_cyan")
    for x in (-3.6, 3.6):
        body.box((1.8, 2.6, 1.4), (x, 0.8, 1.1), "ceramic", taper=(0.8, 0.85))
        body.box((0.9, 1.4, 0.06), (x, 0.8, 1.83), "team")
        body.cyl(0.07, 1.8, (x, 1.6, 2.7), "steel", segments=6)
        body.sphere(0.16, (x, 1.6, 3.65), "glow_cyan", segments=8)
    body.finish(bevel=0.06)

    dish = fl.Part("dish", root, pivot=(0.0, 2.4, 2.6))
    dish.cyl(0.14, 1.0, (0, 2.4, 3.1), "steel", segments=8)
    dish.cyl(1.2, 0.24, (0, 2.1, 3.9), "ceramic", rot=(58, 0, 0), radius_top=0.8, segments=14)
    dish.cyl(0.66, 0.08, (0, 2.03, 3.95), "graphite", rot=(58, 0, 0), segments=14)
    dish.sphere(0.12, (0, 1.5, 4.3), "glow_cyan", segments=8)
    dish.finish(bevel=0.03)
    return root
