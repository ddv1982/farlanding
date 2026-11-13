"""Tech emblem: custodian hush, a guardian's blades folded shut round a dimmed core."""

import fl


def build():
    root = fl.root("tech_custodian_hush")
    body = fl.Part("body", root)
    body.cyl(1.6, 0.3, (0, 0, 0.15), "stone_dark", segments=6)
    body.sphere(0.5, (0, 0, 2.2), "glass", segments=10)
    body.cyl(0.8, 0.16, (0, 0, 2.2), "brass", segments=8)
    for i in range(3):
        angle = fl.math.radians(120 * i + 90)
        x, y = 0.75 * fl.math.cos(angle), 0.75 * fl.math.sin(angle)
        body.box((0.34, 0.9, 3.0), (x, y, 2.2), "stone", rot=(0, 0, 120 * i), taper=(0.5, 0.4))
        body.box((0.36, 0.5, 0.3), (x, y, 2.2), "brass", rot=(0, 0, 120 * i))
    # the hush: a soft ring on the ground round it
    body.cyl(2.3, 0.1, (0, 0, 0.05), "glow_cyan", segments=20)
    body.finish(bevel=0.03)
    return root
