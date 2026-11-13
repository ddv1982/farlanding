"""Action emblem: release a vent's pressure on purpose."""

import fl


def build():
    root = fl.root("action_vent")
    body = fl.Part("body", root)
    body.cyl(1.5, 0.5, (0, 0, 0.25), "kessel_rock", segments=8, radius_top=1.1)
    body.cyl(0.8, 0.3, (0, 0, 0.6), "black", segments=8)
    body.cyl(0.6, 2.6, (0, 0, 2.0), "glow_cyan", segments=8, radius_top=0.12)
    body.cyl(1.0, 0.1, (0, 0, 1.5), "glow_cyan", segments=12)
    body.cyl(0.86, 0.12, (0, 0, 1.5), "black", segments=12)
    body.cyl(0.7, 0.1, (0, 0, 2.4), "glow_cyan", segments=12)
    body.cyl(0.56, 0.12, (0, 0, 2.4), "black", segments=12)
    body.finish(bevel=0.02)
    return root
