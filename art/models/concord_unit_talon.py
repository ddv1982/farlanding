"""Concord Talon: twin-fan gunship. Flies over ground and canopy alike.

Modelled at its flying pose's origin: the game lifts the whole model to its altitude.
Parts `fan_l` and `fan_r` spin about their vertical axis.
"""

import fl


def build():
    root = fl.root("concord_unit_talon")

    body = fl.Part("body", root)
    # slim fuselage with a glazed nose and a raised tail boom
    body.box((0.90, 3.00, 0.60), (0, 0.00, 0.70), "ceramic", taper=(0.75, 0.80))
    body.box((0.70, 1.10, 0.50), (0, -1.75, 0.62), "ceramic", rot=(10, 0, 0), taper=(0.45, 0.55))
    body.box((0.56, 0.90, 0.34), (0, -0.90, 1.02), "glass", rot=(-12, 0, 0), taper=(0.7, 0.6))
    body.box((0.50, 1.90, 0.34), (0, 2.10, 0.88), "ceramic_shade", taper=(0.5, 0.6))
    body.box((0.94, 0.50, 0.16), (0, 0.50, 0.74), "orange")
    body.box((0.50, 0.70, 0.05), (0, 0.20, 1.02), "team")
    body.box((0.60, 1.60, 0.07), (0, 0.10, 0.38), "glow_cyan")
    # twin tail fins
    for x in (-1.0, 1.0):
        body.box((0.06, 0.70, 0.70), (x * 0.42, 2.80, 1.22), "ceramic", rot=(0, x * 18, 0),
                 taper=(1.0, 0.5))
        body.box((0.07, 0.30, 0.20), (x * 0.50, 2.86, 1.44), "team", rot=(0, x * 18, 0))
    # stub wings carrying the fan rings and rocket pods
    for x in (-1.0, 1.0):
        body.box((1.30, 0.70, 0.12), (x * 1.00, 0.30, 0.86), "ceramic_shade")
        body.cyl(0.95, 0.30, (x * 2.05, 0.30, 0.90), "graphite", segments=16)
        body.cyl(0.82, 0.04, (x * 2.05, 0.30, 1.05), "black", segments=16)
        body.cyl(0.97, 0.10, (x * 2.05, 0.30, 0.86), "team", segments=16)
        body.cyl(0.13, 0.90, (x * 0.95, -0.20, 0.62), "gunmetal", rot=(90, 0, 0), segments=8)
        body.cyl(0.10, 0.06, (x * 0.95, -0.66, 0.62), "glow_orange", rot=(90, 0, 0), segments=8)
    # chin cannon
    body.box((0.24, 0.50, 0.20), (0, -1.50, 0.36), "graphite")
    body.cyl(0.05, 0.90, (0, -2.05, 0.34), "steel", rot=(90, 0, 0), segments=8)
    # running lights
    body.sphere(0.07, (0, 3.05, 1.00), "glow_red", segments=8)
    body.finish(bevel=0.03)

    for name, x in (("fan_l", -2.05), ("fan_r", 2.05)):
        fan = fl.Part(name, root, pivot=(x, 0.30, 0.92))
        fan.cyl(0.16, 0.36, (x, 0.30, 0.96), "steel", segments=8)
        for i in range(3):
            fan.box((1.56, 0.18, 0.03), (x, 0.30, 1.08), "ceramic", rot=(8, 0, 60 * i))
        fan.finish(bevel=0.01)
    return root
