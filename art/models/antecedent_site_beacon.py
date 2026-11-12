"""Antecedent beacon: a dormant obelisk on the Trail. Glows once scanned."""

import fl


def build():
    root = fl.root("antecedent_site_beacon")
    body = fl.Part("body", root)
    body.cyl(3.0, 0.5, (0, 0, 0.25), "stone_dark", segments=6, radius_top=2.6)
    body.cyl(2.2, 0.5, (0, 0, 0.75), "stone", segments=6, radius_top=1.8)
    body.cyl(1.1, 6.0, (0, 0, 4.0), "stone", segments=4, radius_top=0.45, rot=(0, 0, 45))
    body.cyl(0.5, 0.9, (0, 0, 7.4), "brass", segments=4, radius_top=0.0, rot=(0, 0, 45))
    for z in (2.0, 3.6, 5.2):
        width = 1.16 - (z - 1.0) * 0.105
        body.cyl(width, 0.14, (0, 0, z), "brass", segments=4, rot=(0, 0, 45))
    # glowing seams up two faces
    body.box((0.10, 0.9, 4.4), (0, -0.52, 3.6), "glow_white", rot=(-6.0, 0, 0))
    body.box((0.10, 0.9, 4.4), (0, 0.52, 3.6), "glow_white", rot=(6.0, 0, 0))
    for i in range(6):
        angle = fl.math.radians(60 * i + 30)
        body.box((0.5, 0.5, 0.9), (2.3 * fl.math.cos(angle), 2.3 * fl.math.sin(angle), 0.9),
                 "stone_dark", taper=(0.5, 0.5))
    body.finish(bevel=0.04)
    return root
