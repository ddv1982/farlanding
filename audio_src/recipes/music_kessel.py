"""Music for Kessel Reach, and the Trail motif.

The Trail motif is the game's sign for discovery. In D Lydian it is four notes,
scale degrees 1 - 5 - 6 - #4 (D A B G#): a wide opening leap, one step further,
then a fall onto the raised fourth, which leaves the phrase hanging like a
question. Short-long-short-long rhythm. It recurs, transposed through the
scale, wherever the score wants to point at the unknown.

The *explore* state is one 48 s loop (80 BPM, 4/4, 16 bars) in three layers
rendered against the same chord plan, so the director can fade any layer:

  pad     slow detuned ensemble chords and a soft bass, 4 bars per chord
  pulse   a quiet marimba arpeggio in eighths with a ping-pong echo: time passing
  melody  the motif and its answers on a chime-and-reed voice, lots of space
"""

from __future__ import annotations

import numpy as np

from synth import dsp
from synth.instruments import chime, marimba, pad_voice, reed, soft_sine

from . import sound

BPM = 80.0
BEAT = 60.0 / BPM
BAR = 4 * BEAT
BARS = 16
LOOP = BAR * BARS  # 48 s
BEATS = 4 * BARS

# (bass, voicing) for each 4-bar block, D Lydian: Dmaj9, E/D, Bm(add9), Aadd9.
CHORDS = [
    (38, [50, 57, 61, 64, 66]),
    (38, [50, 59, 64, 68]),
    (35, [47, 54, 61, 62, 66]),
    (33, [45, 52, 59, 61, 64]),
]

# Trail motif in scale steps: (semitones above the phrase root, length in beats).
MOTIF = [(0, 0.5), (7, 1.5), (9, 0.5), (6, 2.5)]

# Melody phrases: (start beat, [(midi, beats), ...], velocity).
PHRASES = [
    (4.0, [(74, 0.5), (81, 1.5), (83, 0.5), (80, 3.0)], 1.0),       # the motif, over Dmaj9
    (20.0, [(76, 0.5), (83, 1.5), (85, 0.5), (81, 3.0)], 0.95),     # one step up, over E/D
    (28.5, [(88, 0.5), (85, 2.0)], 0.5),                             # a distant echo
    (36.0, [(78, 0.5), (85, 1.5), (86, 3.5)], 0.9),                  # fragment, over Bm
    (52.0, [(69, 0.5), (76, 1.5), (78, 0.5), (74, 4.0)], 0.9),       # answer, falls home to D
]

ARP = [0, 2, 1, 3, 2, 4, 1, 3]
ARP_VEL = [1.0, 0.5, 0.7, 0.5, 0.85, 0.5, 0.7, 0.45]


def _n() -> int:
    return dsp.samples(LOOP)


def _space(x: np.ndarray, rng: np.random.Generator, n: int, reverb_s: float, mix: float,
           echo_s: float = 0.0, feedback: float = 0.0, echo_mix: float = 0.0) -> np.ndarray:
    """Echo and reverb whose tails fold back over the loop point."""
    y = dsp.wrap(x, n)
    if echo_s > 0:
        y = dsp.wrap(dsp.delay(y, echo_s, feedback, echo_mix, 2600.0, ping_pong=True), n)
    y = dsp.wrap(dsp.reverb(y, rng, seconds=reverb_s, mix=mix, predelay_ms=25.0, damp=0.55), n)
    y = dsp.periodic(dsp.highpass, y, 30.0)
    return y - y.mean(axis=1, keepdims=True)


@sound("mus_kessel_explore_pad", "music", -25.0, fmt="ogg", channels=2, loop=True, folder="music/kessel",
       min_seconds=LOOP - 0.01, max_seconds=LOOP + 0.01, bpm=BPM, beats=BEATS)
def pad(rng: np.random.Generator) -> np.ndarray:
    n = _n()
    buf = np.zeros((2, n + dsp.samples(10.0)))
    block = 4 * BAR
    for i, (bass, voicing) in enumerate(CHORDS):
        at = dsp.samples(i * block)
        for k, m in enumerate(voicing):
            v = pad_voice(dsp.midi_hz(m), block, rng, attack=2.8, release=4.0, detune_cents=6.0,
                          brightness=3.0 + 0.4 * k)
            dsp.place(buf, v * (0.9 if k == 0 else 0.6), at)
        low = soft_sine(dsp.midi_hz(bass), block, attack=2.0, release=3.5, harmonics=(1.0, 0.25, 0.08))
        dsp.place(buf, dsp.stereo(low * 0.8), at)
    x = dsp.wrap(buf, n)
    # Brightness breathes twice per loop.
    t = dsp.time_axis(n)
    cutoff = 1100.0 + 700.0 * (0.5 + 0.5 * np.sin(2 * np.pi * 2 * t / LOOP - np.pi / 2))
    x = dsp.periodic(dsp.sweep, x, "lp", cutoff, 0.6, block=512)
    return _space(x, rng, n, reverb_s=4.5, mix=0.4)


