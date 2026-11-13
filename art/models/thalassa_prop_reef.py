"""Thalassa reef rock: a dark, water-worn outcrop with pale barnacle bands. Cover."""

import fl


def build():
    root = fl.root("thalassa_prop_reef")
    body = fl.Part("body", root)
    body.box((3.4, 2.4, 1.3), (0, 0, 0.65), "stone_dark", taper=(0.75, 0.7), rot=(0, 0, 8))
    body.box((2.2, 1.7, 1.2), (-0.3, 0.1, 1.7), "gunmetal", taper=(0.6, 0.65), rot=(4, -3, 24))
    body.box((1.3, 1.1, 0.9), (0.9, -0.4, 1.5), "stone_dark", taper=(0.6, 0.6), rot=(-6, 5, -20))
    body.box((3.0, 2.1, 0.14), (0, 0, 0.42), "ceramic_shade", taper=(0.95, 0.95), rot=(0, 0, 8))
    body.box((1.0, 0.9, 0.5), (1.9, 0.9, 0.25), "gunmetal", taper=(0.7, 0.7), rot=(0, 8, 40))
    body.box((0.7, 0.6, 0.4), (-1.9, -0.9, 0.2), "stone_dark", taper=(0.7, 0.7), rot=(6, 0, 15))
    body.finish(bevel=0.1)
    return root
