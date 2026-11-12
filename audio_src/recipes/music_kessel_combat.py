"""Kessel Reach: tension and combat material, and the victory and defeat stings.

The extra layers are rendered against the explore loop's own grid (80 BPM,
4/4, 16 bars, 48 s) and chord plan (Dmaj9, E/D, Bm(add9), Aadd9), so they run
as more synchronised layers of the same clip: the director fades them in over
the explore layers and nothing ever has to wait for a clip change.

  drive   (tension) a low reed-and-sine ostinato in eighths on the chord root, a
          muted high tick on the off-beats, a soft swell into every fourth bar
  drums   (combat)  synthesised taiko and toms, a frame-drum backbeat, a shaker
          in sixteenths, a tom fill closing each 4-bar phrase
  brass   (combat)  bright reed 'brass' stabs in a dotted rhythm on root and
          fifth, and the Trail motif in long notes as a call to arms (bars 5, 13)

Attacks stay at 8 ms or softer (the native Vorbis encoder pre-echoes sharper
ones, ADR 0005).

Stings (group `sting`, flat on the Music bus, 4-6 s):

  victory  the Trail motif answered: D A B then up to the high D instead of the
           hanging G#, over a Dmaj9 swell and a rising marimba arpeggio
  defeat   the motif darkened and falling: D A Bb, down to the low D, over a slow
           D minor (b6) pad that closes its filter
"""

from __future__ import annotations

import numpy as np

from synth import dsp
from synth.instruments import chime, marimba, pad_voice, reed, soft_sine

from . import sound
from .music_kessel import BAR, BARS, BEAT, BEATS, BPM, CHORDS, LOOP, _space, motif_voice

LAYER = dict(fmt="ogg", channels=2, loop=True, folder="music/kessel", min_seconds=LOOP - 0.01,
             max_seconds=LOOP + 0.01, bpm=BPM, beats=BEATS)
SIXTEENTH = BEAT / 4


def _n() -> int:
    return dsp.samples(LOOP)


def _soft(x: np.ndarray, attack: float = 0.008) -> np.ndarray:
    """Softens a note's onset to at least `attack` (codec-friendly)."""
    return x * dsp.ar(len(x), attack, 0.02, len(x) / dsp.SR - attack - 0.02)


# --------------------------------------------------------------------------- tension


DRIVE_ACCENT = [1.0, 0.45, 0.7, 0.45, 0.9, 0.45, 0.7, 0.55]
DRIVE_OCTAVE = [0, 0, 12, 0, 0, 12, 0, 12]


