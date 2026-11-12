"""Combine Skitter: cheap four-legged attack drone, fielded in swarms."""

import fl


def build():
    root = fl.root("combine_unit_skitter")
    body = fl.Part("body", root)
    body.box((0.90, 1.30, 0.34), (0, 0, 0.86), "hull", taper=(0.7, 0.8))
    body.box((0.70, 0.50, 0.24), (0, -0.62, 0.80), "hull_light", rot=(18, 0, 0), taper=(0.6, 0.7))
    body.box((0.40, 0.08, 0.10), (0, -0.88, 0.80), "acid")
    body.box((0.50, 0.50, 0.05), (0, 0.18, 1.045), "team")
    body.box((0.60, 0.30, 0.20), (0, 0.62, 0.92), "rust")
    body.box((0.16, 0.05, 0.08), (0, 0.78, 0.94), "acid")
    body.finish(bevel=0.02)

    for name, x, y in (("leg_fl", -0.52, -0.42), ("leg_fr", 0.52, -0.42),
                       ("leg_rr", 0.52, 0.42), ("leg_rl", -0.52, 0.42)):
        side = -1 if x < 0 else 1
        leg = fl.Part(name, root, pivot=(x, y, 0.84))
        leg.box((0.46, 0.14, 0.14), (x + side * 0.20, y, 0.90), "gunmetal", rot=(0, side * -24, 0))
        leg.box((0.12, 0.12, 0.84), (x + side * 0.44, y, 0.44), "hull_light", rot=(0, side * 10, 0))
        leg.box((0.20, 0.26, 0.08), (x + side * 0.52, y, 0.04), "olive")
        leg.finish(bevel=0.015)

    gun = fl.Part("turret", root, pivot=(0.0, 0.0, 1.04))
    gun.cyl(0.20, 0.14, (0, 0, 1.12), "gunmetal", segments=8)
    gun.box((0.24, 0.50, 0.18), (0, -0.14, 1.24), "olive")
    gun.cyl(0.05, 0.60, (0, -0.62, 1.24), "gunmetal", rot=(90, 0, 0), segments=6)
    gun.box((0.10, 0.04, 0.10), (0, -0.40, 1.34), "acid")
    gun.finish(bevel=0.015)
    return root
