"""Tech emblem: a supply pod landed with its cargo beside it."""

import fl


def build():
    root = fl.root("tech_supply_manifest")
    body = fl.Part("body", root)
    body.cyl(1.0, 2.0, (-0.6, 0, 1.3), "ceramic", segments=8, radius_top=0.8)
    body.cyl(1.02, 0.3, (-0.6, 0, 1.5), "orange", segments=8)
    body.cyl(0.8, 0.5, (-0.6, 0, 2.5), "ceramic_shade", segments=8, radius_top=0.3)
    body.cyl(1.2, 0.2, (-0.6, 0, 0.2), "graphite", segments=8)
    body.box((0.6, 0.1, 0.8), (-0.6, -0.95, 1.0), "glow_cyan")
    body.box((1.0, 1.0, 0.9), (1.2, -0.4, 0.45), "ceramic_shade")
    body.box((1.04, 0.2, 0.94), (1.2, -0.4, 0.45), "orange")
    body.box((0.8, 0.8, 0.7), (1.3, 0.8, 0.35), "steel")
    body.box((0.7, 0.7, 0.6), (1.15, -0.3, 1.2), "ceramic", rot=(0, 0, 20))
    body.finish(bevel=0.04)
    return root
