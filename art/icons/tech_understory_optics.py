"""Tech emblem: understory optics, a lens looking out from under a leaf."""

import fl


def build():
    root = fl.root("tech_understory_optics")
    body = fl.Part("body", root)
    body.cyl(1.0, 0.7, (0, 0, 1.5), "graphite", rot=(90, 0, 0), segments=16)
    body.cyl(0.78, 0.2, (0, -0.4, 1.5), "glow_cyan", rot=(90, 0, 0), segments=16)
    body.cyl(1.06, 0.16, (0, -0.2, 1.5), "orange", rot=(90, 0, 0), segments=16)
    body.box((0.6, 0.6, 0.9), (0, 0.2, 0.5), "ceramic_shade")
    body.cyl(0.2, 3.0, (0.3, 1.0, 1.7), "rust", segments=6)
    # the leaf it hides under
    body.cyl(2.1, 0.4, (0.3, 1.0, 3.3), "olive", segments=14, radius_top=1.2)
    body.cyl(1.3, 0.3, (-1.4, 1.2, 2.9), "olive", segments=12, radius_top=0.7)
    body.finish(bevel=0.03)
    return root
