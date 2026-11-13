"""Stealth (Phase 5): being watched, being seen, and the enemy's alarm.

Watching and alarms belong to the Halcyon Combine, so they are built in its
sound world (detuned saws, ring modulation off any harmonic, saturation,
decimation, never in the Concord key). The Wisp's cloak is Concord: glass and
air in D.

  stealth_suspicion        a watcher noticing something (positional loop): a beating cluster of
                           detuned saws throbbing four times a second, a radar tick. The runtime
                           raises its pitch and level with the watcher's suspicion, so the beat
                           and the throb speed up: it tightens.
  stealth_spotted          seen: two ring-modulated chirps snapping up into a hard tritone stab
                           with a crack. Sharp and unmistakable, under a second.
  stealth_alert_suspicious the faction is suspicious: a radio squelch and a buzzy two-tone query
                           rising a fourth ("hm?"), squelch off.
  stealth_alert_alarm      the faction is alerted: a saturated klaxon wailing up a fourth and
                           back, twice, with a thump under each cycle.
  stealth_all_clear        the alert has decayed: squelch, the query tones falling (stand down),
                           squelch off, and a soft Concord chime D+A: the player can breathe.
  stealth_cloak_engage     a Wisp cloaks: glass chimes D A E swelled backwards, air rising
                           through a closing comb, folding into nothing.
  stealth_cloak_disengage  it reappears: an air pop sweeping down, the chimes A -> D ringing out.
"""

from __future__ import annotations

import numpy as np

from synth import dsp
from synth.instruments import chime

from . import sound
from .movement import qf

H = dsp.midi_hz


def combine_buzz(f: float | np.ndarray, n: int, ratio: float = 1.37, drive: float = 2.0) -> np.ndarray:
    """Two detuned saws, ring-modulated off any harmonic, saturated and
    coarsely quantised: the Combine's radio voice."""
    x = dsp.warm_saw(f * dsp.cents(-14.0), n, 12.0) + dsp.warm_saw(f * dsp.cents(12.0), n, 12.0)
    x *= 0.7 + 0.3 * dsp.sine(f * ratio, n)
    x = dsp.saturate(x * 1.3, drive)
    return np.round(x * 20.0) / 20.0


def squelch(rng: np.random.Generator, dur: float = 0.06) -> np.ndarray:
    n = dsp.samples(dur)
    x = dsp.bandpass(dsp.white(n, rng), 2600.0, 0.9) * dsp.perc(n, 0.001, dur * 0.35)
    x += 0.4 * dsp.sine(1900.0, n) * dsp.perc(n, 0.0005, 0.006)
    return x


def _flat_finish(x: np.ndarray, rng: np.random.Generator, hp: float = 120.0, seconds: float = 0.5,
                 mix: float = 0.12) -> np.ndarray:
    wet = dsp.reverb(dsp.highpass(x, hp), rng, seconds=seconds, mix=mix, predelay_ms=6.0, damp=0.7).mean(axis=0)
    return dsp.fade(dsp.trim_tail(dsp.dc_block(wet), -58.0), 0.0005, 0.04)


# --------------------------------------------------------------------------- being watched


@sound("stealth_suspicion", "stealth", -26.0, loop=True, min_seconds=1.99, max_seconds=2.01)
def stealth_suspicion(rng: np.random.Generator) -> np.ndarray:
    L = 2.0
    n = dsp.samples(L)
    t = dsp.time_axis(n)
    cluster = np.zeros(n)
    for k, f in enumerate([qf(415.0, L), qf(421.5, L), qf(433.0, L)]):
        x = dsp.warm_saw(f, n, 7.0, start=0.3 * k) * dsp.sine(qf(f * 1.37, L), n)
        cluster += x
    cluster = dsp.periodic(dsp.bandpass, cluster, 900.0, 1.1)
    throb = 0.35 + 0.65 * (0.5 - 0.5 * np.cos(2 * np.pi * 8 * t / L)) ** 2  # 4 per second
    low = dsp.warm_saw(qf(103.5, L), n, 5.0) * 0.25
    ticks = np.zeros(n + dsp.samples(0.05))
    for i in range(4):
        m = dsp.samples(0.03)
        tk = dsp.bandpass(dsp.white(m, rng), 3400.0, 3.0) * dsp.perc(m, 0.0005, 0.003)
        dsp.place(ticks, 0.5 * tk, dsp.samples(i * L / 4 + 0.011))
    x = dsp.saturate((cluster * throb + low) * 0.9, 1.5) + dsp.wrap(ticks, n)
    x = dsp.periodic(dsp.highpass, x, 150.0)
    return x - x.mean()


