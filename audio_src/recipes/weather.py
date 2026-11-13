"""Kessel Reach weather (Phase 6): the dust storm, the planet's rule.

The storm is heard in five parts, all on the **Weather** bus (which the storm's
own muffle leaves alone; it is the thing doing the muffling):

  storm_front_rumble   the warning (`storm_incoming`): a distant wall of low noise
                       rolling in from one side, far thunder inside it, the dust
                       hiss arriving last. Nothing tonal: it is the planet, not us.
  amb_storm_wind       the bed's body: a roaring, surging wind, wide and low-mid
  amb_storm_grit       grit hissing against hulls: fine high sand, grain crackle and
                       the faint ringing of struck metal panels
  amb_storm_throb      low pressure: a slow sub throb on D (36.7 Hz is too low for
                       small speakers, so it sits on D2 with a second harmonic)
  storm_gust_<n>       one-shots: a surge that sweeps across the stereo field
  storm_debris_<n>     one-shots, positional: pebbles skittering, a loose panel
                       rattling, a tumbling can, a spray of grit on armour
  storm_passed         the release: the wind falling away down a closing band, the
                       air opening and a Concord chime D A E rising out of it
  mus_sting_storm_final  Survey's ending: the Trail motif on the reed, each note
                       buried deeper under a rising wall of noise; the hanging G#
                       is swallowed and only wind is left. No resolution.

The beds loop at different lengths (40, 33, 24 s), so their surges never line up
the same way twice; the StormSound node fades them from `storm_changed`.
"""

from __future__ import annotations

import numpy as np

from synth import dsp
from synth.instruments import chime, pad_voice

from . import sound
from .advisor import ADVISOR_LUFS, _phrase, glide_dyad
from .missions import thunder
from .music_kessel import motif_voice
from .world import advisor_dyad

H = dsp.midi_hz


def loop_samples(seconds: float) -> int:
    """Loop length rounded to a multiple of 64 samples (the native Vorbis
    encoder pads to that, which would break the seam)."""
    return int(round(seconds * dsp.SR / 64.0)) * 64


def loop_bounds(n: int) -> dict:
    s = n / dsp.SR
    return dict(min_seconds=s - 0.01, max_seconds=s + 0.01)


def _wide(n: int, rng: np.random.Generator, maker, shared: float) -> np.ndarray:
    common = maker(n, rng)
    return np.stack([shared * common + (1 - shared) * maker(n, rng) for _ in range(2)])


def _finish_loop(x: np.ndarray, hp: float = 30.0) -> np.ndarray:
    x = dsp.periodic(dsp.highpass, x, hp)
    return x - x.mean(axis=1, keepdims=True)


BED = dict(fmt="ogg", channels=2, loop=True, folder="weather")
N_WIND = loop_samples(40.0)
N_GRIT = loop_samples(33.0)
N_THROB = loop_samples(24.0)


@sound("amb_storm_wind", "weather", -25.0, **BED, **loop_bounds(N_WIND))
def storm_wind(rng: np.random.Generator) -> np.ndarray:
    n = N_WIND
    L = n / dsp.SR
    surge = 0.5 + 0.5 * dsp.smooth_random(n, rng, 0.18)
    surge = surge ** 1.3
    drift = dsp.smooth_random(n, rng, 0.07)
    low = _wide(n, rng, dsp.brown, 0.5)
    low = dsp.periodic(dsp.lowpass, low, 260.0, 0.7) * (0.7 + 0.3 * surge)
    body = _wide(n, rng, dsp.pink, 0.25)
    fc = 280.0 + 900.0 * surge
    body = dsp.periodic(dsp.sweep, body, "bp", fc, 0.7, block=256) * (0.35 + 0.65 * surge)
    body = np.stack([body[0] * (1.0 - 0.4 * drift), body[1] * (1.0 + 0.4 * drift)])
    howl = np.zeros((2, n))
    for base, side, cyc in [(620.0, -0.6, 3), (930.0, 0.5, 5)]:
        f = base * (1.0 + 0.08 * np.sin(2 * np.pi * cyc * dsp.time_axis(n) / L))
        tone = dsp.periodic(dsp.sweep, dsp.pink(n, rng), "bp", f, 14.0, block=256)
        howl += dsp.pan(tone * 0.12 * np.clip((surge - 0.35) / 0.65, 0, 1) ** 1.5, side)
    return _finish_loop(0.9 * low + body + howl)


