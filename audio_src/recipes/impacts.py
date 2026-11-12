"""Impacts, explosions and destruction. Mono, positional.

Impacts (group `impact`, Weapons bus) say what was hit, not who fired:

  impact_spark   a light shot on a light target: a short crackle of sparks and a tiny ping
  impact_armour  a shot on heavy armour or a building: a struck steel plate
  impact_ground  a miss: a dull thud, a puff of dust and grit falling back

Explosions (group `explosion`, Explosions bus) come in three sizes built from
the same layers (crack, body, rumble, debris) scaled in length and depth, so
size reads at once. Deaths reuse them: a light unit pops and fizzles out, a
heavy one bursts, groans and pops again, and a building collapses over
three seconds.
"""

from __future__ import annotations

import numpy as np

from synth import dsp

from . import sound

ROOM = dict(seconds=0.5, mix=0.12, predelay_ms=5.0, damp=0.7)
OUTDOOR = dict(seconds=1.6, mix=0.2, predelay_ms=14.0, damp=0.55, width=1.0)


def _finish(x: np.ndarray, rng: np.random.Generator, hp: float, room: dict = ROOM,
            tail_db: float = -58.0, fade_out: float = 0.04) -> np.ndarray:
    wet = dsp.reverb(dsp.highpass(x, hp), rng, **room).mean(axis=0)
    y = dsp.fade(dsp.trim_tail(dsp.dc_block(dsp.highpass(wet, 30.0)), tail_db), 0.0005, fade_out)
    # Long low rumbles can leave a small net offset over the file: remove it
    # under a smooth window (inaudible, no step).
    w = np.hanning(len(y))
    return y - np.mean(y) * w / np.mean(w)


def debris(rng: np.random.Generator, n: int, count: int, start: float, spread: float,
           lo: float = 1200.0, hi: float = 4200.0, level: float = 0.3) -> np.ndarray:
    """Small pieces landing: short band-passed ticks scattered in time, thinning out."""
    buf = np.zeros(n)
    for _ in range(count):
        at = start + spread * float(rng.random()) ** 1.6
        m = dsp.samples(0.04)
        tick = dsp.bandpass(dsp.white(m, rng), float(rng.uniform(lo, hi)), 3.0) * dsp.perc(m, 0.0003, 0.006)
        dsp.place(buf, tick * level * float(rng.uniform(0.3, 1.0)) * (1.0 - 0.6 * (at - start) / max(spread, 1e-3)),
                  dsp.samples(at))
    return buf


# --------------------------------------------------------------------------- impacts


def spark(rng: np.random.Generator, v: int) -> np.ndarray:
    n = dsp.samples(0.18)
    crackle = np.zeros(n)
    count = 28 + 6 * v
    pos = (dsp.samples(0.11) * rng.random(count) ** 2).astype(int)
    crackle[pos] = rng.uniform(-1.0, 1.0, count)
    crackle = dsp.bandpass(crackle, 5200.0 + 600.0 * v, 0.8) * 4.0
    burst = dsp.highpass(dsp.white(n, rng), 3000.0) * dsp.perc(n, 0.0003, 0.01)
    ping = 0.25 * dsp.sine(3100.0 + 450.0 * v, n) * dsp.perc(n, 0.0005, 0.03)
    return _finish(crackle + 0.6 * burst + ping, rng, 900.0)


def armour(rng: np.random.Generator, v: int) -> np.ndarray:
    f = [610.0, 540.0, 690.0][v]
    n = dsp.samples(0.45)
    plate = dsp.partials(f, n, [(1.0, 1.0, 0.09), (2.76, 0.6, 0.05), (5.4, 0.35, 0.025), (8.9, 0.15, 0.012)], rng)
    strike = 0.8 * dsp.bandpass(dsp.white(n, rng), 2600.0, 0.8) * dsp.perc(n, 0.0003, 0.006)
    knock = 0.6 * dsp.sine(f * 0.3, n) * dsp.perc(n, 0.001, 0.025)
    return _finish(plate + strike + knock, rng, 120.0)


def ground(rng: np.random.Generator, v: int) -> np.ndarray:
    n = dsp.samples(0.5)
    t = dsp.time_axis(n)
    thud = dsp.sine((75.0 + 8.0 * v) * (1.0 + 0.7 * np.exp(-t / 0.012)), n) * dsp.perc(n, 0.001, 0.05)
    puff = dsp.lowpass(dsp.white(n, rng), 1100.0) * dsp.perc(n, 0.002, 0.06)
    grit = debris(rng, n, 14, 0.04, 0.3, 1500.0, 5000.0, 0.25)
    return _finish(thud + 0.5 * puff + grit, rng, 50.0)


