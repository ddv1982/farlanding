"""Verdance (Phase 8c): the planet's ambience, the canopy cues and the Advisor
lines of the first air war.

Kessel is dry and dusty, Thalassa wet and wide, Emberfall low and hot.
Verdance is hushed and alive and close overhead: leaves always moving in the
crowns, a chorus of small invented creatures (never a real bird or insect:
pulsed sines, trills, formant glides), a shallow stream babbling somewhere, and
the sense that something is just out of sight under the next crown.

Planet beds (group `ambience`, the AmbienceDirector's own players):

  amb_verdance_leaves  the crowns: a soft broadband hush, leaf flutter (dense
                       tiny ticks) that thickens in slow gusts high up (43 s)
  amb_verdance_chorus  the life: pulsed high trills in overlapping groups, a
                       slow two-note piping far off, wooden 'tok's (37 s)
  amb_verdance_stream  a shallow stream: a running wash and many small
                       bubbling chirps over stones (29 s)

Details (group `ambdetail`, positional one-shots around the listener):

  amb_branch_creak_<n>  a big branch flexing: stick-slip creaks through wood
                        resonances, a few leaves after it
  amb_canopy_call_<n>   a call and an answer: an invented creature trills a
                        two-note phrase, another, further off and duller,
                        answers lower
  amb_leaf_drip_<n>     water running off leaves: plips and leaf ticks
  amb_wing_flurry_<n>   something takes off: a burst of wingbeats moving
                        away, a shaken branch

Canopy (group `canopy`, CanopySound, positional on the Units bus):

  canopy_rustle_in_<n>   a unit pushing in under a crown: a soft swell of
                         leaves closing over it, twig ticks, darker at the end
  canopy_rustle_out_<n>  coming out: lighter, shorter, brighter, opening

Advisor (Meridian dyads): canopy_contact, air_contact, air_lost.
"""

from __future__ import annotations

import numpy as np

from synth import dsp

from . import sound
from .advisor import ADVISOR_LUFS, _phrase, glide_dyad
from .ambience import _detail
from .movement import lfo
from .weather import loop_bounds, loop_samples
from .world import advisor_dyad

H = dsp.midi_hz


def _wide(n: int, rng: np.random.Generator, maker, shared: float) -> np.ndarray:
    common = maker(n, rng)
    return np.stack([shared * common + (1 - shared) * maker(n, rng) for _ in range(2)])


def _finish(x: np.ndarray, hp: float = 40.0) -> np.ndarray:
    x = dsp.periodic(dsp.highpass, x, hp)
    return x - x.mean(axis=-1, keepdims=True)


def _flutter(n: int, rng: np.random.Generator, density: np.ndarray, lo: float, hi: float,
             count: int) -> np.ndarray:
    """Leaves touching: `count` tiny band-passed ticks scattered over the loop,
    kept with a probability that follows `density` (0..1), stereo, wrapped."""
    buf = np.zeros((2, n + dsp.samples(0.1)))
    m = dsp.samples(0.02)
    for _ in range(count):
        at = int(rng.integers(0, n))
        if rng.random() > density[at]:
            continue
        exc = dsp.white(m, rng) * dsp.perc(m, 0.0004, 0.003)
        tick = dsp.bandpass(exc, float(rng.uniform(lo, hi)), 3.0) * float(rng.uniform(0.2, 1.0))
        dsp.place(buf, dsp.pan(tick, float(rng.uniform(-0.9, 0.9))), at)
    return dsp.wrap(buf, n)


# --------------------------------------------------------------------------- planet beds


AMB = dict(fmt="ogg", channels=2, loop=True, folder="ambience/verdance")
N_LEAVES = loop_samples(43.0)
N_CHORUS = loop_samples(37.0)
N_STREAM = loop_samples(29.0)


