"""Concord Lancer: anti-armour walker carrying one long rail lance."""

import fl


def build():
    root = fl.root("concord_unit_lancer")
    hips = fl.Part("body", root)
    hips.box((0.90, 0.70, 0.34), (0, 0, 1.30), "graphite", taper=(0.8, 0.8))
    hips.cyl(0.18, 1.10, (0, 0, 1.28), "steel", rot=(0, 90, 0), segments=12)
    hips.finish(bevel=0.03)

    for name, x in (("leg_l", -0.55), ("leg_r", 0.55)):
        leg = fl.Part(name, root, pivot=(x, 0.0, 1.28))
        leg.box((0.28, 0.44, 0.66), (x, -0.12, 0.98), "ceramic", rot=(18, 0, 0))
        leg.box((0.20, 0.28, 0.66), (x, 0.08, 0.48), "graphite", rot=(-22, 0, 0))
        leg.cyl(0.13, 0.32, (x, -0.04, 0.70), "orange", rot=(0, 90, 0), segments=10)
        leg.box((0.38, 0.70, 0.15), (x, -0.08, 0.075), "ceramic_shade", taper=(0.8, 0.75))
        leg.finish(bevel=0.025)

    torso = fl.Part("turret", root, pivot=(0.0, 0.0, 1.50))
    torso.box((0.90, 1.00, 0.56), (-0.20, 0.0, 1.84), "ceramic", taper=(0.82, 0.78))
    torso.box((0.50, 0.26, 0.26), (-0.20, -0.46, 1.90), "glass", rot=(-24, 0, 0))
    torso.box((0.94, 0.34, 0.18), (-0.20, 0.24, 1.70), "orange")
    torso.box((0.46, 0.46, 0.05), (-0.20, 0.06, 2.13), "team")
    # the lance: a long rail on the right shoulder with glowing coils
    torso.box((0.34, 1.50, 0.40), (0.62, 0.10, 1.90), "graphite")
    torso.box((0.38, 0.50, 0.12), (0.62, 0.30, 2.13), "team")
    for dx in (-0.08, 0.08):
        torso.box((0.06, 2.40, 0.10), (0.62 + dx, -1.60, 1.90), "steel")
    for y in (-0.90, -1.50, -2.10):
        torso.box((0.30, 0.10, 0.30), (0.62, y, 1.90), "glow_cyan")
    torso.box((0.24, 0.16, 0.24), (0.62, -2.82, 1.90), "orange")
    torso.cyl(0.03, 0.60, (-0.50, 0.40, 2.36), "steel", segments=6)
    torso.finish(bevel=0.03)
    return root
