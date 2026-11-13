"""Tech emblem: a second survey satellite, so the orbital scan comes round sooner."""

import fl


def build():
    root = fl.root("tech_scan_discount")
    body = fl.Part("body", root)
    for x, z, s in ((-0.9, 2.9, 1.0), (1.0, 1.5, 0.75)):
        body.box((0.7 * s, 0.7 * s, 0.8 * s), (x, 0, z), "ceramic")
        body.box((0.74 * s, 0.74 * s, 0.16 * s), (x, 0, z + 0.15 * s), "orange")
        for side in (-1.0, 1.0):
            body.box((1.2 * s, 0.06, 0.6 * s), (x + side * 1.0 * s, 0, z), "glass")
        body.cyl(0.22 * s, 0.3 * s, (x, 0, z - 0.5 * s), "glow_cyan", segments=8,
                 radius_top=0.1 * s)
    body.cyl(1.9, 0.06, (0, 0, 0.3), "glow_cyan", segments=20)
    body.cyl(1.76, 0.08, (0, 0, 0.3), "graphite", segments=20)
    body.finish(bevel=0.02)
    return root