for _v in range(3):
    sound(f"impact_spark_{_v + 1}", "impact", -27.0, folder="impacts", max_seconds=0.6,
          params={"recipe": "spark"})(lambda rng, v=_v: spark(rng, v))
    sound(f"impact_armour_{_v + 1}", "impact", -26.0, folder="impacts", max_seconds=0.9,
          params={"recipe": "armour"})(lambda rng, v=_v: armour(rng, v))
    sound(f"impact_ground_{_v + 1}", "impact", -26.0, folder="impacts", max_seconds=0.9,
          params={"recipe": "ground"})(lambda rng, v=_v: ground(rng, v))


# --------------------------------------------------------------------------- explosions


def explosion(rng: np.random.Generator, size: float) -> np.ndarray:
    """size 0 (small) .. 1 (large). Crack, body, rumble and debris; bigger is
    longer, deeper and has a second wave of debris."""
    dur = 0.8 + 2.2 * size
    n = dsp.samples(dur)
    t = dsp.time_axis(n)
    crack = dsp.bandpass(dsp.white(n, rng), 1800.0 - 600.0 * size, 0.6) * dsp.perc(n, 0.0004, 0.012 + 0.01 * size)
    f_lo = 55.0 - 20.0 * size
    thump = dsp.sine(f_lo + (90.0 - 30.0 * size) * np.exp(-t / (0.03 + 0.03 * size)), n)
    thump *= dsp.perc(n, 0.001, 0.12 + 0.2 * size)
    body_cut = 2200.0 - 1200.0 * size
    body = dsp.sweep(dsp.white(n, rng), "lp", body_cut * (0.25 + 0.75 * np.exp(-t / (0.15 + 0.3 * size))), 0.7)
    body *= dsp.perc(n, 0.002, 0.1 + 0.25 * size)
    rumble = dsp.lowpass(dsp.brown(n, rng), 180.0 + 60.0 * (1.0 - size))
    rumble *= dsp.env([(0.0, 0.0), (0.03, 1.0), (dur * 0.3, 0.6), (dur, 0.0)], n, 2.0)
    bits = debris(rng, n, int(10 + 30 * size), 0.08, dur * 0.6, level=0.25)
    # The sub thump carries weight but little loudness; bigger blasts lean on
    # the body and rumble instead, so the limiter is not left doing the work.
    x = 0.8 * crack + (1.2 - 0.5 * size) * thump + (0.9 + 0.5 * size) * body + (0.4 + 0.8 * size) * rumble + bits
    if size > 0.4:
        x += debris(rng, n, int(20 * size), dur * 0.35, dur * 0.4, 600.0, 2500.0, 0.2)
    # Bigger blasts are driven harder: denser, and the limiter has less to do.
    x = dsp.saturate(x * 1.4, 1.2 + 1.3 * size)
    room = dict(OUTDOOR, seconds=1.0 + 1.2 * size)
    return _finish(x, rng, 32.0, room, -60.0, 0.15)


SIZES = {"small": (0.0, -23.0, 1.6), "medium": (0.45, -21.0, 2.6), "large": (1.0, -19.0, 4.2)}
for _name, (_size, _lufs, _max) in SIZES.items():
    for _v in range(3):
        sound(f"explosion_{_name}_{_v + 1}", "explosion", _lufs, folder="explosions", max_seconds=_max,
              params={"recipe": "explosion"})(lambda rng, s=_size, v=_v: explosion(rng, s + 0.06 * v))


# --------------------------------------------------------------------------- deaths


def power_down(rng: np.random.Generator, dur: float, f0: float) -> np.ndarray:
    """Electrical fizz falling in pitch: the machine's systems dying."""
    n = dsp.samples(dur)
    u = dsp.time_axis(n) / dur
    f = f0 * 0.25 ** u
    buzz = dsp.warm_saw(f, n, 10.0) * (0.7 + 0.3 * dsp.sine(37.0, n))
    fizz = dsp.bandpass(dsp.white(n, rng), 3500.0, 0.8) * (0.4 + 0.6 * (rng.random(n) > 0.7))
    return (0.5 * buzz + 0.3 * fizz) * dsp.env([(0.0, 0.0), (0.02, 1.0), (dur, 0.0)], n, 1.5)


