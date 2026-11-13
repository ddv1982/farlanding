"""Thalassa Low (Phase 8a): the planet's ambience, the tide, and the Recovery
mission's sounds.

Kessel was dry, warm and dusty; Thalassa is wet, wide and cold. Its air is
broadband and soft (wind over open water, no rock whistles), there is always
far surf, and under it a low tidal drone on F# (the planet's key, F# Aeolian).

Planet beds (group `ambience`, the AmbienceDirector's own players):

  amb_thalassa_wind    wide wind over water: soft broadband gusts, spray hiss
                       breathing with them (44 s)
  amb_thalassa_surf    distant surf: five long swells per loop, each a low roll
                       that breaks into a wash and draws back (39 s)
  amb_thalassa_drone   the tidal drone: F# and C# low, very slowly beating, a
                       pressure of filtered noise under it (31 s)

Details (group `ambdetail`, positional one-shots around the listener):

  amb_water_lap_<n>    two to four small laps against a hull or a bank, a glug
  amb_shore_call_<n>   a far, abstract shore call: a sine glide with a soft
                       formant, falling E6 -> C#6 (never a real bird), sparse
  amb_shell_click_<n>  shells and pebbles clicking as the water moves them
  amb_buoy_bell_<n>    a far bell buoy: a low bell struck twice by the swell
  amb_drip_<n>         drips from wet rock and metal

The tide (group `weather`, on the Weather bus, the TideSound's players):

  amb_tide_low         low water: dark, distant water, slow washes (36 s)
  amb_tide_high        high water: bright close lapping, bubbles, trickles (27 s)
                       (the two crossfade with the level: the bed's brightness)
  amb_tide_rush        the rising rush: a band of water noise that seems to
                       climb for ever (three bands sweeping up an octave in
                       turn, a Shepard figure), a rushing flow (22 s)
  amb_tide_pull        the falling pull: the same figure sweeping down, with the
                       pebbly rattle of backwash and a sucking gurgle (25 s)
  tide_turn_rising     the warning, rising: three bell tones going up, F# B F#,
                       short-short-long, over a swelling wash
  tide_turn_falling    the warning, falling: F# C# F# going down, long-short-long,
                       over a draining hiss

Advisor (the Meridian's dyads): tide_rising, tide_falling, units_in_water,
artefact_taken, artefact_secured. Interface: ui_artefact_pickup,
ui_artefact_drop. And `loop_hum_artefact`, the carried artefact's soft hum.
"""

from __future__ import annotations

import numpy as np

from synth import dsp
from synth.instruments import bell, chime

from . import sound
from .advisor import ADVISOR_LUFS, _phrase, glide_dyad
from .ambience import _detail
from .movement import lfo, qf
from .weather import loop_bounds, loop_samples
from .world import advisor_dyad

H = dsp.midi_hz


def _wide(n: int, rng: np.random.Generator, maker, shared: float) -> np.ndarray:
    common = maker(n, rng)
    return np.stack([shared * common + (1 - shared) * maker(n, rng) for _ in range(2)])


def _finish(x: np.ndarray, hp: float = 30.0) -> np.ndarray:
    x = dsp.periodic(dsp.highpass, x, hp)
    return x - x.mean(axis=1, keepdims=True)


def _cyc(n: int, cycles: int, phase: float = 0.0) -> np.ndarray:
    """0..1 raised cosine with a whole number of cycles over the loop."""
    t = np.arange(n) / n
    return 0.5 - 0.5 * np.cos(2 * np.pi * cycles * t + phase)


# --------------------------------------------------------------------------- planet beds


AMB = dict(fmt="ogg", channels=2, loop=True, folder="ambience/thalassa")
N_WIND = loop_samples(44.0)
N_SURF = loop_samples(39.0)
N_DRONE = loop_samples(31.0)


