"""Combine Scrapper: armoured ore truck that strips Alloy deposits."""

import fl


def build():
    root = fl.root("combine_unit_scrapper")
    body = fl.Part("body", root)
    body.box((1.60, 3.50, 0.30), (0, 0, 0.66), "gunmetal")
    # low armoured cab with an acid visor
    body.box((1.70, 1.10, 0.80), (0, -1.15, 1.18), "hull", taper=(0.8, 0.7))
    body.box((1.10, 0.10, 0.22), (0, -1.66, 1.28), "acid")
    body.box((0.70, 0.50, 0.05), (0, -1.10, 1.60), "team")
    # slab-sided ore bin with rust ore and a rear tooth bar
    body.box((1.96, 2.30, 0.90), (0, 0.62, 1.22), "hull_light", taper=(1.06, 1.02))
    body.box((1.70, 2.06, 0.20), (0, 0.62, 1.62), "rust")
    body.box((2.02, 0.50, 0.30), (0, 0.62, 1.10), "olive")
    for x in (-1.03, 1.03):
        body.box((0.08, 1.40, 0.40), (x, 0.62, 1.30), "team")
    for x in (-0.6, 0.0, 0.6):
        body.box((0.30, 0.30, 0.50), (x, 1.85, 0.92), "gunmetal", taper=(0.3, 1.0))
    # grinder jaw under the nose
    body.box((1.50, 0.50, 0.36), (0, -1.86, 0.70), "gunmetal", taper=(1.0, 0.5))
    for x in (-0.5, 0.0, 0.5):
        body.box((0.16, 0.10, 0.16), (x, -2.12, 0.66), "acid")
    body.finish(bevel=0.035)

    for side, x in (("l", -0.96), ("r", 0.96)):
        for index, y in enumerate((-1.15, 0.95)):
            wheel = fl.Part(f"wheel_{side}{index}", root, pivot=(x, y, 0.52))
            wheel.cyl(0.52, 0.44, (x, y, 0.52), "rubber", rot=(0, 90, 0), segments=14)
            wheel.cyl(0.28, 0.48, (x, y, 0.52), "gunmetal", rot=(0, 90, 0), segments=8)
            wheel.finish(bevel=0.04)
    return root
