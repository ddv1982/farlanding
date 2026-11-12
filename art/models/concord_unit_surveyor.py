"""Concord Surveyor: fast unarmed scout rover with a scanner dish."""

import fl


def build():
    root = fl.root("concord_unit_surveyor")

    body = fl.Part("body", root)
    # underframe and suspension beam
    body.box((1.10, 2.30, 0.22), (0, 0, 0.52), "graphite")
    body.box((1.70, 0.16, 0.14), (0, -0.78, 0.46), "steel")
    body.box((1.70, 0.16, 0.14), (0, 0.78, 0.46), "steel")
    # hull: wedge nose, cabin, rear deck
    body.box((1.30, 2.40, 0.36), (0, 0, 0.80), "ceramic", taper=(0.92, 0.96))
    body.box((1.10, 1.05, 0.40), (0, -0.25, 1.14), "ceramic", taper=(0.78, 0.70))
    body.box((0.84, 0.50, 0.30), (0, -0.62, 1.13), "glass", rot=(-28, 0, 0))
    body.box((1.20, 0.80, 0.16), (0, 0.72, 1.04), "ceramic_shade")
    # colour blocking
    body.box((1.34, 0.95, 0.17), (0, 0.20, 0.86), "orange")
    body.box((0.62, 0.50, 0.05), (0, -0.25, 1.34), "team")
    body.box((0.50, 0.30, 0.05), (0, 0.98, 1.13), "team")
    # fenders
    for x in (-0.80, 0.80):
        for y in (-0.78, 0.78):
            body.box((0.40, 0.98, 0.07), (x, y, 0.88), "ceramic_shade")
    body.box((1.34, 0.12, 0.16), (0, -1.16, 0.72), "graphite")
    # lamps and tail lights
    for x in (-0.45, 0.45):
        body.box((0.20, 0.06, 0.08), (x, -1.20, 0.84), "glow_cyan")
        body.box((0.14, 0.05, 0.06), (x, 1.20, 0.86), "glow_orange")
    # equipment: side pods and mast base
    for x in (-0.70, 0.70):
        body.box((0.14, 0.70, 0.22), (x, 0.55, 0.86), "ceramic_shade")
    body.cyl(0.10, 0.50, (0.0, 0.62, 1.34), "steel", segments=12)
    body.finish(bevel=0.03)

    for name, x, y in (("wheel_fl", -0.80, -0.78), ("wheel_fr", 0.80, -0.78),
                       ("wheel_rl", -0.80, 0.78), ("wheel_rr", 0.80, 0.78)):
        wheel = fl.Part(name, root, pivot=(x, y, 0.40))
        wheel.cyl(0.40, 0.30, (x, y, 0.40), "rubber", rot=(0, 90, 0), segments=20)
        wheel.cyl(0.22, 0.34, (x, y, 0.40), "steel", rot=(0, 90, 0), segments=10)
        wheel.cyl(0.09, 0.38, (x, y, 0.40), "orange", rot=(0, 90, 0), segments=8)
        wheel.finish(bevel=0.04)

    dish = fl.Part("dish", root, pivot=(0.0, 0.62, 1.60))
    dish.cyl(0.42, 0.10, (0, 0.50, 1.86), "ceramic", rot=(62, 0, 0), radius_top=0.30)
    dish.cyl(0.26, 0.04, (0, 0.47, 1.88), "graphite", rot=(62, 0, 0))
    dish.cyl(0.03, 0.34, (0, 0.38, 1.94), "steel", rot=(62, 0, 0), segments=8)
    dish.sphere(0.07, (0, 0.24, 2.02), "glow_cyan", segments=10)
    dish.box((0.10, 0.10, 0.30), (0, 0.62, 1.70), "steel")
    dish.finish(bevel=0.015)
    return root
