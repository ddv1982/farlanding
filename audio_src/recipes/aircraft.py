"""The first air units (Phase 8c): the Concord Talon and the Combine Hornet.

Their engines are loops like any chassis (mono, seamless by the movement.py
rules), but an aircraft's engine never stops: the MovementLoops keep a loop
whose SoundEvent has `loops_at_rest` sounding while the unit hovers, at a
lower level and pitch than at full speed.

  ducted   (Talon)   twin ducted fans: two clean turbine whines a few hertz
                     apart on D and A (a slow, even beat), the blade-pass hum
                     of the fans, a smooth air rush; no rattle (Concord: clean)
  rotor    (Hornet)  one crude rotor: a loud slapping blade beat (about 9 a
                     second), an angry detuned two-stroke under it, loose
                     panels rattling, a whine that is never in tune (Combine)

Weapons:

  talon    the chin autocannon (`talon_autocannon`): two quick FM bolts a
           fifth apart (D6 then A5, or E6/B5, F#6/C#6), very short, a clean
           puff of air between (-25)
  hornet   the dart gun (`hornet_dartgun`, every half second): a ragged
           pneumatic crack, a ring-modulated metal twang as the dart leaves,
           the loader rattling; short, dirty, decimated (-26)

Replies (Barks, the shared grammar: select rises, move falls, attack repeats
with an accent):

  talon    high and light (A5-E6), a quick pair of airy marimba strokes with a
           rising reed glide behind them: something lifting; fifths
  hornet   Combine, never in the Concord key: a buzzy ring-modulated two-tone
           over a rotor chop, rough and impatient

Deaths: `death_talon` (hit: a crack, the fans spinning down and wobbling as it
falls, a whistle of air, then the ground impact: a thump, crunch and a small
blast), `death_hornet` (the rotor slap staggering and slowing, an engine
scream falling, a hard crash and a fireball).
"""

from __future__ import annotations

import numpy as np

from synth import dsp
from synth.instruments import chime, marimba, reed

from . import sound
from .impacts import _finish as impact_finish, debris, explosion
from .movement import MOVE_LUFS, _finish as move_finish, lfo, qf
from .units import UNIT_LUFS, _finish as unit_finish
from .weapons import _finish as weapon_finish, bolt, dirty

H = dsp.midi_hz


# --------------------------------------------------------------------------- engines


def _ducted(rng: np.random.Generator, L: float) -> np.ndarray:
    n = dsp.samples(L)
    wob = 1.0 + 0.002 * lfo(n, L, 1) + 0.001 * lfo(n, L, 3, 0.3)
    whine = np.zeros(n)
    for f, amp in ((H(86), 1.0), (H(86) + 3.0, 0.8), (H(81), 0.6), (H(81) + 2.0, 0.5)):  # D6, A5, beating
        whine += amp * dsp.sine(qf(f, L) * wob, n)
    whine *= 0.035
    blade = dsp.wavetable(qf(147.0, L) * wob, n, lambda k: np.exp(-(k - 1) / 3.0) / k)  # ~D3 blade pass
    blade += 0.8 * dsp.wavetable(qf(149.5, L) * wob, n, lambda k: np.exp(-(k - 1) / 3.0) / k, start=0.3)
    blade = dsp.periodic(dsp.lowpass, blade, 1500.0) * 0.16
    rush = dsp.periodic(dsp.bandpass, dsp.pink(n, rng), 1100.0, 0.5) * 0.55 * (0.9 + 0.1 * lfo(n, L, 2))
    hiss = dsp.periodic(dsp.highpass, dsp.pink(n, rng), 4500.0) * 0.12
    body = dsp.sine(qf(H(38), L), n) * 0.12  # D2 under it
    return move_finish(whine + blade + rush + hiss + body)


@sound("move_ducted", "movement", MOVE_LUFS, loop=True, folder="movement", params={"events": ["move_talon"]},
       min_seconds=3.9, max_seconds=4.1)
def move_ducted(rng: np.random.Generator) -> np.ndarray:
    return _ducted(rng, 4.0)