@sound("amb_storm_grit", "weather", -29.0, **BED, **loop_bounds(N_GRIT))
def storm_grit(rng: np.random.Generator) -> np.ndarray:
    n = N_GRIT
    density = 0.5 + 0.5 * dsp.smooth_random(n, rng, 0.35)
    hiss = _wide(n, rng, dsp.white, 0.15)
    hiss = dsp.periodic(dsp.highpass, hiss, 3800.0)
    hiss = dsp.periodic(dsp.lowpass, hiss, 8000.0) * (0.06 + 0.1 * density)
    grains = np.zeros((2, n + dsp.samples(0.1)))
    weights = density ** 2 / np.sum(density ** 2)
    for at in rng.choice(n, size=int(n / dsp.SR * 140), p=weights):
        m = dsp.samples(0.008)
        g = dsp.bandpass(dsp.white(m, rng), float(rng.uniform(2500, 8000)), 2.5) * dsp.perc(m, 0.0002, 0.0015)
        dsp.place(grains, dsp.pan(g * float(rng.uniform(0.03, 0.1)), float(rng.uniform(-1, 1))), int(at))
    # Struck hull panels: faint resonant rings when a heavier spray hits.
    for at in rng.choice(n, size=int(n / dsp.SR * 0.8), p=weights):
        m = dsp.samples(0.9)
        exc = dsp.white(m, rng) * dsp.perc(m, 0.001, 0.01)
        ring = sum(dsp.bandpass(exc, float(f), 60.0) for f in rng.uniform(1800, 3600, 3))
        dsp.place(grains, dsp.pan(ring * 0.5, float(rng.uniform(-0.8, 0.8))), int(at))
    return _finish_loop(hiss + dsp.wrap(grains, n), 200.0)


@sound("amb_storm_throb", "weather", -31.0, **BED, **loop_bounds(N_THROB))
def storm_throb(rng: np.random.Generator) -> np.ndarray:
    n = N_THROB
    L = n / dsp.SR
    t = dsp.time_axis(n)
    f = round(H(38) * L) / L  # D2, whole cycles per loop
    beat = 0.5 - 0.5 * np.cos(2 * np.pi * round(0.32 * L) * t / L)  # ~0.3 Hz pressure swell
    tone = dsp.sine(f, n) + 0.35 * dsp.sine(2 * f, n) + 0.1 * dsp.sine(3 * f, n)
    tone *= 0.25 + 0.75 * beat ** 2
    rumble = dsp.periodic(dsp.lowpass, dsp.brown(n, rng), 140.0) * (0.5 + 0.5 * beat)
    x = np.stack([0.6 * tone + 0.8 * rumble, 0.6 * tone + 0.8 * dsp.periodic(dsp.lowpass, dsp.brown(n, rng), 140.0)
                  * (0.5 + 0.5 * beat)])
    return _finish_loop(x, 32.0)


ONESHOT = dict(fmt="ogg", channels=2, folder="weather")


def _gust(rng: np.random.Generator, dur: float, peak: float, f0: float, f1: float, pan0: float,
          pan1: float) -> np.ndarray:
    n = dsp.samples(dur)
    u = dsp.time_axis(n) / dur
    shape = dsp.env([(0.0, 0.0), (peak * dur, 1.0), (dur, 0.0)], n, 1.5)
    fc = f0 * (f1 / f0) ** np.sin(np.pi * u)
    out = np.zeros((2, n))
    for k in range(2):
        src = dsp.pink(n, rng)
        band = dsp.sweep(src, "bp", fc * (1.0 + 0.06 * k), 0.8, block=128)
        out += dsp.pan(band * shape, pan0 + (pan1 - pan0) * u) * 0.5
    sand = dsp.bandpass(dsp.white(n, rng), 4500.0, 1.2) * shape ** 2 * 0.05
    out += dsp.pan(sand, pan0 + (pan1 - pan0) * u)
    return dsp.fade(dsp.dc_block(dsp.highpass(out, 40.0)), 0.01, 0.2)


