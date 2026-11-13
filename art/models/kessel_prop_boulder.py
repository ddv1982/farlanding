"""Kessel boulder: wind-cut basin rock, natural cover."""

import fl


def build():
    root = fl.root("kessel_prop_boulder")
    body = fl.Part("body", root)
    body.box((3.4, 3.0, 2.2), (0, 0, 1.0), "kessel_rock", rot=(4, -6, 12), taper=(0.7, 0.75))
    body.box((2.2, 2.4, 1.6), (0.9, -0.5, 1.9), "kessel_rock_pale", rot=(-8, 5, 34),
             taper=(0.6, 0.7))
    body.box((1.8, 1.6, 1.2), (-1.5, 0.8, 0.5), "kessel_rock", rot=(6, 10, -20), taper=(0.7, 0.6))
    body.box((1.2, 1.0, 0.7), (1.6, 1.3, 0.3), "kessel_rock_pale", rot=(0, -8, 50),
             taper=(0.75, 0.7))
    body.box((3.0, 2.6, 0.2), (0.1, 0.1, 1.5), "kessel_rock_pale", rot=(4, -6, 12))
    body.finish(bevel=0.08)
    return root
