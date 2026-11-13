"""The Antecedents' sound world, and the Survey Lab.

A third world, neither Concord (tuned instruments) nor Combine (dirty
machines): resonant, bell-like, ancient. Stone and brass hovering on nothing.
Everything is built from the Antecedent bell (synth.instruments.bell), whose
partials include a faint raised fourth: D and G#, the frame of the Trail
motif, are the Warden's two notes.

  warden  hover loop    a deep bell drone on D with slow beating partials, a
                        breath of air, faint brass ticks as the stones shift
  warden  dormant hum   the same drone, purer and quieter (idle, unseen until near)
  warden  wake          grinding stone rising, a great bell strike on D with the
                        G# above, a glide up as it lifts
  warden  fire (x3)     a struck bell-bolt: a bright strike whose pitch drops,
                        a brass clang and a short resonant beam
  warden  death         the bell cracks (its partials split and beat), falls in
                        pitch, stone crumbles

The Survey Lab (a Concord building) answers in the Concord way, tuned into D:
a dish servo turning, then three sensor pings climbing D-A-B, the first three
notes of the Trail motif: the lab listens for it.
"""

from __future__ import annotations

import numpy as np

from synth import dsp
from synth.instruments import bell, chime, marimba

from . import sound
from .buildings import BUILDING_LUFS, _finish as building_finish
from .impacts import _finish as impact_finish, debris
from .movement import MOVE_LUFS, _finish as move_finish, lfo, qf

H = dsp.midi_hz


def bell_drone(n: int, seconds: float, f0: float, rng: np.random.Generator, beat_hz: float = 0.5,
               bright: float = 1.0) -> np.ndarray:
    """A sustained bell spectrum for loops: every partial (and its beating
    twin) runs a whole number of cycles in `seconds`."""
    out = np.zeros(n)
    for ratio, amp, _dk in [(0.5, 0.6, 0), (1.0, 1.0, 0), (1.25, 0.25, 0), (1.414, 0.08, 0), (1.5, 0.22, 0),
                            (2.0, 0.35, 0), (3.0, 0.08, 0)]:
        a = amp * (bright if ratio > 1.6 else 1.0)
        f = qf(f0 * ratio, seconds)
        f2 = qf(f0 * ratio + beat_hz * ratio, seconds)
        out += 0.5 * a * (dsp.sine(f, n, float(rng.random())) + dsp.sine(f2, n, float(rng.random())))
    return out


@sound("move_warden", "movement", MOVE_LUFS, loop=True, folder="movement", min_seconds=3.9, max_seconds=4.1)
def move_warden(rng: np.random.Generator) -> np.ndarray:
    L = 4.0
    n = dsp.samples(L)
    drone = bell_drone(n, L, H(38), rng, beat_hz=0.75) * 0.18
    drone *= 0.85 + 0.15 * lfo(n, L, 3)
    air = dsp.periodic(dsp.bandpass, dsp.pink(n, rng), 700.0, 0.6) * 0.18 * (0.7 + 0.3 * lfo(n, L, 2, 0.3))
    grind = dsp.periodic(dsp.lowpass, dsp.brown(n, rng), 180.0) * 0.12
    ticks = np.zeros(n + dsp.samples(2.0))
    for i in range(5):
        at = dsp.samples(i * L / 5 + float(rng.uniform(0, 0.3)))
        m = float(rng.choice([86.0, 92.0, 81.0]))
        dsp.place(ticks, 0.07 * bell(H(m), rng, decay=0.25, brightness=0.8, strike=0.6, length=1.4), at)
    return move_finish(drone + air + grind + dsp.wrap(ticks, n))


@sound("loop_hum_warden", "baseloop", -32.0, loop=True, folder="base/loops", min_seconds=5.9, max_seconds=6.1)
def loop_hum_warden(rng: np.random.Generator) -> np.ndarray:
    """Dormant: the Warden's drone alone, slow beating, a breath that comes
    and goes once per loop. Six seconds."""
    L = 6.0
    n = dsp.samples(L)
    drone = bell_drone(n, L, H(38), rng, beat_hz=0.34, bright=0.6) * 0.2
    drone *= 0.8 + 0.2 * lfo(n, L, 1)
    tri = dsp.sine(qf(H(68), L), n) * 0.025 * (0.5 + 0.5 * lfo(n, L, 2, 0.1))  # the G#, faint
    air = dsp.periodic(dsp.bandpass, dsp.pink(n, rng), 1200.0, 0.8) * 0.05 * (0.5 + 0.5 * lfo(n, L, 1, 0.5))
    return move_finish(drone + tri + air)