for _i, (_d, _p, _f0, _f1, _a, _b) in enumerate([
    (3.0, 0.55, 300.0, 1400.0, -0.9, 0.8),
    (2.6, 0.4, 380.0, 1800.0, 0.8, -0.6),
    (3.6, 0.65, 250.0, 1100.0, -0.3, 0.9),
    (2.2, 0.35, 450.0, 2200.0, 0.6, -0.9),
], start=1):
    def _make(rng: np.random.Generator, d=_d, p=_p, f0=_f0, f1=_f1, a=_a, b=_b) -> np.ndarray:
        return _gust(rng, d, p, f0, f1, a, b)

    sound(f"storm_gust_{_i}", "weather", -26.0, max_seconds=4.0, min_seconds=2.0,
          params={"recipe": "_gust"}, **ONESHOT)(_make)


DEBRIS = dict(folder="weather")


def _debris_done(x: np.ndarray) -> np.ndarray:
    return dsp.fade(dsp.trim_tail(dsp.dc_block(dsp.highpass(x, 120.0)), -55.0), 0.001, 0.05)


@sound("storm_debris_1", "weather", -26.0, max_seconds=1.6, **DEBRIS)
def debris_pebbles(rng: np.random.Generator) -> np.ndarray:
    """Pebbles skittering past."""
    buf = np.zeros(dsp.samples(1.5))
    at = 0.0
    for k in range(int(rng.integers(9, 14))):
        m = dsp.samples(0.05)
        hit = dsp.bandpass(dsp.white(m, rng), float(rng.uniform(1800, 4200)), 4.0) * dsp.perc(m, 0.0005, 0.006)
        dsp.place(buf, hit * float(rng.uniform(0.4, 1.0)) * (1.0 - k / 16), dsp.samples(at))
        at += float(rng.uniform(0.03, 0.12))
    return _debris_done(buf)


@sound("storm_debris_2", "weather", -26.0, max_seconds=1.6, **DEBRIS)
def debris_panel(rng: np.random.Generator) -> np.ndarray:
    """A loose metal panel rattling in a surge."""
    buf = np.zeros(dsp.samples(1.4))
    for k in range(7):
        m = dsp.samples(0.35)
        exc = dsp.white(m, rng) * dsp.perc(m, 0.001, 0.008)
        ring = sum(dsp.bandpass(exc, f, 40.0) for f in (410.0, 1130.0, 2210.0))
        dsp.place(buf, ring * (0.9 - 0.1 * k), dsp.samples(0.06 + k * 0.11 + float(rng.uniform(0, 0.03))))
    return _debris_done(buf)


@sound("storm_debris_3", "weather", -26.0, max_seconds=1.6, **DEBRIS)
def debris_can(rng: np.random.Generator) -> np.ndarray:
    """A tumbling canister: hollow knocks slowing down."""
    buf = np.zeros(dsp.samples(1.5))
    at = 0.0
    gap = 0.09
    for k in range(8):
        m = dsp.samples(0.25)
        exc = dsp.white(m, rng) * dsp.perc(m, 0.001, 0.004)
        knock = dsp.bandpass(exc, 760.0, 18.0) + 0.6 * dsp.bandpass(exc, 1850.0, 25.0)
        dsp.place(buf, knock * (1.0 - 0.09 * k), dsp.samples(at))
        at += gap
        gap *= 1.18
    return _debris_done(buf)


