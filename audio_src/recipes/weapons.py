"""Weapon fire: one sound per weapon sound set, three variations each. Mono
(positional, Weapons bus).

The two factions must be told apart by ear alone:

  Concord Survey   clean, tonal and tight. Sine and FM voices pitched on D
                   Lydian notes, short controlled noise, no distortion, a
                   small dry room. Rapid weapons are short and high-passed so a
                   squad firing together stays a pleasant patter.
  Halcyon Combine  harsher, lower and dirtier. Detuned saws and ring
                   modulation at inharmonic ratios, saturated noise, crackle,
                   rattle. Nothing sits in the Concord key.

  repeater     (Ranger)  a bright FM bolt that chirps down an octave onto A/B/C#, 0.15 s
  light_gun    (Kite)    a double-tap of tight tonal 'tak's on E/F#, 0.15 s
  sentry       (turret)  twin bolts a fifth apart (high, then lower) with a soft body, 0.3 s
  cannon       (Bulwark) a deep tuned thump, a tight crack, the barrel ringing on D, a breech clack
  skitter_gun  (drone)   a buzzy ring-modulated snap with grit, low and short
  lance        (Stinger) a 0.3 s piercing beam: detuned saw cluster, a whine sweeping up, crackle
  siege        (Mauler)  two dirty saturated booms with a metal clang and rattle
"""

from __future__ import annotations

import numpy as np

from synth import dsp

from . import sound

H = dsp.midi_hz
ROOM = dict(seconds=0.35, mix=0.1, predelay_ms=4.0, damp=0.7)
HEAVY_ROOM = dict(seconds=0.9, mix=0.16, predelay_ms=8.0, damp=0.6)


def _finish(x: np.ndarray, rng: np.random.Generator, hp: float, room: dict = ROOM,
            tail_db: float = -55.0) -> np.ndarray:
    wet = dsp.reverb(dsp.highpass(x, hp), rng, **room).mean(axis=0)
    return dsp.fade(dsp.trim_tail(dsp.dc_block(wet), tail_db), 0.0005, 0.02)


def chirp(f0: float, f1: float, dur: float, curve: float = 30.0) -> np.ndarray:
    """Exponential pitch fall from f0 to f1 (fast at first)."""
    n = dsp.samples(dur)
    u = 1.0 - np.exp(-curve * dsp.time_axis(n) / dur)
    return f0 * (f1 / f0) ** (u / (1.0 - np.exp(-curve)))


def bolt(f_land: float, dur: float, rng: np.random.Generator, drop: float = 2.0,
         glass: float = 0.6) -> np.ndarray:
    """Concord energy bolt: an FM tone that falls onto `f_land`, a glassy
    overtone and a tiny click. Clean and in key."""
    n = dsp.samples(dur)
    f = chirp(f_land * drop, f_land, dur * 0.35)
    f = np.concatenate([f, np.full(n - len(f), f_land)]) if len(f) < n else f[:n]
    idx = 1.4 * dsp.perc(n, 0.0005, dur * 0.12)
    tone = dsp.fm(f, 2.0, idx, n) * dsp.perc(n, 0.0008, dur * 0.22)
    shine = glass * 0.3 * dsp.sine(f * 3.0, n) * dsp.perc(n, 0.0005, dur * 0.06)
    click = 0.25 * dsp.highpass(dsp.white(n, rng), 3000.0) * dsp.perc(n, 0.0002, 0.0025)
    return tone + shine + click


# --------------------------------------------------------------------------- Concord


REPEATER_NOTES = [81, 83, 85]  # A5, B5, C#6 (D Lydian)


@sound("weapon_repeater_fire_1", "weapon", -26.0, folder="weapons", max_seconds=0.4, params={"recipe": "repeater"})
def repeater_1(rng: np.random.Generator) -> np.ndarray:
    return repeater(rng, 0)


@sound("weapon_repeater_fire_2", "weapon", -26.0, folder="weapons", max_seconds=0.4, params={"recipe": "repeater"})
def repeater_2(rng: np.random.Generator) -> np.ndarray:
    return repeater(rng, 1)


@sound("weapon_repeater_fire_3", "weapon", -26.0, folder="weapons", max_seconds=0.4, params={"recipe": "repeater"})
def repeater_3(rng: np.random.Generator) -> np.ndarray:
    return repeater(rng, 2)


def repeater(rng: np.random.Generator, v: int) -> np.ndarray:
    """Ranger repeater: a bright bolt chirping down an octave, very short,
    nothing below 500 Hz, so many at once stay a light patter."""
    x = bolt(H(REPEATER_NOTES[v]), 0.13, rng, drop=2.0, glass=0.7)
    air = 0.12 * dsp.bandpass(dsp.white(len(x), rng), 5200.0, 1.0) * dsp.perc(len(x), 0.0005, 0.012)
    return _finish(x + air, rng, 500.0)


