"""Emberfall (Phase 8b): the adaptive score.

Kessel Reach is warm and dry in D Lydian at 80 BPM in four; Thalassa cold and
wide in F# Aeolian at 63 BPM in three. Emberfall is hot, heavy and close:
**C# Phrygian** (C# D E F# G# A B: the same seven pitches as the Concord's D
Lydian, so unit replies, the Advisor and the Trail motif never clash with it,
but centred on C# with the flat second D leaning on it), **56 BPM in 4/4**,
slow and weighted, with a low end the other planets do not have: a sub on the
root under every block. One loop is 16 bars, 64 beats, 68.57 s (3 024 000
samples, a multiple of 64 for the native Vorbis encoder).

Chords, four bars each: C#m(add11), Amaj9, Bsus4(add9), Dmaj7(#11); the D
block falls back onto C# at the loop point, the Phrygian cadence (the
Concord's own chord sinking into the planet's).

Timbres: no glass, no marimba, no taiko. A low *forge horn* (bright, saturated
reed pair), *anvils* (short inharmonic metal), *basalt drums* (deep thuds with a
pitch fall, sub and grit), *bowed metal* (inharmonic partials swelling slowly:
heat haze) and dark metal *tines*. Rooms are short and close (1.5-3 s).

The Emberfall motif (pressure): C# up a semitone to D and back, then falling a
fourth to G#; short, short, long, very long: a vent drawing breath and letting
it go.

Layers (all synchronised; the MusicDirector fades them on the beat):

  pad        dark pad chords, bowed metal above, a sub on the root, heat shimmer
  pulse      metal tines in 3+3+2 eighths over a root thud
  melody     the pressure motif and its answers on the forge horn and bowed metal
  drive      tension: muted horn eighths on the root, the flat second on beat 4
  drums      combat: basalt drums, anvil backbeat, a gritty shaker
  brass      combat: forge-horn stabs on root and fifth, the motif as a call
  trail      the Trail motif (D A B G#) on the Antecedent bell, in the gaps
  hush       stealth unaware: low bowed metal far off, a rumble, embers
  watch      stealth suspicious: a low lub-dub on the root, a tick, D as shadow
  melody_b   variation: answers high on bowed metal, ending on G#
  melody_c   variation: the motif augmented low on the horn, an anvil above
  pulse_b    variation: a simmer of anvil sixteenths, accents moving
  drums_b    variation: half time, one huge drum, rolling toms into each block
  urgency    base under attack: muted sixteenths of C# against the D-G#
             tritone, a horn siren rising a fourth G# -> C# every two bars
  heavy      heavy combat: horn in half notes, doubled drums, a grinding sub
  pressure   the vent filling: a throbbing sub, magma bubbles, a hiss band that
             rises every two bars, a beating whine on G#; gain-driven
             (EruptionCues.music_gain_db) by the most pressing vent near the base
  holdout    the last minutes of a Holdout: a steady march, tines in eighths,
             a horn calling root -> fifth (the Concord's D -> A in the D block),
             frame hits on 2 and 4; gain-driven (HoldoutCues)

Re-voiced hits and stings (`<id>_emberfall`): the combat hit (a vent drawing
in, a basalt drum, an anvil, a low horn C#), the aftermath hit (the horn sighs
D -> C#, cooling hiss, an anvil ring), victory (the motif answered upward,
landing on the Concord's Dmaj7: the planet's C# lifts a semitone home) and
defeat (the motif sinking to the low C# under a rumble as the filter closes).

Attacks stay at 8 ms or softer (native Vorbis pre-echo, ADR 0005).
"""

from __future__ import annotations

import numpy as np

from synth import dsp
from synth.instruments import bell, chime, pad_voice, reed, soft_sine

from . import sound
from .music_kessel import _space
from .music_kessel_combat import _soft, frame_hit

H = dsp.midi_hz

BPM = 56.0
BEAT = 60.0 / BPM
BAR_BEATS = 4
BAR = BAR_BEATS * BEAT
BARS = 16
BEATS = BAR_BEATS * BARS
LOOP = BAR * BARS  # 68.57 s
BLOCK_BARS = 4

# (bass, voicing, sub) per four-bar block, C# Phrygian.
CHORDS = [
    (37, [49, 56, 61, 64, 66], 25),  # C#m(add11): C# G# C# E F#, sub C#1
    (33, [45, 52, 56, 59, 61], 33),  # Amaj9: A E G# B C#, sub A1
    (35, [47, 54, 59, 61, 64], 35),  # Bsus4(add9): B F# B C# E, sub B1
    (38, [50, 57, 61, 66, 68], 26),  # Dmaj7(#11): D A C# F# G#, sub D1
]

# The pressure motif: (semitones above the phrase root, beats).
MOTIF = [(0, 0.5), (1, 0.5), (0, 1.0), (-5, 2.0)]

LAYER = dict(fmt="ogg", channels=2, loop=True, folder="music/emberfall", min_seconds=LOOP - 0.01,
             max_seconds=LOOP + 0.01, bpm=BPM, beats=BEATS, bar_beats=BAR_BEATS)


def _n() -> int:
    return dsp.samples(LOOP)