@sound("amb_thalassa_wind", "ambience", -30.0, **AMB, **loop_bounds(N_WIND))
def amb_thalassa_wind(rng: np.random.Generator) -> np.ndarray:
    n = N_WIND
    gust = (0.5 + 0.5 * dsp.smooth_random(n, rng, 0.06)) ** 1.2
    drift = dsp.smooth_random(n, rng, 0.03)
    low = _wide(n, rng, dsp.brown, 0.4)
    low = dsp.periodic(dsp.lowpass, low, 300.0, 0.6) * (0.5 + 0.3 * gust)
    body = _wide(n, rng, dsp.pink, 0.2)
    body = dsp.periodic(dsp.sweep, body, "bp", 500.0 + 700.0 * gust, 0.5, block=256) * (0.25 + 0.5 * gust)
    body = np.stack([body[0] * (1.0 - 0.4 * drift), body[1] * (1.0 + 0.4 * drift)])
    spray = _wide(n, rng, dsp.white, 0.1)
    spray = dsp.periodic(dsp.bandpass, spray, 6500.0, 0.7) * 0.035 * gust ** 2
    return _finish(low + body + spray)


@sound("amb_thalassa_surf", "ambience", -33.0, **AMB, **loop_bounds(N_SURF))
def amb_thalassa_surf(rng: np.random.Generator) -> np.ndarray:
    n = N_SURF
    out = np.zeros((2, n))
    for k, (cycles, side, phase) in enumerate([(5, -0.5, 0.0), (4, 0.55, 2.1), (3, 0.0, 4.0)]):
        u = np.arange(n) / n * cycles + phase / (2 * np.pi)
        frac = u - np.floor(u)
        # a slow roll in, a quicker break, a long wash back out
        roll = np.where(frac < 0.55, (frac / 0.55) ** 2, ((1.0 - frac) / 0.45) ** 2.5)
        src = dsp.pink(n, rng)
        fc = 250.0 + 1300.0 * roll
        band = dsp.periodic(dsp.sweep, src, "bp", fc, 0.6, block=256) * roll * (0.8 - 0.15 * k)
        out += dsp.pan(band, side)
    rumble = _wide(n, rng, dsp.brown, 0.5)
    rumble = dsp.periodic(dsp.lowpass, rumble, 180.0) * 0.4
    x = dsp.periodic(dsp.lowpass, out + rumble, 5000.0)
    return _finish(x, 40.0)


@sound("amb_thalassa_drone", "ambience", -34.0, **AMB, **loop_bounds(N_DRONE))
def amb_thalassa_drone(rng: np.random.Generator) -> np.ndarray:
    n = N_DRONE
    L = n / dsp.SR
    t = dsp.time_axis(n)
    tone = np.zeros(n)
    for note, amp in [(42, 0.5), (49, 0.28), (54, 0.18), (61, 0.06)]:  # F#2 C#3 F#3 C#4
        f = qf(H(note), L)
        f2 = qf(H(note) + 0.35, L)
        tone += amp * (dsp.sine(f, n) + 0.8 * dsp.sine(f2, n))
    breathe = 0.7 + 0.3 * _cyc(n, 3)
    pressure = dsp.periodic(dsp.lowpass, dsp.brown(n, rng), 160.0) * 0.35
    left = tone * breathe + pressure
    right = tone * (0.7 + 0.3 * _cyc(n, 3, 1.3)) + dsp.periodic(dsp.lowpass, dsp.brown(n, rng), 160.0) * 0.35
    x = np.stack([left, right])
    x += 0.02 * np.stack([np.sin(2 * np.pi * qf(H(85), L) * t) * _cyc(n, 2), np.zeros(n)])
    return _finish(x, 35.0)


# --------------------------------------------------------------------------- details


DETAIL = dict(folder="ambience/details")


def _lap(rng: np.random.Generator, count: int) -> np.ndarray:
    buf = np.zeros(dsp.samples(3.5))
    at = 0.05
    for k in range(count):
        m = dsp.samples(0.5)
        u = dsp.time_axis(m) / 0.5
        wash = dsp.sweep(dsp.pink(m, rng), "bp", 900.0 + 900.0 * (1 - u), 1.2, block=64)
        wash *= dsp.env([(0, 0), (0.03, 1.0), (0.5, 0)], m, 2.5)
        glug_m = dsp.samples(0.12)
        tt = dsp.time_axis(glug_m)
        glug = dsp.sine(float(rng.uniform(260, 420)) * (1 + 1.5 * tt / 0.12), glug_m) * dsp.perc(glug_m, 0.004, 0.03)
        dsp.place(buf, wash * (1.0 - 0.15 * k), dsp.samples(at))
        dsp.place(buf, 0.35 * glug, dsp.samples(at + 0.08))
        at += float(rng.uniform(0.45, 0.8))
    return buf


