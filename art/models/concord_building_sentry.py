"""Concord Sentry: a defence turret with twin repeaters on an armoured base."""

import fl


def build():
    root = fl.root("concord_building_sentry")
    body = fl.Part("body", root)
    body.cyl(2.0, 0.4, (0, 0, 0.2), "graphite", segments=8, radius_top=1.8)
    body.cyl(1.6, 1.2, (0, 0, 1.0), "ceramic", segments=8, radius_top=1.15)
    body.cyl(1.2, 0.26, (0, 0, 1.5), "orange", segments=8, radius_top=1.14)
    body.cyl(0.9, 0.3, (0, 0, 1.75), "graphite", segments=12)
    for x, y in ((1.25, 1.25), (-1.25, 1.25), (1.25, -1.25), (-1.25, -1.25)):
        body.box((0.7, 0.7, 0.5), (x, y, 0.5), "ceramic_shade")
    body.finish(bevel=0.05)

    turret = fl.Part("turret", root, pivot=(0.0, 0.0, 1.9))
    turret.box((1.5, 1.7, 0.8), (0, 0.1, 2.35), "ceramic", taper=(0.8, 0.8))
    turret.box((0.7, 0.7, 0.06), (0, 0.2, 2.78), "team")
    turret.box((0.6, 0.3, 0.3), (0, -0.74, 2.42), "glow_cyan")
    turret.cyl(0.05, 0.9, (0.5, 0.6, 3.1), "steel", segments=6)
    for x in (-0.95, 0.95):
        turret.box((0.44, 1.3, 0.5), (x, 0.0, 2.3), "graphite")
        turret.box((0.46, 0.5, 0.52), (x, 0.3, 2.3), "team")
        for dz in (-0.11, 0.11):
            turret.cyl(0.06, 1.2, (x, -1.2, 2.3 + dz), "steel", rot=(90, 0, 0), segments=8)
        turret.box((0.2, 0.06, 0.34), (x, -0.67, 2.3), "glow_cyan")
    turret.finish(bevel=0.04)
    return root