@sound("amb_verdance_leaves", "ambience", -31.0, **AMB, **loop_bounds(N_LEAVES))
def amb_verdance_leaves(rng: np.random.Generator) -> np.ndarray:
    n = N_LEAVES
    gust = (0.5 + 0.5 * dsp.smooth_random(n, rng, 0.06)) ** 1.6
    drift = dsp.smooth_random(n, rng, 0.03)
    hush = _wide(n, rng, dsp.pink, 0.15)
    hush = dsp.periodic(dsp.sweep, hush, "bp", 1100.0 + 1300.0 * gust, 0.6, block=256) * (0.25 + 0.5 * gust)
    hush = np.stack([hush[0] * (1.0 - 0.3 * drift), hush[1] * (1.0 + 0.3 * drift)])
    # Kept below the top octave: a broadband hiss up there is what the codec
    # renders worst, and the leaves read from the flutter, not from the hiss.
    top = dsp.periodic(dsp.bandpass, _wide(n, rng, dsp.pink, 0.1), 4800.0, 0.9) * 0.02 * (0.4 + 0.6 * gust)
    flutter = _flutter(n, rng, 0.15 + 0.85 * gust, 1800.0, 5200.0, int(n / dsp.SR * 70)) * 0.1
    low = dsp.periodic(dsp.lowpass, _wide(n, rng, dsp.brown, 0.6), 320.0) * 0.3 * (0.7 + 0.3 * gust)
    return _finish(hush + top + flutter + low, 60.0)


def _trill(rng: np.random.Generator, f: float, rate: float, dur: float) -> np.ndarray:
    """An invented insect: a high sine pulsed `rate` times a second in a group
    that swells and fades, its pitch dipping a hair on each pulse."""
    m = dsp.samples(dur)
    t = dsp.time_axis(m)
    gate = (0.5 + 0.5 * np.sin(2 * np.pi * rate * t)) ** 3
    dip = 1.0 - 0.01 * gate
    tone = dsp.sine(f * dip, m) + 0.2 * dsp.sine(2.0 * f * dip, m)
    return tone * gate * dsp.env([(0, 0), (dur * 0.2, 1.0), (dur * 0.7, 0.8), (dur, 0)], m)


def _piping(rng: np.random.Generator, a: float, b: float) -> np.ndarray:
    """A far, slow two-note piping (no real bird): a soft sine stepping a to b
    through a gentle formant, a slow wobble."""
    parts = []
    for f, dur in ((a, 0.28), (b, 0.42)):
        m = dsp.samples(dur)
        t = dsp.time_axis(m)
        wob = 1.0 + 0.006 * np.sin(2 * np.pi * 6.0 * t)
        tone = dsp.sine(f * wob, m) + 0.15 * dsp.sine(2 * f * wob, m)
        parts.append(tone * dsp.env([(0, 0), (0.04, 1.0), (dur * 0.7, 0.7), (dur, 0)], m))
    gap = np.zeros(dsp.samples(0.07))
    return dsp.lowpass(np.concatenate([parts[0], gap, parts[1]]), 3500.0)


def _tok(rng: np.random.Generator, f: float) -> np.ndarray:
    """A wooden 'tok' (an invented frog-like knock): a short pitched knock."""
    m = dsp.samples(0.12)
    t = dsp.time_axis(m)
    x = dsp.sine(f * (1.0 + 0.15 * np.exp(-t / 0.01)), m) * dsp.perc(m, 0.001, 0.03)
    return x + 0.2 * dsp.bandpass(dsp.white(m, rng), f * 3.0, 3.0) * dsp.perc(m, 0.0005, 0.005)