for _i, _c in enumerate([2, 3, 4, 2], start=1):
    def _make_lap(rng: np.random.Generator, c=_c) -> np.ndarray:
        return _detail(_lap(rng, c), rng, 0.25, 1.8)

    sound(f"amb_water_lap_{_i}", "ambdetail", -26.0, max_seconds=5.0, params={"recipe": "_lap"},
          **DETAIL)(_make_lap)


def _call(rng: np.random.Generator, calls: int, top: int, low: int) -> np.ndarray:
    """An abstract shore call: a falling sine glide through a soft formant."""
    buf = np.zeros(dsp.samples(3.0))
    at = 0.05
    for k in range(calls):
        dur = 0.32 if k < calls - 1 else 0.55
        m = dsp.samples(dur)
        u = dsp.time_axis(m) / dur
        f = H(top) * (H(low) / H(top)) ** (u ** 0.7)
        vib = 1.0 + 0.012 * np.sin(2 * np.pi * 9.0 * dsp.time_axis(m))
        tone = dsp.sine(f * vib, m) + 0.25 * dsp.sine(2 * f * vib, m)
        tone = dsp.bandpass(tone, 1900.0, 0.8) * dsp.env([(0, 0), (0.03, 1.0), (dur * 0.6, 0.7), (dur, 0)], m)
        dsp.place(buf, tone * (1.0 - 0.15 * k), dsp.samples(at))
        at += dur + float(rng.uniform(0.06, 0.14))
    return buf


for _i, (_n, _top, _low) in enumerate([(2, 88, 85), (3, 90, 85), (1, 88, 83)], start=1):
    def _make_call(rng: np.random.Generator, c=_n, top=_top, low=_low) -> np.ndarray:
        return _detail(_call(rng, c, top, low), rng, 0.35, 2.2)

    sound(f"amb_shore_call_{_i}", "ambdetail", -27.0, max_seconds=4.5, params={"recipe": "_call"},
          **DETAIL)(_make_call)


def _clicks(rng: np.random.Generator, count: int, spread: float) -> np.ndarray:
    buf = np.zeros(dsp.samples(spread + 0.8))
    at = 0.0
    for k in range(count):
        m = dsp.samples(0.08)
        exc = dsp.white(m, rng) * dsp.perc(m, 0.0004, 0.002)
        f = float(rng.uniform(2500, 5200))
        click = dsp.bandpass(exc, f, 14.0) + 0.4 * dsp.bandpass(exc, f * 1.7, 10.0)
        dsp.place(buf, click * float(rng.uniform(0.4, 1.0)), dsp.samples(at))
        at += float(rng.exponential(spread / count))
    hiss_m = dsp.samples(spread + 0.3)
    hiss = dsp.bandpass(dsp.white(hiss_m, rng), 3000.0, 0.9) * dsp.env([(0, 0), (0.1, 1), (spread + 0.3, 0)], hiss_m)
    dsp.place(buf, 0.04 * hiss, 0)
    return buf


for _i, (_c, _s) in enumerate([(8, 0.9), (14, 1.8), (5, 0.4)], start=1):
    def _make_clicks(rng: np.random.Generator, c=_c, s=_s) -> np.ndarray:
        return _detail(_clicks(rng, c, s), rng, 0.15, 1.2)

    sound(f"amb_shell_click_{_i}", "ambdetail", -26.0, max_seconds=3.5, params={"recipe": "_clicks"},
          **DETAIL)(_make_clicks)


def _buoy(rng: np.random.Generator, note: int, second: float) -> np.ndarray:
    buf = np.zeros(dsp.samples(6.0))
    for k, at in enumerate([0.05, second]):
        b = bell(H(note), rng, decay=1.6, brightness=0.35, strike=0.25, length=4.0)
        dsp.place(buf, b * (1.0 if k == 0 else 0.6), dsp.samples(at))
    return dsp.lowpass(buf, 2600.0)


