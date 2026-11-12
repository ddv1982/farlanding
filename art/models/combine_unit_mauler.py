"""Combine Mauler: slab-sided siege tank on four track pods."""

import fl


def build():
    root = fl.root("combine_unit_mauler")
    hull = fl.Part("body", root)
    hull.box((2.50, 4.20, 0.70), (0, 0, 0.95), "hull", taper=(0.84, 0.90))
    hull.box((2.30, 1.30, 0.40), (0, -1.80, 0.80), "hull_light", rot=(30, 0, 0))
    hull.box((2.54, 0.80, 0.30), (0, 0.70, 1.00), "olive")
    hull.box((1.10, 0.90, 0.06), (0, 1.40, 1.33), "team")
    hull.box((1.60, 0.20, 0.50), (0, 2.14, 0.96), "rust")
    for x in (-0.60, 0.60):
        hull.box((0.30, 0.06, 0.10), (x, -2.14, 0.98), "acid")
        hull.box((0.20, 0.06, 0.20), (x, 2.26, 1.00), "acid")
    # four independent track pods
    for x in (-1.45, 1.45):
        for y in (-1.25, 1.25):
            hull.box((0.70, 1.90, 0.80), (x, y, 0.42), "rubber", taper=(1.0, 0.8))
            hull.box((0.76, 1.30, 0.26), (x, y, 0.78), "hull_light")
            hull.box((0.78, 0.50, 0.28), (x, y, 0.80), "team")
            for dy in (-0.55, 0.0, 0.55):
                hull.cyl(0.24, 0.74, (x, y + dy, 0.32), "gunmetal", rot=(0, 90, 0), segments=8)
    hull.finish(bevel=0.04)

    turret = fl.Part("turret", root, pivot=(0.0, 0.30, 1.30))
    turret.box((2.00, 2.30, 0.70), (0, 0.40, 1.68), "hull", taper=(0.74, 0.70))
    turret.box((1.50, 0.80, 0.50), (0, -0.90, 1.62), "hull_light", taper=(0.6, 0.8))
    turret.box((0.70, 0.60, 0.06), (0, 0.50, 2.05), "team")
    turret.box((0.50, 0.90, 0.36), (-0.80, 0.50, 2.00), "olive")
    turret.box((0.36, 0.06, 0.16), (-0.80, 0.04, 2.02), "acid")
    turret.box((0.50, 0.50, 0.30), (0.70, 0.80, 2.05), "rust")
    turret_obj = turret.finish(bevel=0.04)

    barrel = fl.Part("barrel", turret_obj, pivot=(0.0, -1.20, 1.64))
    for x in (-0.26, 0.26):
        barrel.box((0.26, 2.60, 0.26), (x, -2.50, 1.64), "gunmetal")
        barrel.box((0.34, 0.50, 0.34), (x, -3.60, 1.64), "hull_light")
        barrel.box((0.16, 0.06, 0.16), (x, -3.87, 1.64), "acid")
    barrel.box((0.90, 0.70, 0.44), (0, -1.50, 1.64), "olive")
    barrel.finish(bevel=0.02)
    return root
