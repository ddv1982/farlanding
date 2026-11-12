"""Concord Bulwark: heavy tracked tank."""

import fl


def build():
    root = fl.root("concord_unit_bulwark")

    hull = fl.Part("body", root)
    hull.box((2.30, 3.80, 0.50), (0, 0, 0.78), "ceramic", taper=(0.90, 0.88))
    hull.box((1.90, 1.10, 0.30), (0, -1.55, 0.72), "ceramic_shade", rot=(24, 0, 0))
    hull.box((2.00, 1.30, 0.24), (0, 1.10, 1.08), "ceramic_shade")
    hull.box((2.34, 1.20, 0.18), (0, 0.30, 0.86), "orange")
    hull.box((0.90, 0.70, 0.05), (0, 1.15, 1.215), "team")
    for x in (-0.55, 0.55):
        hull.box((0.50, 0.10, 0.34), (x, 1.92, 0.82), "graphite")
        hull.box((0.22, 0.05, 0.08), (x, 1.92, 1.02), "glow_orange")
        hull.box((0.26, 0.06, 0.09), (x * 1.5, -1.84, 0.84), "glow_cyan")
    # tracks: belt, skirt and road wheels on each side
    for x in (-1.32, 1.32):
        hull.box((0.56, 4.00, 0.72), (x, 0, 0.40), "rubber", taper=(1.0, 0.86))
        hull.box((0.62, 3.30, 0.20), (x, 0, 0.82), "ceramic")
        hull.box((0.64, 0.80, 0.22), (x, -1.20, 0.82), "team")
        for y in (-1.35, -0.45, 0.45, 1.35):
            hull.cyl(0.26, 0.60, (x, y, 0.34), "steel", rot=(0, 90, 0), segments=10)
    hull.finish(bevel=0.04)

    turret = fl.Part("turret", root, pivot=(0.0, 0.15, 1.05))
    turret.cyl(0.80, 0.14, (0, 0.15, 1.10), "graphite", segments=20)
    turret.box((1.70, 1.90, 0.56), (0, 0.25, 1.44), "ceramic", taper=(0.80, 0.74))
    turret.box((1.20, 0.60, 0.40), (0, -0.74, 1.40), "ceramic_shade", taper=(0.7, 0.8))
    turret.box((0.60, 0.50, 0.05), (0, 0.35, 1.74), "team")
    turret.box((0.40, 0.70, 0.30), (0.62, 0.45, 1.78), "graphite")
    turret.box((0.34, 0.06, 0.16), (0.62, 0.08, 1.80), "glow_cyan")
    turret.cyl(0.16, 0.16, (-0.50, 0.55, 1.78), "steel", segments=12)
    turret.cyl(0.025, 0.70, (-0.60, 0.95, 2.05), "steel", segments=6)
    turret_obj = turret.finish(bevel=0.04)

    barrel = fl.Part("barrel", turret_obj, pivot=(0.0, -0.90, 1.42))
    barrel.cyl(0.17, 1.00, (0, -1.40, 1.42), "ceramic_shade", rot=(90, 0, 0), segments=12)
    barrel.cyl(0.11, 1.50, (0, -2.40, 1.42), "steel", rot=(90, 0, 0), segments=12)
    barrel.cyl(0.16, 0.36, (0, -3.10, 1.42), "graphite", rot=(90, 0, 0), segments=12)
    barrel.cyl(0.12, 0.10, (0, -1.92, 1.42), "orange", rot=(90, 0, 0), segments=12)
    barrel.finish(bevel=0.02)
    return root