for _i, (_note, _second) in enumerate([(61, 1.7), (66, 2.3)], start=1):
    def _make_buoy(rng: np.random.Generator, note=_note, second=_second) -> np.ndarray:
        return _detail(_buoy(rng, note, second), rng, 0.45, 3.0)

    sound(f"amb_buoy_bell_{_i}", "ambdetail", -27.0, max_seconds=7.5, params={"recipe": "_buoy"},
          **DETAIL)(_make_buoy)


def _drips(rng: np.random.Generator, count: int) -> np.ndarray:
    buf = np.zeros(dsp.samples(2.0))
    at = 0.02
    for k in range(count):
        m = dsp.samples(0.09)
        tt = dsp.time_axis(m)
        f0 = float(rng.uniform(900, 1500))
        drop = dsp.sine(f0 * (1 + 1.8 * tt / 0.09), m) * dsp.perc(m, 0.001, 0.018)
        dsp.place(buf, drop * float(rng.uniform(0.6, 1.0)), dsp.samples(at))
        at += float(rng.uniform(0.25, 0.7))
    return buf


for _i, _c in enumerate([1, 2, 3], start=1):
    def _make_drips(rng: np.random.Generator, c=_c) -> np.ndarray:
        return _detail(_drips(rng, c), rng, 0.4, 1.4)

    sound(f"amb_drip_{_i}", "ambdetail", -28.0, max_seconds=3.5, params={"recipe": "_drips"},
          **DETAIL)(_make_drips)


# --------------------------------------------------------------------------- the tide


TIDE = dict(fmt="ogg", channels=2, loop=True, folder="weather/tide")
N_LOW = loop_samples(36.0)
N_HIGH = loop_samples(27.0)
N_RUSH = loop_samples(22.0)
N_PULL = loop_samples(25.0)


@sound("amb_tide_low", "weather", -28.0, **TIDE, **loop_bounds(N_LOW))
def tide_low(rng: np.random.Generator) -> np.ndarray:
    n = N_LOW
    wash = 0.6 + 0.4 * _cyc(n, 4)
    x = _wide(n, rng, dsp.pink, 0.3)
    x = dsp.periodic(dsp.sweep, x, "lp", 250.0 + 450.0 * wash, 0.6, block=256) * wash
    low = dsp.periodic(dsp.lowpass, _wide(n, rng, dsp.brown, 0.5), 140.0) * 0.5
    return _finish(x + low, 35.0)


@sound("amb_tide_high", "weather", -27.0, **TIDE, **loop_bounds(N_HIGH))
def tide_high(rng: np.random.Generator) -> np.ndarray:
    n = N_HIGH
    buf = np.zeros((2, n + dsp.samples(1.0)))
    at = 0.0
    while at < n / dsp.SR:
        m = dsp.samples(0.45)
        u = dsp.time_axis(m) / 0.45
        lap = dsp.sweep(dsp.pink(m, rng), "bp", 1600.0 + 1200.0 * (1 - u), 1.1, block=64)
        lap *= dsp.env([(0, 0), (0.025, 1.0), (0.45, 0)], m, 3.0) * float(rng.uniform(0.4, 1.0))
        dsp.place(buf, dsp.pan(lap, float(rng.uniform(-0.8, 0.8))), dsp.samples(at))
        at += float(rng.uniform(0.35, 1.1))
    for at in rng.uniform(0.0, n / dsp.SR, int(n / dsp.SR * 3)):
        m = dsp.samples(0.06)
        tt = dsp.time_axis(m)
        bub = dsp.sine(float(rng.uniform(600, 1400)) * (1 + 1.2 * tt / 0.06), m) * dsp.perc(m, 0.002, 0.012)
        dsp.place(buf, dsp.pan(0.18 * bub, float(rng.uniform(-0.9, 0.9))), dsp.samples(float(at)))
    x = dsp.wrap(buf, n)
    trickle = dsp.periodic(dsp.bandpass, _wide(n, rng, dsp.white, 0.0), 4200.0, 1.0) * 0.03
    body = dsp.periodic(dsp.lowpass, _wide(n, rng, dsp.pink, 0.3), 600.0) * 0.25
    return _finish(x + trickle + body, 60.0)


