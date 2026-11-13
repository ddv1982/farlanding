"""Tech emblem: a survey dish pushing its scan deeper into the ground."""

import fl


def build():
    root = fl.root("tech_deep_scan")
    body = fl.Part("body", root)
    body.cyl(0.9, 0.3, (0, 0, 3.3), "ceramic", segments=12, radius_top=1.5)
    body.cyl(0.5, 0.1, (0, 0, 3.2), "orange", segments=12)
    body.cyl(0.12, 0.6, (0, 0, 3.7), "steel", segments=6)
    body.sphere(0.2, (0, 0, 4.0), "glow_cyan", segments=8)
    for i, radius in enumerate((1.3, 1.0, 0.7, 0.4)):
        body.cyl(radius, 0.12, (0, 0, 2.5 - i * 0.65), "glow_cyan", segments=16)
        body.cyl(radius - 0.14, 0.14, (0, 0, 2.5 - i * 0.65), "graphite", segments=16)
    body.cyl(1.7, 0.1, (0, 0, 0.05), "kessel_rock", segments=10)
    body.finish(bevel=0.02)
    return root
