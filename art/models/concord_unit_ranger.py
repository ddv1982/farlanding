"""Concord Ranger: light bipedal walker, the basic line unit."""

import fl


def build():
    root = fl.root("concord_unit_ranger")

    hips = fl.Part("body", root)
    hips.box((0.80, 0.60, 0.30), (0, 0, 1.12), "graphite", taper=(0.8, 0.8))
    hips.cyl(0.16, 1.00, (0, 0, 1.10), "steel", rot=(0, 90, 0), segments=12)
    hips.finish(bevel=0.03)

    for name, x in (("leg_l", -0.48), ("leg_r", 0.48)):
        leg = fl.Part(name, root, pivot=(x, 0.0, 1.10))
        leg.box((0.26, 0.40, 0.56), (x, -0.10, 0.84), "ceramic", rot=(18, 0, 0))
        leg.box((0.18, 0.26, 0.56), (x, 0.06, 0.42), "graphite", rot=(-22, 0, 0))
        leg.cyl(0.12, 0.30, (x, -0.04, 0.60), "orange", rot=(0, 90, 0), segments=10)
        leg.box((0.34, 0.62, 0.14), (x, -0.08, 0.07), "ceramic_shade", taper=(0.8, 0.75))
        leg.finish(bevel=0.025)

    torso = fl.Part("turret", root, pivot=(0.0, 0.0, 1.30))
    torso.box((0.96, 0.90, 0.60), (0, 0.0, 1.66), "ceramic", taper=(0.82, 0.78))
    torso.box((0.62, 0.30, 0.30), (0, -0.40, 1.74), "glass", rot=(-24, 0, 0))
    torso.box((1.00, 0.34, 0.20), (0, 0.22, 1.52), "orange")
    torso.box((0.50, 0.46, 0.05), (0, 0.06, 1.975), "team")
    torso.box((0.56, 0.36, 0.34), (0, 0.50, 1.72), "ceramic_shade")
    for x in (-0.20, 0.20):
        torso.box((0.10, 0.05, 0.10), (x, 0.69, 1.76), "glow_orange")
    # arm-mounted repeaters
    for x in (-0.68, 0.68):
        torso.box((0.30, 0.62, 0.34), (x, -0.02, 1.58), "graphite")
        torso.box((0.36, 0.30, 0.10), (x, 0.06, 1.79), "team")
        for dz in (-0.07, 0.07):
            torso.cyl(0.045, 0.60, (x, -0.58, 1.58 + dz), "steel", rot=(90, 0, 0), segments=8)
        torso.box((0.16, 0.05, 0.20), (x, -0.335, 1.58), "glow_cyan")
    torso.cyl(0.03, 0.50, (0.32, 0.40, 2.14), "steel", segments=6)
    torso.finish(bevel=0.03)
    return root
