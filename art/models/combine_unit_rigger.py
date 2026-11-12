"""Combine Rigger: hovering construction drone with a welding arm."""

import fl


def build():
    root = fl.root("combine_unit_rigger")
    body = fl.Part("body", root)
    body.box((1.30, 1.50, 0.40), (0, 0, 0.95), "hull", taper=(0.75, 0.8))
    body.box((1.34, 0.50, 0.14), (0, 0.10, 0.82), "olive")
    body.box((0.90, 1.10, 0.10), (0, 0, 0.66), "acid")
    body.box((0.50, 0.50, 0.05), (0, 0.20, 1.17), "team")
    body.box((0.60, 0.10, 0.14), (0, -0.74, 0.98), "acid")
    # two side thruster pods
    for x in (-0.95, 0.95):
        body.box((0.40, 1.20, 0.34), (x, 0.0, 0.92), "gunmetal", taper=(0.8, 0.9))
        body.box((0.30, 0.90, 0.06), (x, 0.0, 0.72), "acid")
        body.box((0.42, 0.40, 0.36), (x, 0.3, 0.92), "team")
    body.finish(bevel=0.03)

    arm = fl.Part("turret", root, pivot=(0.0, -0.1, 1.18))
    arm.cyl(0.16, 0.22, (0, -0.1, 1.28), "gunmetal", segments=6)
    arm.box((0.18, 1.00, 0.16), (0, -0.56, 1.44), "hull_light", rot=(16, 0, 0))
    arm.box((0.14, 0.60, 0.14), (0, -1.16, 1.34), "gunmetal", rot=(-36, 0, 0))
    arm.box((0.24, 0.24, 0.18), (0, -1.40, 1.12), "rust")
    arm.cyl(0.05, 0.18, (0, -1.40, 0.96), "acid", segments=6)
    arm.finish(bevel=0.02)
    return root