def _shepard(n: int, rng: np.random.Generator, up: bool, cycles: int, lo: float, hi: float) -> np.ndarray:
    """Water noise whose band seems to climb (or fall) for ever: three bands an
    octave-span apart, each sweeping across [lo, hi] in turn and fading at the ends."""
    out = np.zeros((2, n))
    span = np.log(hi / lo)
    for k in range(3):
        u = (np.arange(n) / n * cycles + k / 3.0) % 1.0
        pos = u if up else 1.0 - u
        fc = lo * np.exp(span * pos)
        level = np.sin(np.pi * pos) ** 2
        src = _wide(n, rng, dsp.pink, 0.4)
        band = dsp.periodic(dsp.sweep, src, "bp", fc, 0.9, block=128)
        out += band * level
    return out


@sound("amb_tide_rush", "weather", -29.0, **TIDE, **loop_bounds(N_RUSH))
def tide_rush(rng: np.random.Generator) -> np.ndarray:
    n = N_RUSH
    climb = _shepard(n, rng, True, 4, 300.0, 3200.0)
    flow = dsp.periodic(dsp.bandpass, _wide(n, rng, dsp.pink, 0.2), 700.0, 0.5) * (0.35 + 0.15 * _cyc(n, 6))
    return _finish(climb + flow, 50.0)


@sound("amb_tide_pull", "weather", -29.0, **TIDE, **loop_bounds(N_PULL))
def tide_pull(rng: np.random.Generator) -> np.ndarray:
    n = N_PULL
    fall = _shepard(n, rng, False, 4, 250.0, 2600.0) * 0.8
    buf = np.zeros((2, n + dsp.samples(0.5)))
    backwash = _cyc(n, 5, -1.0)
    weights = backwash ** 3 / np.sum(backwash ** 3)
    for at in rng.choice(n, size=int(n / dsp.SR * 45), p=weights):
        m = dsp.samples(0.05)
        exc = dsp.white(m, rng) * dsp.perc(m, 0.0004, 0.003)
        f = float(rng.uniform(1800, 4500))
        click = dsp.bandpass(exc, f, 10.0)
        dsp.place(buf, dsp.pan(click * float(rng.uniform(0.15, 0.5)), float(rng.uniform(-0.9, 0.9))), int(at))
    for at in rng.uniform(0.0, n / dsp.SR, int(n / dsp.SR * 0.8)):  # a sucking gurgle
        m = dsp.samples(0.4)
        tt = dsp.time_axis(m)
        gurgle = dsp.sine(220.0 * (1 - 0.4 * tt / 0.4) * (1 + 0.05 * np.sin(2 * np.pi * 30 * tt)), m)
        gurgle *= dsp.env([(0, 0), (0.05, 1), (0.4, 0)], m)
        dsp.place(buf, dsp.pan(0.25 * gurgle, float(rng.uniform(-0.6, 0.6))), dsp.samples(float(at)))
    return _finish(fall + dsp.wrap(buf, n), 50.0)


ONESHOT = dict(fmt="ogg", channels=2, folder="weather/tide")


def _turn(rng: np.random.Generator, notes, wash_up: bool) -> np.ndarray:
    total = 4.6
    n = dsp.samples(total)
    buf = np.zeros((2, n + dsp.samples(5.0)))
    for k, (m, at) in enumerate(notes):
        b = bell(H(m), rng, decay=1.0 + 0.4 * k, brightness=0.45, strike=0.3, length=3.5)
        c = chime(H(m + 12), 0.04, rng, brightness=0.4, decay=0.6, attack=0.008, tail=1.5)
        dsp.place(buf, dsp.pan(dsp.mix(0.8 * b, 0.25 * c), -0.3 + 0.3 * k), dsp.samples(at))
    u = dsp.time_axis(n) / total
    if wash_up:
        shape = dsp.env([(0, 0), (2.6, 1.0), (total, 0)], n, 0.0)
        fc = 300.0 * 8.0 ** u
    else:
        shape = dsp.env([(0, 0), (0.4, 1.0), (total, 0)], n, 1.5)
        fc = 2400.0 * 0.125 ** u
    wash = np.stack([dsp.sweep(dsp.pink(n, rng), "bp", fc, 0.7, block=256) for _ in range(2)]) * shape * 0.35
    dsp.place(buf, wash, 0)
    y = dsp.reverb(buf, rng, seconds=3.0, mix=0.35, predelay_ms=25.0, damp=0.55)
    y = dsp.trim_tail(dsp.dc_block(dsp.highpass(y, 40.0)), -60.0)[:, : dsp.samples(5.4)]
    return dsp.fade(y, 0.01, 1.0)


