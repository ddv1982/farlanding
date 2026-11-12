"""Combine Spire: enemy defence tower with a lance emitter."""

import fl


def build():
    root = fl.root("combine_building_spire")
    body = fl.Part("body", root)
    body.cyl(2.2, 0.5, (0, 0, 0.25), "gunmetal", segments=6, radius_top=2.0)
    body.cyl(1.5, 3.0, (0, 0, 2.0), "hull", segments=6, radius_top=0.9)
    body.cyl(1.56, 0.4, (0, 0, 0.9), "olive", segments=6, radius_top=1.5)
    body.cyl(1.0, 0.3, (0, 0, 3.6), "gunmetal", segments=6)
    for i in range(3):
        angle = fl.math.radians(90 + 120 * i)
        x, y = fl.math.cos(angle) * 1.7, fl.math.sin(angle) * 1.7
        body.box((0.7, 0.7, 1.4), (x, y, 1.0), "hull_light", taper=(0.5, 0.5))
        body.box((0.3, 0.3, 0.3), (x, y, 1.8), "acid")
    body.finish(bevel=0.05)

    turret = fl.Part("turret", root, pivot=(0.0, 0.0, 3.75))
    turret.box((1.4, 1.8, 0.9), (0, 0.1, 4.25), "hull_light", taper=(0.7, 0.8))
    turret.box((0.7, 0.7, 0.06), (0, 0.3, 4.72), "team")
    turret.box((0.5, 0.2, 0.3), (0, -0.82, 4.3), "acid")
    turret.cyl(0.14, 2.2, (0, -1.9, 4.25), "gunmetal", rot=(90, 0, 0), segments=6)
    turret.cyl(0.22, 0.4, (0, -1.2, 4.25), "rust", rot=(90, 0, 0), segments=6)
    turret.box((0.2, 0.2, 0.2), (0, -3.0, 4.25), "acid")
    turret.finish(bevel=0.04)
    return root
