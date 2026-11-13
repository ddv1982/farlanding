"""Combine supply crates: a strapped stack, cover for anything that keeps low."""

import fl


def build():
    root = fl.root("combine_prop_crates")
    body = fl.Part("body", root)
    body.box((1.5, 1.9, 1.0), (-0.72, 0, 0.5), "olive")
    body.box((1.4, 1.9, 1.0), (0.76, 0.02, 0.5), "hull_light")
    body.box((1.5, 1.5, 0.95), (-0.3, 0.1, 1.48), "hull", rot=(0, 0, 9))
    for x in (-0.72, 0.76):
        body.box((1.56, 0.12, 1.04), (x, -0.55, 0.5), "gunmetal")
        body.box((1.56, 0.12, 1.04), (x, 0.55, 0.5), "gunmetal")
    body.box((0.5, 0.05, 0.3), (0.76, -0.96, 0.6), "acid")
    body.box((0.4, 0.4, 0.05), (-0.3, 0.1, 1.97), "rust")
    body.box((0.7, 0.5, 0.4), (1.2, 0.9, 1.2), "rust", rot=(0, 0, -14))
    body.finish(bevel=0.03)
    return root