LIGHT_GUN_NOTES = [(88, 90), (90, 88), (88, 88)]  # E6 / F#6 pairs


def light_gun(rng: np.random.Generator, v: int) -> np.ndarray:
    """Kite light gun: a double-tap of tight tonal 'tak's, 45 ms apart, the
    second a little softer. Higher and drier than the repeater."""
    buf = np.zeros(dsp.samples(0.2))
    for k, m in enumerate(LIGHT_GUN_NOTES[v]):
        n = dsp.samples(0.07)
        f = H(m)
        tak = dsp.fm(f, 1.5, 2.0 * dsp.perc(n, 0.0003, 0.006), n) * dsp.perc(n, 0.0004, 0.014)
        snap = 0.35 * dsp.bandpass(dsp.white(n, rng), 4200.0, 1.4) * dsp.perc(n, 0.0002, 0.004)
        dsp.place(buf, (tak + snap) * (1.0 if k == 0 else 0.75), dsp.samples(k * 0.045))
    return _finish(buf, rng, 700.0)


@sound("weapon_light_gun_fire_1", "weapon", -26.0, folder="weapons", max_seconds=0.4, params={"recipe": "light_gun"})
def light_gun_1(rng: np.random.Generator) -> np.ndarray:
    return light_gun(rng, 0)


@sound("weapon_light_gun_fire_2", "weapon", -26.0, folder="weapons", max_seconds=0.4, params={"recipe": "light_gun"})
def light_gun_2(rng: np.random.Generator) -> np.ndarray:
    return light_gun(rng, 1)


@sound("weapon_light_gun_fire_3", "weapon", -26.0, folder="weapons", max_seconds=0.4, params={"recipe": "light_gun"})
def light_gun_3(rng: np.random.Generator) -> np.ndarray:
    return light_gun(rng, 2)


SENTRY_PAIRS = [(86, 81), (88, 81), (86, 80)]  # D6>A5, E6>A5, D6>G#5


def sentry(rng: np.random.Generator, v: int) -> np.ndarray:
    """Sentry turret: twin bolts 70 ms apart, the second a fifth/fourth lower,
    with a soft 220 Hz body so a turret sounds sturdier than a Ranger."""
    hi, lo = SENTRY_PAIRS[v]
    buf = np.zeros(dsp.samples(0.35))
    for k, m in enumerate([hi, lo]):
        x = bolt(H(m), 0.16, rng, drop=1.7, glass=0.5)
        n = len(x)
        body = 0.35 * dsp.sine(H(57) * (1.0 + 0.5 * np.exp(-dsp.time_axis(n) / 0.01)), n) * dsp.perc(n, 0.001, 0.03)
        dsp.place(buf, (x + body) * (1.0 if k == 0 else 0.9), dsp.samples(k * 0.07))
    return _finish(buf, rng, 180.0)


@sound("weapon_sentry_fire_1", "weapon", -25.0, folder="weapons", max_seconds=0.6, params={"recipe": "sentry"})
def sentry_1(rng: np.random.Generator) -> np.ndarray:
    return sentry(rng, 0)


@sound("weapon_sentry_fire_2", "weapon", -25.0, folder="weapons", max_seconds=0.6, params={"recipe": "sentry"})
def sentry_2(rng: np.random.Generator) -> np.ndarray:
    return sentry(rng, 1)


@sound("weapon_sentry_fire_3", "weapon", -25.0, folder="weapons", max_seconds=0.6, params={"recipe": "sentry"})
def sentry_3(rng: np.random.Generator) -> np.ndarray:
    return sentry(rng, 2)


CANNON_RING = [50, 45, 52]  # D3, A2, E3