@sound("unit_warden_wake", "antecedent", -21.0, folder="units/warden", max_seconds=3.4, min_seconds=1.5)
def warden_wake(rng: np.random.Generator) -> np.ndarray:
    total = 3.0
    buf = np.zeros(dsp.samples(total + 3.0))
    m = dsp.samples(0.9)
    u = dsp.time_axis(m) / 0.9
    grind = dsp.sweep(dsp.brown(m, rng), "bp", 120.0 * 4.0 ** u, 1.5) * u ** 1.5
    grind += 0.3 * dsp.sweep(dsp.white(m, rng), "bp", 900.0 * 3.0 ** u, 3.0) * u ** 2
    dsp.place(buf, 0.6 * grind, 0)
    strike = 0.85
    dsp.place(buf, 1.0 * bell(H(38), rng, decay=1.6, brightness=0.8, strike=0.8), dsp.samples(strike))
    dsp.place(buf, 0.45 * bell(H(56), rng, decay=1.2, brightness=0.7, strike=0.3), dsp.samples(strike + 0.02))
    m = dsp.samples(1.4)
    u = dsp.time_axis(m) / 1.4
    lift = dsp.sine(H(62) * 2.0 ** (6.0 * u ** 0.7 / 12.0), m) + 0.4 * dsp.sine(H(50) * 2.0 ** (6.0 * u ** 0.7 / 12.0), m)
    lift *= dsp.env([(0, 0), (0.2, 0.2), (1.0, 0.16), (1.4, 0)], m)
    dsp.place(buf, lift, dsp.samples(strike + 0.3))
    y = impact_finish(buf, rng, 30.0, dict(seconds=1.6, mix=0.2, predelay_ms=12.0, damp=0.55), -58.0, 0.4)
    return y[: dsp.samples(total)] if len(y) > dsp.samples(total) else y


def warden_fire(rng: np.random.Generator, v: int) -> np.ndarray:
    root = [68, 74, 69][v]  # G#4, D5, A4: the motif's frame and its fifth
    n = dsp.samples(0.75)
    t = dsp.time_axis(n)
    f = H(root) * (1.0 + 1.0 * np.exp(-t / 0.035))  # the bolt drops onto its note
    bolt = (dsp.sine(f, n) + 0.4 * dsp.sine(f * 2.0, n) + 0.2 * dsp.sine(f * 1.414, n)) * dsp.perc(n, 0.002, 0.12)
    ring = 0.6 * bell(H(root), rng, decay=0.35, brightness=1.0, strike=0.8, length=0.75)
    clang = 0.25 * dsp.partials(H(root) * 3.1, n, [(1.0, 1.0, 0.03), (1.73, 0.6, 0.02), (2.9, 0.3, 0.01)], rng)
    beam = dsp.bandpass(dsp.white(n, rng), 2400.0 + 600.0 * v, 6.0) * dsp.perc(n, 0.003, 0.08) * 0.3
    x = 0.5 * bolt + ring + clang + beam
    return impact_finish(x, rng, 120.0, dict(seconds=0.6, mix=0.14, predelay_ms=6.0, damp=0.6), -56.0, 0.08)


for _v in range(3):
    sound(f"weapon_warden_fire_{_v + 1}", "weapon", -24.0, folder="weapons", max_seconds=0.9,
          params={"recipe": "warden_fire"})(lambda rng, v=_v: warden_fire(rng, v))