@sound("amb_verdance_chorus", "ambience", -33.0, **AMB, **loop_bounds(N_CHORUS))
def amb_verdance_chorus(rng: np.random.Generator) -> np.ndarray:
    n = N_CHORUS
    buf = np.zeros((2, n + dsp.samples(4.0)))
    # Trill groups: three kinds of invented insects, overlapping, panned apart.
    for f_lo, f_hi, rate, count, gain in [(4200, 4600, 28.0, 18, 0.08), (5600, 6100, 41.0, 14, 0.05),
                                          (3300, 3500, 19.0, 9, 0.07)]:
        for _ in range(count):
            dur = float(rng.uniform(0.8, 2.6))
            x = _trill(rng, float(rng.uniform(f_lo, f_hi)), rate * float(rng.uniform(0.95, 1.05)), dur)
            dsp.place(buf, dsp.pan(gain * x, float(rng.uniform(-0.9, 0.9))), int(rng.integers(0, n)))
    # Far piping in the key (B Dorian): F#-B, A-F#, G#-E.
    for k in range(5):
        a, b = [(78, 83), (81, 78), (80, 76), (78, 83), (83, 81)][k]
        x = _piping(rng, H(a), H(b))
        dsp.place(buf, dsp.pan(0.05 * x, float(rng.uniform(-0.7, 0.7))), int(n * (k + float(rng.random())) / 5))
    # Wooden toks, in little runs.
    for _ in range(12):
        at = int(rng.integers(0, n))
        f = float(rng.choice([H(59), H(61), H(66)]))
        for j in range(int(rng.integers(2, 5))):
            dsp.place(buf, dsp.pan(0.06 * _tok(rng, f), 0.6 if at % 2 else -0.6), at + dsp.samples(0.16 * j))
    x = dsp.wrap(buf, n)
    x = dsp.reverb(x, rng, seconds=2.2, mix=0.35, predelay_ms=30.0, damp=0.6)
    x = dsp.wrap(x, n)
    air = dsp.periodic(dsp.bandpass, _wide(n, rng, dsp.pink, 0.2), 3000.0, 0.5) * 0.01
    return _finish(x + air, 80.0)


def _bubble(rng: np.random.Generator) -> np.ndarray:
    """A small bubble over a stone: a short sine chirping upward."""
    dur = float(rng.uniform(0.012, 0.04))
    m = dsp.samples(dur)
    t = dsp.time_axis(m)
    f0 = float(rng.uniform(400.0, 1600.0))
    return dsp.sine(f0 * (1.0 + 2.5 * t / dur), m) * dsp.env([(0, 0), (dur * 0.1, 1.0), (dur, 0)], m)


@sound("amb_verdance_stream", "ambience", -32.0, **AMB, **loop_bounds(N_STREAM))
def amb_verdance_stream(rng: np.random.Generator) -> np.ndarray:
    n = N_STREAM
    L = n / dsp.SR
    churn = 0.5 + 0.5 * dsp.smooth_random(n, rng, 1.5)
    flow = _wide(n, rng, dsp.pink, 0.5)
    flow = dsp.periodic(dsp.sweep, flow, "bp", 700.0 + 600.0 * churn, 0.9, block=128) * (0.4 + 0.3 * churn)
    wash = dsp.periodic(dsp.bandpass, _wide(n, rng, dsp.white, 0.3), 2600.0, 0.6) * 0.08
    buf = np.zeros((2, n + dsp.samples(0.2)))
    for _ in range(int(L * 45)):
        at = int(rng.integers(0, n))
        dsp.place(buf, dsp.pan(_bubble(rng) * float(rng.uniform(0.05, 0.25)), float(rng.uniform(-0.5, 0.5))), at)
    low = dsp.periodic(dsp.lowpass, _wide(n, rng, dsp.brown, 0.7), 200.0) * 0.15 * (0.8 + 0.2 * lfo(n, L, 3))
    return _finish(flow + wash + dsp.wrap(buf, n) + low, 60.0)


# --------------------------------------------------------------------------- details


DETAIL = dict(folder="ambience/details")