@sound("tide_turn_rising", "weather", -24.0, max_seconds=5.6, min_seconds=3.0, **ONESHOT)
def tide_turn_rising(rng: np.random.Generator) -> np.ndarray:
    """Short-short-long, going up: F#4 B4 F#5."""
    return _turn(rng, [(66, 0.1), (71, 0.42), (78, 0.74)], True)


@sound("tide_turn_falling", "weather", -24.0, max_seconds=5.6, min_seconds=3.0, **ONESHOT)
def tide_turn_falling(rng: np.random.Generator) -> np.ndarray:
    """Long-short-long, going down: F#5 C#5 F#4."""
    return _turn(rng, [(78, 0.1), (73, 0.9), (66, 1.22)], False)


# --------------------------------------------------------------------------- Advisor


@sound("advisor_tide_rising", "advisor", ADVISOR_LUFS + 1.0, max_seconds=1.8)
def advisor_tide_rising(rng: np.random.Generator) -> np.ndarray:
    """The water is coming: F#+C#, A+E, then B+F# gliding up a step: a climb that keeps going."""
    a = advisor_dyad(H(66), H(73), 0.14)
    b = advisor_dyad(H(69), H(76), 0.14)
    c = glide_dyad(H(71), H(78), 0.5, 2.0, 0.3)
    return _phrase([(0.0, 0.85, a), (0.18, 0.9, b), (0.36, 1.0, c)], rng, 1.6)


@sound("advisor_tide_falling", "advisor", ADVISOR_LUFS, max_seconds=1.8)
def advisor_tide_falling(rng: np.random.Generator) -> np.ndarray:
    """The water goes out: B+F#, A+E, then F#+C# sliding down a step: the fords open."""
    a = advisor_dyad(H(71), H(78), 0.2)
    b = advisor_dyad(H(69), H(76), 0.2)
    c = glide_dyad(H(66), H(73), 0.55, -2.0, 0.35)
    return _phrase([(0.0, 0.9, a), (0.26, 0.85, b), (0.52, 0.8, c)], rng, 1.6)


@sound("advisor_units_in_water", "advisor", ADVISOR_LUFS + 1.0, max_seconds=1.6)
def advisor_units_in_water(rng: np.random.Generator) -> np.ndarray:
    """Units wading: the D+G# warning tritone, twice, wobbling as if under water."""
    parts = []
    for k, at in enumerate([0.0, 0.3]):
        n = dsp.samples(0.22 + 0.25)
        t = dsp.time_axis(n)
        wobble = 2.0 ** (0.35 * np.sin(2 * np.pi * 11.0 * t) / 12.0)
        x = advisor_dyad(H(62) * wobble, H(68) * wobble, 0.22)
        parts.append((at, 1.0 - 0.1 * k, x))
    return _phrase(parts, rng, 1.2)


@sound("advisor_artefact_taken", "advisor", ADVISOR_LUFS + 1.0, max_seconds=1.8)
def advisor_artefact_taken(rng: np.random.Generator) -> np.ndarray:
    """The Combine has the artefact: the Trail motif's D+A, at once bent down to
    their Bb+F, fast and twice, the second sagging further."""
    a = advisor_dyad(H(74), H(81), 0.12)
    b = glide_dyad(H(70), H(77), 0.2, -0.8, 0.4)
    c = advisor_dyad(H(74), H(81), 0.12)
    d = glide_dyad(H(70), H(77), 0.45, -2.5, 0.3)
    return _phrase([(0.0, 0.9, a), (0.14, 1.0, b), (0.48, 0.9, c), (0.62, 1.0, d)], rng, 1.6)