@sound("death_warden", "explosion", -21.0, folder="deaths", max_seconds=3.6, min_seconds=1.5)
def death_warden(rng: np.random.Generator) -> np.ndarray:
    """The bell cracks: struck hard, its partials split (wide detune, rough
    beating), it falls in pitch as it drops, and stone breaks up."""
    total = 3.2
    n = dsp.samples(total)
    buf = np.zeros(n)
    cracked = bell(H(38), rng, decay=1.2, brightness=1.0, strike=1.0, detune_cents=28.0, length=total)
    t = dsp.time_axis(n)
    fall = 2.0 ** (-3.0 * np.clip(t / total, 0, 1) / 12.0)
    # The pitch fall: resample the cracked bell along a slowing time axis.
    pos = np.cumsum(fall)
    pos = np.clip(pos - pos[0], 0, n - 1)
    dsp.place(buf, np.interp(pos, np.arange(n), cracked), 0)
    dsp.place(buf, 0.5 * bell(H(56), rng, decay=0.6, brightness=0.9, strike=0.5, detune_cents=35.0), dsp.samples(0.03))
    m = dsp.samples(1.6)
    tt = dsp.time_axis(m)
    thud = dsp.sine(45.0 * (1.0 + 0.5 * np.exp(-tt / 0.04)), m) * dsp.perc(m, 0.003, 0.25)
    rubble = dsp.lowpass(dsp.brown(m, rng), 500.0) * dsp.env([(0, 0), (0.04, 0.6), (1.6, 0)], m, 2.0)
    dsp.place(buf, 0.8 * thud + 0.5 * rubble, dsp.samples(0.55))
    buf += debris(rng, n, 50, 0.6, 1.8, 700.0, 3200.0, 0.3)
    return impact_finish(buf, rng, 30.0, dict(seconds=1.4, mix=0.16, predelay_ms=10.0, damp=0.6), -60.0, 0.3)


@sound("building_survey_lab_select", "building", BUILDING_LUFS, folder="buildings", max_seconds=1.9)
def building_survey_lab_select(rng: np.random.Generator) -> np.ndarray:
    """Survey Lab: a dish servo turning, then three sensor pings climbing
    D-A-B (the start of the Trail motif) with a data chatter under them."""
    dur = 0.26
    n = dsp.samples(dur)
    u = dsp.time_axis(n) / dur
    f = 520.0 * (1.0 + 0.3 * np.sin(np.pi * u))
    servo = dsp.wavetable(f, n, lambda k: [1.0, 0.4, 0.25][k - 1] if k <= 3 else 0.0) * dsp.ar(n, 0.03, 0.06, dur - 0.09) * 0.2
    buf = np.zeros(dsp.samples(1.7))
    dsp.place(buf, servo, 0)
    for k, (m, at) in enumerate([(74, 0.28), (81, 0.4), (83, 0.52)]):
        p = chime(H(m), 0.04, rng, brightness=0.9, decay=0.18 + 0.1 * k, tail=0.7)
        p = dsp.mix(p, 0.5 * marimba(H(m), 0.04, rng, hardness=0.5, decay=0.12, tail=0.4))
        dsp.place(buf, 0.5 * p, dsp.samples(at))
    for i in range(10):
        dsp.place(buf, 0.06 * dsp.sine(float(rng.choice([2349.0, 2960.0, 3520.0])), dsp.samples(0.015)) *
                  dsp.ar(dsp.samples(0.015), 0.002, 0.005, 0.008), dsp.samples(0.3 + 0.04 * i))
    return building_finish(buf, rng, hp=110.0)


@sound("loop_hum_survey_lab", "baseloop", -33.0, loop=True, folder="base/loops", min_seconds=5.9, max_seconds=6.1)
def loop_hum_survey_lab(rng: np.random.Generator) -> np.ndarray:
    """Survey Lab at rest: the Concord building hum on D with a receiver hiss,
    and once per loop the dish pings the motif's question, D then A, very
    softly: the lab is still listening."""
    L = 6.0
    n = dsp.samples(L)
    hum = dsp.wavetable(qf(H(38), L), n, lambda k: [1.0, 0.5, 0.3, 0.15][k - 1] if k <= 4 else 0.0) * 0.18
    hum *= 0.9 + 0.1 * lfo(n, L, 2)
    hiss = dsp.periodic(dsp.bandpass, dsp.pink(n, rng), 4200.0, 0.9) * 0.025 * (0.7 + 0.3 * lfo(n, L, 1, 0.4))
    pings = np.zeros(n + dsp.samples(2.0))
    for k, (m, at) in enumerate([(86, 1.0), (93, 1.35)]):
        p = chime(H(m), 0.03, rng, brightness=0.5, decay=0.25 + 0.15 * k, tail=0.9)
        dsp.place(pings, 0.12 * p, dsp.samples(at))
    return move_finish(hum + hiss + dsp.wrap(pings, n))