def _rotor(rng: np.random.Generator, L: float) -> np.ndarray:
    n = dsp.samples(L)
    rate = qf(9.0, L)  # blade slaps per second (whole number per loop)
    t = dsp.time_axis(n)
    slap_env = (0.5 + 0.5 * np.cos(2 * np.pi * rate * t)) ** 6
    chop = dsp.periodic(dsp.bandpass, dsp.pink(n, rng), 380.0, 0.8) * slap_env * 1.4
    thump = dsp.sine(qf(68.0, L), n) * slap_env * 0.5
    f0 = qf(43.0, L)
    engine = dsp.warm_saw(f0 * (1.0 + 0.01 * lfo(n, L, 5)), n, 18.0)
    engine += 0.6 * dsp.warm_saw(qf(f0 * 1.47, L), n, 12.0)
    engine = dsp.periodic(dsp.lowpass, dsp.saturate(engine * 2.0, 2.2), 900.0) * 0.3
    whine = (dsp.sine(qf(1123.0, L), n) + 0.6 * dsp.sine(qf(1187.0, L), n)) * 0.025 * (0.8 + 0.2 * lfo(n, L, 7))
    rattle = np.zeros(n + dsp.samples(0.1))
    for _ in range(int(L * 22)):
        at = int(rng.integers(0, n))
        m = dsp.samples(0.03)
        r = dsp.bandpass(dsp.white(m, rng), float(rng.uniform(1500, 3500)), 4.0) * dsp.perc(m, 0.0004, 0.005)
        dsp.place(rattle, r * float(rng.uniform(0.15, 0.45)) * (0.5 + slap_env[at]), at)
    return move_finish(dsp.saturate(chop + thump + engine + whine + dsp.wrap(rattle, n), 1.2))


@sound("move_rotor", "movement", MOVE_LUFS, loop=True, folder="movement", params={"events": ["move_hornet"]},
       min_seconds=2.9, max_seconds=3.1)
def move_rotor(rng: np.random.Generator) -> np.ndarray:
    return _rotor(rng, 3.0)


# --------------------------------------------------------------------------- weapons


TALON_PAIRS = [(86, 81), (88, 83), (90, 85)]  # D6/A5, E6/B5, F#6/C#6


def talon_gun(rng: np.random.Generator, v: int) -> np.ndarray:
    hi, lo = TALON_PAIRS[v]
    buf = np.zeros(dsp.samples(0.32))
    dsp.place(buf, bolt(H(hi), 0.09, rng, drop=1.8, glass=0.5), 0)
    dsp.place(buf, 0.85 * bolt(H(lo), 0.1, rng, drop=1.8, glass=0.4), dsp.samples(0.06))
    m = dsp.samples(0.12)
    puff = dsp.bandpass(dsp.white(m, rng), 2400.0, 0.7) * dsp.perc(m, 0.001, 0.025) * 0.25
    dsp.place(buf, puff, dsp.samples(0.01))
    return weapon_finish(buf, rng, 500.0)


def hornet_dart(rng: np.random.Generator, v: int) -> np.ndarray:
    """A crude dart gun: a ragged pneumatic crack, a ring-modulated metal twang
    as the dart leaves the barrel, a rattle of the loader; short, dirty, off key."""
    total = 0.26
    n = dsp.samples(total)
    t = dsp.time_axis(n)
    crack = dsp.bandpass(dsp.white(n, rng), 1500.0 + 250.0 * v, 0.8) * dsp.perc(n, 0.0004, 0.012)
    puff = dsp.lowpass(dsp.white(n, rng), 900.0) * dsp.perc(n, 0.001, 0.03)
    f = 640.0 + 70.0 * v
    twang = dsp.warm_saw(f * (1.0 + 0.5 * np.exp(-t / 0.01)), n, 10.0) * dsp.sine(f * 0.73, n)
    twang *= dsp.perc(n, 0.001, 0.045)
    rattle = np.zeros(n)
    for k in range(3):
        m = dsp.samples(0.02)
        r = dsp.bandpass(dsp.white(m, rng), float(rng.uniform(2000, 3600)), 4.0) * dsp.perc(m, 0.0003, 0.004)
        dsp.place(rattle, r * (0.4 - 0.1 * k), dsp.samples(0.06 + 0.025 * k + float(rng.uniform(0, 0.006))))
    x = 0.9 * crack + 0.5 * puff + 0.45 * twang + rattle
    return weapon_finish(dirty(x, 2.0, 4), rng, 350.0)


for _v in range(3):
    sound(f"weapon_talon_fire_{_v + 1}", "weapon", -25.0, folder="weapons", max_seconds=0.45,
          params={"recipe": "talon_gun"})(lambda rng, v=_v: talon_gun(rng, v))
    sound(f"weapon_hornet_fire_{_v + 1}", "weapon", -26.0, folder="weapons", max_seconds=0.45,
          params={"recipe": "hornet_dart"})(lambda rng, v=_v: hornet_dart(rng, v))


