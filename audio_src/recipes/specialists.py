"""The Concord specialists (Phase 5): Wisp, Lancer and Arc. Their movement
loops, weapons and deaths; their replies are in units.py.

Movement (mono loops, seamless by the movement.py rules):

  phantom  (Wisp)    almost nothing: air sliding past a smooth hull, a soft glass
                     shimmer on D and A, a muffled fan a few hertz apart (-28, quieter
                     than any other chassis by design)
  strider  (Lancer)  a heavier biped than the Ranger's walker: three slow steps per loop
                     (alternating weight), deeper footfalls, a servo per step and the
                     faint whine of the charged lance
  crawler  (Arc)     a squat artillery crawler: an electric drive drone, light tread clicks,
                     the gun mount creaking once per loop and a hydraulic stabiliser sigh

Weapons (Concord: clean, tonal, in D Lydian, no distortion):

  wisp    a suppressed glass "pff": a short FM bolt falling onto D6/E6/C#6 under
          a breath of air, quiet and close (-27)
  lancer  anti-armour: a 0.1 s charge whine rising into a long FM spear that drops
          onto D5/E5/A4, a crack and a sub knock (-23)
  arc     artillery: the tube's deep "thoonk" ringing on D3/A2/E3, a puff of propellant
          and the shell's whistle climbing away (-22)

Deaths: `death_wisp` (the cloak tears: glass shards scatter, the whisper falls),
`death_lancer` (a small blast, the lance capacitor discharging and fizzing out),
`death_arc` (a heavy blast and the shells left in the rack cooking off).
"""

from __future__ import annotations

import numpy as np

from synth import dsp
from synth.instruments import chime, reed

from . import sound
from .impacts import explosion, groan, power_down
from .impacts import _finish as impact_finish
from .movement import MOVE_LUFS, _finish as move_finish, footfall, lfo, qf, servo
from .weapons import HEAVY_ROOM, _finish as weapon_finish, bolt, chirp

H = dsp.midi_hz


# --------------------------------------------------------------------------- movement


@sound("move_phantom", "movement", MOVE_LUFS - 4.0, loop=True, folder="movement",
       params={"events": ["move_wisp"]}, min_seconds=3.9, max_seconds=4.1)
def move_phantom(rng: np.random.Generator) -> np.ndarray:
    L = 4.0
    n = dsp.samples(L)
    t = dsp.time_axis(n)
    air = dsp.periodic(dsp.sweep, dsp.pink(n, rng), "bp", 1400.0 * (1.0 + 0.3 * lfo(n, L, 1, 0.2)), 0.6)
    air *= 0.4 * (0.8 + 0.2 * lfo(n, L, 2))
    shimmer = np.zeros(n)
    for k, m in enumerate([86, 93]):
        f = qf(H(m), L)
        shimmer += dsp.sine(f, n) * (0.5 - 0.5 * np.cos(2 * np.pi * (1 + k) * t / L))
    shimmer *= 0.025
    fans = (dsp.wavetable(qf(118.0, L), n, lambda h: 1.0 / h ** 1.5) +
            dsp.wavetable(qf(121.5, L), n, lambda h: 1.0 / h ** 1.5, start=0.4))
    fans = dsp.periodic(dsp.lowpass, fans, 700.0) * 0.08
    return move_finish(air + shimmer + fans)


@sound("move_strider", "movement", MOVE_LUFS, loop=True, folder="movement",
       params={"events": ["move_lancer"]}, min_seconds=2.3, max_seconds=2.5)
def move_strider(rng: np.random.Generator) -> np.ndarray:
    L = 2.4
    n = dsp.samples(L)
    buf = np.zeros(n + dsp.samples(0.6))
    for i in range(4):
        at = dsp.samples(i * L / 4 + float(rng.uniform(0.0, 0.006)))
        step = footfall(rng, 1.25 if i % 2 == 0 else 1.05)
        step = dsp.mix(step, 0.4 * dsp.lowpass(step, 300.0))
        dsp.place(buf, step, at)
        dsp.place(buf, 1.2 * servo(rng, i % 2 == 0), at + dsp.samples(0.24))
    whine = dsp.sine(qf(1480.0, L) * (1.0 + 0.003 * lfo(n, L, 3)), n) * 0.012
    hiss = dsp.periodic(dsp.bandpass, dsp.pink(n, rng), 3000.0, 0.8) * 0.025 * (0.6 + 0.4 * lfo(n, L, 4, 0.1))
    return move_finish(dsp.wrap(buf, n) + whine + hiss)


@sound("move_crawler", "movement", MOVE_LUFS, loop=True, folder="movement",
       params={"events": ["move_arc"]}, min_seconds=3.9, max_seconds=4.1)
