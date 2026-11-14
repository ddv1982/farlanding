"""Planet ambience beds. Stereo, long, seamless loops (Ogg)."""

from __future__ import annotations

import numpy as np

from synth import dsp

from . import sound


def _decorrelated(n: int, rng: np.random.Generator, maker, shared: float) -> np.ndarray:
    """Stereo noise: `shared` of the signal is common to both channels."""
    common = maker(n, rng)
    return np.stack([shared * common + (1 - shared) * maker(n, rng) for _ in range(2)])


@sound("amb_kessel_wind", "ambience", -30.0, fmt="ogg", channels=2, loop=True,
       min_seconds=47.9, max_seconds=48.1)
def amb_kessel_wind(rng: np.random.Generator) -> np.ndarray:
    """Kessel Reach: a dry dust basin. A low steady wind, gusts that move
    across the stereo field, fine sand hiss that rises with each gust, and a
    faint whistle where the wind catches rock edges."""
    L = 48.0
    n = dsp.samples(L)
    gust = 0.5 + 0.5 * dsp.smooth_random(n, rng, 0.09)  # 0..1, slow
    gust = gust ** 1.4
    drift = dsp.smooth_random(n, rng, 0.04)  # -1..1, slower: where the gust sits

    low = _decorrelated(n, rng, dsp.brown, 0.6)
    low = dsp.periodic(dsp.lowpass, low, 220.0, 0.6) * (0.55 + 0.25 * gust)

    mid = _decorrelated(n, rng, dsp.pink, 0.3)
    centre = 380.0 + 650.0 * gust
    mid = dsp.periodic(dsp.sweep, mid, "bp", centre, 0.9, block=256) * (0.15 + 0.6 * gust)
    mid = np.stack([mid[0] * (1.0 - 0.35 * drift), mid[1] * (1.0 + 0.35 * drift)])

    dust = _decorrelated(n, rng, dsp.white, 0.2)
    dust = dsp.periodic(dsp.highpass, dust, 4500.0)
    dust = dsp.periodic(dsp.lowpass, dust, 11000.0) * 0.05 * gust ** 2

    grains = np.zeros((2, n + dsp.samples(0.05)))
    count = int(L * 24)
    weights = gust / gust.sum()
    for at in rng.choice(n, size=count, p=weights):
        m = dsp.samples(0.006)
        g = dsp.bandpass(dsp.white(m, rng), float(rng.uniform(3000, 7000)), 3.0) * dsp.perc(m, 0.0002, 0.0012)
        dsp.place(grains, dsp.pan(g * float(rng.uniform(0.02, 0.07)), float(rng.uniform(-0.9, 0.9))), int(at))
    grains = dsp.wrap(grains, n)

    whistle = np.zeros((2, n))
    for base, side, cyc in [(1250.0, -0.5, 3), (1870.0, 0.45, 2)]:
        src = dsp.pink(n, rng)
        f = base * (1.0 + 0.04 * np.sin(2 * np.pi * cyc * dsp.time_axis(n) / L))
        tone = dsp.periodic(dsp.sweep, src, "bp", f, 28.0, block=256)
        level = np.clip((gust - 0.45) / 0.55, 0.0, 1.0) ** 2 * 0.12
        whistle += dsp.pan(tone * level, side)

    x = low + mid + dust + grains + whistle
    x = dsp.periodic(dsp.highpass, x, 28.0)
    return x - x.mean(axis=1, keepdims=True)


# --------------------------------------------------------------------------- Phase 6: the full Kessel bed
#
# The base wind (48 s) is joined by a second bed of a different length, so the
# two never line up the same way twice (their pattern repeats only every
# 48 x 37 s), and both have their level wandered slowly at runtime by the
# AmbienceDirector. Over them, positional one-shots (group `ambdetail`) are
# scheduled at random around the listener: settling rock, distant Flux vents,
# dust devils, far Combine industry near a base the player has seen. Near an
# Antecedent site the `hush` bed rises and the wind steps back.


def _loop_n(seconds: float) -> int:
    return int(round(seconds * dsp.SR / 64.0)) * 64


