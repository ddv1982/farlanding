"""Combine Stinger: fast three-wheeled raider with a forward lance."""

import fl


def build():
    root = fl.root("combine_unit_stinger")
    body = fl.Part("body", root)
    body.box((0.90, 2.60, 0.44), (0, 0.10, 0.78), "hull", taper=(0.7, 0.9))
    body.box((0.70, 1.20, 0.30), (0, -1.50, 0.70), "hull_light", rot=(-8, 0, 0), taper=(0.4, 0.5))
    body.box((0.56, 0.70, 0.30), (0, 0.10, 1.10), "olive", taper=(0.7, 0.6))
    body.box((0.40, 0.10, 0.16), (0, -0.28, 1.12), "acid")
    body.box((0.44, 0.50, 0.05), (0, 0.70, 1.03), "team")
    # rear outriggers
    for x in (-0.80, 0.80):
        body.box((0.80, 0.30, 0.16), (x * 0.62, 0.95, 0.72), "hull_light")
        body.box((0.26, 0.90, 0.30), (x * 1.06, 0.95, 0.86), "team")
        body.box((0.12, 0.06, 0.12), (x * 1.06, 1.42, 0.86), "acid")
    # lance
    body.cyl(0.07, 1.50, (0, -2.40, 0.78), "gunmetal", rot=(90, 0, 0), segments=6)
    body.cyl(0.12, 0.30, (0, -1.80, 0.78), "rust", rot=(90, 0, 0), segments=6)
    body.box((0.10, 0.10, 0.10), (0, -3.16, 0.78), "acid")
    body.finish(bevel=0.025)

    for name, x, y, radius in (("wheel_f", 0.0, -1.10, 0.42), ("wheel_rl", -0.85, 0.95, 0.50),
                               ("wheel_rr", 0.85, 0.95, 0.50)):
        wheel = fl.Part(name, root, pivot=(x, y, radius))
        wheel.cyl(radius, 0.30, (x, y, radius), "rubber", rot=(0, 90, 0), segments=16)
        wheel.cyl(radius * 0.5, 0.34, (x, y, radius), "gunmetal", rot=(0, 90, 0), segments=8)
        wheel.cyl(radius * 0.2, 0.38, (x, y, radius), "acid", rot=(0, 90, 0), segments=6)
        wheel.finish(bevel=0.03)
    return root
