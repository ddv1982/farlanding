"""Movement loops, one per chassis. Mono (they play positionally).

Seamless by construction: every oscillator runs a whole number of cycles per
loop, every modulator a whole number of periods, noise is generated circularly,
filters run through `dsp.periodic`, and one-off events (footfalls, clanks)
are placed in one loop length and folded with `dsp.wrap`.
"""

from __future__ import annotations

import numpy as np

from synth import dsp

from . import sound

MOVE_LUFS = -24.0


def qf(freq: float, seconds: float) -> float:
    """Nearest frequency that completes a whole number of cycles in the loop."""
    return max(round(freq * seconds), 1) / seconds


def lfo(n: int, seconds: float, cycles: int, phase: float = 0.0) -> np.ndarray:
    return np.sin(2 * np.pi * (cycles * dsp.time_axis(n) / seconds + phase))


def _finish(x: np.ndarray) -> np.ndarray:
    x = dsp.periodic(dsp.highpass, x, 35.0)
    return x - x.mean()


@sound("move_rover", "movement", MOVE_LUFS, loop=True, params={"events": ["move_surveyor"]}, min_seconds=2.9, max_seconds=3.1)
def move_rover(rng: np.random.Generator) -> np.ndarray:
    """Wheeled rover (Surveyor): electric hub-motor whine, tyre hiss on grit,
    and light suspension rattles."""
    L = 3.0
    n = dsp.samples(L)
    wobble = 1.0 + 0.004 * lfo(n, L, 2) + 0.002 * lfo(n, L, 5, 0.3)
    f0 = qf(196.0, L)
    whine = dsp.wavetable(f0 * wobble, n, lambda k: [1.0, 0.5, 0.35, 0.0, 0.2, 0.0, 0.12][k - 1] if k <= 7 else 0.0)
    whine += 0.25 * dsp.sine(qf(f0 * 7.5, L) * wobble, n)  # gear mesh
    whine *= 0.18
    grit = dsp.periodic(dsp.bandpass, dsp.pink(n, rng), 900.0, 0.6)
    grit *= 0.5 * (0.75 + 0.25 * dsp.smooth_random(n, rng, 6.0))
    rattles = np.zeros(n + dsp.samples(0.2))
    for _ in range(9):
        at = int(rng.integers(0, n))
        m = dsp.samples(0.05)
        r = dsp.bandpass(dsp.white(m, rng), float(rng.uniform(1800, 3200)), 4.0) * dsp.perc(m, 0.0005, 0.008)
        dsp.place(rattles, r * float(rng.uniform(0.2, 0.5)), at)
    return _finish(whine + grit + dsp.wrap(rattles, n))


def footfall(rng: np.random.Generator, weight: float) -> np.ndarray:
    n = dsp.samples(0.35)
    t = dsp.time_axis(n)
    thump = dsp.sine(70.0 * (1.0 + 0.6 * np.exp(-t / 0.012)), n) * dsp.perc(n, 0.002, 0.035)
    crunch = dsp.bandpass(dsp.white(n, rng), 2200.0, 0.7) * dsp.perc(n, 0.003, 0.03) * 0.35
    clack = dsp.partials(820.0, n, [(1.0, 0.25, 0.02), (2.7, 0.12, 0.012)], rng)
    return weight * (thump + crunch + clack)


def servo(rng: np.random.Generator, up: bool) -> np.ndarray:
    n = dsp.samples(0.16)
    u = dsp.time_axis(n) / 0.16
    f = 620.0 * (1.5 ** (u if up else 1.0 - u))
    x = dsp.wavetable(f, n, lambda k: [1.0, 0.3, 0.2][k - 1] if k <= 3 else 0.0)
    return 0.12 * x * dsp.ar(n, 0.03, 0.06, 0.07)


