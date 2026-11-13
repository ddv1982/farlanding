"""Concord Arc: wheeled artillery that lobs shells over the front line."""

import fl


def build():
    root = fl.root("concord_unit_arc")
    body = fl.Part("body", root)
    body.box((1.50, 3.40, 0.28), (0, 0, 0.66), "graphite")
    body.box((1.70, 1.00, 0.70), (0, -1.15, 1.12), "ceramic", taper=(0.84, 0.74))
    body.box((1.20, 0.26, 0.30), (0, -1.60, 1.20), "glass", rot=(-18, 0, 0))
    body.box((1.80, 2.10, 0.36), (0, 0.55, 0.98), "ceramic_shade")
    body.box((1.84, 0.50, 0.20), (0, 0.55, 0.92), "orange")
    body.box((0.60, 0.50, 0.05), (0, -1.12, 1.49), "team")
    # stabiliser feet
    for x in (-1.05, 1.05):
        body.box((0.30, 0.50, 0.50), (x, 1.30, 0.50), "steel")
        body.box((0.50, 0.70, 0.10), (x * 1.1, 1.30, 0.20), "hazard")
    body.finish(bevel=0.035)

    for side, x in (("l", -0.90), ("r", 0.90)):
        for index, y in enumerate((-1.15, 0.0, 1.10)):
            wheel = fl.Part(f"wheel_{side}{index}", root, pivot=(x, y, 0.44))
            wheel.cyl(0.44, 0.34, (x, y, 0.44), "rubber", rot=(0, 90, 0), segments=16)
            wheel.cyl(0.22, 0.38, (x, y, 0.44), "steel", rot=(0, 90, 0), segments=8)
            wheel.finish(bevel=0.04)

    turret = fl.Part("turret", root, pivot=(0.0, 0.55, 1.16))
    turret.cyl(0.70, 0.16, (0, 0.55, 1.24), "graphite", segments=14)
    turret.box((1.10, 1.30, 0.60), (0, 0.65, 1.60), "ceramic", taper=(0.8, 0.8))
    turret.box((0.50, 0.50, 0.05), (0, 0.85, 1.92), "team")
    turret.box((0.30, 0.06, 0.20), (0.36, 0.0, 1.62), "glow_cyan")
    turret_obj = turret.finish(bevel=0.035)

    barrel = fl.Part("barrel", turret_obj, pivot=(0.0, 0.20, 1.70))
    barrel.cyl(0.24, 1.20, (0, -0.35, 2.10), "ceramic_shade", rot=(50, 0, 0), segments=12)
    barrel.cyl(0.17, 1.60, (0, -1.25, 2.86), "steel", rot=(50, 0, 0), segments=12)
    barrel.cyl(0.23, 0.30, (0, -1.80, 3.32), "graphite", rot=(50, 0, 0), segments=12)
    barrel.cyl(0.18, 0.10, (0, -0.86, 2.53), "orange", rot=(50, 0, 0), segments=12)
    barrel.finish(bevel=0.02)
    return root
