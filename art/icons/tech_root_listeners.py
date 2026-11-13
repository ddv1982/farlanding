"""Tech emblem: root listeners, a probe in the ground sending rings through the roots."""

import fl


def build():
    root = fl.root("tech_root_listeners")
    body = fl.Part("body", root)
    body.cyl(2.2, 0.2, (0, 0, 0.1), "olive", segments=20)
    body.cyl(1.7, 0.06, (0, 0, 0.24), "glow_cyan", segments=20)
    body.cyl(1.5, 0.08, (0, 0, 0.24), "olive", segments=20)
    body.cyl(1.0, 0.06, (0, 0, 0.3), "glow_cyan", segments=20)
    body.cyl(0.8, 0.08, (0, 0, 0.3), "olive", segments=20)
    body.cyl(0.3, 2.4, (0, 0, 1.4), "ceramic", segments=8, radius_top=0.2)
    body.cyl(0.36, 0.3, (0, 0, 1.9), "orange", segments=8)
    body.sphere(0.4, (0, 0, 2.9), "glow_cyan", segments=10)
    body.finish(bevel=0.02)
    return root
