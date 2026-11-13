"""Tech emblem: heat shielding, a ceramic plate holding off a burst of fire."""

import fl


def build():
    root = fl.root("tech_heat_shielding")
    body = fl.Part("body", root)
    body.box((2.6, 0.3, 2.6), (0, -0.4, 2.0), "ceramic", taper=(0.75, 1.0), rot=(170, 0, 0))
    body.box((2.2, 0.34, 0.3), (0, -0.44, 2.7), "orange")
    body.box((1.4, 0.34, 0.2), (0, -0.44, 1.5), "graphite")
    for i, x in enumerate((-0.8, 0.0, 0.8)):
        body.cyl(0.32, 1.4 + 0.5 * (i % 2), (x, 0.7, 1.2 + 0.25 * (i % 2)), "glow_orange",
                 segments=6, radius_top=0.05)
    body.cyl(1.5, 0.2, (0, 0.5, 0.1), "black", segments=8)
    body.finish(bevel=0.04)
    return root
