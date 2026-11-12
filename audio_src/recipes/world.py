"""World markers and the Advisor's tone family.

The Advisor (the ship *Meridian*) must never be mistaken for a unit, so it
avoids the unit instruments entirely: pure sine dyads with a slow tremolo,
heard through a band-limited 'ship channel' with a faint carrier hiss.
"""

from __future__ import annotations

import numpy as np

from synth import dsp
from synth.instruments import soft_sine

from . import sound


@sound("world_order_ping", "world", -25.0, max_seconds=0.8)
def world_order_ping(rng: np.random.Generator) -> np.ndarray:
    """Ground marker: a soft sonar ping that drops a little in pitch, one echo."""
    n = dsp.samples(0.35)
    f = 1318.5 * (1.0 - 0.06 * np.clip(dsp.time_axis(n) / 0.2, 0, 1))
    x = dsp.fm(f, 2.0, 0.9 * dsp.perc(n, 0.001, 0.03), n) * dsp.perc(n, 0.002, 0.07)
    x += 0.35 * dsp.sine(f / 2.0, n) * dsp.perc(n, 0.002, 0.05)
    echo = np.zeros(dsp.samples(0.7))
    dsp.place(echo, x, 0)
    dsp.place(echo, 0.25 * dsp.lowpass(x, 2500.0), dsp.samples(0.16))
    wet = dsp.reverb(echo, rng, seconds=0.5, mix=0.15, damp=0.6).mean(axis=0)
    return dsp.fade(dsp.trim_tail(dsp.dc_block(dsp.highpass(wet, 300.0)), -55.0), 0.001, 0.03)


def advisor_dyad(lo: float, hi: float, dur: float) -> np.ndarray:
    x = soft_sine(lo, dur, 0.008, 0.25, (1.0, 0.08, 0.04)) + 0.8 * soft_sine(hi, dur, 0.008, 0.25, (1.0, 0.05))
    n = len(x)
    t = dsp.time_axis(n)
    trem = 1.0 - 0.18 * (0.5 + 0.5 * np.sin(2 * np.pi * 7.0 * t))
    # A quiet ring-modulated shimmer gives the 'transmitted' colour.
    ring = 0.12 * dsp.sine(hi * 2.01, n) * dsp.sine(lo * 0.5, n) * dsp.perc(n, 0.01, 0.1)
    return (x[:n] * trem + ring) * 0.5


def ship_channel(x: np.ndarray, rng: np.random.Generator) -> np.ndarray:
    """Band-limits to the ship's comms channel and adds a gated carrier hiss."""
    y = dsp.bandpass(dsp.highpass(x, 350.0), 1800.0, 0.5) * 1.6 + 0.4 * dsp.highpass(x, 350.0)
    gate = dsp.ar(len(y), 0.02, 0.15, max(len(y) / dsp.SR - 0.17, 0.0))
    hiss = 0.012 * dsp.bandpass(dsp.white(len(y), rng), 5000.0, 0.7) * gate
    return y + hiss


@sound("advisor_alert", "advisor", -20.0, max_seconds=1.6)
def advisor_alert(rng: np.random.Generator) -> np.ndarray:
    """Generic Advisor alert: two-step dyad call (high, lower), heard twice."""
    buf = np.zeros(dsp.samples(1.5))
    a = advisor_dyad(dsp.midi_hz(81), dsp.midi_hz(88), 0.11)  # A5 + E6
    b = advisor_dyad(dsp.midi_hz(78), dsp.midi_hz(85), 0.16)  # F#5 + C#6
    for k, at in enumerate([0.0, 0.34]):
        g = 1.0 if k == 0 else 0.8
        dsp.place(buf, g * a, dsp.samples(at))
        dsp.place(buf, g * b, dsp.samples(at + 0.13))
    y = ship_channel(buf, rng)
    y = dsp.reverb(y, rng, seconds=0.6, mix=0.12, damp=0.7).mean(axis=0)
    return dsp.fade(dsp.trim_tail(dsp.dc_block(y), -55.0), 0.001, 0.05)