@sound("mus_kessel_tension_drive", "music", -28.0, **LAYER)
def drive(rng: np.random.Generator) -> np.ndarray:
    n = _n()
    buf = np.zeros((2, n + dsp.samples(3.0)))
    eighth = BEAT / 2
    for bar in range(BARS):
        bass = CHORDS[bar // 4][0] + 12  # D2.. one octave above the pad's bass
        for s in range(8):
            m = bass + DRIVE_OCTAVE[s]
            low = soft_sine(dsp.midi_hz(m), eighth * 0.55, attack=0.01, release=0.12, harmonics=(1.0, 0.45, 0.2, 0.1))
            body = reed(dsp.midi_hz(m), eighth * 0.5, rng, brightness=3.0, attack=0.012, release=0.1,
                        breath=0.02, vibrato_cents=0.0)
            note = dsp.mix(low, 0.5 * body) * DRIVE_ACCENT[s]
            dsp.place(buf, dsp.stereo(note * 0.7), dsp.samples(bar * BAR + s * eighth))
        if bar % 2 == 1:  # the raised fourth as a shadow on the last off-beat
            g = soft_sine(dsp.midi_hz(56), eighth * 0.4, attack=0.01, release=0.1, harmonics=(1.0, 0.3))
            dsp.place(buf, dsp.pan(g * 0.35, -0.2), dsp.samples(bar * BAR + 7 * eighth))
        for s in range(8):  # muted tick on every off-beat sixteenth pair
            tick = marimba(dsp.midi_hz(81), 0.03, rng, hardness=0.3, decay=0.05, tail=0.12)
            dsp.place(buf, dsp.pan(_soft(tick) * (0.22 if s % 2 else 0.14), 0.45),
                      dsp.samples(bar * BAR + s * eighth + SIXTEENTH))
        if bar % 4 == 3:  # a swell of air into the next phrase
            m = dsp.samples(BAR)
            u = dsp.time_axis(m) / BAR
            air = dsp.sweep(dsp.pink(m, rng), "bp", 400.0 * 8.0 ** u, 1.2) * (u ** 2) * 0.18
            dsp.place(buf, dsp.stereo(air), dsp.samples(bar * BAR))
    x = dsp.periodic(dsp.lowpass, dsp.wrap(buf, n), 2600.0)
    return _space(x, rng, n, reverb_s=2.2, mix=0.22)


# --------------------------------------------------------------------------- combat


def taiko(rng: np.random.Generator, f: float, dur: float = 0.5) -> np.ndarray:
    n = dsp.samples(dur)
    t = dsp.time_axis(n)
    head = dsp.sine(f * (1.0 + 0.5 * np.exp(-t / 0.025)), n) * dsp.perc(n, 0.008, dur * 0.3)
    skin = dsp.lowpass(dsp.white(n, rng), f * 6.0) * dsp.perc(n, 0.008, 0.03) * 0.4
    return head + skin


def frame_hit(rng: np.random.Generator) -> np.ndarray:
    n = dsp.samples(0.3)
    x = dsp.bandpass(dsp.white(n, rng), 1300.0, 0.7) * dsp.perc(n, 0.008, 0.06)
    x += 0.4 * dsp.sine(190.0, n) * dsp.perc(n, 0.008, 0.05)
    return x


TAIKO = [(0, 1.0), (6, 0.7), (8, 0.9), (11, 0.45), (12, 0.8)]
TOM = [(4, 0.55), (14, 0.5)]


@sound("mus_kessel_combat_drums", "music", -26.0, **LAYER)
def drums(rng: np.random.Generator) -> np.ndarray:
    n = _n()
    buf = np.zeros((2, n + dsp.samples(2.0)))
    for bar in range(BARS):
        at0 = bar * BAR
        fill = bar % 4 == 3
        for s, v in TAIKO:
            if fill and s >= 8:
                continue
            dsp.place(buf, dsp.stereo(taiko(rng, 58.0) * v), dsp.samples(at0 + s * SIXTEENTH))
        for s, v in TOM:
            if fill and s >= 8:
                continue
            dsp.place(buf, dsp.pan(taiko(rng, 118.0, 0.3) * v * 0.7, 0.35), dsp.samples(at0 + s * SIXTEENTH))
        for s in (4, 12):
            dsp.place(buf, dsp.pan(frame_hit(rng) * 0.55, -0.25), dsp.samples(at0 + s * SIXTEENTH))
        if fill:  # descending toms through beats 3 and 4
            for k, s in enumerate(range(8, 16)):
                f = 150.0 * 0.92 ** k
                dsp.place(buf, dsp.pan(taiko(rng, f, 0.3) * (0.5 + 0.06 * k), 0.4 - 0.1 * k),
                          dsp.samples(at0 + s * SIXTEENTH))
        for s in range(16):
            m = dsp.samples(0.08)
            shake = dsp.highpass(dsp.white(m, rng), 6500.0) * dsp.perc(m, 0.008, 0.02)
            g = 0.14 if s % 4 == 2 else 0.07
            dsp.place(buf, dsp.pan(shake * g, 0.5), dsp.samples(at0 + s * SIXTEENTH))
    x = dsp.wrap(buf, n)
    x = dsp.saturate(x * 1.2, 0.8)
    return _space(x, rng, n, reverb_s=1.8, mix=0.18)


STABS = [(0, 1.0), (3, 0.75), (6, 0.85), (8, 0.95), (11, 0.7), (14, 0.8)]
CALL = [(62, 1.0), (69, 3.0), (71, 1.0), (68, 5.0)]  # the motif augmented: D4 A4 B4 G#4


def brass_note(rng: np.random.Generator, m: int, dur: float, bright: float = 9.0) -> np.ndarray:
    f = dsp.midi_hz(m)
    x = reed(f, dur, rng, brightness=bright, attack=0.012, release=0.08, breath=0.03, vibrato_cents=2.0)
    x = dsp.mix(x, 0.5 * reed(f * dsp.cents(7.0), dur, rng, brightness=bright, attack=0.014, release=0.08,
                               breath=0.0, vibrato_cents=2.0))
    return dsp.saturate(x * 1.6, 1.2)


@sound("mus_kessel_combat_brass", "music", -27.0, **LAYER)
def brass(rng: np.random.Generator) -> np.ndarray:
    n = _n()
    buf = np.zeros((2, n + dsp.samples(4.0)))
    for bar in range(BARS):
        bass, voicing = CHORDS[bar // 4]
        root = bass + 12 if bass + 12 >= 45 else bass + 24
        calling = bar in (4, 5, 12, 13)
        for s, v in STABS:
            if calling and s >= 8:
                continue
            for k, m in enumerate([root, root + 7, root + 12]):
                note = brass_note(rng, m, SIXTEENTH * 1.4, 7.0 + 2.0 * k)
                dsp.place(buf, dsp.pan(note * v * (0.6 if k else 0.8), -0.3 + 0.3 * k),
                          dsp.samples(bar * BAR + s * SIXTEENTH))
    for start_bar in (4, 12):
        at = start_bar * BAR + 2 * BEAT
        for m, beats in CALL:
            dur = beats * BEAT * 0.5
            note = brass_note(rng, m + 12, dur * 0.95, 6.0)
            dsp.place(buf, dsp.pan(note * 0.9, 0.1), dsp.samples(at))
            at += dur
    x = dsp.periodic(dsp.lowpass, dsp.wrap(buf, n), 4200.0)
    return _space(x, rng, n, reverb_s=2.6, mix=0.25)


# --------------------------------------------------------------------------- stings


STING = dict(fmt="ogg", channels=2, folder="music/stings", min_seconds=3.0, max_seconds=6.5)


@sound("mus_sting_victory", "sting", -22.0, **STING)
def sting_victory(rng: np.random.Generator) -> np.ndarray:
    beat = 0.42
    buf = np.zeros((2, dsp.samples(7.0)))
    at = 0.2
    for i, (m, beats) in enumerate([(74, 0.5), (81, 1.0), (83, 0.5), (86, 4.0)]):
        v = motif_voice(m, beats, 0.85 if i == 0 else 1.0, rng, beat)
        dsp.place(buf, dsp.pan(v, 0.05 * (i - 1.5)), dsp.samples(at))
        if i == 3:  # the answer is doubled an octave down on the brass reed
            dsp.place(buf, dsp.stereo(0.45 * brass_note(rng, 74, 1.6, 6.0)), dsp.samples(at))
        at += beats * beat
    for k, m in enumerate([50, 57, 61, 64, 66]):  # Dmaj9 swell
        p = pad_voice(dsp.midi_hz(m), 3.2, rng, attack=0.7, release=2.2, brightness=3.5)
        dsp.place(buf, p * (0.5 if k == 0 else 0.32), 0)
    low = soft_sine(dsp.midi_hz(38), 3.0, attack=0.3, release=1.8, harmonics=(1.0, 0.3, 0.1))
    dsp.place(buf, dsp.stereo(0.6 * low), dsp.samples(0.2))
    for k, m in enumerate([74, 78, 81, 85, 88, 90]):  # rising arpeggio into the answer
        note = _soft(marimba(dsp.midi_hz(m), 0.1, rng, hardness=0.5, decay=0.4, tail=0.8))
        dsp.place(buf, dsp.pan(note * 0.35, -0.4 + 0.16 * k), dsp.samples(0.2 + 2.0 * beat + k * beat / 3))
    spark = chime(dsp.midi_hz(98), 0.05, rng, brightness=0.5, decay=1.0, attack=0.02, tail=2.0)
    dsp.place(buf, dsp.pan(spark * 0.25, 0.4), dsp.samples(at - 1.4))
    y = dsp.delay(buf, beat * 1.5, 0.28, 0.2, 2600.0, ping_pong=True)
    y = dsp.reverb(y, rng, seconds=3.2, mix=0.36, predelay_ms=25.0, damp=0.55)
    y = dsp.trim_tail(dsp.dc_block(y), -60.0)[:, : dsp.samples(5.6)]
    return dsp.fade(y, 0.002, 1.2)


@sound("mus_sting_defeat", "sting", -22.0, **STING)
def sting_defeat(rng: np.random.Generator) -> np.ndarray:
    beat = 0.62
    buf = np.zeros((2, dsp.samples(7.5)))
    at = 0.3
    for i, (m, beats) in enumerate([(74, 0.5), (69, 1.5), (70, 0.5), (62, 3.5)]):
        v = motif_voice(m, beats, 0.9, rng, beat)
        v = dsp.lowpass(v, 3200.0 - 500.0 * i)
        dsp.place(buf, dsp.pan(v, -0.05 * i), dsp.samples(at))
        at += beats * beat
    for k, m in enumerate([50, 53, 57, 58]):  # D F A Bb: minor with the flat sixth
        p = pad_voice(dsp.midi_hz(m), 4.0, rng, attack=1.2, release=2.0, brightness=2.6)
        dsp.place(buf, p * (0.5 if k == 0 else 0.3), 0)
    low = reed(dsp.midi_hz(38), 2.6, rng, brightness=2.0, attack=0.6, release=1.4, breath=0.03, vibrato_cents=0.0)
    dsp.place(buf, dsp.stereo(0.55 * low), dsp.samples(at - 2.2))
    n = buf.shape[-1]
    closing = 2400.0 * (0.15 + 0.85 * np.exp(-dsp.time_axis(n) / 2.5))
    buf = dsp.sweep(buf, "lp", closing, 0.6, block=256)
    y = dsp.reverb(buf, rng, seconds=3.6, mix=0.4, predelay_ms=30.0, damp=0.65)
    y = dsp.trim_tail(dsp.dc_block(y), -60.0)[:, : dsp.samples(6.0)]
    return dsp.fade(y, 0.002, 1.4)
