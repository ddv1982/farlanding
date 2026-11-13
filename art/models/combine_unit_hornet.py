"""Combine Hornet: crude single-rotor attack flyer with a slung gun.

Modelled at its flying pose's origin: the game lifts the whole model to its altitude.
Part `fan` spins about its vertical axis.
"""

import fl


def build():
    root = fl.root("combine_unit_hornet")

    body = fl.Part("body", root)
    # boxy cab, open frame tail
    body.box((1.10, 1.80, 0.80), (0, -0.30, 0.80), "hull", taper=(0.8, 0.85))
    body.box((0.90, 0.80, 0.50), (0, -1.40, 0.66), "hull_light", rot=(14, 0, 0), taper=(0.5, 0.6))
    body.box((0.70, 0.10, 0.26), (0, -1.24, 0.98), "acid")
    body.box((0.70, 0.70, 0.06), (0, -0.20, 1.22), "team")
    body.box((1.16, 0.30, 0.50), (0, 0.40, 0.80), "rust")
    for x in (-1.0, 1.0):
        body.box((0.10, 2.20, 0.10), (x * 0.26, 1.60, 0.94), "gunmetal", rot=(-6, 0, x * 4))
        body.box((0.30, 0.90, 0.36), (x * 0.74, -0.20, 0.50), "olive")
        body.box((0.50, 0.30, 0.10), (x * 0.90, 0.10, 0.34), "team")
        # skids
        body.box((0.08, 1.90, 0.08), (x * 0.66, -0.20, 0.10), "gunmetal")
        body.box((0.06, 0.06, 0.34), (x * 0.66, -0.80, 0.28), "gunmetal")
        body.box((0.06, 0.06, 0.34), (x * 0.66, 0.40, 0.28), "gunmetal")
    # tail: fin and exhaust
    body.box((0.08, 0.70, 0.80), (0, 2.60, 1.10), "hull_light", taper=(1.0, 0.5))
    body.box((0.10, 0.30, 0.24), (0, 2.66, 1.36), "team")
    body.cyl(0.14, 0.50, (0, 0.90, 0.60), "rust", rot=(90, 0, 0), segments=6)
    body.cyl(0.10, 0.06, (0, 1.18, 0.60), "acid", rot=(90, 0, 0), segments=6)
    # slung gun
    body.box((0.26, 0.60, 0.24), (0, -1.00, 0.26), "gunmetal")
    body.cyl(0.07, 1.00, (0, -1.70, 0.24), "gunmetal", rot=(90, 0, 0), segments=6)
    body.box((0.10, 0.10, 0.10), (0, -2.22, 0.24), "acid")
    # rotor mast
    body.cyl(0.14, 0.50, (0, -0.10, 1.40), "gunmetal", segments=6)
    body.finish(bevel=0.025)

    fan = fl.Part("fan", root, pivot=(0.0, -0.10, 1.68))
    fan.cyl(0.22, 0.14, (0, -0.10, 1.68), "rust", segments=6)
    for i in range(2):
        fan.box((4.20, 0.24, 0.04), (0, -0.10, 1.70), "hull_light", rot=(6, 0, 90 * i))
    fan.box((0.30, 0.30, 0.05), (0, -0.10, 1.76), "acid")
    fan.finish(bevel=0.01)
    return root