@sound("advisor_artefact_secured", "advisor", ADVISOR_LUFS, max_seconds=1.8)
def advisor_artefact_secured(rng: np.random.Generator) -> np.ndarray:
    """Ours: the Trail motif's question D+A, B+F#, answered home: a held D+A with its octave."""
    a = advisor_dyad(H(74), H(81), 0.14)
    b = advisor_dyad(H(71), H(78), 0.14)
    c = advisor_dyad(H(74), H(81), 0.5)
    d = advisor_dyad(H(86), H(93), 0.45)
    return _phrase([(0.0, 0.85, a), (0.18, 0.85, b), (0.36, 1.0, c), (0.4, 0.4, d)], rng, 1.6)


# --------------------------------------------------------------------------- interface


def _ui_done(x: np.ndarray) -> np.ndarray:
    return dsp.fade(dsp.trim_tail(dsp.dc_block(dsp.highpass(x, 250.0)), -55.0), 0.0005, 0.02)


@sound("ui_artefact_pickup", "ui", -27.0, max_seconds=0.45)
def ui_artefact_pickup(rng: np.random.Generator) -> np.ndarray:
    """Picked up: a small Antecedent bell lifting a fifth, D6 then A6, and a soft latch."""
    buf = np.zeros(dsp.samples(0.42))
    for k, (m, at) in enumerate([(86, 0.0), (93, 0.06)]):
        b = bell(H(m), rng, decay=0.1 + 0.04 * k, brightness=0.5, strike=0.2, length=0.32)
        dsp.place(buf, b * (0.8 if k == 0 else 1.0), dsp.samples(at))
    m = dsp.samples(0.03)
    latch = dsp.bandpass(dsp.white(m, rng), 2200.0, 4.0) * dsp.perc(m, 0.0005, 0.004)
    dsp.place(buf, 0.3 * latch, 0)
    return _ui_done(buf)


@sound("ui_artefact_drop", "ui", -28.0, max_seconds=0.45)
def ui_artefact_drop(rng: np.random.Generator) -> np.ndarray:
    """Set down: the bell falling a fifth, A6 then D6, and a soft low thud."""
    buf = np.zeros(dsp.samples(0.42))
    for k, (m, at) in enumerate([(93, 0.0), (86, 0.07)]):
        b = bell(H(m), rng, decay=0.09 + 0.05 * k, brightness=0.45, strike=0.15, length=0.32)
        dsp.place(buf, b * (0.8 if k == 0 else 1.0), dsp.samples(at))
    m = dsp.samples(0.12)
    tt = dsp.time_axis(m)
    thud = dsp.sine(300.0 * (1 + 0.4 * np.exp(-tt / 0.01)), m) * dsp.perc(m, 0.001, 0.025)
    dsp.place(buf, 0.35 * thud, dsp.samples(0.07))
    return _ui_done(buf)


# --------------------------------------------------------------------------- the carried artefact


@sound("loop_hum_artefact", "baseloop", -31.0, loop=True, folder="base/loops", min_seconds=5.9, max_seconds=6.1)
def loop_hum_artefact(rng: np.random.Generator) -> np.ndarray:
    """The artefact, carried: an Antecedent drone on D and G# beating slowly
    (the frame of the Trail motif, as in the Warden's metal), a glassy shimmer
    that swells twice per loop. Soft, and never in a hurry."""
    L = 6.0
    n = dsp.samples(L)
    tone = np.zeros(n)
    for note, amp in [(62, 0.5), (68, 0.3), (74, 0.2), (86, 0.05)]:
        tone += amp * (dsp.sine(qf(H(note), L), n) + 0.7 * dsp.sine(qf(H(note) + 0.5, L), n))
    tone *= 0.8 + 0.2 * lfo(n, L, 1)
    shimmer = dsp.periodic(dsp.bandpass, dsp.pink(n, rng), 5200.0, 3.0) * 0.06 * (0.5 + 0.5 * lfo(n, L, 2))
    x = tone * 0.4 + shimmer
    x = dsp.periodic(dsp.highpass, x, 120.0)
    return x - x.mean()
