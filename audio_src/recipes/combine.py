"""Halcyon Combine movement loops, and the Concord Sentry turret.

Combine machines are salvage-built: inharmonic, detuned, rattling and dirty,
never in the Concord key. Loops follow the movement.py rules (whole cycles,
circular noise, periodic filters, wrapped one-offs), so they are seamless.

  skitter  light drone: two harsh rotors a few hertz apart (a rough beat), ring-modulated, servo ticks
  stinger  six-legged strider: fast irregular leg clicks over an inharmonic electric whine
  mauler   heavy tracked siege walker: a rough saturated engine, squealing idlers, loose clanks

The Sentry is Concord (a building): its machine identity is a servo whir
gliding up A4 -> D5, two lock clicks and a chime on D6+A6. `base_turret_traverse`
is the short whir a turret makes when it swings onto a new target.
"""

from __future__ import annotations

import numpy as np

from synth import dsp
from synth.instruments import chime

from . import sound
from .buildings import BUILDING_LUFS, _finish as building_finish
from .movement import MOVE_LUFS, _finish, lfo, qf


def _grit(x: np.ndarray, drive: float) -> np.ndarray:
    return dsp.saturate(x, drive)


@sound("move_skitter", "movement", MOVE_LUFS, loop=True, folder="movement", min_seconds=1.9, max_seconds=2.1)
def move_skitter(rng: np.random.Generator) -> np.ndarray:
    L = 2.0
    n = dsp.samples(L)
    r1 = dsp.soft_square(qf(117.0, L) * (1.0 + 0.01 * lfo(n, L, 3)), n, 8.0)
    r2 = dsp.soft_square(qf(124.0, L) * (1.0 + 0.012 * lfo(n, L, 5, 0.3)), n, 8.0)
    rotors = (r1 + r2) * (0.7 + 0.3 * dsp.sine(qf(71.0, L), n))  # ring-ish roughness
    rotors = dsp.periodic(dsp.bandpass, _grit(rotors * 1.5, 2.0), 900.0, 0.5) * 0.35
    wash = dsp.periodic(dsp.bandpass, dsp.pink(n, rng), 2000.0, 0.7) * 0.25
    ticks = np.zeros(n + dsp.samples(0.1))
    for i in range(14):
        at = dsp.samples(i * L / 14 + float(rng.uniform(0, 0.02)))
        m = dsp.samples(0.03)
        tick = dsp.bandpass(dsp.white(m, rng), float(rng.uniform(2500, 3800)), 4.0) * dsp.perc(m, 0.0003, 0.004)
        dsp.place(ticks, tick * float(rng.uniform(0.2, 0.45)), at)
    return _finish(rotors + wash + dsp.wrap(ticks, n))


@sound("move_stinger", "movement", MOVE_LUFS, loop=True, folder="movement", min_seconds=1.9, max_seconds=2.1)
def move_stinger(rng: np.random.Generator) -> np.ndarray:
    L = 2.0
    n = dsp.samples(L)
    f0 = qf(203.0, L)
    whine = dsp.sine(f0, n) + 0.5 * dsp.sine(qf(f0 * 2.37, L), n) + 0.3 * dsp.sine(qf(f0 * 3.91, L), n)
    whine *= 0.08 * (0.8 + 0.2 * lfo(n, L, 6))
    legs = np.zeros(n + dsp.samples(0.2))
    # Six legs, three steps each per loop, in a skittering uneven pattern.
    for leg in range(6):
        for step in range(3):
            at = (step / 3.0 + leg * 0.053 + float(rng.uniform(0, 0.015))) * L
            m = dsp.samples(0.08)
            f = float(rng.uniform(1100, 1500))
            click = dsp.partials(f, m, [(1.0, 0.5, 0.012), (2.13, 0.35, 0.008), (3.7, 0.2, 0.004)], rng)
            click += 0.4 * dsp.bandpass(dsp.white(m, rng), 2400.0, 2.0) * dsp.perc(m, 0.0003, 0.005)
            thud = 0.3 * dsp.sine(95.0, m) * dsp.perc(m, 0.001, 0.015)
            dsp.place(legs, dsp.fade(click + thud, 0.0005, 0.005) * float(rng.uniform(0.5, 0.9)), dsp.samples(at))
    hyd = dsp.periodic(dsp.bandpass, dsp.pink(n, rng), 3200.0, 1.0) * 0.05 * (0.5 + 0.5 * lfo(n, L, 6, 0.2))
    return _finish(_grit(whine + dsp.wrap(legs, n) + hyd, 1.5))