def _creak(rng: np.random.Generator, length: float, rate: float, pitch: float) -> np.ndarray:
    """Stick-slip friction in wood: a pulse train whose rate wanders, through
    two or three wooden resonances, then a few leaves."""
    n = dsp.samples(length + 0.8)
    t = dsp.time_axis(n)
    shape = dsp.env([(0, 0), (length * 0.15, 1.0), (length * 0.7, 0.8), (length, 0)], n, 1.0)
    wander = rate * (1.0 + 0.35 * dsp.smooth_random(n, rng, 2.5, periodic=False) + 0.2 * np.sin(np.pi * t / length))
    ph = np.cumsum(wander) / dsp.SR
    pulses = (np.diff(np.floor(ph), prepend=0.0) > 0).astype(float)
    pulses *= rng.uniform(0.5, 1.0, n)
    body = np.zeros(n)
    for fc, q, amp in ((pitch, 6.0, 1.0), (pitch * 2.3, 5.0, 0.5), (pitch * 4.1, 4.0, 0.25)):
        body += amp * dsp.bandpass(pulses, fc, q)
    out = body * shape * 3.0
    for _ in range(int(rng.integers(3, 7))):
        k = dsp.samples(0.03)
        leaf = dsp.bandpass(dsp.white(k, rng), float(rng.uniform(2500, 6000)), 2.0) * dsp.perc(k, 0.001, 0.008)
        dsp.place(out, 0.15 * leaf, dsp.samples(length * float(rng.uniform(0.6, 1.0))))
    return out


for _i, (_len, _rate, _pitch) in enumerate([(1.1, 34.0, 420.0), (1.6, 22.0, 330.0), (0.7, 48.0, 560.0)], start=1):
    def _make_creak(rng: np.random.Generator, length=_len, rate=_rate, pitch=_pitch) -> np.ndarray:
        return _detail(_creak(rng, length, rate, pitch), rng, 0.3, 1.8)

    sound(f"amb_branch_creak_{_i}", "ambdetail", -26.0, max_seconds=3.5, params={"recipe": "_creak"},
          **DETAIL)(_make_creak)


def _voice(rng: np.random.Generator, notes: list[tuple[float, float]], trill: float, formant: float) -> np.ndarray:
    """One invented creature's phrase: sines gliding into each note with a fast
    flutter (`trill` Hz), through a soft formant."""
    out = []
    prev = notes[0][0]
    for f, dur in notes:
        m = dsp.samples(dur)
        t = dsp.time_axis(m)
        glide = f * (prev / f) ** np.exp(-t / 0.025)
        flut = 1.0 - 0.45 * (0.5 + 0.5 * np.sin(2 * np.pi * trill * t))
        tone = (dsp.sine(glide, m) + 0.3 * dsp.sine(2 * glide, m)) * flut
        tone = dsp.bandpass(tone, formant, 0.9) * 2.0
        out.append(tone * dsp.env([(0, 0), (0.02, 1.0), (dur * 0.75, 0.7), (dur, 0)], m))
        out.append(np.zeros(dsp.samples(0.05)))
        prev = f
    return np.concatenate(out)


def _call(rng: np.random.Generator, call: list[int], answer: list[int], wait: float) -> np.ndarray:
    a = _voice(rng, [(H(m), 0.16 if k < len(call) - 1 else 0.3) for k, m in enumerate(call)], 24.0, 2200.0)
    b = _voice(rng, [(H(m), 0.2 if k < len(answer) - 1 else 0.36) for k, m in enumerate(answer)], 17.0, 1500.0)
    b = dsp.lowpass(b, 2400.0) * 0.45  # further off, duller
    buf = np.zeros(len(a) + dsp.samples(wait) + len(b) + dsp.samples(0.5))
    dsp.place(buf, a, 0)
    dsp.place(buf, b, len(a) + dsp.samples(wait))
    return buf


for _i, (_call_notes, _answer_notes, _wait) in enumerate([
    ([78, 83], [76, 71], 0.7),
    ([81, 80, 85], [73, 71], 0.9),
    ([83, 78, 83], [74, 76, 71], 0.6),
], start=1):
    def _make_call(rng: np.random.Generator, c=_call_notes, a=_answer_notes, w=_wait) -> np.ndarray:
        return _detail(_call(rng, c, a, w), rng, 0.35, 2.4)

    sound(f"amb_canopy_call_{_i}", "ambdetail", -27.0, max_seconds=4.5, params={"recipe": "_call"},
          **DETAIL)(_make_call)


