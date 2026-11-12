"""Concord Kite: fast hover skimmer for raids and flanking."""

import fl


def build():
    root = fl.root("concord_unit_kite")

    body = fl.Part("body", root)
    # dart-shaped hull floating above the ground
    body.box((1.10, 2.60, 0.34), (0, 0.10, 0.82), "ceramic", taper=(0.70, 0.86))
    body.box((0.80, 1.20, 0.30), (0, -1.35, 0.74), "ceramic", rot=(12, 0, 0), taper=(0.5, 0.6))
    body.box((0.60, 0.80, 0.26), (0, -0.30, 1.06), "glass", rot=(-10, 0, 0), taper=(0.7, 0.6))
    body.box((0.70, 0.90, 0.22), (0, 0.72, 1.04), "ceramic_shade", taper=(0.8, 0.8))
    body.box((1.14, 0.60, 0.14), (0, 0.60, 0.84), "orange")
    body.box((0.44, 0.50, 0.05), (0, 0.74, 1.16), "team")
    body.box((0.90, 1.90, 0.08), (0, 0.10, 0.60), "glow_cyan")
    # outrigger thruster pods on stub wings
    for x in (-1.00, 1.00):
        body.box((0.80, 0.50, 0.10), (x * 0.62, 0.50, 0.84), "ceramic_shade")
        body.box((0.50, 0.34, 0.06), (x * 0.66, 0.50, 0.90), "team")
        body.cyl(0.26, 1.30, (x, 0.50, 0.82), "graphite", rot=(90, 0, 0), segments=12)
        body.cyl(0.20, 0.20, (x, -0.22, 0.82), "steel", rot=(90, 0, 0), segments=12)
        body.cyl(0.19, 0.08, (x, 1.16, 0.82), "glow_cyan", rot=(90, 0, 0), segments=12)
        body.box((0.06, 0.50, 0.46), (x, 0.92, 1.10), "ceramic", taper=(1.0, 0.5))
    # chin gun
    body.cyl(0.05, 0.80, (0, -1.80, 0.62), "steel", rot=(90, 0, 0), segments=8)
    body.box((0.20, 0.40, 0.16), (0, -1.40, 0.60), "graphite")
    body.finish(bevel=0.03)
    return root