@sound("move_mauler", "movement", MOVE_LUFS, loop=True, folder="movement", min_seconds=3.9, max_seconds=4.1)
def move_mauler(rng: np.random.Generator) -> np.ndarray:
    L = 4.0
    n = dsp.samples(L)
    f0 = qf(27.0, L)
    lope = 0.6 + 0.4 * (0.5 + 0.5 * lfo(n, L, int(round(f0 * L / 3))))  # uneven firing
    engine = dsp.warm_saw(f0, n, 25.0) * lope
    engine += 0.5 * dsp.warm_saw(qf(f0 * 1.51, L), n, 15.0)
    engine = dsp.periodic(dsp.lowpass, _grit(engine * 2.0, 2.5), 600.0, 1.1) * 0.6
    rumble = dsp.periodic(dsp.lowpass, dsp.brown(n, rng), 140.0) * 0.4
    squeal = dsp.periodic(dsp.bandpass, dsp.white(n, rng), qf(2750.0, L), 12.0)
    squeal *= 0.25 * np.clip(lfo(n, L, 3, 0.1), 0.0, 1.0) ** 2
    clanks = np.zeros(n + dsp.samples(0.2))
    t = float(rng.uniform(0.04, 0.08))
    while t < L:
        m = dsp.samples(0.1)
        f = float(rng.uniform(380, 620))
        c = dsp.partials(f, m, [(1.0, 1.0, 0.03), (2.31, 0.6, 0.02), (4.17, 0.3, 0.01)], rng)
        dsp.place(clanks, dsp.fade(c, 0.0005, 0.005) * float(rng.uniform(0.15, 0.35)), dsp.samples(t))
        t += float(rng.uniform(0.09, 0.22))
    return _finish(engine + rumble + squeal + dsp.wrap(clanks, n))


@sound("building_sentry_select", "building", BUILDING_LUFS, folder="buildings", max_seconds=1.8)
def building_sentry_select(rng: np.random.Generator) -> np.ndarray:
    """Sentry: the turret wakes. A geared servo whir gliding A4 -> D5, two
    lock clicks, then a clear chime on D6 + A6: on guard."""
    dur = 0.32
    n = dsp.samples(dur)
    u = dsp.time_axis(n) / dur
    f = dsp.midi_hz(69) * 2.0 ** (5.0 / 12.0 * (u * u * (3 - 2 * u)))
    whir = dsp.wavetable(f, n, lambda k: [1.0, 0.45, 0.3, 0.15][k - 1] if k <= 4 else 0.0)
    whir += 0.2 * dsp.sine(f * 6.0, n)
    whir *= 0.25 * dsp.ar(n, 0.03, 0.05, dur - 0.08)
    buf = np.zeros(dsp.samples(1.6))
    dsp.place(buf, whir, 0)
    for k, at in enumerate([0.33, 0.39]):
        m = dsp.samples(0.06)
        click = dsp.partials(2200.0 - 300.0 * k, m, [(1.0, 0.5, 0.008), (2.4, 0.3, 0.004)], rng)
        click += 0.4 * dsp.bandpass(dsp.white(m, rng), 3000.0, 1.5) * dsp.perc(m, 0.0003, 0.003)
        dsp.place(buf, 0.6 * click, dsp.samples(at))
    ding = chime(dsp.midi_hz(86), 0.05, rng, brightness=0.8, decay=0.35, tail=0.8)
    ding = dsp.mix(ding, 0.6 * chime(dsp.midi_hz(93), 0.05, rng, brightness=0.6, decay=0.3, tail=0.8))
    dsp.place(buf, 0.45 * ding, dsp.samples(0.44))
    return building_finish(buf, rng, hp=120.0)


@sound("base_turret_traverse", "base", -27.0, max_seconds=0.7)
def base_turret_traverse(rng: np.random.Generator) -> np.ndarray:
    """A turret swinging onto a target: a quick geared whir up and a soft stop."""
    dur = 0.24
    n = dsp.samples(dur)
    u = dsp.time_axis(n) / dur
    f = 420.0 * (1.0 + 0.5 * np.sin(np.pi * u))
    whir = dsp.wavetable(f, n, lambda k: [1.0, 0.5, 0.35, 0.2, 0.1][k - 1] if k <= 5 else 0.0)
    whir += 0.25 * dsp.sine(f * 7.0, n)
    whir *= dsp.ar(n, 0.02, 0.06, dur - 0.08) * 0.4
    buf = np.zeros(dsp.samples(0.45))
    dsp.place(buf, whir, 0)
    m = dsp.samples(0.06)
    stop = dsp.partials(1500.0, m, [(1.0, 0.4, 0.01), (2.6, 0.2, 0.005)], rng) + 0.3 * dsp.sine(160.0, m) * dsp.perc(m, 0.001, 0.012)
    dsp.place(buf, 0.5 * stop, dsp.samples(dur - 0.01))
    return building_finish(buf, rng, hp=150.0)