def death_light(rng: np.random.Generator, v: int) -> np.ndarray:
    buf = np.zeros(dsp.samples(1.4))
    dsp.place(buf, explosion(rng, 0.05 * v), 0)
    dsp.place(buf, 0.35 * power_down(rng, 0.6, 900.0 + 120.0 * v), dsp.samples(0.03))
    return _finish(buf, rng, 40.0, dict(seconds=0.4, mix=0.05), -60.0, 0.1)


def groan(rng: np.random.Generator, dur: float, f0: float) -> np.ndarray:
    """Stressed metal: a slow-falling saw through a moving resonance."""
    n = dsp.samples(dur)
    u = dsp.time_axis(n) / dur
    f = f0 * (1.0 - 0.35 * u) * (1.0 + 0.02 * dsp.smooth_random(n, rng, 6.0, periodic=False))
    x = dsp.warm_saw(f, n, 20.0)
    x = dsp.sweep(x, "bp", 500.0 + 900.0 * (0.5 + 0.5 * dsp.smooth_random(n, rng, 3.0, periodic=False)), 4.0)
    return x * dsp.env([(0.0, 0.0), (dur * 0.2, 1.0), (dur * 0.7, 0.7), (dur, 0.0)], n)


def death_heavy(rng: np.random.Generator, v: int) -> np.ndarray:
    buf = np.zeros(dsp.samples(2.6))
    dsp.place(buf, explosion(rng, 0.5 + 0.05 * v), 0)
    dsp.place(buf, 0.5 * groan(rng, 1.2, 70.0 + 9.0 * v), dsp.samples(0.15))
    dsp.place(buf, 0.6 * explosion(rng, 0.0), dsp.samples(0.32 + 0.05 * v))
    dsp.place(buf, 0.3 * power_down(rng, 0.9, 500.0), dsp.samples(0.1))
    return _finish(buf, rng, 32.0, dict(seconds=0.6, mix=0.06), -60.0, 0.2)


def death_building(rng: np.random.Generator, v: int) -> np.ndarray:
    """A building comes down: the blast, a long metal groan as the frame gives,
    the collapse thud a second later, a cascade of debris, settling dust."""
    total = 3.8
    n = dsp.samples(total)
    buf = np.zeros(n)
    dsp.place(buf, explosion(rng, 0.7), 0)
    dsp.place(buf, 0.7 * groan(rng, 1.4, 52.0 + 6.0 * v), dsp.samples(0.35))
    m = dsp.samples(2.4)
    t = dsp.time_axis(m)
    fall = dsp.sine(38.0 + 40.0 * np.exp(-t / 0.05), m) * dsp.perc(m, 0.004, 0.25)
    fall += 0.9 * dsp.lowpass(dsp.brown(m, rng), 260.0) * dsp.env([(0.0, 0.0), (0.05, 1.0), (2.4, 0.0)], m, 2.5)
    dsp.place(buf, fall, dsp.samples(1.15 + 0.1 * v))
    dsp.place(buf, debris(rng, n, 70, 1.2, 2.0, 500.0, 3500.0, 0.35), 0)
    for k in range(5):
        f = float(rng.uniform(300, 700))
        c = dsp.partials(f, dsp.samples(0.3), [(1.0, 0.6, 0.05), (2.76, 0.3, 0.03), (5.4, 0.15, 0.015)], rng)
        dsp.place(buf, 0.4 * c, dsp.samples(1.25 + 0.3 * k + float(rng.uniform(0, 0.15))))
    dust = dsp.bandpass(dsp.white(n, rng), 2500.0, 0.5) * dsp.env([(0.0, 0.0), (1.4, 0.0), (2.0, 0.12), (total, 0.0)], n)
    return _finish(buf + dust, rng, 30.0, dict(OUTDOOR, seconds=1.8), -60.0, 0.4)


for _v in range(3):
    sound(f"death_light_{_v + 1}", "explosion", -23.0, folder="deaths", max_seconds=1.8,
          params={"recipe": "death_light"})(lambda rng, v=_v: death_light(rng, v))
    sound(f"death_heavy_{_v + 1}", "explosion", -21.0, folder="deaths", max_seconds=3.0,
          params={"recipe": "death_heavy"})(lambda rng, v=_v: death_heavy(rng, v))
for _v in range(2):
    sound(f"death_building_{_v + 1}", "explosion", -20.0, folder="deaths", max_seconds=4.6, min_seconds=2.5,
          params={"recipe": "death_building"})(lambda rng, v=_v: death_building(rng, v))