def move_crawler(rng: np.random.Generator) -> np.ndarray:
    L = 4.0
    n = dsp.samples(L)
    wob = 1.0 + 0.003 * lfo(n, L, 1) + 0.002 * lfo(n, L, 3, 0.4)
    f0 = qf(98.0, L)
    drive = dsp.wavetable(f0 * wob, n, lambda k: [1.0, 0.6, 0.4, 0.25, 0.15][k - 1] if k <= 5 else 0.0)
    drive = dsp.periodic(dsp.lowpass, drive, 800.0) * 0.3
    roll = dsp.periodic(dsp.lowpass, dsp.brown(n, rng), 200.0) * 0.35
    clicks = np.zeros(n + dsp.samples(0.2))
    rate = 5
    for i in range(int(L * rate)):
        m = dsp.samples(0.05)
        c = dsp.partials(float(rng.uniform(1100, 1300)), m, [(1.0, 1.0, 0.01), (2.6, 0.5, 0.006)], rng)
        dsp.place(clicks, 0.15 * c, dsp.samples(i / rate + float(rng.uniform(0.0, 0.004))))
    m = dsp.samples(0.5)
    creak = dsp.sweep(dsp.warm_saw(220.0 * (1.0 + 0.1 * dsp.time_axis(m)), m, 20.0), "bp",
                      np.full(m, 900.0), 6.0) * dsp.ar(m, 0.08, 0.2, 0.2) * 0.12
    dsp.place(clicks, creak, dsp.samples(1.2))
    m = dsp.samples(0.6)
    sigh = dsp.bandpass(dsp.white(m, rng), 2000.0, 0.8) * dsp.ar(m, 0.05, 0.4, 0.15) * 0.06
    dsp.place(clicks, sigh, dsp.samples(3.0))
    return move_finish(drive + roll + dsp.wrap(clicks, n))


# --------------------------------------------------------------------------- weapons


WISP_NOTES = [86, 88, 85]  # D6, E6, C#6


def wisp_gun(rng: np.random.Generator, v: int) -> np.ndarray:
    n = dsp.samples(0.14)
    x = bolt(H(WISP_NOTES[v]), 0.14, rng, drop=1.5, glass=0.3)
    x = dsp.lowpass(x, 5000.0)
    puff = dsp.bandpass(dsp.white(n, rng), 1800.0, 0.6) * dsp.perc(n, 0.002, 0.02) * 0.4
    return weapon_finish(0.8 * x + puff, rng, 500.0, dict(seconds=0.3, mix=0.08, predelay_ms=3.0, damp=0.75))


LANCER_NOTES = [74, 76, 69]  # D5, E5, A4


def lancer_gun(rng: np.random.Generator, v: int) -> np.ndarray:
    f = H(LANCER_NOTES[v])
    total = 0.75
    buf = np.zeros(dsp.samples(total))
    m = dsp.samples(0.11)
    u = dsp.time_axis(m) / 0.11
    charge = dsp.sine(f * 0.5 * 2.0 ** (u * 1.0), m) * (u ** 2) * 0.25
    dsp.place(buf, charge, 0)
    spear = bolt(f, 0.42, rng, drop=3.0, glass=0.8)
    m2 = len(spear)
    tt = dsp.time_axis(m2)
    knock = 0.6 * dsp.sine(90.0 * (1.0 + 0.6 * np.exp(-tt / 0.012)), m2) * dsp.perc(m2, 0.001, 0.045)
    crack = 0.4 * dsp.bandpass(dsp.white(m2, rng), 3200.0, 0.8) * dsp.perc(m2, 0.0004, 0.012)
    tail = 0.3 * dsp.sine(f * 2.0, m2) * dsp.perc(m2, 0.002, 0.12)
    dsp.place(buf, spear + knock + crack + tail, dsp.samples(0.1))
    return weapon_finish(buf, rng, 60.0, dict(seconds=0.6, mix=0.13, predelay_ms=6.0, damp=0.65), -58.0)


ARC_RING = [50, 45, 52]  # D3, A2, E3


