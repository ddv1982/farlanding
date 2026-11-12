"""Combine Forge: builds the enemy's machines. A long slab hall with a toothed gate."""

import fl


def build():
    root = fl.root("combine_building_forge")
    body = fl.Part("body", root)
    body.box((10.0, 12.0, 0.5), (0, 0, 0.25), "gunmetal")
    body.box((8.6, 10.0, 3.6), (0, 0.6, 2.3), "hull", taper=(0.86, 0.94))
    body.box((8.7, 10.1, 0.5), (0, 0.6, 1.1), "olive")
    body.box((5.2, 6.4, 0.9), (0, 1.2, 4.5), "hull_light", taper=(0.8, 0.9))
    body.box((3.0, 3.6, 0.1), (0, 1.2, 5.0), "team")
    body.box((5.6, 0.7, 3.0), (0, -4.3, 1.9), "hull_light")
    body.box((4.6, 0.4, 2.4), (0, -4.62, 1.7), "acid")
    for x in (-1.6, -0.5, 0.5, 1.6):
        body.box((0.5, 0.5, 0.9), (x, -4.7, 2.75), "gunmetal", taper=(0.3, 1.0))
    body.box((5.0, 2.4, 0.3), (0, -5.6, 0.5), "gunmetal", rot=(-7, 0, 0))
    for x in (-4.6, 4.6):
        body.box((0.5, 5.0, 1.8), (x, 0.6, 2.4), "team")
        body.cyl(0.6, 3.4, (x * 0.8, 4.2, 5.2), "rust", segments=6, radius_top=0.45)
        body.cyl(0.46, 0.2, (x * 0.8, 4.2, 6.95), "acid", segments=6)
    body.finish(bevel=0.08)
    return root
