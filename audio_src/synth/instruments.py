"""Instrument voices shared by recipes. Each returns a mono note of `dur`
seconds (plus its natural release) at frequency `f`.

The Concord Survey family is built from three voices: a warm FM `chime` (glass
and wood, like a vibraphone), a `marimba` with inharmonic wooden partials, and a
`reed` (soft filtered saw with breath). Unit signatures, interface sounds and
music all draw on them, which is what makes them sound like one faction.
"""

from __future__ import annotations

import numpy as np

from . import dsp
from .dsp import SR


def chime(f: float, dur: float, rng: np.random.Generator, brightness: float = 1.0,
          decay: float = 0.6, attack: float = 0.004, tail: float = 1.2) -> np.ndarray:
    """Warm FM bell: carrier:modulator 1:1 for body, a 1:3.5 glassy overtone
    that fades fast, and a soft wooden thump on the attack."""
    n = dsp.samples(dur + tail)
    e = dsp.perc(n, attack, decay)
    idx = brightness * (0.4 + 1.8 * dsp.perc(n, attack, decay * 0.35))
    body = dsp.fm(f, 1.0, idx, n)
    glass = 0.22 * brightness * dsp.fm(f * 2.0, 3.5, 0.8 * dsp.perc(n, attack, decay * 0.2), n) * dsp.perc(n, attack, decay * 0.25)
    thump = 0.15 * dsp.lowpass(dsp.white(n, rng), f * 2.5) * dsp.perc(n, 0.001, 0.012)
    return (body * e + glass + thump) * 0.6


def marimba(f: float, dur: float, rng: np.random.Generator, hardness: float = 1.0,
            decay: float = 0.35, tail: float = 0.6) -> np.ndarray:
    """Wooden bar: tuned partials at 1 : 3.93 : 9.2 that die quickly, plus mallet."""
    n = dsp.samples(dur + tail)
    spec = [(1.0, 1.0, decay), (3.93, 0.35 * hardness, decay * 0.25), (9.2, 0.12 * hardness, decay * 0.08)]
    x = dsp.partials(f, n, spec, rng)
    mallet = 0.3 * hardness * dsp.bandpass(dsp.white(n, rng), min(f * 6, 9000), 1.2) * dsp.perc(n, 0.0005, 0.004)
    return (x * dsp.perc(n, 0.0015, 10.0) + mallet) * 0.7


def reed(f: float | np.ndarray, dur: float, rng: np.random.Generator, brightness: float = 5.0,
         attack: float = 0.03, release: float = 0.12, breath: float = 0.08,
         vibrato_hz: float = 5.0, vibrato_cents: float = 6.0) -> np.ndarray:
    """Soft wind-like tone: rolled-off saw, gentle vibrato that grows in, breath."""
    n = dsp.samples(dur + release)
    t = dsp.time_axis(n)
    if np.ndim(f):
        src = np.asarray(f, dtype=np.float64)
        freq = np.interp(np.arange(n), np.arange(len(src)), src)  # holds the last value
    else:
        freq = np.full(n, float(f))
    vib = dsp.cents(vibrato_cents) - 1.0
    freq = freq * (1.0 + vib * np.clip(t / 0.25, 0, 1) * np.sin(2 * np.pi * vibrato_hz * t))
    tone = dsp.warm_saw(freq, n, brightness)
    air = breath * dsp.bandpass(dsp.white(n, rng), float(np.median(freq)) * 2.0, 0.8)
    e = dsp.ar(n, attack, release, max(dur - attack, 0.0))
    return (tone + air) * e * 0.5


def soft_sine(f: float | np.ndarray, dur: float, attack: float = 0.01, release: float = 0.08,
              harmonics: tuple[float, ...] = (1.0, 0.18, 0.05)) -> np.ndarray:
    n = dsp.samples(dur + release)
    x = dsp.wavetable(f, n, lambda k: harmonics[k - 1] if k <= len(harmonics) else 0.0)
    return x * dsp.ar(n, attack, release, max(dur - attack, 0.0))


def pad_voice(f: float, dur: float, rng: np.random.Generator, attack: float = 2.0,
              release: float = 3.0, detune_cents: float = 7.0, brightness: float = 4.0,
              voices: int = 3) -> np.ndarray:
    """Slow detuned warm-saw ensemble for pads. Stereo (2, n)."""
    n = dsp.samples(dur + release)
    t = dsp.time_axis(n)
    out = np.zeros((2, n))
    for v in range(voices):
        det = dsp.cents(detune_cents * (v - (voices - 1) / 2.0) / max((voices - 1) / 2.0, 1.0))
        drift = 1.0 + 0.0008 * np.sin(2 * np.pi * (0.13 + 0.05 * v) * t + rng.random() * 6.28)
        x = dsp.warm_saw(f * det * drift, n, brightness, start=float(rng.random()))
        out += dsp.pan(x, -0.7 + 1.4 * v / max(voices - 1, 1))
    return out * dsp.ar(n, attack, release, max(dur - attack, 0.0)) / voices


# The Antecedent bell: a third sound world, neither Concord instrument nor
# Combine machine. Its partials are those of a tuned bell (hum an octave down,
# prime, a major-third tierce, quint, nominal) plus a faint raised-fourth
# partial: the interval the Trail motif hangs on is literally in the metal.
BELL_PARTIALS = [
    # (ratio, amplitude, decay as a fraction of the bell's decay)
    (0.5, 0.55, 1.6),    # hum
    (1.0, 1.0, 1.0),     # prime
    (1.25, 0.32, 0.7),   # tierce (major third)
    (1.414, 0.12, 0.45), # the raised fourth, faint
    (1.5, 0.28, 0.6),    # quint
    (2.0, 0.5, 0.5),     # nominal
    (2.51, 0.18, 0.3),
    (3.0, 0.16, 0.22),
    (4.07, 0.1, 0.12),
    (5.43, 0.06, 0.07),
]


def bell(f: float, rng: np.random.Generator, decay: float = 1.5, brightness: float = 1.0,
         strike: float = 0.5, detune_cents: float = 1.5, length: float | None = None) -> np.ndarray:
    """Struck Antecedent bell: stone-and-brass, slow beating between paired
    partials (each partial is two slightly detuned sines), a soft mallet strike."""
    n = dsp.samples(length if length is not None else decay * 5.0 + 0.1)
    t = dsp.time_axis(n)
    out = np.zeros(n)
    for ratio, amp, dk in BELL_PARTIALS:
        fr = f * ratio
        if fr >= dsp.NYQUIST * 0.9:
            continue
        a = amp * (brightness if ratio > 1.6 else 1.0)
        d = dsp.cents(detune_cents * (1.0 + ratio))
        p0, p1 = rng.random(2)
        osc = np.sin(2 * np.pi * (fr * t + p0)) + np.sin(2 * np.pi * (fr * d * t + p1))
        out += 0.5 * a * osc * np.exp(-t / (decay * dk))
    out *= dsp.perc(n, 0.003, 1e6)
    hit = strike * dsp.bandpass(dsp.white(n, rng), min(f * 4.0, 8000.0), 1.0) * dsp.perc(n, 0.0005, 0.008)
    return (out + hit) * 0.35