# --------------------------------------------------------------------------- replies


def talon(rng: np.random.Generator, notes: list[int], step: float, rise: float, accent: bool = False) -> np.ndarray:
    """Airy marimba strokes with a reed glide behind them that lifts by `rise`
    semitones (falls when negative): an aircraft answering."""
    total = step * len(notes) + 1.0
    buf = np.zeros(dsp.samples(total))
    for i, m in enumerate(notes):
        last = i == len(notes) - 1
        hard = 1.4 if accent and not last else 0.9
        wood = marimba(H(m), 0.05, rng, hardness=hard, decay=0.2 if last else 0.08, tail=0.5)
        glass = 0.3 * chime(H(m + 12), 0.04, rng, brightness=0.5, decay=0.12 if last else 0.05, tail=0.4)
        dsp.place(buf, dsp.mix(wood, glass), dsp.samples(i * step))
    dur = step * len(notes) + 0.1
    m = dsp.samples(dur)
    u = dsp.time_axis(m) / dur
    f = H(notes[-1]) * 2.0 ** (rise * (u * u * (3 - 2 * u)) / 12.0)
    glide = reed(f, dur, rng, brightness=2.2, attack=0.04, release=0.1, breath=0.35, vibrato_cents=0.0)
    dsp.place(buf, 0.35 * glide, 0)
    return unit_finish(dsp.highpass(buf, 220.0), rng, dict(seconds=0.8, mix=0.2, predelay_ms=12.0, damp=0.5))


TALON = {
    "select": [([81, 88], 0.08, 5.0), ([83, 88], 0.08, 5.0), ([81, 85, 88], 0.065, 7.0)],
    "move": [([88, 81], 0.08, -5.0), ([88, 83], 0.08, -5.0), ([88, 85, 81], 0.065, -7.0)],
    "attack": [([81, 81, 88], 0.065, 0.0), ([83, 83, 88], 0.065, 0.0), ([76, 76, 83], 0.065, 0.0)],
}


def hornet(rng: np.random.Generator, freqs: list[float], step: float, accent: bool = False) -> np.ndarray:
    """Combine: a buzzy ring-modulated tone per step over the rotor's chop."""
    total = step * len(freqs) + 0.6
    buf = np.zeros(dsp.samples(total))
    for i, f in enumerate(freqs):
        last = i == len(freqs) - 1
        dur = step * (1.6 if last else 0.85)
        m = dsp.samples(dur)
        saw = dsp.warm_saw(f, m, 14.0) + 0.7 * dsp.warm_saw(f * 1.013, m, 14.0)
        ring = saw * (0.6 + 0.4 * dsp.sine(f * 0.71, m))
        hard = 1.5 if accent and not last else 1.0
        x = dsp.saturate(ring * hard, 1.8) * dsp.ar(m, 0.006, 0.05, dur - 0.056)
        dsp.place(buf, 0.6 * x, dsp.samples(i * step))
    n = len(buf)
    t = dsp.time_axis(n)
    chop = dsp.bandpass(dsp.white(n, rng), 420.0, 1.0) * (0.5 + 0.5 * np.cos(2 * np.pi * 18.0 * t)) ** 6
    buf += 0.25 * chop * dsp.env([(0, 0), (0.02, 1.0), (total - 0.4, 0.6), (total, 0)], n)
    buf = dsp.lowpass(dsp.highpass(buf, 160.0), 3800.0)
    y = dsp.reverb(buf, rng, seconds=0.5, mix=0.12, predelay_ms=6.0, damp=0.7).mean(axis=0)
    return dsp.fade(dsp.trim_tail(dsp.dc_block(y), -58.0), 0.001, 0.04)


HORNET = {  # Hz, deliberately between the Concord's notes
    "select": [([311.0, 466.0], 0.1), ([330.0, 494.0], 0.1), ([300.0, 380.0, 466.0], 0.08)],
    "move": [([466.0, 311.0], 0.1), ([494.0, 330.0], 0.1), ([466.0, 380.0, 300.0], 0.08)],
    "attack": [([311.0, 311.0, 466.0], 0.075), ([330.0, 330.0, 494.0], 0.075), ([300.0, 300.0, 440.0], 0.075)],
}