@sound("stealth_spotted", "stealth", -19.0, max_seconds=1.1)
def stealth_spotted(rng: np.random.Generator) -> np.ndarray:
    total = 1.0
    buf = np.zeros(dsp.samples(total))
    for k, (a, b) in enumerate([(700.0, 1400.0), (900.0, 1800.0)]):
        m = dsp.samples(0.07)
        u = dsp.time_axis(m) / 0.07
        f = a * (b / a) ** u
        chirp = combine_buzz(f, m, 1.53, 2.5) * dsp.perc(m, 0.001, 0.04)
        dsp.place(buf, 0.6 * chirp, dsp.samples(0.07 * k))
    m = dsp.samples(0.55)
    stab = combine_buzz(H(78) * 1.012, m, 1.29, 3.0) + 0.8 * combine_buzz(H(84) * 0.991, m, 1.41, 3.0)
    stab *= dsp.env([(0.0, 0.0), (0.004, 1.0), (0.12, 0.7), (0.55, 0.0)], m, 1.5)
    crack = dsp.bandpass(dsp.white(m, rng), 3800.0, 0.7) * dsp.perc(m, 0.0005, 0.02)
    sub = dsp.sine(110.0 * (1.0 + 0.5 * np.exp(-dsp.time_axis(m) / 0.02)), m) * dsp.perc(m, 0.002, 0.06)
    dsp.place(buf, dsp.lowpass(stab, 5000.0) + 0.8 * crack + 0.6 * sub, dsp.samples(0.14))
    return _flat_finish(buf, rng, 90.0, 0.45, 0.1)


# --------------------------------------------------------------------------- alert levels


def _two_tone(rng: np.random.Generator, notes: list[tuple[float, float]], step: float) -> np.ndarray:
    total = step * len(notes) + 0.5
    buf = np.zeros(dsp.samples(total))
    dsp.place(buf, 0.8 * squelch(rng), 0)
    at = 0.07
    for i, (f, dur) in enumerate(notes):
        m = dsp.samples(dur + 0.05)
        x = combine_buzz(f, m, 1.37, 1.8) * dsp.ar(m, 0.012, 0.05, dur - 0.012)
        dsp.place(buf, 0.55 * dsp.lowpass(x, 3000.0), dsp.samples(at))
        at += step
    dsp.place(buf, 0.6 * squelch(rng, 0.04), dsp.samples(at + 0.02))
    return buf


@sound("stealth_alert_suspicious", "stealth", -23.0, max_seconds=1.2)
def stealth_alert_suspicious(rng: np.random.Generator) -> np.ndarray:
    x = _two_tone(rng, [(340.0, 0.14), (455.0, 0.26)], 0.2)
    return _flat_finish(x, rng, 140.0, 0.5, 0.14)


@sound("stealth_alert_alarm", "stealth", -21.0, max_seconds=2.8, min_seconds=1.5)
def stealth_alert_alarm(rng: np.random.Generator) -> np.ndarray:
    cycle = 0.95
    total = 2.6
    buf = np.zeros(dsp.samples(total))
    for c in range(2):
        m = dsp.samples(cycle)
        u = dsp.time_axis(m) / cycle
        f = 311.0 * (1.335 ** np.sin(np.pi * u))  # up a fourth and back
        x = combine_buzz(f, m, 1.29, 3.0) * (0.75 + 0.25 * dsp.sine(13.0, m))
        x *= dsp.ar(m, 0.03, 0.12, cycle - 0.15)
        x = np.repeat(x[::3], 3)[:m]
        dsp.place(buf, 0.6 * dsp.lowpass(x, 4200.0), dsp.samples(c * cycle))
        tt = dsp.time_axis(m)
        thump = dsp.sine(70.0 * (1.0 + 0.5 * np.exp(-tt / 0.03)), m) * dsp.perc(m, 0.003, 0.09)
        dsp.place(buf, 0.6 * thump, dsp.samples(c * cycle))
    return _flat_finish(buf, rng, 60.0, 0.9, 0.18)


