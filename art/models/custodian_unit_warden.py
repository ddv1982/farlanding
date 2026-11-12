"""Custodian Warden: an Antecedent guardian. A hovering core inside three stone blades."""

import fl


def build():
    root = fl.root("custodian_unit_warden")
    body = fl.Part("body", root)
    body.sphere(0.55, (0, 0, 1.7), "glow_white", segments=10)
    body.cyl(0.8, 0.16, (0, 0, 1.7), "brass", segments=8)
    body.cyl(0.5, 0.5, (0, 0, 1.05), "stone_dark", segments=6, radius_top=0.75)
    body.cyl(0.3, 0.3, (0, 0, 0.7), "brass", segments=6, radius_top=0.5)
    body.cyl(0.2, 0.1, (0, 0, 0.5), "glow_white", segments=6)
    body.finish(bevel=0.03)

    blades = fl.Part("dish", root, pivot=(0.0, 0.0, 1.7))
    for i in range(3):
        angle = fl.math.radians(120 * i + 90)
        x, y = 1.25 * fl.math.cos(angle), 1.25 * fl.math.sin(angle)
        blades.box((0.34, 0.9, 2.2), (x, y, 1.7), "stone", rot=(0, 0, 120 * i), taper=(0.5, 0.4))
        blades.box((0.36, 0.5, 0.3), (x, y, 1.7), "brass", rot=(0, 0, 120 * i))
        blades.box((0.1, 0.2, 1.2), (x * 0.86, y * 0.86, 1.7), "glow_white", rot=(0, 0, 120 * i))
    blades.finish(bevel=0.03)
    return root