def _drips(rng: np.random.Generator, count: int) -> np.ndarray:
    buf = np.zeros(dsp.samples(2.6))
    at = 0.02
    for _ in range(count):
        m = dsp.samples(0.05)
        t = dsp.time_axis(m)
        f0 = float(rng.uniform(1100.0, 2300.0))
        plip = dsp.sine(f0 * (1.0 + 1.2 * t / 0.05), m) * dsp.perc(m, 0.001, 0.012)
        k = dsp.samples(0.03)
        leaf = dsp.bandpass(dsp.white(k, rng), float(rng.uniform(3000, 5500)), 2.5) * dsp.perc(k, 0.0005, 0.006)
        dsp.place(buf, 0.6 * plip, dsp.samples(at))
        dsp.place(buf, 0.35 * leaf, dsp.samples(at + 0.004))
        at += float(rng.uniform(0.15, 0.55))
    return buf


for _i, _count in enumerate([3, 5, 2], start=1):
    def _make_drips(rng: np.random.Generator, c=_count) -> np.ndarray:
        return _detail(_drips(rng, c), rng, 0.2, 1.4)

    sound(f"amb_leaf_drip_{_i}", "ambdetail", -28.0, max_seconds=4.0, params={"recipe": "_drips"},
          **DETAIL)(_make_drips)


def _flurry(rng: np.random.Generator, beats: int, rate: float) -> np.ndarray:
    """Wingbeats: soft low-mid air 'whup's at `rate` per second, moving away
    (each a little quieter and duller), a shaken branch at the start."""
    buf = np.zeros(dsp.samples(beats / rate + 1.2))
    for k in range(beats):
        m = dsp.samples(0.07)
        whup = dsp.bandpass(dsp.white(m, rng), 500.0 + 300.0 * float(rng.random()), 1.2)
        whup *= dsp.env([(0, 0), (0.02, 1.0), (0.07, 0)], m, 1.2)
        fall = 0.82 ** k
        dsp.place(buf, dsp.lowpass(whup, 3000.0 * fall + 600.0) * fall,
                  dsp.samples(k / rate + float(rng.uniform(0.0, 0.008))))
    for _ in range(int(rng.integers(6, 12))):
        k = dsp.samples(0.03)
        leaf = dsp.bandpass(dsp.white(k, rng), float(rng.uniform(2500, 6000)), 2.0) * dsp.perc(k, 0.001, 0.01)
        dsp.place(buf, 0.3 * leaf, dsp.samples(float(rng.uniform(0.0, 0.35))))
    return buf


for _i, (_beats, _rate) in enumerate([(9, 14.0), (14, 17.0)], start=1):
    def _make_flurry(rng: np.random.Generator, b=_beats, r=_rate) -> np.ndarray:
        return _detail(_flurry(rng, b, r), rng, 0.25, 1.6)

    sound(f"amb_wing_flurry_{_i}", "ambdetail", -26.0, max_seconds=3.0, params={"recipe": "_flurry"},
          **DETAIL)(_make_flurry)


# --------------------------------------------------------------------------- canopy


CANOPY = dict(folder="canopy")


