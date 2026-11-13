"""Field option emblem: the Beacon Lance, an Antecedent spire discharging."""

import fl


def build():
    root = fl.root("option_antecedent_power")
    body = fl.Part("body", root)
    body.cyl(1.3, 0.3, (0, 0, 0.15), "stone_dark", segments=6, radius_top=1.1)
    body.cyl(0.7, 1.6, (0, 0, 1.1), "stone", segments=6, radius_top=0.4)
    body.cyl(0.74, 0.14, (0, 0, 0.6), "brass", segments=6)
    body.cyl(0.46, 0.12, (0, 0, 1.9), "brass", segments=6)
    body.cyl(0.16, 2.2, (0, 0, 3.0), "glow_white", segments=6)
    body.cyl(0.5, 0.5, (0, 0, 2.2), "glow_white", segments=6, radius_top=0.16)
    for i in range(3):
        angle = fl.math.radians(120 * i)
        body.box((0.14, 0.14, 0.9), (1.0 * fl.math.cos(angle), 1.0 * fl.math.sin(angle), 0.9),
                 "brass", rot=(0, 0, 120 * i))
    body.finish(bevel=0.02)
    return root
