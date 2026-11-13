"""Tech emblem: a faster mining drill, bit spinning into the rock."""

import fl


def build():
    root = fl.root("tech_rapid_drills")
    body = fl.Part("body", root)
    body.box((1.5, 1.5, 1.2), (0, 0, 3.3), "ceramic")
    body.box((1.56, 1.56, 0.3), (0, 0, 3.4), "orange")
    body.box((0.5, 0.1, 0.3), (0, -0.78, 3.0), "glow_cyan")
    body.cyl(0.5, 0.5, (0, 0, 2.5), "graphite", segments=10)
    for i in range(5):
        radius = 0.75 - i * 0.14
        body.cyl(radius, 0.34, (0, 0, 2.1 - i * 0.36), "steel", segments=8,
                 radius_top=radius + 0.1, rot=(0, 0, i * 22))
    body.cyl(1.5, 0.3, (0, 0, 0.15), "kessel_rock", segments=8, radius_top=1.1)
    body.box((0.4, 0.3, 0.3), (1.0, -0.6, 0.45), "kessel_rock_pale", rot=(10, 20, 30))
    body.box((0.3, 0.3, 0.24), (-0.9, 0.5, 0.42), "kessel_rock_pale", rot=(0, 15, 50))
    body.finish(bevel=0.03)
    return root
