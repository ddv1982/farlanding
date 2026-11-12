"""Concord Fabricator: hovering builder drone with a printer arm."""

import fl


def build():
    root = fl.root("concord_unit_fabricator")

    body = fl.Part("body", root)
    body.cyl(0.85, 0.36, (0, 0, 0.92), "ceramic", segments=8, radius_top=0.70)
    body.cyl(0.90, 0.12, (0, 0, 0.72), "orange", segments=8)
    body.cyl(0.62, 0.10, (0, 0, 0.62), "glow_cyan", segments=8)
    body.cyl(0.46, 0.22, (0, 0, 1.20), "ceramic_shade", segments=8, radius_top=0.36)
    body.cyl(0.30, 0.06, (0, 0, 1.33), "team", segments=8)
    body.box((0.40, 0.14, 0.14), (0, -0.80, 0.96), "glass")
    # four lift fans on short booms
    for x, y in ((-0.78, -0.78), (0.78, -0.78), (-0.78, 0.78), (0.78, 0.78)):
        body.box((0.14, 0.14, 0.10), (x * 0.72, y * 0.72, 0.92), "steel")
        body.cyl(0.34, 0.16, (x, y, 0.92), "graphite", segments=12)
        body.cyl(0.26, 0.05, (x, y, 0.83), "glow_cyan", segments=12)
        body.cyl(0.10, 0.20, (x, y, 0.96), "team", segments=8)
    body.finish(bevel=0.03)

    arm = fl.Part("turret", root, pivot=(0.0, 0.0, 1.36))
    arm.cyl(0.14, 0.24, (0, 0, 1.46), "steel", segments=10)
    arm.box((0.16, 1.00, 0.14), (0, -0.46, 1.60), "ceramic", rot=(14, 0, 0))
    arm.box((0.12, 0.60, 0.12), (0, -1.08, 1.50), "graphite", rot=(-34, 0, 0))
    arm.box((0.22, 0.22, 0.16), (0, -1.34, 1.30), "orange")
    arm.cyl(0.05, 0.16, (0, -1.34, 1.16), "glow_orange", segments=8)
    arm.finish(bevel=0.02)
    return root
