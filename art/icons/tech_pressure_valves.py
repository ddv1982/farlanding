"""Tech emblem: a pressure valve with its wheel, venting a jet."""

import math

import fl


def build():
    root = fl.root("tech_pressure_valves")
    body = fl.Part("body", root)
    body.cyl(0.7, 1.2, (0, 0, 0.9), "steel", segments=10)
    body.cyl(0.9, 0.24, (0, 0, 0.3), "graphite", segments=10)
    body.cyl(0.9, 0.24, (0, 0, 1.5), "graphite", segments=10)
    body.cyl(0.45, 1.6, (1.2, 0, 0.9), "steel", rot=(0, 90, 0), segments=10)
    body.cyl(0.16, 1.0, (0, 0, 2.1), "gunmetal", segments=6)
    for i in range(6):
        angle = math.radians(60 * i)
        body.box((1.0, 0.14, 0.14), (math.cos(angle) * 0.5, math.sin(angle) * 0.5, 2.6),
                 "orange", rot=(0, 0, math.degrees(angle)))
    body.cyl(1.05, 0.14, (0, 0, 2.6), "orange", segments=16)
    body.cyl(0.9, 0.16, (0, 0, 2.6), "black", segments=16)
    body.cyl(0.4, 1.3, (2.6, 0, 0.9), "glow_cyan", rot=(0, 90, 0), segments=8, radius_top=0.08)
    body.finish(bevel=0.03)
    return root
