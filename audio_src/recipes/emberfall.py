"""Emberfall (Phase 8b): the planet's ambience, the eruptions, the Holdout
mission's cues, Advisor phrases and interface sounds.

Kessel was dry and dusty, Thalassa wet, wide and cold. Emberfall is hot, heavy
and close: a low volcanic rumble always under everything (a low end the other
planets do not have), lava moving with slow bubbles, a hot dry wind with a
flutter of heat in it, and rock that cracks and ticks as it cools.

Planet beds (group `ambience`, the AmbienceDirector's own players):

  amb_emberfall_rumble   the ground: deep rumble, slow surges, a pressure
                         throb (41 s)
  amb_emberfall_lava     lava flow: a thick, slow, low churn, crust crackle,
                         slow bubbles and plops (35 s)
  amb_emberfall_wind     hot wind: dry, narrower than Thalassa's, gritty, with
                         a fast heat flutter in its gusts (46 s)

Details (group `ambdetail`, positional one-shots around the listener):

  amb_rock_crack_<n>        rock cracking as it cools: sharp splits, a tinkle
  amb_gas_hiss_<n>          a hiss of gas from a crack, a soft pop (near vents)
  amb_distant_collapse_<n>  far away: a slab gives way, a rumble, debris
  amb_ember_tick_<n>        embers ticking: tiny hot clicks and a fizz

Eruptions (group `weather`, the EruptionSound's own positional players, on the
Weather bus):

  eruption_build_low    the vent filling, early: a deep growl, slow gloops,
                        grinding rock (loop)
  eruption_build_high   the vent about to go: pressurised hiss, rattling
                        stones, a whistle (loop)
                        (the two crossfade as the eruption nears, and their
                        pitch rises with it: 0.65 -> 1.7)
  eruption_knock_<n>    the clock: a rock knock with a burp of gas; they come
                        faster as the eruption nears (about 7 / seconds left)
  eruption_blast_<n>    the eruption: a crack, a deep boom, a roar of gas, a
                        long low tail with falling debris (~6.5 s)

Holdout (group `sting`, flat on the Music bus):

  mus_holdout_minute    one minute left: help on the way: a far engine swelling
                        in, a horn call C# -> G# -> high C#, a tine answer
  mus_holdout_engine    the last ten seconds: the dropship's engine hovering on
                        C# and G#, a turbine whine, rotor beats (loop; it rises
                        as it nears)
  mus_holdout_arrived   help is here: the engine's C# and G# glide up a semitone
                        into the Concord's D and A, a bright chime chord, a horn
                        D -> A

Advisor (Meridian dyads): eruption_warning, eruption_damage, surge_incoming,
wave_incoming, extraction_inbound, extraction_arrived. Interface:
ui_vent_release (a controlled vent: a sharp hiss and a thud), ui_vent_denied.
"""

from __future__ import annotations

import numpy as np

from synth import dsp
from synth.instruments import chime, reed

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
    return x - x.mean(axis=-1, keepdims=True)


def _cyc(n: int, cycles: int, phase: float = 0.0) -> np.ndarray:
    """0..1 raised cosine with a whole number of cycles over the loop."""
    t = np.arange(n) / n
    return 0.5 - 0.5 * np.cos(2 * np.pi * cycles * t + phase)


def _scatter(buf: np.ndarray, n: int, rng: np.random.Generator, count: int, maker, stereo: bool = True) -> None:
    for _ in range(count):
        at = int(rng.integers(0, n))
        x = maker(rng)
        dsp.place(buf, dsp.pan(x, float(rng.uniform(-0.85, 0.85))) if stereo else x, at)


