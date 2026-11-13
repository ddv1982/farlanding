"""Tech emblem: resonance keys, a tuning fork ringing over an Antecedent plate."""

import fl


def build():
    root = fl.root("tech_resonance_keys")
    body = fl.Part("body", root)
    body.cyl(2.0, 0.3, (0, 0, 0.15), "stone_dark", segments=8)
    body.cyl(1.5, 0.08, (0, 0, 0.34), "glow_white", segments=8)
    body.cyl(1.3, 0.1, (0, 0, 0.34), "stone", segments=8)
    body.cyl(0.18, 1.4, (0, 0, 1.0), "brass", segments=8)
    body.box((1.5, 0.3, 0.3), (0, 0, 1.8), "brass")
    for x in (-1.0, 1.0):
        body.box((0.3, 0.3, 2.4), (x * 0.6, 0, 3.0), "brass")
        body.box((0.12, 0.34, 1.6), (x * 1.1, 0, 3.2), "glow_cyan")
        body.box((0.08, 0.34, 1.0), (x * 1.5, 0, 3.2), "glow_cyan")
    body.finish(bevel=0.03)
    return root
