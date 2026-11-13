"""Kessel Reach: the *trail* layer of the explore clip.

A fourth synchronised layer on the explore grid (80 BPM, 16 bars, 48 s). The
MusicDirector raises it as the player resolves the map's discovery sites
(silent before the first, full when every site is resolved), so the Trail
motif surfaces more clearly the more the player has found.

It is played on the Antecedent bell (the sound world of the signals and the
Warden), an octave above the melody layer and in its gaps, so the two never
speak at once:

  beat 12  the motif on D (D6 A6 B6 G#6), over Dmaj9, after the melody's own
  beat 28  only its question, D -> A, over E/D (the signal pulse, in time)
  beat 44  the motif moved through the scale onto B (B F# G# E), over Bm
  beat 56  and onto A (A E F# D), over Aadd9: the last note is home

Under it a faint bell air on A and E keeps the layer present between quotes.
"""

from __future__ import annotations

import numpy as np

from synth import dsp
from synth.instruments import bell

from . import sound
from .music_kessel import BEAT, LOOP, _space
from .music_kessel_combat import LAYER, _soft

# (start beat, [(midi, beats), ...], velocity)
QUOTES = [
    (12.0, [(86, 0.5), (93, 1.5), (95, 0.5), (92, 2.5)], 1.0),
    (28.0, [(86, 0.5), (93, 2.5)], 0.6),
    (44.0, [(83, 0.5), (90, 1.5), (92, 0.5), (88, 2.5)], 0.85),
    (56.0, [(81, 0.5), (88, 1.5), (90, 0.5), (86, 3.0)], 0.9),
]


@sound("mus_kessel_explore_trail", "music", -29.0, **LAYER)
def trail(rng: np.random.Generator) -> np.ndarray:
    n = dsp.samples(LOOP)
    buf = np.zeros((2, n + dsp.samples(8.0)))
    for start, notes, vel in QUOTES:
        at = start
        for i, (m, beats) in enumerate(notes):
            b = bell(dsp.midi_hz(m), rng, decay=0.6 + 0.45 * beats, brightness=0.45, strike=0.15)
            b = _soft(dsp.lowpass(b, 6500.0), 0.01)
            side = -0.35 + 0.23 * i
            dsp.place(buf, dsp.pan(b * vel * (0.8 if i == 0 else 1.0), side), dsp.samples(at * BEAT))
            at += beats
    x = dsp.wrap(buf, n)
    t = dsp.time_axis(n)
    air = np.zeros((2, n))
    for k, m in enumerate([81, 88]):
        f = round(dsp.midi_hz(m) * LOOP) / LOOP
        f2 = round((dsp.midi_hz(m) + 0.25) * LOOP) / LOOP
        tone = 0.5 * (dsp.sine(f, n) + dsp.sine(f2, n))
        swell = 0.5 - 0.5 * np.cos(2 * np.pi * (2 + k) * t / LOOP)
        air += dsp.pan(0.035 * tone * swell, -0.4 + 0.8 * k)
    return _space(x + air, rng, n, reverb_s=4.2, mix=0.45, echo_s=BEAT * 1.5, feedback=0.3, echo_mix=0.25)