@sound("mus_kessel_explore_pulse", "music", -29.0, fmt="ogg", channels=2, loop=True, folder="music/kessel",
       min_seconds=LOOP - 0.01, max_seconds=LOOP + 0.01, bpm=BPM, beats=BEATS)
def pulse(rng: np.random.Generator) -> np.ndarray:
    n = _n()
    buf = np.zeros((2, n + dsp.samples(2.0)))
    eighth = BEAT / 2
    soften = None
    for bar in range(BARS):
        bass, voicing = CHORDS[bar // 4]
        tones = sorted(m + 12 if m < 62 else m for m in voicing)
        steps = 5 if bar % 4 == 3 else 8  # breathe at the end of each phrase
        for s in range(steps):
            m = tones[ARP[s] % len(tones)]
            note = marimba(dsp.midi_hz(m), 0.1, rng, hardness=0.45, decay=0.26, tail=0.5)
            if soften is None or len(soften) != len(note):
                soften = dsp.ar(len(note), 0.008, 0.05, len(note) / dsp.SR - 0.06)
            side = 0.3 if s % 2 else -0.3
            dsp.place(buf, dsp.pan(note * soften * ARP_VEL[s] * float(rng.uniform(0.92, 1.0)), side),
                      dsp.samples(bar * BAR + s * eighth))
        for beat in (0, 2):
            heart = soft_sine(dsp.midi_hz(bass + 12), 0.2, attack=0.015, release=0.35, harmonics=(1.0, 0.1))
            dsp.place(buf, dsp.stereo(heart * 0.45), dsp.samples(bar * BAR + beat * BEAT))
    x = dsp.periodic(dsp.lowpass, dsp.wrap(buf, n), 3200.0)
    return _space(x, rng, n, reverb_s=2.4, mix=0.28, echo_s=BEAT * 0.75, feedback=0.32, echo_mix=0.3)


def motif_voice(m: int, beats: float, vel: float, rng: np.random.Generator, beat_s: float = BEAT) -> np.ndarray:
    """Chime struck softly, doubled by a breathy reed that sustains the note."""
    f = dsp.midi_hz(m)
    dur = beats * beat_s
    bell = chime(f, 0.05, rng, brightness=0.7, decay=0.5 + 0.35 * dur, attack=0.012, tail=2.5)
    flute = reed(f, dur * 0.9, rng, brightness=2.2, attack=0.06, release=0.4, breath=0.07,
                 vibrato_hz=4.6, vibrato_cents=9.0)
    out = np.zeros(max(len(bell), len(flute)))
    out[: len(bell)] += bell
    out[: len(flute)] += 0.55 * flute
    return out * vel


@sound("mus_kessel_explore_melody", "music", -27.0, fmt="ogg", channels=2, loop=True, folder="music/kessel",
       min_seconds=LOOP - 0.01, max_seconds=LOOP + 0.01, bpm=BPM, beats=BEATS)
def melody(rng: np.random.Generator) -> np.ndarray:
    n = _n()
    buf = np.zeros((2, n + dsp.samples(6.0)))
    for start, notes, vel in PHRASES:
        at = start
        for m, beats in notes:
            dsp.place(buf, dsp.pan(motif_voice(m, beats, vel, rng), 0.12), dsp.samples(at * BEAT))
            at += beats
    return _space(buf, rng, n, reverb_s=3.8, mix=0.4, echo_s=BEAT * 1.5, feedback=0.38, echo_mix=0.32)


@sound("mus_trail_motif", "music", -22.0, fmt="ogg", channels=2, max_seconds=8.0, min_seconds=4.0)
def trail_motif(rng: np.random.Generator) -> np.ndarray:
    """Discovery stinger: the motif on its own, over a Lydian swell."""
    beat = 0.5
    buf = np.zeros((2, dsp.samples(9.0)))
    at = 0.25
    for i, (step, beats) in enumerate(MOTIF):
        voice = motif_voice(74 + step, beats + (1.5 if i == 3 else 0.0), 1.0 if i != 0 else 0.85, rng, beat)
        dsp.place(buf, dsp.pan(voice, 0.08 * (i - 1.5)), dsp.samples(at))
        at += beats * beat
    for k, m in enumerate([50, 57, 64, 68]):  # D3 A3 E4 G#4
        v = pad_voice(dsp.midi_hz(m), 2.6, rng, attack=0.9, release=2.6, brightness=3.0)
        dsp.place(buf, v * (0.5 if k == 0 else 0.35), 0)
    sparkle = chime(dsp.midi_hz(92), 0.05, rng, brightness=0.5, decay=0.9, attack=0.02, tail=2.0)
    dsp.place(buf, dsp.pan(sparkle * 0.3, 0.4), dsp.samples(at - 0.6))
    y = dsp.delay(buf, beat * 1.5, 0.3, 0.22, 2600.0, ping_pong=True)
    y = dsp.reverb(y, rng, seconds=3.5, mix=0.38, predelay_ms=25.0, damp=0.55)
    y = dsp.trim_tail(dsp.dc_block(y), -60.0)[:, : dsp.samples(7.5)]
    return dsp.fade(y, 0.002, 1.2)
