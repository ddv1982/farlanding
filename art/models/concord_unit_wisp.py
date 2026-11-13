"""Concord Wisp: a small, low, stealthy infiltrator skimmer."""

import fl


def build():
    root = fl.root("concord_unit_wisp")
    body = fl.Part("body", root)
    # flat manta shape hugging the ground
    body.box((1.50, 1.90, 0.20), (0, 0.10, 0.62), "graphite", taper=(0.6, 0.8))
    body.box((0.70, 1.30, 0.22), (0, -0.10, 0.78), "ceramic_shade", taper=(0.6, 0.7))
    body.box((0.40, 0.50, 0.14), (0, -0.50, 0.90), "glass", taper=(0.7, 0.6))
    body.box((0.36, 0.36, 0.04), (0, 0.30, 0.90), "team")
    body.box((1.10, 1.30, 0.05), (0, 0.10, 0.50), "glow_cyan")
    for x in (-0.80, 0.80):
        body.box((0.50, 0.90, 0.10), (x, 0.40, 0.64), "graphite", taper=(0.4, 0.8))
        body.box((0.10, 0.50, 0.05), (x * 1.1, 0.50, 0.71), "team")
    # sensor whisker and a small chin emitter
    body.cyl(0.02, 0.90, (0.20, 0.60, 1.26), "steel", segments=6)
    body.box((0.16, 0.24, 0.10), (0, -0.98, 0.60), "orange")
    body.box((0.08, 0.06, 0.06), (0, -1.12, 0.60), "glow_cyan")
    body.finish(bevel=0.02)
    return root