N_AIR = _loop_n(37.0)
N_HUSH = _loop_n(29.0)


def _bounds(n: int) -> dict:
    return dict(min_seconds=n / dsp.SR - 0.01, max_seconds=n / dsp.SR + 0.01)


@sound("amb_kessel_air", "ambience", -33.0, fmt="ogg", channels=2, loop=True, **_bounds(N_AIR))
def amb_kessel_air(rng: np.random.Generator) -> np.ndarray:
    """High thin air over the basin: a wide, slow-breathing band of noise near
    2 kHz, a sand-sift that comes and goes, and two very faint rock-edge
    whistles on G# and C# (the Lydian colour, heard as weather)."""
    n = N_AIR
    L = n / dsp.SR
    breath = 0.5 + 0.5 * dsp.smooth_random(n, rng, 0.06)
    # Partly shared between the channels: still wide, and the codec's channel
    # coupling keeps it well clear of the fidelity floor (Phase 9).
    air = _decorrelated(n, rng, dsp.pink, 0.6)
    air = dsp.periodic(dsp.sweep, air, "bp", 1500.0 + 1200.0 * breath, 0.6, block=256) * (0.2 + 0.3 * breath)
    sift = _decorrelated(n, rng, dsp.white, 0.0)
    sift = dsp.periodic(dsp.bandpass, sift, 6000.0, 1.5) * 0.015 * (0.5 + 0.5 * dsp.smooth_random(n, rng, 0.2)) ** 3
    whistle = np.zeros((2, n))
    for note, side, cyc in [(80, -0.6, 2), (85, 0.5, 3)]:
        f = dsp.midi_hz(note) * (1.0 + 0.01 * np.sin(2 * np.pi * cyc * dsp.time_axis(n) / L))
        tone = dsp.periodic(dsp.sweep, dsp.pink(n, rng), "bp", f, 40.0, block=256)
        level = np.clip((dsp.smooth_random(n, rng, 0.05) - 0.2) / 0.8, 0.0, 1.0) ** 2 * 0.15
        whistle += dsp.pan(tone * level, side)
    x = dsp.periodic(dsp.highpass, air + sift + whistle, 120.0)
    return x - x.mean(axis=1, keepdims=True)


@sound("amb_kessel_hush", "ambience", -32.0, fmt="ogg", channels=2, loop=True, **_bounds(N_HUSH))
def amb_kessel_hush(rng: np.random.Generator) -> np.ndarray:
    """Near Antecedent machinery the air holds still: a faint bell drone on D
    and G# (the frame of the Trail motif, as in the Custodians' metal), very
    slow beating, a glassy shimmer that swells twice per loop."""
    from synth.instruments import bell

    n = N_HUSH
    L = n / dsp.SR
    t = dsp.time_axis(n)
    drone = np.zeros(n)
    for note, amp in [(50, 0.5), (56, 0.3), (62, 0.25), (74, 0.08)]:
        f = round(dsp.midi_hz(note) * L) / L
        f2 = round((dsp.midi_hz(note) + 0.5) * L) / L
        drone += amp * (dsp.sine(f, n) + 0.7 * dsp.sine(f2, n))
    swell = 0.5 - 0.5 * np.cos(2 * np.pi * 2 * t / L)
    shimmer = dsp.periodic(dsp.bandpass, dsp.pink(n, rng), 5200.0, 3.0) * 0.05 * swell
    buf = np.zeros((2, n + dsp.samples(6.0)))
    dsp.place(buf, dsp.pan(drone * (0.6 + 0.4 * swell), -0.1), 0)
    dsp.place(buf, dsp.pan(shimmer, 0.3), 0)
    for at, note, side in [(4.0, 86, -0.5), (18.5, 80, 0.5)]:
        strike = bell(dsp.midi_hz(note), rng, decay=3.0, brightness=0.5)
        dsp.place(buf, dsp.pan(0.08 * strike, side), dsp.samples(at))
    x = dsp.wrap(buf, n)
    x = dsp.wrap(dsp.reverb(x, rng, seconds=4.0, mix=0.5, predelay_ms=30.0, damp=0.5), n)
    x = dsp.periodic(dsp.highpass, x, 60.0)
    return x - x.mean(axis=1, keepdims=True)


