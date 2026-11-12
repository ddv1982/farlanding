"""Concord Flux Tap: pumps Flux from a vent. A derrick over a glowing well."""

import math

import fl


def build():
    root = fl.root("concord_building_flux_tap")
    body = fl.Part("body", root)
    body.cyl(2.6, 0.4, (0, 0, 0.2), "graphite", segments=8, radius_top=2.4)
    body.cyl(1.2, 0.5, (0, 0, 0.55), "glow_orange", segments=12)
    # three legs meeting at the pump head
    for i in range(3):
        angle = math.radians(90 + 120 * i)
        cx, cy = math.cos(angle), math.sin(angle)
        body.box((0.36, 0.36, 4.4), (cx * 1.25, cy * 1.25, 2.4), "ceramic",
                 rot=(math.degrees(math.atan2(cy, 4.2)) * 6.2, -math.degrees(math.atan2(cx, 4.2)) * 6.2, 0))
        body.box((0.9, 0.9, 0.3), (cx * 2.0, cy * 2.0, 0.5), "ceramic_shade")
    body.cyl(0.9, 1.0, (0, 0, 4.4), "ceramic", segments=10, radius_top=0.6)
    body.cyl(0.94, 0.3, (0, 0, 4.2), "orange", segments=10)
    body.cyl(0.4, 0.1, (0, 0, 4.95), "team", segments=10)
    body.cyl(0.22, 3.6, (0, 0, 2.4), "copper", segments=8)
    for z in (1.6, 2.6, 3.4):
        body.cyl(0.34, 0.2, (0, 0, z), "glow_orange", segments=8)
    # storage tank and feed pipe
    body.cyl(0.9, 1.8, (1.9, -1.5, 1.2), "ceramic", segments=12)
    body.cyl(0.94, 0.4, (1.9, -1.5, 1.5), "team", segments=12)
    body.cyl(0.14, 2.2, (1.0, -0.8, 1.9), "copper", rot=(0, 90, 40), segments=6)
    body.finish(bevel=0.05)
    return root
