"""Concord Hauler: six-wheeled harvester that carries Alloy to the Refinery."""

import fl


def build():
    root = fl.root("concord_unit_hauler")

    body = fl.Part("body", root)
    body.box((1.50, 3.60, 0.26), (0, 0, 0.62), "graphite")
    # cab up front
    body.box((1.70, 1.10, 0.90), (0, -1.20, 1.20), "ceramic", taper=(0.86, 0.80))
    body.box((1.30, 0.30, 0.42), (0, -1.66, 1.34), "glass", rot=(-18, 0, 0))
    body.box((0.70, 0.50, 0.05), (0, -1.16, 1.66), "team")
    for x in (-0.60, 0.60):
        body.box((0.26, 0.06, 0.10), (x, -1.78, 0.96), "glow_cyan")
    # open cargo hopper with ore showing
    body.box((1.90, 2.30, 0.80), (0, 0.60, 1.14), "ceramic_shade", taper=(1.10, 1.04))
    body.box((1.70, 2.10, 0.20), (0, 0.60, 1.50), "copper")
    body.box((1.96, 0.40, 0.30), (0, 0.60, 1.06), "orange")
    for x in (-1.00, 1.00):
        body.box((0.08, 1.40, 0.36), (x, 0.60, 1.20), "team")
    body.box((1.60, 0.10, 0.16), (0, 1.80, 0.92), "hazard")
    # scoop arm folded over the cab
    body.box((0.16, 1.40, 0.16), (0.70, -0.30, 1.86), "steel", rot=(12, 0, 0))
    body.box((0.50, 0.40, 0.30), (0.70, -1.10, 1.74), "orange", taper=(0.7, 0.6))
    body.finish(bevel=0.035)

    for side, x in (("l", -0.92), ("r", 0.92)):
        for index, y in enumerate((-1.25, 0.05, 1.30)):
            wheel = fl.Part(f"wheel_{side}{index}", root, pivot=(x, y, 0.46))
            wheel.cyl(0.46, 0.38, (x, y, 0.46), "rubber", rot=(0, 90, 0), segments=18)
            wheel.cyl(0.24, 0.42, (x, y, 0.46), "steel", rot=(0, 90, 0), segments=10)
            wheel.finish(bevel=0.04)
    return root