def cannon(rng: np.random.Generator, v: int) -> np.ndarray:
    """Bulwark cannon: weight without dirt. A deep thump that drops from
    110 to 50 Hz, a tight band-limited crack, the barrel ringing on a scale
    note, and a breech clack as the next shell loads."""
    total = 1.1
    n = dsp.samples(total)
    t = dsp.time_axis(n)
    thump = dsp.sine(50.0 + 60.0 * np.exp(-t / 0.03), n) * dsp.perc(n, 0.001, 0.12)
    crack = dsp.bandpass(dsp.white(n, rng), 2400.0, 0.7) * dsp.perc(n, 0.0004, 0.018)
    blast = dsp.lowpass(dsp.white(n, rng), 900.0) * dsp.perc(n, 0.001, 0.08)
    f = H(CANNON_RING[v])
    ring = dsp.partials(f, n, [(1.0, 0.35, 0.35), (2.0, 0.25, 0.22), (3.0, 0.15, 0.12), (4.0, 0.08, 0.08)], rng)
    ring *= dsp.perc(n, 0.004, 10.0)
    x = 1.1 * thump + 0.7 * crack + 0.5 * blast + 0.5 * ring
    m = dsp.samples(0.08)
    clack = dsp.partials(1250.0, m, [(1.0, 0.4, 0.01), (2.4, 0.25, 0.006)], rng)
    clack += 0.2 * dsp.bandpass(dsp.white(m, rng), 3000.0, 1.0) * dsp.perc(m, 0.0003, 0.004)
    dsp.place(x, 0.35 * clack, dsp.samples(0.42 + 0.03 * v))
    return _finish(x, rng, 38.0, HEAVY_ROOM, -58.0)


@sound("weapon_cannon_fire_1", "weapon", -22.0, folder="weapons", max_seconds=1.6, params={"recipe": "cannon"})
def cannon_1(rng: np.random.Generator) -> np.ndarray:
    return cannon(rng, 0)


@sound("weapon_cannon_fire_2", "weapon", -22.0, folder="weapons", max_seconds=1.6, params={"recipe": "cannon"})
def cannon_2(rng: np.random.Generator) -> np.ndarray:
    return cannon(rng, 1)


@sound("weapon_cannon_fire_3", "weapon", -22.0, folder="weapons", max_seconds=1.6, params={"recipe": "cannon"})
def cannon_3(rng: np.random.Generator) -> np.ndarray:
    return cannon(rng, 2)


# --------------------------------------------------------------------------- Combine


def dirty(x: np.ndarray, drive: float, crush: int = 0) -> np.ndarray:
    """Saturation plus optional sample-and-hold decimation: the Combine grit."""
    y = dsp.saturate(x, drive)
    if crush > 1:
        y = np.repeat(y[::crush], crush)[: len(x)]
        y = dsp.lowpass(y, dsp.SR / crush * 0.9)
    return y


SKITTER = [(310.0, 1.37), (290.0, 1.53), (335.0, 1.29)]


def skitter_gun(rng: np.random.Generator, v: int) -> np.ndarray:
    """Skitter drone gun: a short buzzy snap. A saw ring-modulated at an
    inharmonic ratio, decimated noise grit, little low end."""
    f, ratio = SKITTER[v]
    n = dsp.samples(0.12)
    t = dsp.time_axis(n)
    fr = f * (1.0 + 0.4 * np.exp(-t / 0.01))
    buzz = dsp.warm_saw(fr, n, 14.0) * dsp.sine(fr * ratio, n)
    grit = dsp.bandpass(dsp.white(n, rng), 1600.0, 0.9)
    x = (0.9 * buzz + 0.6 * grit) * dsp.perc(n, 0.0005, 0.022)
    x = dirty(x * 2.0, 2.5, crush=3)
    return _finish(x, rng, 300.0, dict(seconds=0.3, mix=0.08, predelay_ms=3.0, damp=0.8))


@sound("weapon_skitter_gun_fire_1", "weapon", -26.0, folder="weapons", max_seconds=0.4, params={"recipe": "skitter_gun"})
def skitter_gun_1(rng: np.random.Generator) -> np.ndarray:
    return skitter_gun(rng, 0)


@sound("weapon_skitter_gun_fire_2", "weapon", -26.0, folder="weapons", max_seconds=0.4, params={"recipe": "skitter_gun"})
def skitter_gun_2(rng: np.random.Generator) -> np.ndarray:
    return skitter_gun(rng, 1)


@sound("weapon_skitter_gun_fire_3", "weapon", -26.0, folder="weapons", max_seconds=0.4, params={"recipe": "skitter_gun"})
def skitter_gun_3(rng: np.random.Generator) -> np.ndarray:
    return skitter_gun(rng, 2)


LANCE = [(116.0, 2600.0), (109.0, 2900.0), (123.0, 2400.0)]