def _rustle(rng: np.random.Generator, length: float, density: int, closing: bool) -> np.ndarray:
    """Leaves moving round a body: a soft noise swell and a swarm of leaf
    ticks; closing (going in) it darkens at the end, opening (coming out) it
    brightens and is lighter."""
    n = dsp.samples(length + 0.3)
    u = np.clip(dsp.time_axis(n) / length, 0.0, 1.0)
    shape = dsp.env([(0, 0), (length * 0.25, 1.0), (length * 0.6, 0.7), (length, 0)], n, 1.2)
    fc = (4200.0 - 2400.0 * u) if closing else (2600.0 + 2600.0 * u)
    swell = dsp.sweep(dsp.pink(n, rng), "bp", fc, 0.8, block=64) * shape * 0.5
    ticks = np.zeros(n)
    m = dsp.samples(0.02)
    for _ in range(density):
        at = float(rng.beta(2.0, 3.0)) * length
        exc = dsp.white(m, rng) * dsp.perc(m, 0.0004, 0.003)
        tick = dsp.bandpass(exc, float(rng.uniform(2200, 6800)), 3.0)
        dsp.place(ticks, tick * float(rng.uniform(0.2, 0.7)), dsp.samples(at))
    out = swell + 0.5 * ticks
    if closing:  # a twig gives a little
        k = dsp.samples(0.05)
        twig = dsp.bandpass(dsp.white(k, rng), 1300.0, 4.0) * dsp.perc(k, 0.0005, 0.01)
        dsp.place(out, 0.4 * twig, dsp.samples(length * float(rng.uniform(0.3, 0.5))))
    y = dsp.reverb(out, rng, seconds=0.5, mix=0.12, predelay_ms=5.0, damp=0.6).mean(axis=0)
    return dsp.fade(dsp.trim_tail(dsp.dc_block(dsp.highpass(y, 200.0)), -55.0), 0.004, 0.06)


for _i, (_len, _d) in enumerate([(0.55, 70), (0.7, 90), (0.6, 60)], start=1):
    sound(f"canopy_rustle_in_{_i}", "canopy", -27.0, max_seconds=1.2, params={"recipe": "_rustle"},
          **CANOPY)(lambda rng, length=_len, d=_d: _rustle(rng, length, d, True))
for _i, (_len, _d) in enumerate([(0.32, 30), (0.4, 40), (0.36, 26)], start=1):
    sound(f"canopy_rustle_out_{_i}", "canopy", -30.0, max_seconds=0.9, params={"recipe": "_rustle"},
          **CANOPY)(lambda rng, length=_len, d=_d: _rustle(rng, length, d, False))


# --------------------------------------------------------------------------- Advisor


@sound("advisor_canopy_contact", "advisor", ADVISOR_LUFS + 1.0, max_seconds=1.9)
def advisor_canopy_contact(rng: np.random.Generator) -> np.ndarray:
    """Contact under the canopy: a muffled B+F# (heard through leaves), then
    the D+G# tritone uncovered, twice, the second held and leaning up."""
    hidden = dsp.lowpass(advisor_dyad(H(71), H(78), 0.24), 700.0) * 1.6
    a = advisor_dyad(H(74), H(80), 0.1)
    b = glide_dyad(H(74), H(80), 0.42, 1.0, 0.5)
    return _phrase([(0.0, 0.9, hidden), (0.34, 0.95, a), (0.5, 1.0, b)], rng, 1.6)


@sound("advisor_air_contact", "advisor", ADVISOR_LUFS + 1.0, max_seconds=1.9)
def advisor_air_contact(rng: np.random.Generator) -> np.ndarray:
    """Enemy aircraft: dyads sweeping up fast (something rising), then a high
    tritone hovering with a rotor-like beat."""
    parts = []
    for k, (lo, hi) in enumerate([(69, 76), (73, 80), (76, 83)]):
        parts.append((0.09 * k, 0.8 + 0.07 * k, advisor_dyad(H(lo), H(hi), 0.08)))
    hover = advisor_dyad(H(80), H(86), 0.6)
    t = dsp.time_axis(len(hover))
    hover = hover * (1.0 - 0.45 * (0.5 + 0.5 * np.sin(2 * np.pi * 13.0 * t)))
    parts.append((0.3, 1.0, hover))
    return _phrase(parts, rng, 1.6)


@sound("advisor_air_lost", "advisor", ADVISOR_LUFS, max_seconds=1.9)
def advisor_air_lost(rng: np.random.Generator) -> np.ndarray:
    """One of ours down: a high D+A falling a fifth as it fades (out of the
    sky), then a low, dull F#+C# where it lands."""
    fall = glide_dyad(H(86), H(93), 0.6, -7.0, 0.15)
    land = dsp.lowpass(advisor_dyad(H(66), H(73), 0.28), 1200.0) * 1.3
    return _phrase([(0.0, 1.0, fall), (0.72, 0.85, land)], rng, 1.6)