def _register() -> None:
    for kind, variants in TALON.items():
        for i, (notes, step, rise) in enumerate(variants, start=1):
            sound(f"unit_talon_{kind}_{i}", "unit", UNIT_LUFS, folder="units/talon", max_seconds=1.4,
                  params={"recipe": f"talon({notes}, step={step}, rise={rise})"})(
                lambda rng, n=notes, s=step, r=rise, k=kind: talon(rng, n, s, r, accent=k == "attack"))
    for kind, variants in HORNET.items():
        for i, (freqs, step) in enumerate(variants, start=1):
            sound(f"unit_hornet_{kind}_{i}", "unit", UNIT_LUFS, folder="units/hornet", max_seconds=1.2,
                  params={"recipe": f"hornet({freqs}, step={step})"})(
                lambda rng, f=freqs, s=step, k=kind: hornet(rng, f, s, accent=k == "attack"))


_register()


# --------------------------------------------------------------------------- deaths


def _fall(rng: np.random.Generator, seconds: float, f0: float, wobble_hz: float) -> np.ndarray:
    """Spinning down while falling: a whine sliding down an octave and a half,
    wobbling as the craft tumbles, under a rising whistle of air."""
    n = dsp.samples(seconds)
    t = dsp.time_axis(n)
    u = t / seconds
    wob = 1.0 + 0.04 * np.sin(2 * np.pi * wobble_hz * t * (1.0 + u))
    f = f0 * 0.35 ** u * wob
    whine = (dsp.sine(f, n) + 0.4 * dsp.sine(f * 1.5, n)) * dsp.env([(0, 1.0), (seconds, 0.3)], n)
    air = dsp.sweep(dsp.pink(n, rng), "bp", 800.0 + 2200.0 * u, 1.2) * u ** 1.5
    return 0.3 * whine + 0.5 * air


@sound("death_talon", "explosion", -21.0, folder="deaths", max_seconds=3.6)
def death_talon(rng: np.random.Generator) -> np.ndarray:
    total = 3.2
    buf = np.zeros(dsp.samples(total))
    dsp.place(buf, 0.6 * explosion(rng, 0.0), 0)
    fall = 1.1
    dsp.place(buf, _fall(rng, fall, H(86), 3.0), dsp.samples(0.05))
    ground = 0.05 + fall
    dsp.place(buf, explosion(rng, 0.35), dsp.samples(ground))
    m = dsp.samples(0.5)
    t = dsp.time_axis(m)
    thump = dsp.sine(60.0 * (1.0 + 0.8 * np.exp(-t / 0.02)), m) * dsp.perc(m, 0.001, 0.12)
    dsp.place(buf, 0.9 * thump, dsp.samples(ground))
    dsp.place(buf, debris(rng, dsp.samples(1.4), 18, 0.05, 1.0, 900.0, 3500.0, 0.3), dsp.samples(ground))
    return impact_finish(buf, rng, 36.0, dict(seconds=0.8, mix=0.08), -60.0, 0.2)


@sound("death_hornet", "explosion", -21.0, folder="deaths", max_seconds=3.6)
def death_hornet(rng: np.random.Generator) -> np.ndarray:
    total = 3.3
    buf = np.zeros(dsp.samples(total))
    dsp.place(buf, 0.6 * explosion(rng, 0.05), 0)
    fall = 1.2
    n = dsp.samples(fall)
    t = dsp.time_axis(n)
    u = t / fall
    rate = 9.0 * (1.0 - 0.6 * u)  # the rotor staggering
    slap = (0.5 + 0.5 * np.cos(2 * np.pi * np.cumsum(rate) / dsp.SR)) ** 6
    chop = dsp.bandpass(dsp.white(n, rng), 380.0, 0.8) * slap * 1.2
    scream = dsp.warm_saw(260.0 * 0.4 ** u, n, 14.0) * 0.4
    dsp.place(buf, dirty(chop + scream + 0.5 * _fall(rng, fall, 1150.0, 5.0), 2.0, 0), dsp.samples(0.05))
    ground = 0.05 + fall
    dsp.place(buf, 1.1 * explosion(rng, 0.45), dsp.samples(ground))
    dsp.place(buf, debris(rng, dsp.samples(1.5), 26, 0.04, 1.2, 600.0, 3000.0, 0.35), dsp.samples(ground))
    return impact_finish(buf, rng, 34.0, dict(seconds=0.8, mix=0.08), -60.0, 0.2)
