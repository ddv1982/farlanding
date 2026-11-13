"""Phase 7: the Meridian's music, heard between landings (title, star map,
the ship, the tech web, the loadout).

The planet scores are the Concord instruments (chime, marimba, reed) in the
open air. The ship theme is the *Meridian's own voice* slowed into music: the
Advisor's sine dyads become a glass pad with a slow tremolo, the lead is a
pure sine with a soft chime edge, and the sonar of the briefing bed becomes a
pulse. Still D Lydian (one key for the whole game), but a different harmony:
F#m9 -> Bm(add9) -> Dmaj9/A -> E6/9, four bars each, ending on the bright
Lydian II so the loop never quite comes home. Calm and curious.

One 70 BPM loop of 16 bars (64 beats, 54.86 s; 2 419 200 samples, a multiple
of 64 for the native Vorbis encoder) in six synchronised layers, so moving
between screens fades layers in and out without restarting anything:

  pad      glass pad (sine pairs, slow tremolo) and a soft bass, 4 bars per chord
  pulse    sonar chimes on dotted quarters drifting against the bar, echoes
  melody   the ship theme on the Meridian lead: four questions, the last
           hanging on G# (the raised fourth, like the Trail motif)
  title    the theme stated broad and low on a warm reed with bells: the title
           screen's arrangement (with the pad only, it is the piece's intro)
  web      tech web: muted high marimba figures and data ticks, thinking
  loadout  loadout: a low soft heartbeat on two and four, brushed eighths, a reed drone on the
           root and fifth: getting ready

Attacks stay at 8 ms or softer (native Vorbis pre-echo, ADR 0005).
"""

from __future__ import annotations

import numpy as np

from synth import dsp
from synth.instruments import chime, marimba, reed, soft_sine

from . import sound

H = dsp.midi_hz

BPM = 70.0
BEAT = 60.0 / BPM
BAR = 4 * BEAT
BARS = 16
BEATS = 4 * BARS
LOOP = BAR * BARS  # 54.857 s

# (bass, voicing) per 4-bar block.
CHORDS = [
    (42, [54, 57, 61, 64, 68]),  # F#m9
    (35, [47, 54, 57, 61, 62]),  # Bm(add9)
    (33, [50, 57, 61, 64, 66]),  # Dmaj9/A
    (40, [52, 56, 61, 64, 66]),  # E6/9
]

LAYER = dict(fmt="ogg", channels=2, loop=True, folder="music/meridian", min_seconds=LOOP - 0.01,
             max_seconds=LOOP + 0.01, bpm=BPM, beats=BEATS)


def _n() -> int:
    return dsp.samples(LOOP)


def _space(x: np.ndarray, rng: np.random.Generator, reverb_s: float, mix: float, echo_s: float = 0.0,
           feedback: float = 0.0, echo_mix: float = 0.0) -> np.ndarray:
    n = _n()
    y = dsp.wrap(x, n)
    if echo_s > 0:
        y = dsp.wrap(dsp.delay(y, echo_s, feedback, echo_mix, 2400.0, ping_pong=True), n)
    y = dsp.wrap(dsp.reverb(y, rng, seconds=reverb_s, mix=mix, predelay_ms=30.0, damp=0.5), n)
    y = dsp.periodic(dsp.highpass, y, 32.0)
    return y - y.mean(axis=1, keepdims=True)


def _soft(x: np.ndarray, attack: float = 0.008) -> np.ndarray:
    return x * dsp.ar(len(x), attack, 0.05, len(x) / dsp.SR - attack - 0.05)


def glass_pad(f: float, dur: float, rng: np.random.Generator, attack: float = 3.0,
              release: float = 4.0) -> np.ndarray:
    """The Meridian's dyad voice as a pad: two near-unison sines a few cents
    apart (left and right), a faint octave, a slow tremolo. Stereo."""
    n = dsp.samples(dur + release)
    t = dsp.time_axis(n)
    out = np.zeros((2, n))
    for side, cents in [(-0.6, -4.0), (0.6, 4.0)]:
        x = dsp.wavetable(f * dsp.cents(cents), n, lambda k: (1.0, 0.1, 0.04)[k - 1] if k <= 3 else 0.0,
                          start=float(rng.random()))
        trem = 1.0 - 0.14 * (0.5 + 0.5 * np.sin(2 * np.pi * (0.23 + 0.04 * side) * t + rng.random() * 6.28))
        out += dsp.pan(x * trem, side)
    return out * dsp.ar(n, attack, release, max(dur - attack, 0.0)) * 0.5