def _bubble(rng: np.random.Generator, lo: float = 70.0, hi: float = 160.0, dur: float = 0.22) -> np.ndarray:
    """A slow magma bubble: a low sine swelling up in pitch, then a soft plop."""
    m = dsp.samples(dur)
    tt = dsp.time_axis(m)
    f0 = float(rng.uniform(lo, hi))
    blob = dsp.sine(f0 * (1 + 1.2 * (tt / dur) ** 2), m) * dsp.env([(0, 0), (dur * 0.7, 1.0), (dur, 0)], m)
    k = dsp.samples(0.05)
    plop = dsp.bandpass(dsp.white(k, rng), float(rng.uniform(400, 900)), 3.0) * dsp.perc(k, 0.002, 0.012)
    out = np.zeros(m + k)
    out[:m] += blob
    out[m - k // 2: m - k // 2 + k] += 0.4 * plop
    return out


def _crackle(rng: np.random.Generator, lo: float = 2500.0, hi: float = 7000.0) -> np.ndarray:
    m = dsp.samples(0.03)
    exc = dsp.white(m, rng) * dsp.perc(m, 0.0003, 0.002)
    return dsp.bandpass(exc, float(rng.uniform(lo, hi)), 6.0)


# --------------------------------------------------------------------------- planet beds


AMB = dict(fmt="ogg", channels=2, loop=True, folder="ambience/emberfall")
N_RUMBLE = loop_samples(41.0)
N_LAVA = loop_samples(35.0)
N_WIND = loop_samples(46.0)


@sound("amb_emberfall_rumble", "ambience", -31.0, **AMB, **loop_bounds(N_RUMBLE))
def amb_emberfall_rumble(rng: np.random.Generator) -> np.ndarray:
    n = N_RUMBLE
    L = n / dsp.SR
    surge = 0.55 + 0.45 * (0.5 + 0.5 * dsp.smooth_random(n, rng, 0.08)) ** 1.5
    deep = _wide(n, rng, dsp.brown, 0.6)
    deep = dsp.periodic(dsp.lowpass, deep, 90.0, 0.8) * surge
    body = dsp.periodic(dsp.bandpass, _wide(n, rng, dsp.brown, 0.4), 160.0, 0.7) * 0.35 * surge ** 2
    throb = np.zeros(n)
    for note, amp in [(25, 0.5), (37, 0.25)]:  # C#1, C#2: the planet's root, felt more than heard
        throb += amp * (dsp.sine(qf(H(note), L), n) + 0.6 * dsp.sine(qf(H(note) + 0.4, L), n))
    throb *= 0.25 * (0.6 + 0.4 * _cyc(n, 5))
    x = deep + body + dsp.stereo(throb)
    return _finish(x, 30.0)


@sound("amb_emberfall_lava", "ambience", -33.0, **AMB, **loop_bounds(N_LAVA))
def amb_emberfall_lava(rng: np.random.Generator) -> np.ndarray:
    n = N_LAVA
    churn = 0.6 + 0.4 * _cyc(n, 7, 0.8)
    flow = _wide(n, rng, dsp.brown, 0.3)
    flow = dsp.periodic(dsp.sweep, flow, "bp", 180.0 + 160.0 * churn, 0.9, block=256) * churn
    buf = np.zeros((2, n + dsp.samples(1.0)))
    _scatter(buf, n, rng, int(n / dsp.SR * 1.1), lambda r: 0.5 * _bubble(r))
    _scatter(buf, n, rng, int(n / dsp.SR * 0.4), lambda r: 0.7 * _bubble(r, 50.0, 90.0, 0.4))
    _scatter(buf, n, rng, int(n / dsp.SR * 9), lambda r: 0.08 * _crackle(r))
    x = flow + dsp.wrap(buf, n)
    x = dsp.periodic(dsp.lowpass, x, 6000.0)
    return _finish(x, 35.0)


@sound("amb_emberfall_wind", "ambience", -31.0, **AMB, **loop_bounds(N_WIND))
def amb_emberfall_wind(rng: np.random.Generator) -> np.ndarray:
    n = N_WIND
    L = n / dsp.SR
    gust = (0.5 + 0.5 * dsp.smooth_random(n, rng, 0.07)) ** 1.4
    drift = dsp.smooth_random(n, rng, 0.04)
    body = _wide(n, rng, dsp.pink, 0.3)
    body = dsp.periodic(dsp.sweep, body, "bp", 700.0 + 900.0 * gust, 1.1, block=256) * (0.2 + 0.55 * gust)
    flutter = 1.0 - 0.25 * gust * (0.5 + 0.5 * lfo(n, L, int(round(L * 9.0))))  # heat shimmer in the gusts
    body = np.stack([body[0] * (1.0 - 0.35 * drift), body[1] * (1.0 + 0.35 * drift)]) * flutter
    grit = dsp.periodic(dsp.bandpass, _wide(n, rng, dsp.white, 0.1), 3800.0, 1.2) * 0.04 * gust ** 2
    low = dsp.periodic(dsp.lowpass, _wide(n, rng, dsp.brown, 0.5), 220.0) * 0.3 * (0.6 + 0.4 * gust)
    return _finish(body + grit + low, 40.0)


# --------------------------------------------------------------------------- details


DETAIL = dict(folder="ambience/details")


def _cracks(rng: np.random.Generator, count: int, spread: float) -> np.ndarray:
    buf = np.zeros(dsp.samples(spread + 1.2))
    at = 0.02
    for k in range(count):
        m = dsp.samples(0.15)
        exc = dsp.white(m, rng) * dsp.perc(m, 0.0004, 0.006 if k == 0 else 0.003)
        split = dsp.bandpass(exc, float(rng.uniform(1400, 3200)), 4.0) + 0.6 * dsp.bandpass(
            exc, float(rng.uniform(250, 500)), 2.0)
        dsp.place(buf, split * (1.0 if k == 0 else float(rng.uniform(0.3, 0.7))), dsp.samples(at))
        at += float(rng.exponential(spread / count))
    for _ in range(int(rng.integers(2, 5))):  # flakes falling away
        dsp.place(buf, 0.25 * _crackle(rng, 3500.0, 7500.0), dsp.samples(float(rng.uniform(0.1, spread + 0.4))))
    return buf


for _i, (_c, _s) in enumerate([(3, 0.4), (5, 0.9), (2, 0.2)], start=1):
    def _make_cracks(rng: np.random.Generator, c=_c, s=_s) -> np.ndarray:
        return _detail(_cracks(rng, c, s), rng, 0.2, 1.2)

    sound(f"amb_rock_crack_{_i}", "ambdetail", -25.0, max_seconds=3.5, params={"recipe": "_cracks"},
          **DETAIL)(_make_cracks)


def _hiss(rng: np.random.Generator, length: float, pop: bool) -> np.ndarray:
    n = dsp.samples(length + 0.4)
    u = np.clip(dsp.time_axis(n) / length, 0.0, 1.0)
    shape = dsp.env([(0, 0), (0.08, 1.0), (length * 0.6, 0.8), (length, 0)], n, 1.2)
    fc = 3200.0 + 1800.0 * np.sin(np.pi * u)
    x = dsp.sweep(dsp.white(n, rng), "bp", fc, 1.4, block=64) * shape
    if pop:
        m = dsp.samples(0.08)
        tt = dsp.time_axis(m)
        p = dsp.sine(180.0 * (1 + 0.8 * np.exp(-tt / 0.01)), m) * dsp.perc(m, 0.002, 0.02)
        dsp.place(x, 0.5 * p, 0)
    return x * 0.6


for _i, (_len, _pop) in enumerate([(0.9, True), (1.6, False), (0.6, True)], start=1):
    def _make_hiss(rng: np.random.Generator, length=_len, pop=_pop) -> np.ndarray:
        return _detail(_hiss(rng, length, pop), rng, 0.2, 1.2)

    sound(f"amb_gas_hiss_{_i}", "ambdetail", -26.0, max_seconds=3.5, params={"recipe": "_hiss"},
          **DETAIL)(_make_hiss)


def _collapse(rng: np.random.Generator, length: float) -> np.ndarray:
    n = dsp.samples(length + 1.0)
    body = dsp.lowpass(dsp.brown(n, rng), 160.0) * dsp.env([(0, 0), (0.15, 1.0), (length * 0.5, 0.5), (length, 0)],
                                                         n, 1.5)
    m = dsp.samples(0.6)
    tt = dsp.time_axis(m)
    give = dsp.sine(55.0 * (1 + 0.5 * np.exp(-tt / 0.05)), m) * dsp.perc(m, 0.008, 0.25)
    out = body * 0.9
    dsp.place(out, 0.8 * give, 0)
    for _ in range(int(rng.integers(10, 20))):  # debris tumbling after
        at = float(rng.uniform(0.2, length * 0.8))
        k = dsp.samples(0.1)
        d = dsp.bandpass(dsp.white(k, rng), float(rng.uniform(500, 1600)), 3.0) * dsp.perc(k, 0.002, 0.02)
        dsp.place(out, d * float(rng.uniform(0.1, 0.35)), dsp.samples(at))
    return dsp.lowpass(out, 2500.0)


for _i, _len in enumerate([3.0, 4.2], start=1):
    def _make_collapse(rng: np.random.Generator, length=_len) -> np.ndarray:
        return _detail(_collapse(rng, length), rng, 0.4, 2.6)

    sound(f"amb_distant_collapse_{_i}", "ambdetail", -26.0, max_seconds=7.0, params={"recipe": "_collapse"},
          **DETAIL)(_make_collapse)


def _embers(rng: np.random.Generator, count: int, spread: float) -> np.ndarray:
    buf = np.zeros(dsp.samples(spread + 0.6))
    at = 0.01
    for _ in range(count):
        m = dsp.samples(0.04)
        exc = dsp.white(m, rng) * dsp.perc(m, 0.0002, 0.0012)
        tick = dsp.bandpass(exc, float(rng.uniform(4000, 8000)), 10.0)
        dsp.place(buf, tick * float(rng.uniform(0.4, 1.0)), dsp.samples(at))
        at += float(rng.exponential(spread / count))
    k = dsp.samples(spread + 0.3)
    fizz = dsp.highpass(dsp.white(k, rng), 6000.0) * dsp.env([(0, 0), (0.05, 1), (spread + 0.3, 0)], k) * 0.03
    dsp.place(buf, fizz, 0)
    return buf


for _i, (_c, _s) in enumerate([(6, 0.6), (11, 1.4), (4, 0.3)], start=1):
    def _make_embers(rng: np.random.Generator, c=_c, s=_s) -> np.ndarray:
        return _detail(_embers(rng, c, s), rng, 0.12, 0.8)

    sound(f"amb_ember_tick_{_i}", "ambdetail", -28.0, max_seconds=3.0, params={"recipe": "_embers"},
          **DETAIL)(_make_embers)


# --------------------------------------------------------------------------- eruptions


ERUPT = dict(folder="weather/eruption")


def _loop_finish(x: np.ndarray, hp: float) -> np.ndarray:
    x = dsp.periodic(dsp.highpass, x, hp)
    return x - x.mean()


@sound("eruption_build_low", "weather", -24.0, loop=True, min_seconds=3.99, max_seconds=4.01, **ERUPT)
def eruption_build_low(rng: np.random.Generator) -> np.ndarray:
    """Early pressure: a deep growl (beating low partials), slow gloops, grinding rock."""
    L = 4.0
    n = dsp.samples(L)
    growl = np.zeros(n)
    for f, amp in [(qf(62.0, L), 0.5), (qf(64.5, L), 0.4), (qf(124.0, L), 0.2), (qf(187.0, L), 0.08)]:
        growl += amp * dsp.sine(f, n, float(rng.random()))
    growl *= 0.7 + 0.3 * lfo(n, L, 3)
    rumble = dsp.periodic(dsp.lowpass, dsp.brown(n, rng), 140.0) * 0.6
    grind = dsp.periodic(dsp.bandpass, dsp.brown(n, rng), 600.0, 1.0) * 0.25 * (0.5 + 0.5 * lfo(n, L, 5))
    buf = np.zeros(n + dsp.samples(1.0))
    for at in (0.3, 1.5, 2.4, 3.3):
        dsp.place(buf, 0.6 * _bubble(rng, 60.0, 120.0, 0.35), dsp.samples(at))
    x = growl + rumble + grind + dsp.wrap(buf, n)
    return _loop_finish(x, 40.0)


@sound("eruption_build_high", "weather", -24.0, loop=True, min_seconds=2.99, max_seconds=3.01, **ERUPT)
def eruption_build_high(rng: np.random.Generator) -> np.ndarray:
    """About to go: a pressurised hiss, rattling stones, a whistle on G#, the growl tighter."""
    L = 3.0
    n = dsp.samples(L)
    hiss = dsp.periodic(dsp.bandpass, dsp.white(n, rng), 2800.0, 0.9) * (0.4 + 0.1 * lfo(n, L, 7))
    whistle = 0.12 * (dsp.sine(qf(H(80), L), n) + dsp.sine(qf(H(80) + 6.0, L), n)) * (0.6 + 0.4 * lfo(n, L, 2))
    growl = 0.4 * (dsp.sine(qf(93.0, L), n) + 0.8 * dsp.sine(qf(97.0, L), n)) * (0.7 + 0.3 * lfo(n, L, 9))
    buf = np.zeros(n + dsp.samples(0.5))
    for _ in range(int(L * 16)):
        at = int(rng.integers(0, n))
        k = dsp.samples(0.05)
        stone = dsp.bandpass(dsp.white(k, rng), float(rng.uniform(900, 2600)), 5.0) * dsp.perc(k, 0.0008, 0.01)
        dsp.place(buf, stone * float(rng.uniform(0.15, 0.5)), at)
    x = hiss + whistle + growl + dsp.wrap(buf, n)
    return _loop_finish(x, 60.0)


def _knock(rng: np.random.Generator, f: float, gas: float) -> np.ndarray:
    n = dsp.samples(0.5)
    tt = dsp.time_axis(n)
    thump = dsp.sine(f * (1 + 0.5 * np.exp(-tt / 0.02)), n) * dsp.perc(n, 0.002, 0.07)
    stone = dsp.bandpass(dsp.white(n, rng), 1300.0, 2.0) * dsp.perc(n, 0.0008, 0.01) * 0.5
    burp = dsp.bandpass(dsp.white(n, rng), 2200.0, 1.0) * dsp.env([(0, 0), (0.03, 1.0), (0.3, 0)], n, 1.5) * gas
    return dsp.fade(dsp.trim_tail(dsp.dc_block(dsp.highpass(thump + stone + burp, 50.0)), -55.0), 0.001, 0.03)


for _i, (_f, _g) in enumerate([(95.0, 0.15), (110.0, 0.25), (82.0, 0.1), (125.0, 0.3)], start=1):
    def _make_knock(rng: np.random.Generator, f=_f, g=_g) -> np.ndarray:
        return _knock(rng, f, g)

    sound(f"eruption_knock_{_i}", "weather", -24.0, max_seconds=0.6, params={"recipe": "_knock"},
          **ERUPT)(_make_knock)


def _blast(rng: np.random.Generator, size: float) -> np.ndarray:
    total = 6.5
    n = dsp.samples(total)
    t = dsp.time_axis(n)
    out = np.zeros(n)
    k = dsp.samples(0.08)
    crack = dsp.bandpass(dsp.white(k, rng), 2400.0, 0.7) * dsp.perc(k, 0.0008, 0.015)
    dsp.place(out, 0.9 * crack, 0)
    boom = dsp.sine(48.0 * size * (1 + 0.8 * np.exp(-t / 0.06)), n) * dsp.perc(n, 0.003, 0.9)
    out += 0.9 * dsp.saturate(boom * 1.5, 1.2)
    roar = dsp.sweep(dsp.pink(n, rng), "bp", 1600.0 * (0.25 + 0.75 * np.exp(-t / 0.8)), 0.6, block=128)
    out += roar * dsp.env([(0, 0), (0.02, 1.0), (0.6, 0.6), (3.0, 0.15), (total, 0)], n, 1.2) * 0.7
    tail = dsp.lowpass(dsp.brown(n, rng), 120.0) * dsp.env([(0, 0), (0.3, 1.0), (2.5, 0.6), (total, 0)], n, 1.0)
    out += 1.4 * tail
    for _ in range(int(30 * size)):  # rocks coming down
        at = float(rng.uniform(0.6, 4.5))
        m = dsp.samples(0.12)
        d = dsp.bandpass(dsp.white(m, rng), float(rng.uniform(400, 1800)), 3.0) * dsp.perc(m, 0.002, 0.03)
        dsp.place(out, d * float(rng.uniform(0.05, 0.3)) * np.exp(-at / 3.0), dsp.samples(at))
    y = dsp.reverb(out, rng, seconds=2.4, mix=0.3, predelay_ms=20.0, damp=0.6).mean(axis=0)
    return dsp.fade(dsp.trim_tail(dsp.dc_block(dsp.highpass(y, 32.0)), -60.0), 0.001, 1.2)


for _i, _size in enumerate([1.0, 0.9, 1.1], start=1):
    def _make_blast(rng: np.random.Generator, size=_size) -> np.ndarray:
        return _blast(rng, size)

    sound(f"eruption_blast_{_i}", "weather", -18.0, max_seconds=7.0, min_seconds=3.0, params={"recipe": "_blast"},
          **ERUPT)(_make_blast)


# --------------------------------------------------------------------------- Holdout


STING = dict(fmt="ogg", channels=2, folder="music/stings")


def _horn(f: float, dur: float, rng: np.random.Generator, bright: float = 4.5) -> np.ndarray:
    a = reed(f, dur, rng, brightness=bright, attack=0.05, release=0.3, breath=0.03, vibrato_cents=5.0)
    b = reed(f * dsp.cents(-7.0), dur, rng, brightness=bright * 0.8, attack=0.07, release=0.3, breath=0.0)
    return dsp.saturate(dsp.mix(a, 0.6 * b) * 1.2, 1.0) * 0.6


def _engine(n: int, rng: np.random.Generator, f_lo: np.ndarray | float, f_hi: np.ndarray | float,
            rotor_hz: float, loop: bool = False) -> np.ndarray:
    """A dropship engine: a hum on two notes (root and fifth), a turbine whine
    an octave and a half up, rotor beats, a wash of air."""
    t = dsp.time_axis(n)
    lo = np.full(n, f_lo) if np.ndim(f_lo) == 0 else f_lo
    hi = np.full(n, f_hi) if np.ndim(f_hi) == 0 else f_hi
    hum = dsp.wavetable(lo, n, lambda k: {1: 1.0, 2: 0.5, 3: 0.3, 4: 0.12}.get(k, 0.0))
    hum += 0.7 * dsp.wavetable(hi, n, lambda k: {1: 1.0, 2: 0.35, 3: 0.12}.get(k, 0.0))
    whine = 0.08 * dsp.sine(hi * 4.0, n)
    beats = 0.75 + 0.25 * np.sin(2 * np.pi * rotor_hz * t)
    air = (dsp.periodic(dsp.bandpass, dsp.pink(n, rng), 900.0, 0.6) if loop
           else dsp.bandpass(dsp.pink(n, rng), 900.0, 0.6)) * 0.5
    return (hum * 0.35 * beats + whine + air * beats) * 0.6


@sound("mus_holdout_minute", "sting", -24.0, min_seconds=3.0, max_seconds=6.0, **STING)
def holdout_minute(rng: np.random.Generator) -> np.ndarray:
    """One minute: help on the way. A far engine swells in and passes, a horn
    calls C# -> G# -> the high C#, a tine answers."""
    total = 5.2
    n = dsp.samples(total)
    buf = np.zeros((2, n + dsp.samples(3.0)))
    swell = dsp.env([(0, 0), (2.2, 1.0), (total, 0.0)], n, 0.0)
    eng = dsp.lowpass(_engine(n, rng, H(37) * dsp.cents(-20.0), H(44) * dsp.cents(-20.0), 6.0), 1400.0) * swell
    dsp.place(buf, dsp.pan(0.5 * eng, np.linspace(-0.6, 0.4, n)), 0)
    at = 0.6
    for m, dur in [(61, 0.35), (68, 0.35), (73, 1.6)]:
        dsp.place(buf, dsp.pan(0.6 * _horn(H(m), dur, rng), 0.1), dsp.samples(at))
        at += dur + 0.05
    for k, m in enumerate([80, 85]):
        c = chime(H(m), 0.05, rng, brightness=0.7, decay=0.7, attack=0.008, tail=1.5)
        dsp.place(buf, dsp.pan(0.25 * c, 0.4 - 0.2 * k), dsp.samples(at + 0.1 + 0.18 * k))
    y = dsp.reverb(buf, rng, seconds=2.5, mix=0.3, predelay_ms=20.0, damp=0.6)
    y = dsp.trim_tail(dsp.dc_block(dsp.highpass(y, 35.0)), -60.0)[:, : dsp.samples(5.8)]
    return dsp.fade(y, 0.01, 1.0)


N_ENGINE = loop_samples(4.0)


@sound("mus_holdout_engine", "sting", -26.0, fmt="ogg", channels=2, loop=True, folder="music/stings",
       **loop_bounds(N_ENGINE))
def holdout_engine(rng: np.random.Generator) -> np.ndarray:
    """The last ten seconds: the engine hovering on C# and G#, rotor beats (a
    whole number per loop), the whine; its level and pitch are raised as it nears."""
    n = N_ENGINE
    L = n / dsp.SR
    x = _engine(n, rng, qf(H(37), L), qf(H(44), L), qf(6.0, L), loop=True)
    x = dsp.periodic(dsp.lowpass, x, 3000.0)
    x += dsp.periodic(dsp.bandpass, dsp.pink(n, rng), 4500.0, 0.8) * 0.06  # jet hiss
    left = x
    right = np.roll(x, dsp.samples(0.011))
    return _finish(np.stack([left, right]), 35.0)


@sound("mus_holdout_arrived", "sting", -22.0, min_seconds=2.5, max_seconds=5.5, **STING)
def holdout_arrived(rng: np.random.Generator) -> np.ndarray:
    """Here: the engine's C# and G# glide up a semitone into D and A, a bright
    chime chord D F# A D, a horn D -> A."""
    total = 4.6
    n = dsp.samples(total)
    buf = np.zeros((2, n + dsp.samples(3.0)))
    u = np.clip(dsp.time_axis(n) / 0.5, 0.0, 1.0)
    rise = 2.0 ** ((u * u * (3 - 2 * u)) / 12.0)
    eng = _engine(n, rng, H(37) * rise, H(44) * rise, 6.0)
    eng = dsp.lowpass(eng, 3000.0) * dsp.env([(0, 1.0), (0.6, 1.0), (total, 0.0)], n, 1.5)
    dsp.place(buf, dsp.stereo(0.55 * eng), 0)
    for k, m in enumerate([74, 78, 81, 86]):
        c = chime(H(m), 0.08, rng, brightness=0.9, decay=1.0, attack=0.008, tail=2.0)
        dsp.place(buf, dsp.pan(0.3 * c, -0.45 + 0.3 * k), dsp.samples(0.5 + 0.05 * k))
    for m, at, dur in [(62, 0.55, 0.35), (69, 0.95, 1.8)]:
        dsp.place(buf, dsp.pan(0.6 * _horn(H(m), dur, rng, 5.0), 0.05), dsp.samples(at))
    y = dsp.reverb(buf, rng, seconds=2.8, mix=0.32, predelay_ms=20.0, damp=0.55)
    y = dsp.trim_tail(dsp.dc_block(dsp.highpass(y, 35.0)), -60.0)[:, : dsp.samples(5.2)]
    return dsp.fade(y, 0.002, 1.0)


# --------------------------------------------------------------------------- Advisor


@sound("advisor_eruption_warning", "advisor", ADVISOR_LUFS + 1.0, max_seconds=1.9)
def advisor_eruption_warning(rng: np.random.Generator) -> np.ndarray:
    """A vent will blow: C#+G# then D+A pressing a semitone up, twice, faster,
    the last bending up a further step over a low growl."""
    a = advisor_dyad(H(73), H(80), 0.12)
    b = advisor_dyad(H(74), H(81), 0.12)
    c = advisor_dyad(H(73), H(80), 0.09)
    d = glide_dyad(H(74), H(81), 0.45, 2.0, 0.35)
    n = dsp.samples(1.1)
    growl = 0.22 * (dsp.sine(H(49), n) + dsp.sine(H(49) + 4.0, n)) * dsp.ar(n, 0.1, 0.3, 0.7)
    return _phrase([(0.0, 0.85, a), (0.15, 0.9, b), (0.32, 0.9, c), (0.43, 1.0, d), (0.0, 1.0, growl)], rng, 1.7)


@sound("advisor_eruption_damage", "advisor", ADVISOR_LUFS + 1.0, max_seconds=1.7)
def advisor_eruption_damage(rng: np.random.Generator) -> np.ndarray:
    """Buildings burning: the D+G# tritone struck hard, then sagging down a tone."""
    a = advisor_dyad(H(74), H(80), 0.1)
    b = glide_dyad(H(74), H(80), 0.5, -2.0, 0.2)
    return _phrase([(0.0, 1.0, a), (0.16, 0.95, b)], rng, 1.4)


@sound("advisor_surge_incoming", "advisor", ADVISOR_LUFS + 1.0, max_seconds=1.9)
def advisor_surge_incoming(rng: np.random.Generator) -> np.ndarray:
    """The caldera's surge (every vent in turn): four dyads climbing by step under a rising tritone pedal."""
    parts = []
    for k, (lo, hi) in enumerate([(66, 73), (68, 74), (69, 76), (71, 78)]):
        parts.append((0.15 * k, 0.8 + 0.06 * k, advisor_dyad(H(lo), H(hi), 0.11 if k < 3 else 0.4)))
    n = dsp.samples(1.0)
    pedal = 0.18 * (dsp.sine(H(62), n) + dsp.sine(H(68), n)) * dsp.env([(0, 0), (0.6, 1.0), (1.0, 0)], n)
    parts.append((0.0, 1.0, pedal))
    return _phrase(parts, rng, 1.7)


@sound("advisor_wave_incoming", "advisor", ADVISOR_LUFS, max_seconds=1.6)
def advisor_wave_incoming(rng: np.random.Generator) -> np.ndarray:
    """Enemies on the way: F#+C#, short, then G#+D, long: a step up into the warning tritone."""
    a = advisor_dyad(H(66), H(73), 0.12)
    b = advisor_dyad(H(68), H(74), 0.36)
    return _phrase([(0.0, 0.9, a), (0.17, 1.0, b)], rng, 1.2)


@sound("advisor_extraction_inbound", "advisor", ADVISOR_LUFS, max_seconds=1.8)
def advisor_extraction_inbound(rng: np.random.Generator) -> np.ndarray:
    """Help is coming: A+E, then D+A held with a slow upward lean: hold on."""
    a = advisor_dyad(H(69), H(76), 0.16)
    b = glide_dyad(H(74), H(81), 0.6, 0.4, 0.4)
    return _phrase([(0.0, 0.85, a), (0.22, 1.0, b)], rng, 1.5)


@sound("advisor_extraction_arrived", "advisor", ADVISOR_LUFS + 1.0, max_seconds=1.9)
def advisor_extraction_arrived(rng: np.random.Generator) -> np.ndarray:
    """Here, go: D+A, F#+C#, A+E quick, landing on a high D+A with its octave."""
    a = advisor_dyad(H(74), H(81), 0.09)
    b = advisor_dyad(H(78), H(85), 0.09)
    c = advisor_dyad(H(81), H(88), 0.09)
    d = advisor_dyad(H(86), H(93), 0.5)
    e = advisor_dyad(H(74), H(81), 0.5)
    return _phrase([(0.0, 0.85, a), (0.12, 0.9, b), (0.24, 0.95, c), (0.36, 1.0, d), (0.36, 0.5, e)], rng, 1.6)


# --------------------------------------------------------------------------- interface


def _ui_done(x: np.ndarray, hp: float = 60.0) -> np.ndarray:
    return dsp.fade(dsp.trim_tail(dsp.dc_block(dsp.highpass(x, hp)), -55.0), 0.0005, 0.02)


@sound("ui_vent_release", "ui", -26.0, max_seconds=0.42)
def ui_vent_release(rng: np.random.Generator) -> np.ndarray:
    """A controlled vent: a valve clack, a short sharp hiss falling away, a thud under it."""
    n = dsp.samples(0.38)
    tt = dsp.time_axis(n)
    shape = dsp.env([(0, 0), (0.006, 1.0), (0.08, 0.7), (0.3, 0.0)], n, 1.5)
    hiss = dsp.sweep(dsp.white(n, rng), "bp", 5200.0 * (1.0 - 0.5 * np.clip(tt / 0.3, 0, 1)), 1.1, block=32)
    thud = dsp.sine(85.0 * (1 + 0.7 * np.exp(-tt / 0.012)), n) * dsp.perc(n, 0.001, 0.06)
    k = dsp.samples(0.02)
    clack = dsp.bandpass(dsp.white(k, rng), 1800.0, 4.0) * dsp.perc(k, 0.0003, 0.003)
    out = 0.5 * hiss * shape + 0.9 * thud
    dsp.place(out, 0.5 * clack, 0)
    return _ui_done(out, 45.0)


@sound("ui_vent_denied", "ui", -28.0, max_seconds=0.3)
def ui_vent_denied(rng: np.random.Generator) -> np.ndarray:
    """No: a stuck valve, two dull clunks and a choked buzz on D+G# (the warning tritone)."""
    n = dsp.samples(0.28)
    out = np.zeros(n)
    for at in (0.0, 0.09):
        k = dsp.samples(0.06)
        kt = dsp.time_axis(k)
        clunk = dsp.sine(220.0 * (1 + 0.3 * np.exp(-kt / 0.006)), k) * dsp.perc(k, 0.0008, 0.018)
        clunk += 0.3 * dsp.bandpass(dsp.white(k, rng), 900.0, 3.0) * dsp.perc(k, 0.0005, 0.004)
        dsp.place(out, clunk, dsp.samples(at))
    buzz = (dsp.warm_saw(H(62), n, 6.0) + dsp.warm_saw(H(68), n, 6.0)) * dsp.env(
        [(0, 0), (0.1, 0), (0.12, 1.0), (0.26, 0)], n) * 0.15
    return _ui_done(out + dsp.lowpass(buzz, 1800.0), 120.0)
