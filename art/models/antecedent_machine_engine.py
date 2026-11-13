"""Antecedent engine: old machinery that gives power once reactivated.

Part `body` is the dormant machine. Part `active` holds everything that lights up
(show it when the engine runs, hide it while dormant). Part `dish` is the ring that
turns while it runs.
"""

import fl


def build():
    root = fl.root("antecedent_machine_engine")
    body = fl.Part("body", root)
    body.cyl(3.4, 0.5, (0, 0, 0.25), "stone_dark", segments=8, radius_top=3.1)
    body.cyl(2.6, 0.6, (0, 0, 0.8), "stone", segments=8, radius_top=2.3)
    body.cyl(1.3, 2.4, (0, 0, 2.3), "stone", segments=8, radius_top=1.0)
    body.cyl(1.36, 0.2, (0, 0, 1.5), "brass", segments=8)
    body.cyl(1.1, 0.2, (0, 0, 3.4), "brass", segments=8)
    body.cyl(0.7, 0.6, (0, 0, 3.8), "stone_dark", segments=8, radius_top=0.5)
    # four buttresses carrying the ring
    for i in range(4):
        angle = fl.math.radians(90 * i + 45)
        x, y = 2.5 * fl.math.cos(angle), 2.5 * fl.math.sin(angle)
        body.box((0.8, 0.8, 3.6), (x, y, 2.2), "stone", rot=(0, 0, 90 * i + 45), taper=(0.6, 0.6))
        body.box((0.84, 0.84, 0.24), (x, y, 2.9), "brass", rot=(0, 0, 90 * i + 45))
    body.finish(bevel=0.04)

    ring = fl.Part("dish", root, pivot=(0.0, 0.0, 4.4))
    for i in range(8):
        angle = fl.math.radians(45 * i)
        x, y = 2.5 * fl.math.cos(angle), 2.5 * fl.math.sin(angle)
        ring.box((0.5, 1.8, 0.5), (x, y, 4.4), "brass" if i % 2 else "stone_dark",
                 rot=(0, 0, 45 * i))
    ring.finish(bevel=0.03)

    active = fl.Part("active", root)
    active.sphere(0.6, (0, 0, 4.5), "glow_white", segments=10)
    active.cyl(1.34, 0.12, (0, 0, 2.4), "glow_white", segments=8)
    active.cyl(2.64, 0.08, (0, 0, 1.08), "glow_white", segments=8)
    for i in range(4):
        angle = fl.math.radians(90 * i + 45)
        x, y = 2.5 * fl.math.cos(angle), 2.5 * fl.math.sin(angle)
        active.box((0.12, 0.5, 2.6), (x * 0.84, y * 0.84, 2.2), "glow_white", rot=(0, 0, 90 * i + 45))
    active.finish(bevel=0.0)
    return root