@sound("move_walker", "movement", MOVE_LUFS, loop=True, params={"events": ["move_ranger"]}, min_seconds=1.9, max_seconds=2.1)
def move_walker(rng: np.random.Generator) -> np.ndarray:
    """Bipedal walker (Ranger): four steps per loop, alternating feet, a servo
    glide lifting each leg and a soft hydraulic breath."""
    L = 2.0
    n = dsp.samples(L)
    buf = np.zeros(n + dsp.samples(0.5))
    for i in range(4):
        at = dsp.samples(i * 0.5 + float(rng.uniform(0.0, 0.008)))
        dsp.place(buf, footfall(rng, 1.0 if i % 2 == 0 else 0.86), at)
        dsp.place(buf, servo(rng, i % 2 == 0), at + dsp.samples(0.2))
    hiss = dsp.periodic(dsp.bandpass, dsp.pink(n, rng), 3500.0, 0.8) * 0.03 * (0.6 + 0.4 * lfo(n, L, 4, 0.1))
    return _finish(dsp.wrap(buf, n) + hiss)


@sound("move_tracks", "movement", MOVE_LUFS, loop=True, params={"events": ["move_bulwark"]}, min_seconds=3.9, max_seconds=4.1)
def move_tracks(rng: np.random.Generator) -> np.ndarray:
    """Heavy tracks (Bulwark): a slow diesel-like engine, track-link clanks and
    the grind of the drive sprockets."""
    L = 4.0
    n = dsp.samples(L)
    f0 = qf(31.0, L)
    fire = 0.65 + 0.35 * (0.5 + 0.5 * lfo(n, L, int(round(f0 * L / 2))))  # firing pulses
    engine = dsp.wavetable(f0, n, lambda k: (1.0 / k) * np.exp(-(k - 1) / 9.0)) * fire
    engine = dsp.periodic(dsp.lowpass, engine, 700.0, 0.9) * 0.6
    rumble = dsp.periodic(dsp.lowpass, dsp.brown(n, rng), 160.0) * 0.35
    clanks = np.zeros(n + dsp.samples(0.2))
    rate = 7  # links per second
    for i in range(int(L * rate)):
        at = dsp.samples(i / rate + float(rng.uniform(0.0, 0.004)))
        m = dsp.samples(0.08)
        c = dsp.partials(float(rng.uniform(760, 880)), m, [(1.0, 1.0, 0.018), (2.76, 0.6, 0.012), (5.4, 0.3, 0.006)], rng)
        c += 0.3 * dsp.bandpass(dsp.white(m, rng), 1500.0, 1.0) * dsp.perc(m, 0.0005, 0.01)
        dsp.place(clanks, c * float(rng.uniform(0.18, 0.32)), at)
    grind = dsp.periodic(dsp.bandpass, dsp.pink(n, rng), 1900.0, 1.2) * 0.12 * (0.7 + 0.3 * lfo(n, L, int(L * rate)))
    return _finish(engine + rumble + dsp.wrap(clanks, n) + grind)


@sound("move_hover", "movement", MOVE_LUFS, loop=True, params={"events": ["move_kite"]}, min_seconds=3.9, max_seconds=4.1)
def move_hover(rng: np.random.Generator) -> np.ndarray:
    """Hover skimmer (Kite): lift-fan blade buzz, a turbine whine and the rush
    of air under the skirt."""
    L = 4.0
    n = dsp.samples(L)
    wob = 1.0 + 0.006 * lfo(n, L, 1) + 0.003 * lfo(n, L, 3, 0.2)
    blades = dsp.wavetable(qf(92.0, L) * wob, n, lambda k: np.exp(-(k - 1) / 5.0) / k ** 0.5) * 0.25
    blades = dsp.periodic(dsp.lowpass, blades, 1200.0)
    turbine = (dsp.sine(qf(1240.0, L) * wob, n) + 0.4 * dsp.sine(qf(2480.0, L) * wob, n)) * 0.05
    sweep = 900.0 * (1.0 + 0.5 * (0.5 + 0.5 * lfo(n, L, 2, 0.25)))
    air = dsp.periodic(dsp.sweep, dsp.pink(n, rng), "bp", sweep, 0.5) * 0.55
    hum = dsp.sine(qf(55.0, L), n) * 0.15
    return _finish(blades + turbine + air + hum)