@sound("storm_debris_4", "weather", -26.0, max_seconds=1.6, **DEBRIS)
def debris_spray(rng: np.random.Generator) -> np.ndarray:
    """A spray of grit hitting armour."""
    n = dsp.samples(0.9)
    hiss = dsp.bandpass(dsp.white(n, rng), 5200.0, 0.8) * dsp.env([(0, 0), (0.05, 1.0), (0.9, 0)], n, 2.0)
    buf = hiss * 0.5
    for at in rng.uniform(0.0, 0.5, 30):
        m = dsp.samples(0.02)
        g = dsp.bandpass(dsp.white(m, rng), float(rng.uniform(3000, 7000)), 3.0) * dsp.perc(m, 0.0003, 0.002)
        dsp.place(buf, g * float(rng.uniform(0.3, 0.9)), dsp.samples(float(at)))
    return _debris_done(buf)


@sound("storm_debris_5", "weather", -26.0, max_seconds=1.8, **DEBRIS)
def debris_scrape(rng: np.random.Generator) -> np.ndarray:
    """Something heavy scraping across rock, then a thud."""
    n = dsp.samples(1.6)
    u = dsp.time_axis(n) / 1.6
    scrape = dsp.sweep(dsp.white(n, rng), "bp", 900.0 + 500.0 * u, 3.0) * dsp.env([(0, 0), (0.1, 1), (1.1, 0.7),
                                                                                   (1.2, 0), (1.6, 0)], n)
    m = dsp.samples(0.4)
    t = dsp.time_axis(m)
    thud = dsp.sine(140.0 * (1 + 0.3 * np.exp(-t / 0.02)), m) * dsp.perc(m, 0.002, 0.08)
    buf = 0.5 * scrape
    dsp.place(buf, thud, dsp.samples(1.15))
    return _debris_done(buf)


@sound("storm_front_rumble", "weather", -25.0, max_seconds=9.0, min_seconds=6.0, **ONESHOT)
def front_rumble(rng: np.random.Generator) -> np.ndarray:
    dur = 8.5
    n = dsp.samples(dur)
    u = dsp.time_axis(n) / dur
    swell = dsp.env([(0.0, 0.0), (dur * 0.65, 1.0), (dur, 0.0)], n, 1.2)
    wall = np.stack([dsp.sweep(dsp.brown(n, rng), "lp", 130.0 + 260.0 * u, 0.7, block=256) for _ in range(2)])
    wall *= swell
    side = -0.7 + 1.0 * u  # rolls in from the left
    out = np.stack([wall[0] * np.sqrt(0.5 * (1 - side)), wall[1] * np.sqrt(0.5 * (1 + side))]) * 1.4
    for at, gain, pan in [(1.4, 0.5, -0.6), (4.2, 0.7, -0.2), (6.0, 0.4, 0.3)]:
        dsp.place(out, dsp.pan(gain * thunder(rng, 2.6), pan), dsp.samples(at))
    hiss = dsp.sweep(dsp.pink(n, rng), "bp", 1500.0 + 2500.0 * u, 0.8, block=256) * u ** 3 * swell * 0.25
    out += dsp.pan(hiss, 0.0)
    return dsp.fade(dsp.dc_block(dsp.highpass(dsp.highpass(out, 45.0), 45.0)), 0.3, 1.5)


@sound("storm_passed", "weather", -24.0, max_seconds=7.0, min_seconds=4.0, **ONESHOT)
def storm_passed(rng: np.random.Generator) -> np.ndarray:
    dur = 6.5
    n = dsp.samples(dur)
    u = dsp.time_axis(n) / dur
    fall = dsp.env([(0.0, 1.0), (2.5, 0.35), (4.5, 0.0)], n, 1.0)
    wind = np.stack([dsp.sweep(dsp.pink(n, rng), "bp", 1400.0 * 0.15 ** np.minimum(u * 1.6, 1.0), 0.8, block=256)
                     for _ in range(2)]) * fall * 0.6
    buf = np.zeros((2, n + dsp.samples(4.0)))
    dsp.place(buf, wind, 0)
    for k, (m, at) in enumerate([(74, 1.6), (81, 2.1), (88, 2.6)]):  # D A E: the sky opens
        c = chime(H(m), 0.05, rng, brightness=0.6, decay=1.2, attack=0.02, tail=2.5)
        dsp.place(buf, dsp.pan(0.35 * c, -0.3 + 0.3 * k), dsp.samples(at))
    for k, m in enumerate([62, 69, 76]):
        p = pad_voice(H(m), 3.0, rng, attack=1.2, release=2.2, brightness=2.6)
        dsp.place(buf, p * (0.22 if k == 0 else 0.15), dsp.samples(1.8))
    y = dsp.reverb(buf, rng, seconds=3.0, mix=0.35, predelay_ms=25.0, damp=0.55)
    y = dsp.trim_tail(dsp.dc_block(dsp.highpass(y, 30.0)), -60.0)[:, : dsp.samples(6.8)]
    return dsp.fade(y, 0.05, 1.2)


