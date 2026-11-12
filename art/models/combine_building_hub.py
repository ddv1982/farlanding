"""Combine Hub: the enemy headquarters. A squat armoured ziggurat with a drill mast."""

import fl


def build():
    root = fl.root("combine_building_hub")
    body = fl.Part("body", root)
    body.box((13.0, 13.0, 0.6), (0, 0, 0.3), "gunmetal")
    body.box((11.0, 11.0, 2.6), (0, 0, 1.9), "hull", taper=(0.82, 0.82))
    body.box((11.1, 11.1, 0.5), (0, 0, 1.0), "olive")
    body.box((7.4, 7.4, 2.2), (0, 0.4, 4.2), "hull_light", taper=(0.78, 0.78))
    body.box((4.2, 4.2, 1.6), (0, 0.8, 6.0), "hull", taper=(0.7, 0.7))
    body.box((2.4, 2.4, 0.1), (0, 0.8, 6.85), "team")
    # gate with acid-lit maw
    body.box((5.0, 0.8, 2.6), (0, -5.3, 1.7), "hull_light")
    body.box((3.8, 0.4, 2.0), (0, -5.62, 1.5), "acid")
    body.box((4.6, 2.6, 0.3), (0, -6.9, 0.5), "gunmetal", rot=(-7, 0, 0))
    # corner buttresses with team plates
    for x in (-5.4, 5.4):
        for y in (-5.4, 5.4):
            body.box((2.0, 2.0, 3.6), (x, y, 2.1), "hull", taper=(0.6, 0.6))
            body.box((1.0, 1.0, 0.1), (x, y, 3.95), "team")
            body.box((0.5, 0.5, 0.5), (x, y, 4.2), "acid")
    # mast and vents
    body.cyl(0.5, 5.0, (0, 0.8, 9.2), "gunmetal", segments=6, radius_top=0.2)
    body.box((0.3, 0.3, 0.3), (0, 0.8, 11.8), "acid")
    for x in (-2.6, 2.6):
        body.cyl(0.7, 2.6, (x, 3.0, 5.6), "rust", segments=6, radius_top=0.5)
        body.cyl(0.52, 0.2, (x, 3.0, 6.95), "acid", segments=6)
    body.finish(bevel=0.09)
    return root