DETAIL = dict(folder="ambience/details")


def _detail(x: np.ndarray, rng: np.random.Generator, room: float = 0.25, seconds: float = 1.6) -> np.ndarray:
    """Far away: a little open-air reverb, rolled-off top, mono."""
    y = dsp.reverb(x, rng, seconds=seconds, mix=room, predelay_ms=40.0, damp=0.7).mean(axis=0)
    y = dsp.lowpass(y, 7000.0)
    return dsp.fade(dsp.trim_tail(dsp.dc_block(dsp.highpass(y, 60.0)), -55.0), 0.005, 0.2)


def _rock(rng: np.random.Generator, count: int, spread: float) -> np.ndarray:
    buf = np.zeros(dsp.samples(spread + 1.0))
    at = 0.0
    for k in range(count):
        m = dsp.samples(0.12)
        exc = dsp.white(m, rng) * dsp.perc(m, 0.0005, 0.004)
        click = dsp.bandpass(exc, float(rng.uniform(900, 2600)), 6.0) + 0.5 * dsp.bandpass(exc, float(rng.uniform(300, 600)), 3.0)
        dsp.place(buf, click * float(rng.uniform(0.3, 1.0)) * (1.0 - 0.5 * k / count), dsp.samples(at))
        at += float(rng.exponential(spread / count))
    return buf


for _i, (_count, _spread) in enumerate([(6, 0.8), (14, 2.2), (3, 0.3), (9, 1.4)], start=1):
    def _make_rock(rng: np.random.Generator, c=_count, s=_spread) -> np.ndarray:
        x = _rock(rng, c, s)
        if c <= 3:  # a crack of stone cooling, then the trickle
            m = dsp.samples(0.4)
            crack = dsp.bandpass(dsp.white(m, rng), 1700.0, 1.5) * dsp.perc(m, 0.0005, 0.02)
            dsp.place(x, 1.5 * crack, 0)
        return _detail(x, rng, 0.2)

    sound(f"amb_rock_settle_{_i}", "ambdetail", -24.0, max_seconds=3.6, params={"recipe": "_rock"},
          **DETAIL)(_make_rock)


def _vent(rng: np.random.Generator, dur: float, bubbles: int, base: int) -> np.ndarray:
    n = dsp.samples(dur)
    u = dsp.time_axis(n) / dur
    shape = dsp.env([(0, 0), (dur * 0.3, 1.0), (dur * 0.7, 0.8), (dur, 0)], n, 1.0)
    hiss = dsp.sweep(dsp.white(n, rng), "bp", 2400.0 + 1200.0 * np.sin(np.pi * u), 1.2, block=128) * shape * 0.4
    hiss += dsp.lowpass(dsp.brown(n, rng), 300.0) * shape * 0.5
    notes = [base, base + 3, base + 5, base + 6]  # G# B C# D: the Flux colour
    for k in range(bubbles):
        m = dsp.samples(0.25)
        f = dsp.midi_hz(notes[k % 4] + 12 * int(rng.integers(0, 2)))
        tt = dsp.time_axis(m)
        b = dsp.sine(f * (1.0 + 0.4 * tt / 0.25), m) * dsp.perc(m, 0.004, 0.04)
        dsp.place(hiss, 0.12 * b, dsp.samples(float(rng.uniform(0.1, dur - 0.3))))
    return hiss


for _i, (_dur, _b, _base) in enumerate([(3.0, 5, 80), (4.2, 8, 80), (2.4, 3, 68)], start=1):
    def _make_vent(rng: np.random.Generator, d=_dur, b=_b, base=_base) -> np.ndarray:
        return _detail(_vent(rng, d, b, base), rng, 0.3, 2.0)

    sound(f"amb_flux_vent_{_i}", "ambdetail", -25.0, max_seconds=6.5, params={"recipe": "_vent"},
          **DETAIL)(_make_vent)


