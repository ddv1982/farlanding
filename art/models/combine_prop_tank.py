"""Combine storage tank: a squat pressure vessel on a ring of struts."""

import fl


def build():
    root = fl.root("combine_prop_tank")
    body = fl.Part("body", root)
    body.cyl(1.4, 0.3, (0, 0, 0.15), "gunmetal", segments=8)
    body.cyl(1.3, 2.4, (0, 0, 1.5), "hull_light", segments=10)
    body.cyl(1.3, 0.5, (0, 0, 2.95), "hull", segments=10, radius_top=0.7)
    body.cyl(1.34, 0.22, (0, 0, 1.0), "rust", segments=10)
    body.cyl(1.34, 0.22, (0, 0, 2.2), "olive", segments=10)
    body.cyl(0.3, 0.3, (0, 0, 3.3), "gunmetal", segments=6)
    body.box((0.5, 0.08, 0.7), (0, -1.3, 1.6), "acid")
    body.cyl(0.12, 2.6, (1.1, 0.9, 1.5), "gunmetal", segments=6)
    body.box((0.5, 0.5, 0.4), (1.1, 0.9, 0.2), "hull")
    body.finish(bevel=0.03)
    return root
