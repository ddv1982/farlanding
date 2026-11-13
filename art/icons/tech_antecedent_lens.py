"""Tech emblem: an Antecedent lens in its stone ring, lit from within."""

import math

import fl


def build():
    root = fl.root("tech_antecedent_lens")
    body = fl.Part("body", root)
    for i in range(10):
        angle = 2.0 * math.pi * i / 10
        x, z = math.cos(angle) * 1.5, math.sin(angle) * 1.5
        body.box((0.75, 0.6, 0.55), (x, 0, 2.2 + z), "stone" if i % 2 else "stone_dark",
                 rot=(0, -math.degrees(angle) + 90, 0))
    body.cyl(1.15, 0.2, (0, 0, 2.2), "glow_white", rot=(90, 0, 0), segments=20)
    body.cyl(0.6, 0.26, (0, 0, 2.2), "brass", rot=(90, 0, 0), segments=20)
    body.cyl(0.4, 0.3, (0, 0, 2.2), "glow_cyan", rot=(90, 0, 0), segments=20)
    body.box((1.6, 0.9, 0.4), (0, 0, 0.2), "stone_dark", taper=(0.8, 0.8))
    body.finish(bevel=0.04)
    return root