def arc_gun(rng: np.random.Generator, v: int) -> np.ndarray:
    total = 1.4
    n = dsp.samples(total)
    t = dsp.time_axis(n)
    thoonk = dsp.sine(85.0 + 70.0 * np.exp(-t / 0.04), n) * dsp.perc(n, 0.002, 0.14)
    f = H(ARC_RING[v])
    tube = dsp.partials(f, n, [(1.0, 0.4, 0.3), (2.0, 0.25, 0.18), (2.92, 0.12, 0.1)], rng) * dsp.perc(n, 0.004, 10.0)
    puff = dsp.lowpass(dsp.white(n, rng), 700.0) * dsp.perc(n, 0.002, 0.07)
    x = 1.1 * thoonk + 0.5 * tube + 0.45 * puff
    m = dsp.samples(0.6)
    whistle_f = chirp(1300.0, 2300.0, 0.6, 3.0)[:m]
    whistle = dsp.sine(whistle_f, m) * dsp.env([(0, 0), (0.05, 0.12), (0.6, 0)], m)
    dsp.place(x, whistle, dsp.samples(0.12))
    return weapon_finish(x, rng, 38.0, HEAVY_ROOM, -58.0)


for _v in range(3):
    sound(f"weapon_wisp_fire_{_v + 1}", "weapon", -27.0, folder="weapons", max_seconds=0.45,
          params={"recipe": "wisp_gun"})(lambda rng, v=_v: wisp_gun(rng, v))
    sound(f"weapon_lancer_fire_{_v + 1}", "weapon", -23.0, folder="weapons", max_seconds=1.2,
          params={"recipe": "lancer_gun"})(lambda rng, v=_v: lancer_gun(rng, v))
    sound(f"weapon_arc_fire_{_v + 1}", "weapon", -22.0, folder="weapons", max_seconds=2.0,
          params={"recipe": "arc_gun"})(lambda rng, v=_v: arc_gun(rng, v))


# --------------------------------------------------------------------------- deaths


@sound("death_wisp", "explosion", -23.0, folder="deaths", max_seconds=1.8)
def death_wisp(rng: np.random.Generator) -> np.ndarray:
    total = 1.5
    n = dsp.samples(total)
    buf = np.zeros(n)
    dsp.place(buf, 0.6 * explosion(rng, 0.0), 0)
    for _ in range(14):
        f = float(rng.uniform(2500, 6500))
        m = dsp.samples(0.12)
        shard = dsp.partials(f, m, [(1.0, 0.6, 0.03), (2.31, 0.3, 0.015), (3.7, 0.2, 0.01)], rng)
        dsp.place(buf, 0.18 * shard, dsp.samples(float(rng.uniform(0.0, 0.35)) ** 1.5))
    m = dsp.samples(0.7)
    u = dsp.time_axis(m) / 0.7
    whisper = reed(H(80) * 2.0 ** (-7.0 * u / 12.0), 0.6, rng, brightness=1.6, attack=0.01, release=0.1,
                   breath=0.6, vibrato_cents=0.0)
    dsp.place(buf, 0.5 * whisper, dsp.samples(0.05))
    rush = dsp.sweep(dsp.white(n, rng), "bp", 6000.0 * 0.15 ** (dsp.time_axis(n) / total), 1.2)
    rush *= dsp.perc(n, 0.005, 0.25) * 0.3
    return impact_finish(buf + rush, rng, 60.0, dict(seconds=0.5, mix=0.08), -60.0, 0.1)


@sound("death_lancer", "explosion", -23.0, folder="deaths", max_seconds=1.9)
def death_lancer(rng: np.random.Generator) -> np.ndarray:
    buf = np.zeros(dsp.samples(1.6))
    dsp.place(buf, explosion(rng, 0.15), 0)
    dsp.place(buf, 0.4 * power_down(rng, 0.8, 1480.0), dsp.samples(0.04))
    m = dsp.samples(0.3)
    zap = dsp.sine(H(74) * (1.0 + 0.5 * np.exp(-dsp.time_axis(m) / 0.03)), m) * dsp.perc(m, 0.001, 0.08)
    dsp.place(buf, 0.35 * zap, dsp.samples(0.02))
    return impact_finish(buf, rng, 40.0, dict(seconds=0.4, mix=0.05), -60.0, 0.1)


@sound("death_arc", "explosion", -21.0, folder="deaths", max_seconds=3.0)
def death_arc(rng: np.random.Generator) -> np.ndarray:
    buf = np.zeros(dsp.samples(2.6))
    dsp.place(buf, explosion(rng, 0.55), 0)
    dsp.place(buf, 0.45 * groan(rng, 1.0, 82.0), dsp.samples(0.12))
    for k, at in enumerate([0.42, 0.71, 0.88]):
        dsp.place(buf, (0.5 - 0.1 * k) * explosion(rng, 0.0), dsp.samples(at))
    dsp.place(buf, 0.25 * chime(H(50), 0.05, rng, brightness=0.3, decay=0.4, tail=0.8), dsp.samples(0.05))
    return impact_finish(buf, rng, 32.0, dict(seconds=0.6, mix=0.06), -60.0, 0.2)