def lance(rng: np.random.Generator, v: int) -> np.ndarray:
    """Stinger lance: a short piercing beam. A 30 ms charge, then a detuned
    saw cluster beating against itself, ring-modulated, with a whine sweeping
    upward and a crackle of discharge; cut off hard with a sizzling tail."""
    f, whine0 = LANCE[v]
    dur = 0.32
    n = dsp.samples(dur + 0.08)
    t = dsp.time_axis(n)
    e = dsp.env([(0.0, 0.0), (0.03, 1.0), (dur - 0.04, 0.85), (dur, 0.0)], n, 0.0)
    cluster = sum(dsp.warm_saw(f * r, n, 18.0, start=0.3 * k) for k, r in enumerate([1.0, 1.019, 1.497, 2.03]))
    cluster *= 0.6 + 0.4 * dsp.sine(f * 0.37, n)  # ring-ish wobble
    whine = dsp.sine(whine0 * (1.0 + 0.6 * t / dur), n) * 0.35
    crackle = np.zeros(n)
    hits = rng.integers(0, n, 70)
    crackle[hits] = rng.uniform(-1.0, 1.0, len(hits))
    crackle = dsp.highpass(crackle, 2500.0) * 3.0
    x = (0.5 * cluster + whine + crackle) * e
    x = dirty(x * 1.5, 3.0)
    x = dsp.biquad(x, "peak", 1800.0, 1.2, 5.0)
    sizzle = 0.25 * dsp.highpass(dsp.white(n, rng), 4000.0) * dsp.env([(0.0, 0.0), (dur - 0.02, 0.0), (dur, 1.0), (dur + 0.07, 0.0)], n)
    return _finish(x + sizzle, rng, 160.0, dict(seconds=0.4, mix=0.1, predelay_ms=4.0, damp=0.7))


@sound("weapon_lance_fire_1", "weapon", -24.0, folder="weapons", max_seconds=0.8, params={"recipe": "lance"})
def lance_1(rng: np.random.Generator) -> np.ndarray:
    return lance(rng, 0)


@sound("weapon_lance_fire_2", "weapon", -24.0, folder="weapons", max_seconds=0.8, params={"recipe": "lance"})
def lance_2(rng: np.random.Generator) -> np.ndarray:
    return lance(rng, 1)


@sound("weapon_lance_fire_3", "weapon", -24.0, folder="weapons", max_seconds=0.8, params={"recipe": "lance"})
def lance_3(rng: np.random.Generator) -> np.ndarray:
    return lance(rng, 2)


def siege_boom(rng: np.random.Generator, f_clang: float) -> np.ndarray:
    n = dsp.samples(0.9)
    t = dsp.time_axis(n)
    thump = dsp.sine(42.0 + 50.0 * np.exp(-t / 0.035), n) * dsp.perc(n, 0.001, 0.14)
    blast = dsp.lowpass(dsp.brown(n, rng), 1400.0) * dsp.perc(n, 0.001, 0.1)
    hiss = dsp.bandpass(dsp.white(n, rng), 1100.0, 0.5) * dsp.perc(n, 0.0005, 0.04)
    clang = dsp.partials(f_clang, n, [(1.0, 0.3, 0.12), (2.31, 0.25, 0.08), (3.87, 0.2, 0.05), (5.13, 0.1, 0.03)], rng)
    x = 1.2 * thump + 0.9 * blast + 0.6 * hiss + 0.5 * clang
    return dirty(x * 1.8, 3.5)


SIEGE = [(173.0, 0.19), (161.0, 0.21), (187.0, 0.17)]


def siege(rng: np.random.Generator, v: int) -> np.ndarray:
    """Mauler siege guns: twin heavy shells. Two saturated booms (low thump,
    brown-noise blast, a mistuned clang), the second slightly lower, then a
    loose metal rattle as the mounts settle."""
    f, gap = SIEGE[v]
    buf = np.zeros(dsp.samples(1.4))
    dsp.place(buf, siege_boom(rng, f), 0)
    dsp.place(buf, 0.9 * siege_boom(rng, f * 0.94), dsp.samples(gap))
    for _ in range(7):
        m = dsp.samples(0.05)
        r = dsp.bandpass(dsp.white(m, rng), float(rng.uniform(1400, 2600)), 3.0) * dsp.perc(m, 0.0004, 0.008)
        dsp.place(buf, r * float(rng.uniform(0.1, 0.25)), dsp.samples(gap + float(rng.uniform(0.25, 0.6))))
    return _finish(buf, rng, 36.0, HEAVY_ROOM, -58.0)


@sound("weapon_siege_fire_1", "weapon", -22.0, folder="weapons", max_seconds=2.0, params={"recipe": "siege"})
def siege_1(rng: np.random.Generator) -> np.ndarray:
    return siege(rng, 0)


@sound("weapon_siege_fire_2", "weapon", -22.0, folder="weapons", max_seconds=2.0, params={"recipe": "siege"})
def siege_2(rng: np.random.Generator) -> np.ndarray:
    return siege(rng, 1)


@sound("weapon_siege_fire_3", "weapon", -22.0, folder="weapons", max_seconds=2.0, params={"recipe": "siege"})
def siege_3(rng: np.random.Generator) -> np.ndarray:
    return siege(rng, 2)