@sound("mus_sting_storm_final", "sting", -22.0, min_seconds=6.0, max_seconds=9.0, fmt="ogg", channels=2,
       folder="music/stings")
def sting_storm_final(rng: np.random.Generator) -> np.ndarray:
    total = 8.6
    n = dsp.samples(total)
    buf = np.zeros((2, n + dsp.samples(3.0)))
    at = 0.3
    beat = 0.62
    for i, (m, beats) in enumerate([(62, 0.5), (69, 1.5), (71, 0.5), (68, 4.0)]):
        v = motif_voice(m, beats, 0.9 - 0.12 * i, rng, beat)
        v = dsp.lowpass(v, 3200.0 - 650.0 * i)  # each note further away
        dsp.place(buf, dsp.pan(v, 0.1), dsp.samples(at))
        at += beats * beat
    u = dsp.time_axis(n) / total
    wall = np.stack([dsp.sweep(dsp.pink(n, rng), "bp", 250.0 + 900.0 * u, 0.6, block=256) for _ in range(2)])
    wall *= dsp.env([(0.0, 0.05), (2.0, 0.25), (4.2, 1.0), (total, 0.7)], n, 0.0) * 0.9
    dsp.place(buf, wall, 0)
    dsp.place(buf, dsp.stereo(0.9 * thunder(rng, 3.8, crack=0.4)), dsp.samples(3.7))
    low = np.stack([dsp.lowpass(dsp.brown(n, rng), 120.0) for _ in range(2)]) * u * 0.8
    dsp.place(buf, low, 0)
    y = dsp.reverb(buf, rng, seconds=2.8, mix=0.3, predelay_ms=20.0, damp=0.6)
    y = dsp.dc_block(dsp.highpass(y, 30.0))[:, : dsp.samples(8.4)]
    return dsp.fade(y, 0.01, 2.2)


# --------------------------------------------------------------------------- Advisor


@sound("advisor_storm_passed", "advisor", ADVISOR_LUFS - 1.0, max_seconds=1.8)
def advisor_storm_passed(rng: np.random.Generator) -> np.ndarray:
    """Relief, after the out-of-key storm warning: a muffled B+F# opens up and
    lifts a step into D+A, a high A+E answers."""
    a = glide_dyad(H(71), H(78), 0.45, 3.0, 0.3)
    a = dsp.sweep(a, "lp", np.linspace(900.0, 4000.0, len(a)), 0.7)
    b = advisor_dyad(H(74), H(81), 0.6)
    c = advisor_dyad(H(81), H(88), 0.35)
    return _phrase([(0.0, 0.8, a), (0.55, 1.0, b), (1.0, 0.55, c)], rng, 1.8)


@sound("advisor_enemy_intel", "advisor", ADVISOR_LUFS, max_seconds=2.0)
def advisor_enemy_intel(rng: np.random.Generator) -> np.ndarray:
    """The Combine is banking Intel: the motif's opening dyad D+A answered by a
    lower, bent Bb+F (their version of it), twice, the second sagging."""
    a = advisor_dyad(H(74), H(81), 0.22)
    b = glide_dyad(H(70), H(77), 0.3, -0.6, 0.5)
    c = advisor_dyad(H(74), H(81), 0.22)
    d = glide_dyad(H(70), H(77), 0.55, -2.0, 0.3)
    return _phrase([(0.0, 0.8, a), (0.25, 0.95, b), (0.7, 0.8, c), (0.95, 1.0, d)], rng, 1.8)

