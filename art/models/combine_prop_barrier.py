"""Combine barrier: a wall segment of plate on footings, tall enough to hide behind."""

import fl


def build():
    root = fl.root("combine_prop_barrier")
    body = fl.Part("body", root)
    body.box((5.0, 0.5, 2.0), (0, 0, 1.1), "hull", taper=(1.0, 0.55))
    body.box((5.1, 0.9, 0.3), (0, 0, 0.15), "gunmetal")
    for x in (-2.2, 0.0, 2.2):
        body.box((0.3, 0.8, 2.2), (x, 0, 1.1), "hull_light", taper=(1.0, 0.5))
    body.box((1.5, 0.04, 0.5), (-1.1, -0.2, 1.3), "olive")
    body.box((1.5, 0.04, 0.5), (1.1, -0.2, 1.3), "rust")
    body.box((0.5, 0.06, 0.12), (0, -0.16, 1.95), "acid")
    body.finish(bevel=0.03)
    return root