def _devil(rng: np.random.Generator, dur: float, spin: float) -> np.ndarray:
    n = dsp.samples(dur)
    u = dsp.time_axis(n) / dur
    shape = np.sin(np.pi * u) ** 1.5
    whirl = 0.5 + 0.5 * np.sin(2 * np.pi * np.cumsum(spin * (0.6 + 0.8 * u)) / dsp.SR)
    fc = 500.0 + 2200.0 * whirl * shape
    x = dsp.sweep(dsp.pink(n, rng), "bp", fc, 1.4, block=64) * shape * (0.5 + 0.5 * whirl)
    x += dsp.highpass(dsp.white(n, rng), 6000.0) * shape ** 2 * whirl * 0.08
    return x


for _i, (_dur, _spin) in enumerate([(3.8, 3.0), (5.0, 2.2)], start=1):
    def _make_devil(rng: np.random.Generator, d=_dur, s=_spin) -> np.ndarray:
        return _detail(_devil(rng, d, s), rng, 0.15)

    sound(f"amb_dust_devil_{_i}", "ambdetail", -24.0, max_seconds=7.0, params={"recipe": "_devil"},
          **DETAIL)(_make_devil)


def _industry(rng: np.random.Generator, kind: int) -> np.ndarray:
    """Far Combine industry, off the Concord key: clanks, a hammer pattern,
    hydraulic sighs, a low horn a quarter-tone flat."""
    buf = np.zeros(dsp.samples(5.0))
    if kind == 0:  # three heavy clanks
        for k, at in enumerate([0.0, 0.7, 1.15]):
            m = dsp.samples(1.0)
            exc = dsp.white(m, rng) * dsp.perc(m, 0.001, 0.01)
            clank = sum(dsp.bandpass(exc, f, 30.0) for f in (233.0, 611.0, 1377.0))
            dsp.place(buf, clank * (1.0 - 0.2 * k), dsp.samples(at))
    elif kind == 1:  # a drop hammer, four blows
        for k in range(4):
            m = dsp.samples(0.6)
            tt = dsp.time_axis(m)
            blow = dsp.sine(92.0 * (1 + 0.5 * np.exp(-tt / 0.01)), m) * dsp.perc(m, 0.002, 0.08)
            blow += 0.4 * dsp.bandpass(dsp.white(m, rng), 1900.0, 8.0) * dsp.perc(m, 0.001, 0.05)
            dsp.place(buf, blow, dsp.samples(0.9 * k))
    elif kind == 2:  # a hydraulic sigh and a valve tick
        m = dsp.samples(2.2)
        u = dsp.time_axis(m) / 2.2
        sigh = dsp.sweep(dsp.white(m, rng), "bp", 3000.0 * 0.4 ** u, 2.0) * dsp.env([(0, 0), (0.1, 1), (2.2, 0)], m, 1.5)
        dsp.place(buf, 0.6 * sigh, dsp.samples(0.2))
        tick_m = dsp.samples(0.1)
        dsp.place(buf, dsp.bandpass(dsp.white(tick_m, rng), 2500.0, 10.0) * dsp.perc(tick_m, 0.0005, 0.01), 0)
    else:  # a low shift horn, detuned and flat
        m = dsp.samples(2.6)
        f = 98.0 * 0.985
        horn = (dsp.warm_saw(f, m, 6.0) + dsp.warm_saw(f * 1.006, m, 6.0) + 0.6 * dsp.warm_saw(f * 1.5 * 0.99, m, 5.0))
        horn = dsp.lowpass(horn, 900.0) * dsp.env([(0, 0), (0.3, 1.0), (2.0, 0.9), (2.6, 0)], m)
        dsp.place(buf, 0.4 * horn, dsp.samples(0.1))
    return buf


for _i in range(4):
    def _make_industry(rng: np.random.Generator, k=_i) -> np.ndarray:
        x = _industry(rng, k)
        return _detail(x, rng, 0.4, 2.4)

    sound(f"amb_combine_industry_{_i + 1}", "ambdetail", -23.0, max_seconds=7.5, params={"recipe": "_industry"},
          **DETAIL)(_make_industry)
