"""Tech emblem: Talon plating, a fan ring behind layered armour plates."""

import fl


def build():
    root = fl.root("tech_talon_plating")
    body = fl.Part("body", root)
    body.cyl(1.5, 0.5, (0, 0.5, 2.0), "graphite", rot=(90, 0, 0), segments=18)
    body.cyl(1.2, 0.54, (0, 0.5, 2.0), "glow_cyan", rot=(90, 0, 0), segments=18)
    for i, (x, z) in enumerate(((-0.7, 2.6), (0.5, 2.0), (-0.3, 1.2))):
        body.box((2.0, 0.2, 1.0), (x, -0.3 - 0.15 * i, z), "ceramic", taper=(0.8, 1.0))
        body.box((2.0, 0.24, 0.16), (x, -0.32 - 0.15 * i, z - 0.3), "orange")
    body.finish(bevel=0.04)
    return root