@sound("move_sixwheel", "movement", MOVE_LUFS, loop=True, params={"events": ["move_hauler"]}, min_seconds=3.9, max_seconds=4.1)
def move_sixwheel(rng: np.random.Generator) -> np.ndarray:
    """Six-wheeled harvester (Hauler): a deep electric drive drone, a gearbox
    whine a fifth above, heavy tyre roll and ore shifting in the hopper."""
    L = 4.0
    n = dsp.samples(L)
    wob = 1.0 + 0.003 * lfo(n, L, 1) + 0.002 * lfo(n, L, 3, 0.4)
    f0 = qf(73.5, L)
    drive = dsp.wavetable(f0 * wob, n, lambda k: [1.0, 0.7, 0.45, 0.3, 0.2, 0.12][k - 1] if k <= 6 else 0.0)
    drive = dsp.periodic(dsp.lowpass, drive, 900.0) * 0.4
    whine = (dsp.sine(qf(f0 * 6.0, L) * wob, n) + 0.3 * dsp.sine(qf(f0 * 9.0, L) * wob, n)) * 0.045
    roll = dsp.periodic(dsp.lowpass, dsp.brown(n, rng), 220.0) * 0.5
    roll *= 0.8 + 0.2 * lfo(n, L, 6, 0.1)  # wheel rotation
    grit = dsp.periodic(dsp.bandpass, dsp.pink(n, rng), 1100.0, 0.7) * 0.22
    ore = np.zeros(n + dsp.samples(0.2))
    for _ in range(26):
        at = int(rng.integers(0, n))
        m = dsp.samples(0.06)
        r = dsp.bandpass(dsp.white(m, rng), float(rng.uniform(900, 2600)), 3.0) * dsp.perc(m, 0.0005, 0.01)
        dsp.place(ore, r * float(rng.uniform(0.15, 0.45)), at)
    return _finish(drive + whine + roll + grit + dsp.wrap(ore, n))


@sound("move_drone", "movement", MOVE_LUFS, loop=True, params={"events": ["move_fabricator"]}, min_seconds=2.9, max_seconds=3.1)
def move_drone(rng: np.random.Generator) -> np.ndarray:
    """Small hovering builder (Fabricator): four little rotors a few hertz
    apart (a soft beating buzz), rotor wash and a gimbal servo chirp."""
    L = 3.0
    n = dsp.samples(L)
    rotors = np.zeros(n)
    for k, f in enumerate([168.0, 173.0, 179.0, 184.0]):
        wob = 1.0 + 0.004 * lfo(n, L, 1 + k, 0.17 * k)
        rotors += dsp.wavetable(qf(f, L) * wob, n, lambda h: np.exp(-(h - 1) / 4.0) / h ** 0.7, start=0.25 * k)
    rotors = dsp.periodic(dsp.lowpass, rotors, 2600.0) * 0.12
    wash = dsp.periodic(dsp.bandpass, dsp.pink(n, rng), 2400.0, 0.6) * 0.3 * (0.85 + 0.15 * lfo(n, L, 2))
    chirps = np.zeros(n + dsp.samples(0.3))
    for at, up in [(0.4, True), (1.9, False)]:
        m = dsp.samples(0.12)
        u = dsp.time_axis(m) / 0.12
        f = 1500.0 * (1.25 ** (u if up else 1.0 - u))
        dsp.place(chirps, 0.05 * dsp.sine(f, m) * dsp.ar(m, 0.02, 0.05, 0.05), dsp.samples(at))
    return _finish(rotors + wash + dsp.wrap(chirps, n))
