"""Custodian Sentinel: a heavy Antecedent guardian that fires from range.

A floating stone prism with a brass collar; `turret` is the lens head that aims,
`dish` the ring of shards that turns round it.
"""

import fl


def build():
    root = fl.root("custodian_unit_sentinel")
    body = fl.Part("body", root)
    body.cyl(1.2, 1.6, (0, 0, 1.5), "stone", segments=4, radius_top=0.9, rot=(0, 0, 45))
    body.cyl(0.9, 0.7, (0, 0, 0.5), "stone_dark", segments=4, radius_top=1.2, rot=(0, 0, 45))
    body.cyl(1.26, 0.2, (0, 0, 1.0), "brass", segments=4, rot=(0, 0, 45))
    body.cyl(0.5, 0.14, (0, 0, 0.1), "glow_white", segments=4, rot=(0, 0, 45))
    for x in (-1.0, 1.0):
        body.box((0.3, 1.0, 1.5), (x * 1.25, 0, 1.4), "stone_dark", taper=(0.6, 0.5))
        body.box((0.08, 0.5, 1.0), (x * 1.42, 0, 1.4), "glow_white")
    body.finish(bevel=0.04)

    head = fl.Part("turret", root, pivot=(0.0, 0.0, 2.6))
    head.cyl(0.7, 0.5, (0, 0, 2.6), "brass", segments=8)
    head.box((0.8, 1.5, 0.6), (0, -0.4, 3.0), "stone", taper=(0.6, 0.7))
    head.cyl(0.3, 0.3, (0, -1.25, 3.0), "glow_white", rot=(90, 0, 0), segments=8)
    head.cyl(0.36, 0.14, (0, -1.1, 3.0), "brass", rot=(90, 0, 0), segments=8)
    head.finish(bevel=0.03)

    shards = fl.Part("dish", root, pivot=(0.0, 0.0, 1.9))
    for i in range(5):
        angle = fl.math.radians(72 * i)
        x, y = 2.0 * fl.math.cos(angle), 2.0 * fl.math.sin(angle)
        shards.box((0.24, 0.6, 1.3), (x, y, 1.9), "stone", rot=(0, 0, 72 * i), taper=(0.4, 0.3))
        shards.box((0.26, 0.3, 0.2), (x, y, 1.9), "brass", rot=(0, 0, 72 * i))
    shards.finish(bevel=0.02)
    return root