@sound("mus_meridian_pad", "music", -26.0, **LAYER)
def pad(rng: np.random.Generator) -> np.ndarray:
    n = _n()
    buf = np.zeros((2, n + dsp.samples(10.0)))
    block = 4 * BAR
    for i, (bass, voicing) in enumerate(CHORDS):
        at = dsp.samples(i * block)
        for k, m in enumerate(voicing):
            dsp.place(buf, glass_pad(H(m), block, rng) * (0.8 if k == 0 else 0.55), at)
        top = glass_pad(H(voicing[-1] + 12), block, rng, attack=4.5, release=4.0)
        dsp.place(buf, 0.12 * top, at)
        low = soft_sine(H(bass), block, attack=2.5, release=3.5, harmonics=(1.0, 0.3, 0.08))
        dsp.place(buf, dsp.stereo(low * 0.7), at)
    x = dsp.periodic(dsp.lowpass, dsp.wrap(buf, n), 4200.0)
    return _space(x, rng, reverb_s=5.0, mix=0.45)


@sound("mus_meridian_pulse", "music", -30.0, **LAYER)
def pulse(rng: np.random.Generator) -> np.ndarray:
    """Sonar chimes every dotted quarter: three against the bar's four, so the
    figure drifts across the beat and only lines up again every three bars."""
    n = _n()
    buf = np.zeros((2, n + dsp.samples(3.0)))
    pattern = [0, 2, 1, 3, 4, 2, 3, 1]
    beat = 0.5  # off the loop point, so no attack sits on the seam
    k = 0
    while beat < BEATS - 0.01:
        _, voicing = CHORDS[int(beat // 16)]
        tones = sorted(m + 12 for m in voicing)
        m = tones[pattern[k % len(pattern)] % len(tones)]
        note = chime(H(m), 0.04, rng, brightness=0.45, decay=0.45, attack=0.01, tail=1.2)
        vel = (0.85 if k % 4 == 0 else 0.6) * float(rng.uniform(0.9, 1.0))
        side = 0.45 * np.sin(2 * np.pi * beat / 24.0)
        dsp.place(buf, dsp.pan(_soft(note, 0.01) * vel, float(side)), dsp.samples(beat * BEAT))
        beat += 1.5
        k += 1
    x = dsp.periodic(dsp.lowpass, dsp.wrap(buf, n), 5200.0)
    return _space(x, rng, reverb_s=3.0, mix=0.32, echo_s=BEAT, feedback=0.35, echo_mix=0.3)


def lead(m: int, beats: float, vel: float, rng: np.random.Generator) -> np.ndarray:
    """The Meridian lead: a pure sine with a faint octave, a slow vibrato that
    grows in, and a soft chime touch on the attack."""
    f = H(m)
    dur = beats * BEAT
    n = dsp.samples(dur + 1.2)
    t = dsp.time_axis(n)
    vib = 1.0 + (dsp.cents(7.0) - 1.0) * np.clip(t / 0.6, 0, 1) * np.sin(2 * np.pi * 4.4 * t)
    tone = dsp.wavetable(f * vib, n, lambda k: (1.0, 0.22, 0.06)[k - 1] if k <= 3 else 0.0)
    tone *= dsp.ar(n, 0.07, 0.9, max(dur * 0.92 - 0.07, 0.0))
    touch = chime(f, 0.03, rng, brightness=0.35, decay=0.3 + 0.2 * dur, attack=0.01, tail=1.2)
    out = np.zeros(max(n, len(touch)))
    out[:n] += 0.55 * tone
    out[: len(touch)] += 0.45 * touch
    return out * vel


MELODY = [
    (2.0, [(73, 1.0), (76, 1.0), (80, 2.5), (78, 1.0), (76, 3.0)], 0.95, 0.1),
    (18.0, [(74, 1.0), (78, 1.0), (81, 2.0), (83, 1.0), (81, 4.0)], 0.9, -0.1),
    (34.0, [(85, 1.0), (83, 1.0), (81, 1.0), (78, 1.0), (76, 1.0), (78, 4.0)], 0.85, 0.15),
    (50.0, [(76, 1.0), (80, 1.0), (83, 1.0), (85, 2.0), (80, 5.0)], 0.95, 0.0),
]


def _phrases(rng: np.random.Generator, phrases, voice) -> np.ndarray:
    buf = np.zeros((2, _n() + dsp.samples(8.0)))
    for start, notes, vel, side in phrases:
        at = start
        for m, beats in notes:
            dsp.place(buf, dsp.pan(voice(m, beats, vel, rng), side), dsp.samples(at * BEAT))
            at += beats
    return buf


@sound("mus_meridian_melody", "music", -28.0, **LAYER)
def melody(rng: np.random.Generator) -> np.ndarray:
    buf = _phrases(rng, MELODY, lead)
    return _space(buf, rng, reverb_s=4.0, mix=0.4, echo_s=BEAT * 1.5, feedback=0.3, echo_mix=0.25)


def horn(m: int, beats: float, vel: float, rng: np.random.Generator) -> np.ndarray:
    """A warm, dark reed doubled an octave down by a sine: the theme broad."""
    f = H(m)
    dur = beats * BEAT
    r = reed(f, dur * 0.95, rng, brightness=2.4, attack=0.35, release=1.0, breath=0.05, vibrato_hz=4.2,
             vibrato_cents=5.0)
    low = soft_sine(f / 2.0, dur * 0.95, attack=0.4, release=1.0, harmonics=(1.0, 0.15))
    k = min(len(r), len(low))
    return (r[:k] + 0.35 * low[:k]) * vel


TITLE = [
    (4.0, [(61, 2.0), (64, 2.0), (68, 7.0)], 0.9, -0.05),
    (20.0, [(62, 2.0), (66, 2.0), (69, 7.0)], 0.9, 0.05),
    (36.0, [(73, 2.0), (71, 2.0), (69, 2.0), (66, 6.0)], 0.85, 0.0),
    (52.0, [(64, 2.0), (68, 2.0), (73, 8.0)], 0.95, 0.0),
]


@sound("mus_meridian_title", "music", -27.0, **LAYER)
def title(rng: np.random.Generator) -> np.ndarray:
    buf = _phrases(rng, TITLE, horn)
    for i, (_, voicing) in enumerate(CHORDS):
        b = chime(H(voicing[-1] + 12), 0.05, rng, brightness=0.3, decay=1.6, attack=0.012, tail=4.0)
        dsp.place(buf, dsp.pan(0.3 * _soft(b, 0.012), -0.4 + 0.25 * i), dsp.samples(i * 16 * BEAT))
    return _space(buf, rng, reverb_s=5.0, mix=0.45)


@sound("mus_meridian_web", "music", -31.0, **LAYER)
def web(rng: np.random.Generator) -> np.ndarray:
    """The tech web thinking: muted high marimba figures in sixteenths, a new
    figure every two bars from the chord's tones, with data ticks on A7."""
    n = _n()
    buf = np.zeros((2, n + dsp.samples(2.0)))
    six = BEAT / 4
    figures = [[0, 2, 4, 2, 1, 3, 4, 3], [4, 3, 1, 2, 0, 2, 3, 1], [0, 4, 2, 4, 1, 4, 3, 4]]
    for bar in range(BARS):
        _, voicing = CHORDS[bar // 4]
        tones = sorted(m + 24 for m in voicing)
        fig = figures[(bar // 2) % len(figures)]
        for s in range(16):
            if s % 8 == 7 and bar % 2 == 1:
                continue  # breathe
            m = tones[fig[s % 8] % len(tones)]
            note = marimba(H(m), 0.02, rng, hardness=0.25, decay=0.07, tail=0.15)
            vel = (0.7 if s % 4 == 0 else 0.4) * float(rng.uniform(0.85, 1.0))
            side = 0.6 if (s // 2) % 2 else -0.6
            dsp.place(buf, dsp.pan(_soft(note) * vel, side), dsp.samples(bar * BAR + s * six))
        for s in (2, 6, 10, 14):
            m = dsp.samples(0.05)
            tk = dsp.sine(H(93), m) * dsp.perc(m, 0.008, 0.01)
            dsp.place(buf, dsp.pan(0.18 * tk, 0.2), dsp.samples(bar * BAR + s * six))
    x = dsp.periodic(dsp.lowpass, dsp.wrap(buf, n), 7000.0)
    return _space(x, rng, reverb_s=2.2, mix=0.3, echo_s=BEAT * 0.75, feedback=0.25, echo_mix=0.2)


@sound("mus_meridian_loadout", "music", -29.0, **LAYER)
def loadout(rng: np.random.Generator) -> np.ndarray:
    """Getting ready: a soft low heartbeat on beats one and three, brushed
    eighths, and a reed drone on the chord's root and fifth swelling each block.
    The heartbeat falls on beats two and four, so no attack sits on the seam."""
    n = _n()
    buf = np.zeros((2, n + dsp.samples(6.0)))
    for bar in range(BARS):
        for beat in (1, 3):  # off the loop point: no attack on the seam
            m = dsp.samples(0.5)
            t = dsp.time_axis(m)
            thump = dsp.sine(58.0 * (1.0 + 0.35 * np.exp(-t / 0.03)), m) * dsp.perc(m, 0.008, 0.16)
            dsp.place(buf, dsp.stereo(0.6 * thump * (1.0 if beat == 1 else 0.75)),
                      dsp.samples(bar * BAR + beat * BEAT))
        for e in range(8):
            m = dsp.samples(0.12)
            brush = dsp.bandpass(dsp.white(m, rng), 5200.0, 0.7) * dsp.perc(m, 0.008, 0.035)
            g = 0.09 if e % 2 else 0.05
            dsp.place(buf, dsp.pan(brush * g, 0.35 if e % 2 else -0.35), dsp.samples(bar * BAR + e * BEAT / 2))
    for i, (bass, _) in enumerate(CHORDS):
        block = 16 * BEAT
        for mm, g in [(bass + 12, 0.35), (bass + 19, 0.22)]:
            d = reed(H(mm), block * 0.9, rng, brightness=2.0, attack=3.0, release=2.5, breath=0.04,
                     vibrato_cents=3.0)
            dsp.place(buf, dsp.stereo(g * d), dsp.samples(i * block))
    x = dsp.periodic(dsp.lowpass, dsp.wrap(buf, n), 6000.0)
    return _space(x, rng, reverb_s=2.4, mix=0.25)
