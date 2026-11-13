"""The Beacon Core: the end of the Trail, on the dais of Hollow Meridian.

Part `body` is the dormant structure. Part `active` holds what lights up when the
Core wakes. Part `dish` is the pair of rings that turn while it is awake.
"""

import fl


def build():
    root = fl.root("antecedent_site_core")
    body = fl.Part("body", root)
    body.cyl(7.0, 0.6, (0, 0, 0.3), "stone_dark", segments=8, radius_top=6.6)
    body.cyl(5.4, 0.6, (0, 0, 0.9), "stone", segments=8, radius_top=5.0)
    body.cyl(3.2, 0.8, (0, 0, 1.6), "stone_dark", segments=8, radius_top=2.6)
    # the spire: a split obelisk with a gap for the light
    for x in (-1.0, 1.0):
        body.box((1.3, 2.2, 11.0), (x * 1.15, 0, 7.4), "stone", taper=(0.55, 0.4))
        body.box((1.34, 2.24, 0.3), (x * 1.12, 0, 4.4), "brass")
        body.box((1.1, 1.9, 0.3), (x * 0.96, 0, 8.6), "brass")
        body.box((0.5, 1.0, 1.2), (x * 0.62, 0, 13.3), "brass", taper=(0.2, 0.2))
    # eight standing stones round the foot
    for i in range(8):
        angle = fl.math.radians(45 * i + 22.5)
        x, y = 5.6 * fl.math.cos(angle), 5.6 * fl.math.sin(angle)
        body.box((0.9, 0.9, 2.6), (x, y, 2.3), "stone", rot=(0, 0, 45 * i + 22.5), taper=(0.6, 0.6))
        body.box((0.94, 0.94, 0.2), (x, y, 2.9), "brass", rot=(0, 0, 45 * i + 22.5))
    body.finish(bevel=0.05)

    rings = fl.Part("dish", root, pivot=(0.0, 0.0, 7.0))
    for radius, z, count in ((3.6, 6.0, 10), (2.8, 9.4, 8)):
        for i in range(count):
            angle = fl.math.radians(360.0 / count * i)
            x, y = radius * fl.math.cos(angle), radius * fl.math.sin(angle)
            rings.box((0.5, 1.7, 0.5), (x, y, z), "brass" if i % 2 else "stone_dark",
                      rot=(0, 0, 360.0 / count * i))
    rings.finish(bevel=0.03)

    active = fl.Part("active", root)
    active.box((0.5, 1.2, 9.6), (0, 0, 7.4), "glow_white")
    active.sphere(1.1, (0, 0, 13.6), "glow_white", segments=12)
    active.cyl(5.44, 0.08, (0, 0, 1.22), "glow_white", segments=8)
    for i in range(8):
        angle = fl.math.radians(45 * i + 22.5)
        x, y = 5.6 * fl.math.cos(angle), 5.6 * fl.math.sin(angle)
        active.box((0.14, 0.5, 1.8), (x * 0.92, y * 0.92, 2.3), "glow_white", rot=(0, 0, 45 * i + 22.5))
    active.finish(bevel=0.0)
    return root