def _chord(bar: int) -> tuple[int, list[int], int]:
    return CHORDS[(bar // BLOCK_BARS) % len(CHORDS)]


def _close(x: np.ndarray, rng: np.random.Generator, n: int, reverb_s: float = 2.2, mix: float = 0.3,
           echo_s: float = 0.0, feedback: float = 0.0, echo_mix: float = 0.0) -> np.ndarray:
    """The Emberfall room: short, close, a little dark (rock walls, hot air)."""
    return _space(x, rng, n, reverb_s=reverb_s, mix=mix, echo_s=echo_s, feedback=feedback, echo_mix=echo_mix)


def _swell(n: int, bars: float, phase: float = 0.0) -> np.ndarray:
    """0..1, one rise and fall every `bars` bars, periodic over the loop."""
    t = dsp.time_axis(n)
    cycles = round(LOOP / (bars * BAR))
    return 0.5 - 0.5 * np.cos(2 * np.pi * cycles * t / LOOP + phase)


# --------------------------------------------------------------------------- voices


def forge_horn(f: float, dur: float, rng: np.random.Generator, bright: float = 5.0, attack: float = 0.06,
               drive: float = 1.3) -> np.ndarray:
    """A low brass horn from the forge: two bright reeds a few cents apart, saturated."""
    a = reed(f, dur, rng, brightness=bright, attack=attack, release=0.25, breath=0.03, vibrato_hz=4.0,
             vibrato_cents=4.0)
    b = reed(f * dsp.cents(-9.0), dur, rng, brightness=bright * 0.8, attack=attack * 1.3, release=0.25,
             breath=0.0, vibrato_hz=3.3, vibrato_cents=4.0)
    return dsp.saturate(dsp.mix(a, 0.7 * b) * drive, 1.2) * 0.7


ANVIL = [(1.0, 1.0, 1.0), (2.76, 0.55, 0.45), (5.40, 0.3, 0.25), (8.93, 0.16, 0.12)]


def anvil(f: float, rng: np.random.Generator, decay: float = 0.35, length: float = 1.0) -> np.ndarray:
    """Struck metal: inharmonic partials dying fast, a click of the hammer."""
    n = dsp.samples(length)
    t = dsp.time_axis(n)
    out = np.zeros(n)
    for ratio, amp, dk in ANVIL:
        fr = f * ratio
        if fr >= dsp.NYQUIST * 0.8:
            continue
        out += amp * np.sin(2 * np.pi * (fr * t + float(rng.random()))) * np.exp(-t / (decay * dk))
    click = 0.25 * dsp.bandpass(dsp.white(n, rng), min(f * 5.0, 9000.0), 1.5) * dsp.perc(n, 0.0005, 0.004)
    return _soft((out + click) * 0.3, 0.008)


def basalt(rng: np.random.Generator, f: float, dur: float = 0.9, grit: float = 0.3) -> np.ndarray:
    """A basalt drum: a deep thud falling in pitch, a sub under it, stone grit on the attack."""
    n = dsp.samples(dur)
    t = dsp.time_axis(n)
    head = dsp.sine(f * (1.0 + 0.6 * np.exp(-t / 0.035)), n) * dsp.perc(n, 0.008, dur * 0.3)
    fs = max(f * 0.5, 40.0)  # never below 40 Hz: weight, not subsonic mud
    sub = 0.5 * dsp.sine(fs * (1.0 + 0.3 * np.exp(-t / 0.05)), n) * dsp.perc(n, 0.01, dur * 0.45)
    stone = dsp.bandpass(dsp.white(n, rng), 900.0, 0.8) * dsp.perc(n, 0.008, 0.03) * grit
    return dsp.saturate(head + sub + stone, 0.8)


def bowed_metal(f: float, dur: float, rng: np.random.Generator, attack: float = 1.2,
                release: float = 2.0) -> np.ndarray:
    """Heat haze: inharmonic metal partials swelling slowly, a slow shimmer."""
    n = dsp.samples(dur + release)
    t = dsp.time_axis(n)
    wob = 1.0 + 0.0015 * np.sin(2 * np.pi * 5.1 * t + float(rng.random()) * 6.28)
    x = np.zeros(n)
    for ratio, amp in [(1.0, 1.0), (2.0, 0.25), (2.76, 0.18), (4.1, 0.06)]:
        x += amp * dsp.sine(f * ratio * wob, n, float(rng.random()))
    x += 0.6 * dsp.sine(f * 1.003, n, float(rng.random()))
    return x * dsp.ar(n, attack, release, max(dur - attack, 0.0)) * 0.3


def tine(f: float, rng: np.random.Generator, decay: float = 0.45) -> np.ndarray:
    """A dark metal tine: a soft FM chime, rolled off, a little saturated."""
    x = chime(f, 0.05, rng, brightness=0.55, decay=decay, attack=0.008, tail=1.0)
    return dsp.saturate(dsp.lowpass(x, 2600.0) * 1.2, 0.6)


def lead(m: int, beats: float, vel: float, rng: np.random.Generator, beat_s: float = BEAT) -> np.ndarray:
    """The lead: the forge horn, softened, with bowed metal holding the note an octave up."""
    dur = beats * beat_s
    horn = forge_horn(H(m), dur * 0.9, rng, bright=3.6, attack=0.05, drive=1.0)
    haze = bowed_metal(H(m + 12), dur * 0.85, rng, attack=min(0.3, dur * 0.4), release=1.2)
    return dsp.mix(0.85 * horn, 0.5 * haze) * vel


def _phrases(rng: np.random.Generator, phrases, voice, extra: float = 6.0) -> np.ndarray:
    buf = np.zeros((2, _n() + dsp.samples(extra)))
    for start, notes, vel, side in phrases:
        at = start
        for m, beats in notes:
            dsp.place(buf, dsp.pan(voice(m, beats, vel, rng), side), dsp.samples(at * BEAT))
            at += beats
    return buf


def _motif(root: int, stretch: float = 1.0) -> list[tuple[int, float]]:
    return [(root + step, beats * stretch) for step, beats in MOTIF]


def _sub(m: int, dur: float, gain: float = 1.0) -> np.ndarray:
    """The low end: a sine on the root a couple of octaves down, with a little second harmonic."""
    return soft_sine(H(m), dur, attack=1.5, release=2.5, harmonics=(1.0, 0.22, 0.05)) * gain


# --------------------------------------------------------------------------- explore


@sound("mus_emberfall_explore_pad", "music", -25.0, **LAYER)
def pad(rng: np.random.Generator) -> np.ndarray:
    n = _n()
    buf = np.zeros((2, n + dsp.samples(8.0)))
    block = BLOCK_BARS * BAR
    for i, (bass, voicing, sub) in enumerate(CHORDS):
        at = dsp.samples(i * block)
        for k, m in enumerate(voicing):
            v = pad_voice(H(m), block, rng, attack=2.6, release=3.5, detune_cents=11.0, brightness=1.8 + 0.25 * k)
            dsp.place(buf, v * (0.7 if k == 0 else 0.42), at)
            if k >= len(voicing) - 2:
                g = bowed_metal(H(m + 12), block * 0.85, rng, attack=2.2, release=3.0)
                dsp.place(buf, dsp.pan(0.35 * g, -0.5 if k % 2 else 0.5), at)
        dsp.place(buf, dsp.stereo(soft_sine(H(bass), block, attack=2.0, release=3.0, harmonics=(1.0, 0.3, 0.1)) * 0.55),
                  at)
        dsp.place(buf, dsp.stereo(_sub(sub, block, 0.6)), at)
    x = dsp.wrap(buf, n)
    haze = _swell(n, 2.0)
    x = dsp.periodic(dsp.sweep, x, "lp", 500.0 + 700.0 * haze, 0.7, block=512) * (0.8 + 0.2 * haze)
    return _close(x, rng, n, reverb_s=3.0, mix=0.35)


PULSE_STEPS = [(0.0, 1.0), (1.5, 0.65), (3.0, 0.8)]  # 3 + 3 + 2 eighths


@sound("mus_emberfall_explore_pulse", "music", -29.0, **LAYER)
def pulse(rng: np.random.Generator) -> np.ndarray:
    n = _n()
    buf = np.zeros((2, n + dsp.samples(2.0)))
    for bar in range(BARS):
        bass, voicing, _sub_note = _chord(bar)
        tones = sorted(voicing)[1:]
        for k, (at, v) in enumerate(PULSE_STEPS):
            m = tones[(bar + 2 * k) % len(tones)]
            note = _soft(tine(H(m), rng)) * v * float(rng.uniform(0.9, 1.0))
            dsp.place(buf, dsp.pan(note, -0.3 if k % 2 else 0.3), dsp.samples((bar * BAR_BEATS + at) * BEAT))
        thud = basalt(rng, H(bass + 12), 0.5, grit=0.1) * 0.35
        dsp.place(buf, dsp.stereo(thud), dsp.samples(bar * BAR))
    x = dsp.periodic(dsp.lowpass, dsp.wrap(buf, n), 2800.0)
    return _close(x, rng, n, reverb_s=2.0, mix=0.28, echo_s=BEAT * 0.75, feedback=0.3, echo_mix=0.22)


PHRASES = [
    (2.0, _motif(61), 1.0, 0.1),                                            # C#4 D4 C#4 G#3, over C#m
    (18.0, [(64, 0.5), (66, 0.5), (64, 1.0), (61, 2.0)], 0.9, -0.1),       # an answer over A
    (34.0, [(66, 0.5), (68, 0.5), (66, 1.0), (59, 3.0)], 0.9, 0.05),       # over Bsus
    (50.0, [(62, 0.5), (61, 0.5), (62, 1.0), (61, 1.0), (56, 3.0)], 0.95, 0.0),  # the flat second, leaning home
]


@sound("mus_emberfall_explore_melody", "music", -27.0, **LAYER)
def melody(rng: np.random.Generator) -> np.ndarray:
    buf = _phrases(rng, PHRASES, lead)
    return _close(buf, rng, _n(), reverb_s=2.6, mix=0.32, echo_s=BEAT * 1.5, feedback=0.3, echo_mix=0.2)


MELODY_B = [
    (4.0, [(73, 1.0), (74, 1.0), (76, 2.0)], 0.85, 0.2),
    (20.0, [(76, 0.5), (73, 0.5), (69, 3.0)], 0.8, -0.15),
    (36.0, [(78, 1.0), (76, 1.0), (73, 2.0)], 0.8, 0.1),
    (52.0, [(74, 1.0), (73, 1.0), (71, 1.0), (68, 4.0)], 0.85, -0.05),  # ends on G#
]


def _metal_voice(m: int, beats: float, vel: float, rng: np.random.Generator) -> np.ndarray:
    dur = beats * BEAT
    haze = bowed_metal(H(m), dur * 0.9, rng, attack=min(0.25, dur * 0.3), release=1.6)
    ring = anvil(H(m), rng, decay=0.5, length=1.2) * 0.4
    return dsp.mix(haze, ring) * vel


@sound("mus_emberfall_explore_melody_b", "music", -27.0, **LAYER)
def melody_b(rng: np.random.Generator) -> np.ndarray:
    buf = _phrases(rng, MELODY_B, _metal_voice)
    return _close(buf, rng, _n(), reverb_s=2.8, mix=0.35, echo_s=BEAT * 0.75, feedback=0.3, echo_mix=0.25)


def _low_voice(m: int, beats: float, vel: float, rng: np.random.Generator) -> np.ndarray:
    dur = beats * BEAT
    low = forge_horn(H(m), dur * 0.95, rng, bright=3.0, attack=0.12, drive=1.0)
    top = anvil(H(m + 24), rng, decay=0.4, length=1.0) * 0.35
    return dsp.mix(0.8 * low, top) * vel


MELODY_C = [(4.0, _motif(49, 2.0), 0.9, -0.15), (36.0, _motif(47, 2.0), 0.85, 0.15)]


@sound("mus_emberfall_explore_melody_c", "music", -27.0, **LAYER)
def melody_c(rng: np.random.Generator) -> np.ndarray:
    buf = _phrases(rng, MELODY_C, _low_voice)
    return _close(buf, rng, _n(), reverb_s=2.6, mix=0.32)


@sound("mus_emberfall_explore_pulse_b", "music", -29.0, **LAYER)
def pulse_b(rng: np.random.Generator) -> np.ndarray:
    """A simmer: anvil sixteenths, very soft, accents moving across the bar."""
    n = _n()
    buf = np.zeros((2, n + dsp.samples(2.0)))
    six = BEAT / 4
    for bar in range(BARS):
        bass, voicing, _sub_note = _chord(bar)
        top = sorted(voicing)[-1] + 12
        accent = (bar * 3) % 16
        for s in range(16):
            v = 0.55 if s == accent or s % 4 == 0 else 0.18
            m = top if s % 2 == 0 else top - 5
            note = anvil(H(m), rng, decay=0.08, length=0.3) * v * float(rng.uniform(0.85, 1.0))
            dsp.place(buf, dsp.pan(note, 0.4 if s % 2 else -0.4), dsp.samples(bar * BAR + s * six))
        thud = basalt(rng, H(bass + 12), 0.5, grit=0.1) * 0.3
        dsp.place(buf, dsp.stereo(thud), dsp.samples(bar * BAR))
    x = dsp.periodic(dsp.lowpass, dsp.wrap(buf, n), 4200.0)
    return _close(x, rng, n, reverb_s=1.8, mix=0.25)


QUOTES = [  # the Trail motif on the Antecedent bell, where the melody rests
    (10.0, [(74, 0.5), (81, 1.5), (83, 0.5), (80, 2.5)], 1.0),
    (26.0, [(74, 0.5), (81, 2.5)], 0.6),
    (42.0, [(71, 0.5), (78, 1.5), (80, 0.5), (76, 2.5)], 0.85),
    (58.0, [(74, 0.5), (81, 1.5), (83, 0.5), (80, 3.0)], 0.8),  # hangs on G#, the planet's fifth
]


@sound("mus_emberfall_explore_trail", "music", -29.0, **LAYER)
def trail(rng: np.random.Generator) -> np.ndarray:
    n = _n()
    buf = np.zeros((2, n + dsp.samples(8.0)))
    for start, notes, vel in QUOTES:
        at = start
        for i, (m, beats) in enumerate(notes):
            b = bell(H(m), rng, decay=0.6 + 0.4 * beats, brightness=0.45, strike=0.15)
            b = _soft(dsp.lowpass(b, 5500.0), 0.01)
            dsp.place(buf, dsp.pan(b * vel * (0.8 if i == 0 else 1.0), -0.3 + 0.2 * i), dsp.samples(at * BEAT))
            at += beats
    x = dsp.wrap(buf, n)
    t = dsp.time_axis(n)
    for k, m in enumerate([61, 68]):  # a faint bell air on C# and G#
        f = round(H(m) * LOOP) / LOOP
        f2 = round((H(m) + 0.3) * LOOP) / LOOP
        swell = 0.5 - 0.5 * np.cos(2 * np.pi * (2 + k) * t / LOOP)
        x += dsp.pan(0.03 * 0.5 * (dsp.sine(f, n) + dsp.sine(f2, n)) * swell, -0.4 + 0.8 * k)
    return _close(x, rng, n, reverb_s=3.0, mix=0.38, echo_s=BEAT * 1.5, feedback=0.25, echo_mix=0.2)


# --------------------------------------------------------------------------- tension and combat


@sound("mus_emberfall_tension_drive", "music", -28.0, **LAYER)
def drive(rng: np.random.Generator) -> np.ndarray:
    n = _n()
    buf = np.zeros((2, n + dsp.samples(2.0)))
    eighth = BEAT / 2
    accents = [1.0, 0.4, 0.6, 0.4, 0.85, 0.45, 0.7, 0.55]
    for bar in range(BARS):
        bass = _chord(bar)[0] + 12
        for s in range(8):
            m = bass + (1 if s == 7 else 0)  # the flat second leans in on the last eighth
            low = soft_sine(H(m), eighth * 0.6, attack=0.012, release=0.12, harmonics=(1.0, 0.45, 0.2))
            body = forge_horn(H(m), eighth * 0.45, rng, bright=2.6, attack=0.012, drive=0.9)
            dsp.place(buf, dsp.stereo(dsp.mix(low, 0.35 * body) * accents[s] * 0.7),
                      dsp.samples(bar * BAR + s * eighth))
        for s in (0, 4):
            dsp.place(buf, dsp.stereo(basalt(rng, H(_chord(bar)[2] + 12), 0.6, grit=0.05) * 0.35),
                      dsp.samples(bar * BAR + s * eighth))
        tick = anvil(H(80), rng, decay=0.05, length=0.2) * 0.25
        for s in (2, 6):
            dsp.place(buf, dsp.pan(tick, 0.45), dsp.samples(bar * BAR + s * eighth))
        if bar % BLOCK_BARS == BLOCK_BARS - 1:  # a vent drawing breath before the next block
            m = dsp.samples(BAR)
            u = dsp.time_axis(m) / BAR
            air = dsp.sweep(dsp.pink(m, rng), "bp", 200.0 * 8.0 ** u, 1.0) * u ** 2 * 0.2
            dsp.place(buf, dsp.stereo(air), dsp.samples(bar * BAR))
    x = dsp.periodic(dsp.lowpass, dsp.wrap(buf, n), 2000.0)
    return _close(x, rng, n, reverb_s=1.8, mix=0.25)


def grit_shake(rng: np.random.Generator, gain: float) -> np.ndarray:
    m = dsp.samples(0.08)
    return dsp.bandpass(dsp.white(m, rng), 4500.0, 0.9) * dsp.perc(m, 0.008, 0.025) * gain


@sound("mus_emberfall_combat_drums", "music", -26.0, **LAYER)
def drums(rng: np.random.Generator) -> np.ndarray:
    n = _n()
    buf = np.zeros((2, n + dsp.samples(2.0)))
    six = BEAT / 4
    for bar in range(BARS):
        at0 = bar * BAR
        fill = bar % BLOCK_BARS == BLOCK_BARS - 1
        for b, f, v, side in [(0.0, 48.0, 1.0, 0.0), (1.5, 62.0, 0.6, 0.25), (2.0, 48.0, 0.85, 0.0),
                              (3.5, 70.0, 0.55, -0.25)]:
            if fill and b >= 2.0:
                continue
            dsp.place(buf, dsp.pan(v * basalt(rng, f, 0.8), side), dsp.samples(at0 + b * BEAT))
        if not fill:
            for b in (1, 3):
                ring = anvil(H(73), rng, decay=0.12, length=0.5) * 0.45
                dsp.place(buf, dsp.pan(ring, -0.2), dsp.samples(at0 + b * BEAT))
                dsp.place(buf, dsp.pan(0.35 * frame_hit(rng), -0.2), dsp.samples(at0 + b * BEAT))
        else:
            for k in range(8):  # falling drums through beats 3 and 4
                f = 130.0 * 0.88 ** k
                dsp.place(buf, dsp.pan((0.45 + 0.06 * k) * basalt(rng, f, 0.45), 0.4 - 0.1 * k),
                          dsp.samples(at0 + 2 * BEAT + k * six))
        for s in range(16):
            dsp.place(buf, dsp.pan(grit_shake(rng, 0.1 if s % 4 == 2 else 0.04), 0.5), dsp.samples(at0 + s * six))
    x = dsp.saturate(dsp.wrap(buf, n) * 1.1, 0.7)
    return _close(x, rng, n, reverb_s=1.6, mix=0.2)


@sound("mus_emberfall_combat_drums_b", "music", -26.0, **LAYER)
def drums_b(rng: np.random.Generator) -> np.ndarray:
    n = _n()
    buf = np.zeros((2, n + dsp.samples(2.0)))
    trip = BEAT / 3
    for bar in range(BARS):
        at0 = bar * BAR
        dsp.place(buf, dsp.stereo(1.15 * basalt(rng, 42.0, 1.4, grit=0.4)), dsp.samples(at0))
        dsp.place(buf, dsp.pan(0.5 * anvil(H(68), rng, decay=0.2, length=0.6), 0.25), dsp.samples(at0 + 2 * BEAT))
        if bar % BLOCK_BARS == BLOCK_BARS - 1:
            for k in range(6):  # rolling toms in triplets into the next block
                dsp.place(buf, dsp.pan(0.4 * basalt(rng, 110.0 - 9.0 * k, 0.35), -0.4 + 0.15 * k),
                          dsp.samples(at0 + 2 * BEAT + k * trip))
        else:
            dsp.place(buf, dsp.pan(0.55 * basalt(rng, 64.0, 0.6), -0.2), dsp.samples(at0 + 3.5 * BEAT))
    x = dsp.saturate(dsp.wrap(buf, n), 0.6)
    return _close(x, rng, n, reverb_s=2.0, mix=0.22)


def _stab(rng: np.random.Generator, m: int, dur: float, bright: float = 5.5) -> np.ndarray:
    return forge_horn(H(m), dur, rng, bright=bright, attack=0.015, drive=1.5)


@sound("mus_emberfall_combat_brass", "music", -27.0, **LAYER)
def brass(rng: np.random.Generator) -> np.ndarray:
    n = _n()
    buf = np.zeros((2, n + dsp.samples(3.0)))
    for bar in range(BARS):
        bass = _chord(bar)[0]
        root = bass + 12
        calling = bar in (4, 5, 12, 13)
        steps = [(0.0, 1.0), (1.5, 0.7), (3.0, 0.85)] if not calling else [(0.0, 1.0)]
        for at, v in steps:
            for k, m in enumerate([root, root + 7, root + 12]):
                note = _stab(rng, m, BEAT * 0.4, 5.0 + 1.5 * k)
                dsp.place(buf, dsp.pan(note * v * (0.75 if k == 0 else 0.5), -0.3 + 0.3 * k),
                          dsp.samples((bar * BAR_BEATS + at) * BEAT))
    for start_bar, root in ((4, 61), (12, 59)):
        at = start_bar * BAR + BEAT
        for m, beats in _motif(root):
            dur = beats * BEAT * 0.8
            dsp.place(buf, dsp.pan(0.85 * _stab(rng, m, dur * 0.95, 4.5), 0.1), dsp.samples(at))
            at += dur
    x = dsp.periodic(dsp.lowpass, dsp.wrap(buf, n), 3400.0)
    return _close(x, rng, n, reverb_s=2.0, mix=0.25)


@sound("mus_emberfall_urgency", "music", -29.0, **LAYER)
def urgency(rng: np.random.Generator) -> np.ndarray:
    n = _n()
    buf = np.zeros((2, n + dsp.samples(3.0)))
    six = BEAT / 4
    for bar in range(BARS):
        at0 = bar * BAR
        for s in range(16):
            m = 61 if s % 4 else (62 if s % 8 == 0 else 68)  # C#, the D-G# tritone on the beats
            note = _soft(tine(H(m + 12), rng, 0.06)) * (0.5 if s % 4 == 0 else 0.28)
            dsp.place(buf, dsp.pan(note, 0.3 if s % 2 else -0.3), dsp.samples(at0 + s * six))
        if bar % 2 == 0:  # the siren: a horn rising a fourth, G# -> C#
            m = dsp.samples(2 * BAR)
            u = np.clip(dsp.time_axis(m) / (BAR * 0.9), 0.0, 1.0)
            f = H(56) * 2.0 ** (5.0 * (u * u * (3 - 2 * u)) / 12.0)
            siren = forge_horn(f, 2 * BAR * 0.85, rng, bright=4.0, attack=0.3, drive=1.0)
            dsp.place(buf, dsp.pan(0.3 * siren, 0.15), dsp.samples(at0 + BEAT))
    x = dsp.periodic(dsp.lowpass, dsp.wrap(buf, n), 4800.0)
    return _close(x, rng, n, reverb_s=1.6, mix=0.2)


@sound("mus_emberfall_heavy", "music", -27.0, **LAYER)
def heavy(rng: np.random.Generator) -> np.ndarray:
    n = _n()
    buf = np.zeros((2, n + dsp.samples(3.0)))
    for bar in range(BARS):
        at0 = bar * BAR
        root, _voicing, sub = _chord(bar)
        for half in range(2):
            m = root + (0 if half == 0 else 7)
            dur = 2 * BEAT * 0.92
            dsp.place(buf, dsp.stereo(0.45 * forge_horn(H(m), dur, rng, bright=6.0, attack=0.04, drive=1.6)
                                      + 0.25 * forge_horn(H(m + 12), dur, rng, bright=5.0, attack=0.04)),
                      dsp.samples(at0 + half * 2 * BEAT))
        for b in range(4):
            v = 0.85 if b % 2 == 0 else 0.55
            dsp.place(buf, dsp.pan(v * basalt(rng, 56.0, 0.5), -0.2), dsp.samples(at0 + b * BEAT))
        k = dsp.samples(BAR * 0.6)
        tt = dsp.time_axis(k)
        grind = dsp.sine(H(sub + 12) * (1 + 0.02 * np.sin(2 * np.pi * 7 * tt)), k) * dsp.perc(k, 0.01, 0.6)
        dsp.place(buf, dsp.stereo(0.45 * dsp.saturate(grind, 1.5)), dsp.samples(at0))
    x = dsp.periodic(dsp.lowpass, dsp.wrap(buf, n), 3000.0)
    return _close(x, rng, n, reverb_s=1.8, mix=0.2)


# --------------------------------------------------------------------------- stealth


@sound("mus_emberfall_stealth_hush", "music", -31.0, **LAYER)
def hush(rng: np.random.Generator) -> np.ndarray:
    n = _n()
    buf = np.zeros((2, n + dsp.samples(6.0)))
    block = BLOCK_BARS * BAR
    for i, (bass, voicing, sub) in enumerate(CHORDS):
        for k, m in enumerate(sorted(voicing)[1:3]):
            g = bowed_metal(H(m), block * 0.7, rng, attack=3.5, release=3.5)
            dsp.place(buf, dsp.pan(0.3 * g, -0.6 + 1.2 * k), dsp.samples(i * block + BAR * k))
        dsp.place(buf, dsp.stereo(_sub(sub + 12, block, 0.25)), dsp.samples(i * block))
    for bar in range(1, BARS, 3):  # an ember now and then
        m = sorted(_chord(bar)[1])[-1] + 12
        ember = anvil(H(m), rng, decay=0.25, length=0.8) * 0.2
        dsp.place(buf, dsp.pan(ember, 0.35 if bar % 2 else -0.35), dsp.samples(bar * BAR + 1.5 * BEAT))
    x = dsp.wrap(buf, n)
    rumble = dsp.periodic(dsp.lowpass, np.stack([dsp.brown(n, rng) for _ in range(2)]), 140.0)
    x = x + 0.035 * rumble * (0.6 + 0.4 * _swell(n, 4.0))
    # A faint hot air over it, so the layer is never only a smooth low hum.
    air = dsp.periodic(dsp.bandpass, np.stack([dsp.pink(n, rng) for _ in range(2)]), 2200.0, 0.7)
    x = x + 0.01 * air * (0.6 + 0.4 * _swell(n, 2.0))
    return _close(x, rng, n, reverb_s=3.2, mix=0.4)


@sound("mus_emberfall_stealth_watch", "music", -29.0, **LAYER)
def watch(rng: np.random.Generator) -> np.ndarray:
    n = _n()
    buf = np.zeros((2, n + dsp.samples(2.0)))
    for bar in range(BARS):
        bass = _chord(bar)[0] + 12
        for beat in (0, 2):
            for offset, gain in ((0.0, 1.0), (0.25, 0.55)):  # lub-dub on beats 1 and 3
                note = soft_sine(H(bass), 0.14, attack=0.01, release=0.2, harmonics=(1.0, 0.4, 0.12))
                dsp.place(buf, dsp.stereo(0.5 * gain * note), dsp.samples(bar * BAR + (beat + offset) * BEAT))
        for s in range(4):
            m = dsp.samples(0.07)
            tk = dsp.bandpass(dsp.white(m, rng), 3800.0, 2.5) * dsp.perc(m, 0.008, 0.012)
            dsp.place(buf, dsp.pan(0.2 * tk, 0.4), dsp.samples(bar * BAR + (s + 0.5) * BEAT))
        if bar % 2 == 1:  # D over C#: the flat second as a shadow
            shadow = soft_sine(H(62), BEAT * 1.4, attack=0.04, release=0.3, harmonics=(1.0, 0.2))
            dsp.place(buf, dsp.pan(0.15 * shadow, -0.3), dsp.samples(bar * BAR + 3 * BEAT))
    x = dsp.periodic(dsp.lowpass, dsp.wrap(buf, n), 5000.0)
    # A faint hot air under the pulse, so the layer is never digital silence.
    air = dsp.periodic(dsp.bandpass, np.stack([dsp.pink(n, rng) for _ in range(2)]), 700.0, 0.7)
    x = x + 0.012 * air * (0.6 + 0.4 * _swell(n, 2.0))
    return _close(x, rng, n, reverb_s=1.8, mix=0.22)


# --------------------------------------------------------------------------- planet rule and Holdout


@sound("mus_emberfall_pressure", "music", -29.0, **LAYER)
def pressure(rng: np.random.Generator) -> np.ndarray:
    """The vent filling: a throbbing sub on the root (eighths), magma bubbles
    rising in pitch, a hiss band that climbs and breaks every two bars, a
    beating whine on G# high above."""
    n = _n()
    buf = np.zeros((2, n + dsp.samples(2.0)))
    eighth = BEAT / 2
    for bar in range(BARS):
        bass, _voicing, sub = _chord(bar)
        for s in range(8):
            g = 1.0 if s % 2 == 0 else 0.6
            throb = soft_sine(H(sub + 12), eighth * 0.7, attack=0.012, release=0.15, harmonics=(1.0, 0.5, 0.25))
            dsp.place(buf, dsp.stereo(0.5 * g * throb), dsp.samples(bar * BAR + s * eighth))
        for k in range(int(rng.integers(3, 6))):  # magma bubbles
            m = dsp.samples(0.18)
            tt = dsp.time_axis(m)
            f0 = float(rng.uniform(90, 170))
            blob = dsp.sine(f0 * (1 + 1.4 * tt / 0.18), m) * dsp.ar(m, 0.01, 0.1, 0.05)
            dsp.place(buf, dsp.pan(0.3 * blob, float(rng.uniform(-0.7, 0.7))),
                      dsp.samples(bar * BAR + float(rng.uniform(0.0, BAR - 0.3))))
    x = dsp.wrap(buf, n)
    rise = _swell(n, 2.0, -np.pi / 2)  # climbs, then breaks at the bar line
    hiss = np.stack([dsp.pink(n, rng) for _ in range(2)])
    hiss = dsp.periodic(dsp.sweep, hiss, "bp", 400.0 + 2600.0 * rise, 0.8, block=256) * rise ** 2 * 0.1
    fw = round(H(80) * LOOP) / LOOP
    fw2 = round((H(80) + 3.0) * LOOP) / LOOP
    whine = 0.02 * (dsp.sine(fw, n) + dsp.sine(fw2, n)) * (0.3 + 0.7 * rise)
    x = x + hiss + dsp.stereo(whine)
    x = dsp.periodic(dsp.lowpass, x, 5000.0)
    return _close(x, rng, n, reverb_s=1.6, mix=0.2)


HOLDOUT_CALLS = {0: (61, 68), 1: (57, 64), 2: (59, 66), 3: (62, 69)}  # root -> fifth per block


@sound("mus_emberfall_holdout", "music", -28.0, **LAYER)
def holdout(rng: np.random.Generator) -> np.ndarray:
    """Hold the line: a steady march, tines in eighths, frame hits on 2 and 4,
    and a horn calling root -> fifth at each block (the Concord's D -> A in the
    D block): someone is coming."""
    n = _n()
    buf = np.zeros((2, n + dsp.samples(3.0)))
    eighth = BEAT / 2
    for bar in range(BARS):
        at0 = bar * BAR
        bass, voicing, _sub_note = _chord(bar)
        top = sorted(voicing)[-2] + 12
        for s in range(8):
            v = 0.5 if s % 2 == 0 else 0.3
            dsp.place(buf, dsp.pan(_soft(tine(H(top), rng, 0.15)) * v, 0.35), dsp.samples(at0 + s * eighth))
        for b in (1, 3):
            dsp.place(buf, dsp.pan(0.45 * frame_hit(rng), -0.25), dsp.samples(at0 + b * BEAT))
        dsp.place(buf, dsp.stereo(0.55 * basalt(rng, H(bass + 12), 0.5, grit=0.1)), dsp.samples(at0))
        if bar % BLOCK_BARS == 0:
            lo, hi = HOLDOUT_CALLS[bar // BLOCK_BARS]
            dsp.place(buf, dsp.pan(0.5 * forge_horn(H(lo + 12), BEAT * 0.9, rng, bright=4.5, attack=0.03, drive=1.0),
                                   -0.1), dsp.samples(at0 + BEAT))
            dsp.place(buf, dsp.pan(0.55 * forge_horn(H(hi + 12), BEAT * 2.6, rng, bright=4.5, attack=0.05, drive=1.0),
                                   0.1), dsp.samples(at0 + 2 * BEAT))
    x = dsp.periodic(dsp.lowpass, dsp.wrap(buf, n), 4500.0)
    return _close(x, rng, n, reverb_s=2.2, mix=0.26)


# --------------------------------------------------------------------------- hits and stings


STING = dict(fmt="ogg", channels=2, folder="music/stings")


@sound("mus_hit_combat_emberfall", "sting", -24.0, min_seconds=1.5, max_seconds=3.6, **STING)
def hit_combat(rng: np.random.Generator) -> np.ndarray:
    buf = np.zeros((2, dsp.samples(4.0)))
    m = dsp.samples(1.0)
    u = dsp.time_axis(m) / 1.0
    drawn = dsp.sweep(dsp.pink(m, rng), "bp", 180.0 * 10.0 ** u, 0.9) * u ** 2.5 * 0.5  # a vent drawing in
    dsp.place(buf, dsp.stereo(drawn), 0)
    down = 1.0
    dsp.place(buf, dsp.stereo(1.25 * basalt(rng, 44.0, 1.4, grit=0.45)), dsp.samples(down))
    dsp.place(buf, dsp.pan(0.6 * anvil(H(73), rng, decay=0.5, length=1.5), 0.2), dsp.samples(down))
    horn = forge_horn(H(37), 1.6, rng, bright=6.0, attack=0.02, drive=1.6)
    horn2 = forge_horn(H(49), 1.6, rng, bright=5.0, attack=0.02, drive=1.3)
    dsp.place(buf, dsp.stereo(0.45 * horn + 0.3 * horn2), dsp.samples(down))
    y = dsp.reverb(buf, rng, seconds=2.2, mix=0.28, predelay_ms=15.0, damp=0.6)
    y = dsp.trim_tail(dsp.dc_block(dsp.highpass(y, 30.0)), -60.0)[:, : dsp.samples(3.4)]
    return dsp.fade(y, 0.01, 0.8)


@sound("mus_hit_aftermath_emberfall", "sting", -25.0, min_seconds=2.5, max_seconds=5.6, **STING)
def hit_aftermath(rng: np.random.Generator) -> np.ndarray:
    buf = np.zeros((2, dsp.samples(6.0)))
    at = 0.1
    for m, beats in [(62, 1.0), (61, 3.0)]:  # D -> C#: the Phrygian sigh
        dur = beats * BEAT
        dsp.place(buf, dsp.pan(0.5 * forge_horn(H(m), dur * 0.95, rng, bright=2.6, attack=0.1, drive=0.9), -0.1),
                  dsp.samples(at))
        at += dur
    k = dsp.samples(3.5)
    cool = dsp.bandpass(dsp.white(k, rng), 5200.0, 0.8) * dsp.env([(0, 0), (0.4, 1.0), (3.5, 0)], k, 1.5) * 0.08
    dsp.place(buf, dsp.pan(cool, 0.4), dsp.samples(0.6))
    dsp.place(buf, dsp.pan(0.4 * anvil(H(80), rng, decay=1.2, length=2.6), 0.3), dsp.samples(at - 2.2))
    y = dsp.reverb(buf, rng, seconds=3.0, mix=0.36, predelay_ms=20.0, damp=0.6)
    y = dsp.trim_tail(dsp.dc_block(dsp.highpass(y, 30.0)), -60.0)[:, : dsp.samples(5.4)]
    return dsp.fade(y, 0.01, 1.2)


ENDING = dict(STING, min_seconds=3.0, max_seconds=6.5)


@sound("mus_sting_victory_emberfall", "sting", -22.0, **ENDING)
def sting_victory(rng: np.random.Generator) -> np.ndarray:
    """The motif answered upward, C# D C# then up to E and the high D: the
    planet's C# lifts a semitone into the Concord's Dmaj7."""
    beat = 0.42
    buf = np.zeros((2, dsp.samples(7.0)))
    at = 0.2
    for i, (m, beats) in enumerate([(61, 0.5), (62, 0.5), (61, 1.0), (64, 1.0), (74, 4.0)]):
        dsp.place(buf, dsp.pan(lead(m, beats, 0.85 if i < 4 else 1.0, rng, beat), 0.05 * (i - 2)), dsp.samples(at))
        at += beats * beat
    for k, m in enumerate([37, 49, 56, 61, 64]):  # C#m under the motif
        p = pad_voice(H(m), 1.3, rng, attack=0.4, release=0.8, brightness=2.6)
        dsp.place(buf, p * (0.45 if k == 0 else 0.28), 0)
    lift = 0.2 + 3.0 * beat
    for k, m in enumerate([38, 50, 57, 61, 66, 69]):  # Dmaj7: home for the Concord
        p = pad_voice(H(m), 2.8, rng, attack=0.35, release=2.0, brightness=3.4)
        dsp.place(buf, p * (0.45 if k == 0 else 0.28), dsp.samples(lift))
    dsp.place(buf, dsp.stereo(1.0 * basalt(rng, 46.0, 1.2, grit=0.3)), dsp.samples(lift))
    for k, m in enumerate([74, 78, 81, 85, 86]):
        note = _soft(tine(H(m), rng, 0.6)) * 0.35
        dsp.place(buf, dsp.pan(note, -0.4 + 0.2 * k), dsp.samples(lift + 0.1 + k * beat / 3))
    y = dsp.reverb(buf, rng, seconds=3.2, mix=0.35, predelay_ms=20.0, damp=0.55)
    y = dsp.trim_tail(dsp.dc_block(dsp.highpass(y, 30.0)), -60.0)[:, : dsp.samples(5.8)]
    return dsp.fade(y, 0.002, 1.2)


@sound("mus_sting_defeat_emberfall", "sting", -22.0, **ENDING)
def sting_defeat(rng: np.random.Generator) -> np.ndarray:
    """The motif sinking: C# D C# G#, then down to the low C#, a rumble rising
    under it as the filter closes."""
    beat = 0.6
    buf = np.zeros((2, dsp.samples(7.5)))
    at = 0.3
    for i, (m, beats) in enumerate([(61, 0.5), (62, 0.5), (61, 1.0), (56, 1.5), (49, 3.0)]):
        v = dsp.lowpass(lead(m, beats, 0.9, rng, beat), 2800.0 - 400.0 * i)
        dsp.place(buf, dsp.pan(v, -0.05 * i), dsp.samples(at))
        at += beats * beat
    for k, m in enumerate([37, 49, 56, 62]):  # C# with the flat second on top
        p = pad_voice(H(m), 4.5, rng, attack=1.0, release=2.0, brightness=2.0)
        dsp.place(buf, p * (0.45 if k == 0 else 0.25), 0)
    k = dsp.samples(6.5)
    rumble = dsp.lowpass(dsp.brown(k, rng), 110.0) * dsp.env([(0, 0), (3.0, 1.0), (6.5, 0)], k, 1.0) * 0.6
    dsp.place(buf, dsp.stereo(rumble), dsp.samples(0.3))
    n = buf.shape[-1]
    closing = 2000.0 * (0.15 + 0.85 * np.exp(-dsp.time_axis(n) / 2.6))
    buf = dsp.sweep(buf, "lp", closing, 0.6, block=256)
    y = dsp.reverb(buf, rng, seconds=3.5, mix=0.4, predelay_ms=25.0, damp=0.65)
    y = dsp.trim_tail(dsp.dc_block(dsp.highpass(y, 30.0)), -60.0)[:, : dsp.samples(6.2)]
    return dsp.fade(y, 0.002, 1.4)