@sound("stealth_all_clear", "stealth", -24.0, max_seconds=1.9)
def stealth_all_clear(rng: np.random.Generator) -> np.ndarray:
    x = _two_tone(rng, [(455.0, 0.14), (340.0, 0.3)], 0.2)
    buf = np.zeros(dsp.samples(1.7))
    dsp.place(buf, x, 0)
    relief = chime(H(74), 0.08, rng, brightness=0.5, decay=0.4, attack=0.01, tail=0.9)
    relief = dsp.mix(relief, 0.7 * chime(H(81), 0.08, rng, brightness=0.45, decay=0.45, attack=0.012, tail=0.9))
    dsp.place(buf, 0.45 * relief, dsp.samples(0.62))
    return _flat_finish(buf, rng, 140.0, 0.7, 0.16)


# --------------------------------------------------------------------------- the Wisp's cloak


@sound("stealth_cloak_engage", "stealth", -24.0, max_seconds=1.2)
def stealth_cloak_engage(rng: np.random.Generator) -> np.ndarray:
    total = 0.9
    n = dsp.samples(total)
    buf = np.zeros(n)
    for k, m in enumerate([86, 93, 100]):
        c = chime(H(m), 0.05, rng, brightness=0.6, decay=0.25, attack=0.004, tail=0.6)[: dsp.samples(0.7)]
        c = c[::-1] * dsp.ar(len(c), 0.02, 0.02, len(c) / dsp.SR - 0.04)
        dsp.place(buf, (0.5 - 0.1 * k) * c, dsp.samples(0.03 * k))
    u = dsp.time_axis(n) / total
    air = dsp.sweep(dsp.pink(n, rng), "bp", 800.0 * 6.0 ** np.minimum(u / 0.7, 1.0), 2.0)
    air *= dsp.env([(0.0, 0.0), (0.6, 0.5), (0.72, 0.15), (total, 0.0)], n)
    x = buf + air
    comb = dsp.fractional_delay(x, 20.0 + 140.0 * u)
    x = 0.6 * (x + comb)
    x = dsp.sweep(x, "lp", 9000.0 * np.where(u < 0.7, 1.0, 0.08 ** ((u - 0.7) / 0.3)), 0.8)
    return dsp.fade(dsp.trim_tail(dsp.dc_block(dsp.highpass(x, 250.0)), -58.0), 0.002, 0.05)


@sound("stealth_cloak_disengage", "stealth", -24.0, max_seconds=1.2)
def stealth_cloak_disengage(rng: np.random.Generator) -> np.ndarray:
    total = 1.0
    n = dsp.samples(total)
    buf = np.zeros(n)
    m = dsp.samples(0.2)
    u = dsp.time_axis(m) / 0.2
    pop = dsp.sweep(dsp.white(m, rng), "bp", 5000.0 * 0.15 ** u, 1.4) * dsp.perc(m, 0.002, 0.05)
    dsp.place(buf, 0.6 * pop, 0)
    dsp.place(buf, 0.5 * chime(H(93), 0.04, rng, brightness=0.7, decay=0.12, tail=0.4), dsp.samples(0.03))
    dsp.place(buf, 0.6 * chime(H(86), 0.06, rng, brightness=0.6, decay=0.3, tail=0.7), dsp.samples(0.1))
    wet = dsp.reverb(buf, rng, seconds=0.6, mix=0.18, predelay_ms=6.0, damp=0.5).mean(axis=0)
    return dsp.fade(dsp.trim_tail(dsp.dc_block(dsp.highpass(wet, 250.0)), -58.0), 0.001, 0.05)

