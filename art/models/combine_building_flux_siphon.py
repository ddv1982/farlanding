"""Combine Flux Siphon: a squat pump clamped over a vent, all pipes and rust."""

import math

import fl


def build():
    root = fl.root("combine_building_flux_siphon")
    body = fl.Part("body", root)
    body.cyl(2.7, 0.5, (0, 0, 0.25), "hull", segments=6, radius_top=2.4)
    body.cyl(1.2, 0.5, (0, 0, 0.6), "glow_orange", segments=10)
    # four clamps biting into the vent's rim
    for i in range(4):
        angle = math.radians(45 + 90 * i)
        cx, cy = math.cos(angle), math.sin(angle)
        body.box((0.7, 1.5, 1.6), (cx * 1.7, cy * 1.7, 1.1), "hull_light", rot=(0, 0, 45 + 90 * i + 90),
                 taper=(0.7, 0.6))
        body.box((0.74, 0.5, 0.3), (cx * 1.7, cy * 1.7, 1.5), "team", rot=(0, 0, 45 + 90 * i + 90))
    # pump drum and stack
    body.cyl(1.5, 1.6, (0, 0, 2.2), "olive", segments=8, radius_top=1.3)
    body.cyl(1.56, 0.3, (0, 0, 1.9), "rust", segments=8)
    body.cyl(1.1, 0.5, (0, 0, 3.2), "hull", segments=8, radius_top=0.8)
    body.cyl(0.4, 1.8, (0.4, 0.3, 4.2), "rust", segments=6, radius_top=0.3)
    body.cyl(0.32, 0.12, (0.4, 0.3, 5.1), "acid", segments=6)
    body.box((0.9, 0.12, 0.4), (0, -1.36, 2.4), "acid")
    # side tank and pipework
    body.cyl(0.8, 2.0, (-2.0, 1.6, 1.3), "hull_light", rot=(90, 0, 40), segments=8)
    body.cyl(0.84, 0.4, (-2.0, 1.6, 1.3), "team", rot=(90, 0, 40), segments=8)
    body.cyl(0.16, 2.0, (-1.0, 0.8, 2.3), "rust", rot=(0, 70, -40), segments=6)
    body.cyl(0.16, 1.6, (1.4, 0.9, 2.0), "gunmetal", rot=(0, 60, 30), segments=6)
    body.finish(bevel=0.04)
    return root
