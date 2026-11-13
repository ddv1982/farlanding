"""Field option emblem: a supply pod coming down under its canopy."""

import fl


def build():
    root = fl.root("option_supply_drop")
    body = fl.Part("body", root)
    body.box((1.2, 1.2, 1.0), (0, 0, 0.5), "ceramic")
    body.box((1.26, 1.26, 0.2), (0, 0, 0.5), "orange")
    body.box((0.4, 0.06, 0.4), (0, -0.62, 0.5), "glow_cyan")
    body.box((0.4, 0.4, 0.1), (0, 0, 1.05), "steel")
    body.sphere(1.5, (0, 0, 2.7), "orange", scale=(1.0, 1.0, 0.55))
    body.cyl(1.5, 0.12, (0, 0, 2.6), "ceramic", segments=12)
    for x, y in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
        body.box((0.05, 0.05, 1.9), (x * 0.75, y * 0.75, 1.75), "graphite",
                 rot=(y * 22, -x * 22, 0))
    body.finish(bevel=0.02)
    return root
