"""Tech emblem: armour plate made from the alloy of an Antecedent cache."""

import fl


def build():
    root = fl.root("tech_cache_alloys")
    body = fl.Part("body", root)
    body.box((2.4, 0.3, 2.8), (0, 0, 2.0), "brass", taper=(0.7, 1.0), rot=(180, 0, 0))
    body.box((1.8, 0.36, 2.1), (0, -0.02, 2.05), "stone_dark", taper=(0.7, 1.0), rot=(180, 0, 0))
    for i, width in enumerate((1.3, 1.0, 0.7)):
        body.box((width, 0.44, 0.2), (0, -0.04, 2.7 - i * 0.5), "glow_white")
    for x in (-1.0, 1.0):
        body.cyl(0.12, 0.4, (x * 0.95, 0, 3.1), "steel", rot=(90, 0, 0), segments=6)
    body.box((2.0, 1.2, 0.4), (0, 0.2, 0.2), "stone", taper=(0.85, 0.85))
    body.finish(bevel=0.04)
    return root
