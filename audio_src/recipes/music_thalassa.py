"""Thalassa Low (Phase 8a): the adaptive score.

Kessel Reach is warm, dry and in D Lydian at 80 BPM in four. Thalassa is cold,
wet and wide: **F# Aeolian** (F# G# A B C# D E: the same seven pitches as the
Concord's D Lydian, so unit replies and the Advisor never clash with it, but
centred on F# minor), **63 BPM in 3/4**, so the music sways like a swell
rather than walks. One loop is 24 bars, 72 beats, 68.57 s (3 024 000 samples,
a multiple of 64 for the native Vorbis encoder).

Chords, six bars each: F#m(add9), Dmaj9(#11) (the Lydian chord of the Concord,
heard here as the flat sixth), Bm9, C#m7(add11), which leans back to F#m and
never quite resolves.

Timbres: no marimba and no taiko. A cold *glass* voice (sine partials with a
slow beating pair), a hollow *flute* (soft sine with breath), water *plucks*
(soft FM chime, dark, long ping-pong echo), a bowed low reed, and hull drums
(long, low, with a splash of noise) instead of the Kessel taiko.

The Thalassa motif (the tide): F# up a minor sixth to D, a step down to C#,
falling to A; long, long, short, very long, over two bars: a wave that rises,
breaks and draws back.

Layers (all synchronised; the MusicDirector fades them on the beat):

  pad        glass and pad chords, a swell every two bars, a low F# floor
  pulse      water plucks on beats 1, 2+ and 3 with a dotted echo
  melody     the tide motif and its answers on the glass-and-flute voice
  drive      tension: a slow low heartbeat on the root, a muffled tick, swells
  drums      combat: hull drums in three, a splash backbeat, a shaker in triplets
  brass      combat: bowed-reed stabs on root and fifth, the motif as a call
  trail      the Trail motif (D A B G#) on the Antecedent bell, in the gaps
  hush       stealth unaware: high cold glass on two chord tones, a far F#
  watch      stealth suspicious: a low two-stroke pulse, a tick, the flat sixth
  melody_b   variation: other phrases on the flute, ending on the hanging B
  melody_c   variation: the motif augmented on a low bowed reed with glass above
  pulse_b    variation: plucks in a hemiola (two against three)
  drums_b    variation of the drums: half time, rolling toms
  urgency    base under attack: muted fast F# repeated against the D-G# tritone,
             a reed siren rising a fourth every two bars
  heavy      heavy combat: bowed reed in dotted halves, drums on every beat, sub
  tide       the sea coming in: a rolling low arpeggio in triplets that swells
             like a wave every two bars, surf noise in the same breath; its gain
             follows the water level (TideCues.music_gain_db)

Re-voiced hits and stings, picked over the generic ones by the score id suffix
(`<id>_thalassa_low`): the combat hit (a wave drawn in, two hull drums, a low
reed F#), the aftermath hit (the reed falls C# A F#, a glass bell), and the
victory and defeat stings (the tide motif answered up to the high F#, or sinking
under a closing filter).

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

BPM = 63.0
BEAT = 60.0 / BPM
BAR_BEATS = 3
BAR = BAR_BEATS * BEAT
BARS = 24
BEATS = BAR_BEATS * BARS
LOOP = BAR * BARS  # 68.57 s
BLOCK_BARS = 6

# (bass, voicing) per six-bar block, F# Aeolian.
CHORDS = [
    (42, [54, 61, 64, 68, 73]),  # F#m(add9): F# C# E G# C#
    (38, [50, 57, 61, 64, 68]),  # Dmaj9(#11): D A C# E G#
    (35, [47, 54, 57, 61, 62]),  # Bm9: B F# A C# D
    (37, [49, 56, 59, 64, 66]),  # C#m7(add11): C# G# B E F#
]

# The tide motif: (semitones above the phrase root, beats).
MOTIF = [(0, 1.0), (8, 1.5), (7, 0.5), (3, 3.0)]

LAYER = dict(fmt="ogg", channels=2, loop=True, folder="music/thalassa", min_seconds=LOOP - 0.01,
             max_seconds=LOOP + 0.01, bpm=BPM, beats=BEATS, bar_beats=BAR_BEATS)


def _n() -> int:
    return dsp.samples(LOOP)


def _chord(bar: int) -> tuple[int, list[int]]:
    return CHORDS[(bar // BLOCK_BARS) % len(CHORDS)]


def _wet(x: np.ndarray, rng: np.random.Generator, n: int, reverb_s: float = 5.5, mix: float = 0.45,
         echo_s: float = 0.0, feedback: float = 0.0, echo_mix: float = 0.0) -> np.ndarray:
    """The Thalassa room: longer and darker than Kessel's open basin."""
    return _space(x, rng, n, reverb_s=reverb_s, mix=mix, echo_s=echo_s, feedback=feedback, echo_mix=echo_mix)


# --------------------------------------------------------------------------- voices


def glass(f: float, dur: float, rng: np.random.Generator, attack: float = 0.25, release: float = 1.5,
          beat_hz: float = 0.7) -> np.ndarray:
    """Cold glass: a sine and its slowly beating twin, soft octave and twelfth,
    a faint struck edge."""
    n = dsp.samples(dur + release)
    body = dsp.sine(f, n, float(rng.random())) + 0.8 * dsp.sine(f + beat_hz, n, float(rng.random()))
    body += 0.18 * dsp.sine(2.0 * f * dsp.cents(3.0), n) + 0.06 * dsp.sine(3.0 * f, n)
    x = body * dsp.ar(n, attack, release, max(dur - attack, 0.0)) * 0.35
    edge = chime(f * 2.0, 0.02, rng, brightness=0.3, decay=0.25, attack=0.01, tail=0.5)
    out = np.zeros(max(n, len(edge)))
    out[:n] += x
    out[: len(edge)] += 0.12 * edge
    return out


def flute(f: float, dur: float, rng: np.random.Generator, vel: float = 1.0) -> np.ndarray:
    """Hollow flute: soft sine with a little second harmonic, breath noise, slow vibrato."""
    n = dsp.samples(dur + 0.6)
    t = dsp.time_axis(n)
    vib = 1.0 + (dsp.cents(10.0) - 1.0) * np.clip(t / 0.6, 0, 1) * np.sin(2 * np.pi * 4.2 * t)
    tone = dsp.wavetable(f * vib, n, lambda k: {1: 1.0, 2: 0.12, 3: 0.05}.get(k, 0.0))
    breath = 0.1 * dsp.bandpass(dsp.white(n, rng), f * 2.0, 1.2)
    e = dsp.ar(n, 0.08, 0.5, max(dur - 0.08, 0.0))
    return (tone + breath) * e * 0.5 * vel


def tide_voice(m: int, beats: float, vel: float, rng: np.random.Generator, beat_s: float = BEAT) -> np.ndarray:
    """The lead: glass struck softly, doubled by the flute that holds the note."""
    dur = beats * beat_s
    g = glass(H(m), dur * 0.8, rng, attack=0.02, release=1.8)
    fl = flute(H(m), dur * 0.92, rng)
    return dsp.mix(0.9 * g, 0.6 * fl) * vel


def pluck(f: float, rng: np.random.Generator, decay: float = 0.7, tail: float = 1.6) -> np.ndarray:
    """A water pluck: a dark, soft chime with a little downward drip in pitch."""
    x = chime(f, 0.05, rng, brightness=0.35, decay=decay, attack=0.008, tail=tail)
    return dsp.lowpass(x, 3600.0)


def bowed(f: float, dur: float, rng: np.random.Generator, bright: float = 3.0) -> np.ndarray:
    """A low bowed reed: slow attack, little breath, slow vibrato."""
    return reed(f, dur, rng, brightness=bright, attack=0.18, release=0.6, breath=0.02,
                vibrato_hz=3.8, vibrato_cents=7.0)


def hull(rng: np.random.Generator, f: float, dur: float = 0.8) -> np.ndarray:
    """A hull drum: a long low thud with a short pitch fall and a splash of noise."""
    n = dsp.samples(dur)
    t = dsp.time_axis(n)
    head = dsp.sine(f * (1.0 + 0.35 * np.exp(-t / 0.04)), n) * dsp.perc(n, 0.008, dur * 0.35)
    splash = dsp.bandpass(dsp.white(n, rng), 1800.0, 0.6) * dsp.perc(n, 0.008, 0.07) * 0.25
    return head + splash


def splash(rng: np.random.Generator, dur: float = 0.35) -> np.ndarray:
    """A backbeat of water: a short swept noise burst."""
    n = dsp.samples(dur)
    u = dsp.time_axis(n) / dur
    x = dsp.sweep(dsp.white(n, rng), "bp", 2600.0 * (1.0 - 0.5 * u), 0.9, block=64)
    return dsp.mix(x * dsp.perc(n, 0.008, 0.06) * 0.6, 0.3 * frame_hit(rng))


def _phrases(rng: np.random.Generator, phrases, voice, extra: float = 6.0) -> np.ndarray:
    buf = np.zeros((2, _n() + dsp.samples(extra)))
    for start, notes, vel, side in phrases:
        at = start
        for m, beats in notes:
            dsp.place(buf, dsp.pan(voice(m, beats, vel, rng), side), dsp.samples(at * BEAT))
            at += beats
    return buf


def _swell(n: int, bars: float, phase: float = 0.0) -> np.ndarray:
    """0..1, one rise and fall every `bars` bars, periodic over the loop."""
    t = dsp.time_axis(n)
    cycles = round(LOOP / (bars * BAR))
    return 0.5 - 0.5 * np.cos(2 * np.pi * cycles * t / LOOP + phase)


# --------------------------------------------------------------------------- explore


@sound("mus_thalassa_explore_pad", "music", -25.0, **LAYER)
def pad(rng: np.random.Generator) -> np.ndarray:
    n = _n()
    buf = np.zeros((2, n + dsp.samples(10.0)))
    block = BLOCK_BARS * BAR
    for i, (bass, voicing) in enumerate(CHORDS):
        at = dsp.samples(i * block)
        for k, m in enumerate(voicing):
            v = pad_voice(H(m), block, rng, attack=3.2, release=4.5, detune_cents=9.0, brightness=2.2 + 0.3 * k)
            dsp.place(buf, v * (0.7 if k == 0 else 0.45), at)
            if k >= len(voicing) - 2:
                g = glass(H(m + 12), block * 0.9, rng, attack=2.5, release=4.0, beat_hz=0.4 + 0.2 * k)
                dsp.place(buf, dsp.pan(0.35 * g, -0.6 if k % 2 else 0.6), at)
        low = soft_sine(H(bass), block, attack=2.5, release=4.0, harmonics=(1.0, 0.3, 0.1))
        dsp.place(buf, dsp.stereo(low * 0.75), at)
    x = dsp.wrap(buf, n)
    wave = _swell(n, 2.0)
    cutoff = 700.0 + 900.0 * wave
    x = dsp.periodic(dsp.sweep, x, "lp", cutoff, 0.6, block=512) * (0.75 + 0.25 * wave)
    return _wet(x, rng, n, reverb_s=6.0, mix=0.45)


PLUCK_STEPS = [(0.0, 1.0), (1.5, 0.6), (2.0, 0.75)]


@sound("mus_thalassa_explore_pulse", "music", -29.0, **LAYER)
def pulse(rng: np.random.Generator) -> np.ndarray:
    n = _n()
    buf = np.zeros((2, n + dsp.samples(3.0)))
    for bar in range(BARS):
        bass, voicing = _chord(bar)
        tones = sorted(m + 12 for m in voicing)
        breath = bar % BLOCK_BARS == BLOCK_BARS - 1
        for k, (at, v) in enumerate(PLUCK_STEPS):
            if breath and k == 2:
                continue  # breathe at the end of each block
            m = tones[(bar + 2 * k) % len(tones)]
            # The pluck before a breath rings on through the rest, so the block (and the loop,
            # which ends on one) fades into the next downbeat rather than dropping to silence.
            ring = breath and k == 1
            x = pluck(H(m), rng, 1.4, 3.0) if ring else pluck(H(m), rng)
            note = _soft(x) * v * float(rng.uniform(0.9, 1.0))
            dsp.place(buf, dsp.pan(note, -0.35 if k % 2 else 0.35), dsp.samples((bar * BAR_BEATS + at) * BEAT))
        heart = soft_sine(H(bass + 12), 0.3, attack=0.02, release=0.5, harmonics=(1.0, 0.1))
        dsp.place(buf, dsp.stereo(heart * 0.4), dsp.samples(bar * BAR))
    x = dsp.periodic(dsp.lowpass, dsp.wrap(buf, n), 3000.0)
    return _wet(x, rng, n, reverb_s=3.5, mix=0.35, echo_s=BEAT * 0.75, feedback=0.4, echo_mix=0.35)


def _motif(root: int) -> list[tuple[int, float]]:
    return [(root + step, beats) for step, beats in MOTIF]


PHRASES = [
    (3.0, _motif(78), 1.0, 0.1),                                     # F#5 D6 C#6 A5, over F#m
    (21.0, [(76, 1.0), (81, 1.5), (80, 0.5), (78, 3.0)], 0.9, -0.1),  # an answer over D
    (31.5, [(85, 0.5), (83, 2.5)], 0.45, 0.35),                       # far echo
    (39.0, [(74, 1.0), (81, 1.5), (80, 0.5), (76, 3.0)], 0.85, 0.0),  # over Bm
    (57.0, [(73, 1.0), (80, 1.5), (78, 0.5), (73, 1.0), (78, 3.0)], 0.9, 0.1),  # leans home
]


@sound("mus_thalassa_explore_melody", "music", -27.0, **LAYER)
def melody(rng: np.random.Generator) -> np.ndarray:
    buf = _phrases(rng, PHRASES, tide_voice)
    return _wet(buf, rng, _n(), reverb_s=5.0, mix=0.45, echo_s=BEAT * 1.5, feedback=0.4, echo_mix=0.3)


MELODY_B = [
    (6.0, [(81, 1.0), (80, 0.5), (78, 0.5), (76, 4.0)], 0.9, 0.2),
    (24.0, [(78, 1.0), (85, 2.0), (83, 3.0)], 0.85, -0.15),
    (42.0, [(74, 0.5), (76, 0.5), (78, 2.0), (81, 3.0)], 0.85, 0.1),
    (60.0, [(80, 1.0), (78, 1.0), (76, 1.0), (71, 3.0)], 0.8, -0.05),  # hangs on B
]


def _flute_voice(m: int, beats: float, vel: float, rng: np.random.Generator) -> np.ndarray:
    return flute(H(m), beats * BEAT * 0.95, rng, vel)


@sound("mus_thalassa_explore_melody_b", "music", -27.0, **LAYER)
def melody_b(rng: np.random.Generator) -> np.ndarray:
    buf = _phrases(rng, MELODY_B, _flute_voice)
    return _wet(buf, rng, _n(), reverb_s=5.0, mix=0.42, echo_s=BEAT * 0.75, feedback=0.35, echo_mix=0.28)


def _low_voice(m: int, beats: float, vel: float, rng: np.random.Generator) -> np.ndarray:
    dur = beats * BEAT
    low = bowed(H(m), dur * 0.95, rng, bright=2.6)
    top = glass(H(m + 24), dur * 0.7, rng, attack=0.4, release=2.0)
    return dsp.mix(0.7 * low, 0.25 * top) * vel


MELODY_C = [(6.0, _motif(54), 0.9, -0.15), (42.0, _motif(50), 0.85, 0.15)]
MELODY_C = [(s, [(m, b * 1.5) for m, b in notes], v, side) for s, notes, v, side in MELODY_C]


@sound("mus_thalassa_explore_melody_c", "music", -27.0, **LAYER)
def melody_c(rng: np.random.Generator) -> np.ndarray:
    buf = _phrases(rng, MELODY_C, _low_voice)
    return _wet(buf, rng, _n(), reverb_s=5.5, mix=0.45)


@sound("mus_thalassa_explore_pulse_b", "music", -29.0, **LAYER)
def pulse_b(rng: np.random.Generator) -> np.ndarray:
    """Two against three: plucks on every dotted quarter, across the bar."""
    n = _n()
    buf = np.zeros((2, n + dsp.samples(3.0)))
    for bar in range(BARS):
        bass, voicing = _chord(bar)
        tones = sorted(voicing)[1:]
        for k, at in enumerate((0.0, 1.5)):
            m = tones[(bar * 2 + k) % len(tones)] + 12
            v = (1.0 if k == 0 else 0.7) * float(rng.uniform(0.9, 1.0))
            dsp.place(buf, dsp.pan(_soft(pluck(H(m), rng, 0.5)) * v, 0.4 if k else -0.4),
                      dsp.samples((bar * BAR_BEATS + at) * BEAT))
            if bar % 2 == 1:
                hi = _soft(pluck(H(m + 12), rng, 0.3)) * 0.3
                dsp.place(buf, dsp.pan(hi, 0.6 if k else -0.6), dsp.samples((bar * BAR_BEATS + at + 0.75) * BEAT))
        heart = soft_sine(H(bass + 12), 0.3, attack=0.02, release=0.5, harmonics=(1.0, 0.1))
        dsp.place(buf, dsp.stereo(heart * 0.35), dsp.samples(bar * BAR))
    x = dsp.periodic(dsp.lowpass, dsp.wrap(buf, n), 2800.0)
    return _wet(x, rng, n, reverb_s=3.5, mix=0.35, echo_s=BEAT * 0.5, feedback=0.35, echo_mix=0.3)


QUOTES = [  # the Trail motif on the Antecedent bell, where the melody rests
    (12.0, [(86, 0.5), (93, 1.5), (95, 0.5), (92, 2.5)], 1.0),
    (33.0, [(86, 0.5), (93, 2.5)], 0.6),
    (48.0, [(83, 0.5), (90, 1.5), (92, 0.5), (88, 2.5)], 0.85),
    (66.0, [(81, 0.5), (88, 1.5), (90, 0.5), (85, 2.5)], 0.8),  # lands on C#: Thalassa never comes home
]


@sound("mus_thalassa_explore_trail", "music", -29.0, **LAYER)
def trail(rng: np.random.Generator) -> np.ndarray:
    n = _n()
    buf = np.zeros((2, n + dsp.samples(8.0)))
    for start, notes, vel in QUOTES:
        at = start
        for i, (m, beats) in enumerate(notes):
            b = bell(H(m), rng, decay=0.7 + 0.5 * beats, brightness=0.4, strike=0.15)
            b = _soft(dsp.lowpass(b, 6000.0), 0.01)
            dsp.place(buf, dsp.pan(b * vel * (0.8 if i == 0 else 1.0), -0.3 + 0.2 * i), dsp.samples(at * BEAT))
            at += beats
    x = dsp.wrap(buf, n)
    t = dsp.time_axis(n)
    for k, m in enumerate([78, 85]):  # a faint bell air on F# and C#
        f = round(H(m) * LOOP) / LOOP
        f2 = round((H(m) + 0.25) * LOOP) / LOOP
        swell = 0.5 - 0.5 * np.cos(2 * np.pi * (2 + k) * t / LOOP)
        x += dsp.pan(0.03 * 0.5 * (dsp.sine(f, n) + dsp.sine(f2, n)) * swell, -0.4 + 0.8 * k)
    return _wet(x, rng, n, reverb_s=5.5, mix=0.45, echo_s=BEAT * 1.5, feedback=0.3, echo_mix=0.25)


# --------------------------------------------------------------------------- tension and combat


@sound("mus_thalassa_tension_drive", "music", -28.0, **LAYER)
def drive(rng: np.random.Generator) -> np.ndarray:
    n = _n()
    buf = np.zeros((2, n + dsp.samples(3.0)))
    eighth = BEAT / 2
    accents = [1.0, 0.4, 0.65, 0.4, 0.8, 0.5]
    for bar in range(BARS):
        bass = _chord(bar)[0] + 12
        for s in range(6):
            m = bass + (12 if s in (3, 5) else 0)
            low = soft_sine(H(m), eighth * 0.6, attack=0.012, release=0.15, harmonics=(1.0, 0.4, 0.15))
            body = bowed(H(m), eighth * 0.5, rng, bright=2.5)
            dsp.place(buf, dsp.stereo(dsp.mix(low, 0.35 * body) * accents[s] * 0.7), dsp.samples(bar * BAR + s * eighth))
        tick = _soft(pluck(H(85), rng, 0.08)) * 0.18
        for s in (1, 3, 5):
            dsp.place(buf, dsp.pan(tick, 0.45), dsp.samples(bar * BAR + s * eighth))
        if bar % BLOCK_BARS == BLOCK_BARS - 1:  # a wave drawn in before the next block
            m = dsp.samples(BAR)
            u = dsp.time_axis(m) / BAR
            air = dsp.sweep(dsp.pink(m, rng), "bp", 300.0 * 6.0 ** u, 1.0) * u ** 2 * 0.2
            dsp.place(buf, dsp.stereo(air), dsp.samples(bar * BAR))
    x = dsp.periodic(dsp.lowpass, dsp.wrap(buf, n), 2200.0)
    return _wet(x, rng, n, reverb_s=3.0, mix=0.3)


@sound("mus_thalassa_combat_drums", "music", -26.0, **LAYER)
def drums(rng: np.random.Generator) -> np.ndarray:
    n = _n()
    buf = np.zeros((2, n + dsp.samples(2.0)))
    trip = BEAT / 3
    for bar in range(BARS):
        at0 = bar * BAR
        fill = bar % BLOCK_BARS == BLOCK_BARS - 1
        dsp.place(buf, dsp.stereo(hull(rng, 52.0)), dsp.samples(at0))
        dsp.place(buf, dsp.pan(0.6 * hull(rng, 78.0, 0.5), 0.3), dsp.samples(at0 + 1.5 * BEAT))
        if not fill:
            for b in (1, 2):
                dsp.place(buf, dsp.pan(0.5 * splash(rng), -0.25), dsp.samples(at0 + b * BEAT))
        else:
            for k in range(6):  # falling toms through beats 2 and 3
                f = 120.0 * 0.9 ** k
                dsp.place(buf, dsp.pan((0.45 + 0.06 * k) * hull(rng, f, 0.4), 0.4 - 0.15 * k),
                          dsp.samples(at0 + BEAT + k * trip))
        for s in range(9):
            m = dsp.samples(0.07)
            shake = dsp.highpass(dsp.white(m, rng), 6000.0) * dsp.perc(m, 0.008, 0.02)
            dsp.place(buf, dsp.pan(shake * (0.12 if s % 3 == 0 else 0.06), 0.5), dsp.samples(at0 + s * trip))
    x = dsp.saturate(dsp.wrap(buf, n) * 1.1, 0.7)
    return _wet(x, rng, n, reverb_s=2.4, mix=0.22)


@sound("mus_thalassa_combat_drums_b", "music", -26.0, **LAYER)
def drums_b(rng: np.random.Generator) -> np.ndarray:
    n = _n()
    buf = np.zeros((2, n + dsp.samples(2.0)))
    trip = BEAT / 3
    for bar in range(BARS):
        at0 = bar * BAR
        if bar % 2 == 0:
            dsp.place(buf, dsp.stereo(1.1 * hull(rng, 48.0, 1.0)), dsp.samples(at0))
        else:
            dsp.place(buf, dsp.pan(0.8 * hull(rng, 60.0, 0.7), -0.2), dsp.samples(at0 + BEAT))
        dsp.place(buf, dsp.pan(0.45 * splash(rng, 0.5), 0.3), dsp.samples(at0 + 2 * BEAT))
        for k in range(3):  # rolling toms in triplets into beat 3
            dsp.place(buf, dsp.pan(0.35 * hull(rng, 100.0 - 8.0 * k, 0.3), -0.4 + 0.3 * k),
                      dsp.samples(at0 + BEAT + (k + 3) * trip))
    x = dsp.saturate(dsp.wrap(buf, n), 0.6)
    return _wet(x, rng, n, reverb_s=2.6, mix=0.24)


def _stab(rng: np.random.Generator, m: int, dur: float, bright: float = 5.0) -> np.ndarray:
    f = H(m)
    x = reed(f, dur, rng, brightness=bright, attack=0.015, release=0.12, breath=0.03, vibrato_cents=2.0)
    x = dsp.mix(x, 0.5 * reed(f * dsp.cents(-8.0), dur, rng, brightness=bright, attack=0.02, release=0.12,
                               breath=0.0, vibrato_cents=2.0))
    return dsp.saturate(x * 1.4, 1.0)


@sound("mus_thalassa_combat_brass", "music", -27.0, **LAYER)
def brass(rng: np.random.Generator) -> np.ndarray:
    n = _n()
    buf = np.zeros((2, n + dsp.samples(4.0)))
    for bar in range(BARS):
        bass = _chord(bar)[0]
        root = bass + 12 if bass + 12 >= 45 else bass + 24
        calling = bar in (6, 7, 18, 19)
        steps = [(0.0, 1.0), (1.0, 0.7), (1.5, 0.85)] if not calling else [(0.0, 1.0)]
        for at, v in steps:
            for k, m in enumerate([root, root + 7, root + 12]):
                note = _stab(rng, m, BEAT * 0.45, 5.0 + 1.5 * k)
                dsp.place(buf, dsp.pan(note * v * (0.75 if k == 0 else 0.55), -0.3 + 0.3 * k),
                          dsp.samples((bar * BAR_BEATS + at) * BEAT))
    for start_bar, root in ((6, 66), (18, 61)):
        at = start_bar * BAR + BEAT
        for m, beats in _motif(root):
            dur = beats * BEAT * 0.75
            dsp.place(buf, dsp.pan(0.85 * _stab(rng, m, dur * 0.95, 4.5), 0.1), dsp.samples(at))
            at += dur
    x = dsp.periodic(dsp.lowpass, dsp.wrap(buf, n), 3800.0)
    return _wet(x, rng, n, reverb_s=3.0, mix=0.28)


@sound("mus_thalassa_urgency", "music", -29.0, **LAYER)
def urgency(rng: np.random.Generator) -> np.ndarray:
    n = _n()
    buf = np.zeros((2, n + dsp.samples(3.0)))
    trip = BEAT / 3
    for bar in range(BARS):
        at0 = bar * BAR
        for s in range(9):
            m = 66 if s % 3 else (62 if s == 0 else 68)  # F#, the D-G# tritone on the beats
            note = _soft(pluck(H(m + 12), rng, 0.06)) * (0.5 if s % 3 == 0 else 0.3)
            dsp.place(buf, dsp.pan(note, 0.3 if s % 2 else -0.3), dsp.samples(at0 + s * trip))
        if bar % 2 == 0:  # the siren: a reed rising a fourth, C# -> F#
            m = dsp.samples(2 * BAR)
            u = np.clip(dsp.time_axis(m) / (BAR * 0.9), 0.0, 1.0)
            f = H(73) * 2.0 ** (5.0 * (u * u * (3 - 2 * u)) / 12.0)
            siren = reed(f, 2 * BAR * 0.9, rng, brightness=4.0, attack=0.3, release=1.2, breath=0.03,
                         vibrato_cents=12.0)
            dsp.place(buf, dsp.pan(0.3 * siren, 0.15), dsp.samples(at0 + BEAT))
    x = dsp.periodic(dsp.lowpass, dsp.wrap(buf, n), 5000.0)
    return _wet(x, rng, n, reverb_s=2.0, mix=0.22)


@sound("mus_thalassa_heavy", "music", -27.0, **LAYER)
def heavy(rng: np.random.Generator) -> np.ndarray:
    n = _n()
    buf = np.zeros((2, n + dsp.samples(3.0)))
    for bar in range(BARS):
        at0 = bar * BAR
        root = _chord(bar)[0]
        m = root if bar % 2 == 0 else root + 7
        dur = BAR * 0.92
        low = bowed(H(m), dur, rng, bright=6.0)
        octv = bowed(H(m + 12), dur, rng, bright=5.0)
        dsp.place(buf, dsp.stereo(0.5 * low + 0.3 * octv), dsp.samples(at0))
        for b in range(3):
            v = 0.85 if b == 0 else 0.55
            dsp.place(buf, dsp.pan(v * hull(rng, 64.0, 0.5), -0.2), dsp.samples(at0 + b * BEAT))
        k = dsp.samples(BAR * 0.6)
        tt = dsp.time_axis(k)
        sub = dsp.sine(H(root + 12) * (1 + 0.02 * np.sin(2 * np.pi * 7 * tt)), k) * dsp.perc(k, 0.01, 0.5)
        dsp.place(buf, dsp.stereo(0.45 * sub), dsp.samples(at0))
    x = dsp.periodic(dsp.lowpass, dsp.wrap(buf, n), 3400.0)
    return _wet(x, rng, n, reverb_s=2.6, mix=0.24)


# --------------------------------------------------------------------------- stealth


@sound("mus_thalassa_stealth_hush", "music", -31.0, **LAYER)
def hush(rng: np.random.Generator) -> np.ndarray:
    n = _n()
    buf = np.zeros((2, n + dsp.samples(8.0)))
    block = BLOCK_BARS * BAR
    for i, (bass, voicing) in enumerate(CHORDS):
        for k, m in enumerate(sorted(voicing)[-2:]):
            g = glass(H(m + 12), block * 0.75, rng, attack=4.0, release=4.5, beat_hz=0.3)
            dsp.place(buf, dsp.pan(0.3 * g, -0.6 + 1.2 * k), dsp.samples(i * block + BAR * k))
        low = soft_sine(H(bass + 12), block, attack=3.5, release=3.5, harmonics=(1.0, 0.1))
        dsp.place(buf, dsp.stereo(0.2 * low), dsp.samples(i * block))
    for bar in range(0, BARS, 3):
        m = sorted(_chord(bar)[1])[2] + 12
        drop = _soft(pluck(H(m), rng, 0.9), 0.01) * 0.3
        dsp.place(buf, dsp.pan(drop, 0.3 if bar % 2 else -0.3), dsp.samples(bar * BAR + BEAT))
    x = dsp.wrap(buf, n)
    return _wet(x, rng, n, reverb_s=6.0, mix=0.5, echo_s=BEAT * 1.5, feedback=0.3, echo_mix=0.25)


@sound("mus_thalassa_stealth_watch", "music", -29.0, **LAYER)
def watch(rng: np.random.Generator) -> np.ndarray:
    n = _n()
    buf = np.zeros((2, n + dsp.samples(2.0)))
    for bar in range(BARS):
        bass = _chord(bar)[0] + 12
        for offset, gain in ((0.0, 1.0), (0.25, 0.55)):  # lub-dub on beat 1
            beat_note = soft_sine(H(bass), 0.13, attack=0.01, release=0.2, harmonics=(1.0, 0.35, 0.1))
            dsp.place(buf, dsp.stereo(0.55 * gain * beat_note), dsp.samples(bar * BAR + offset * BEAT))
        for s in range(3):
            m = dsp.samples(0.07)
            tk = dsp.bandpass(dsp.white(m, rng), 4800.0, 2.5) * dsp.perc(m, 0.008, 0.012)
            dsp.place(buf, dsp.pan(0.22 * tk, 0.4), dsp.samples(bar * BAR + (s + 0.5) * BEAT))
        if bar % 2 == 1:  # the flat sixth (D over F#) as a shadow
            shadow = soft_sine(H(74), BEAT * 0.9, attack=0.03, release=0.3, harmonics=(1.0, 0.2))
            dsp.place(buf, dsp.pan(0.16 * shadow, -0.3), dsp.samples(bar * BAR + 2 * BEAT))
    x = dsp.periodic(dsp.lowpass, dsp.wrap(buf, n), 5500.0)
    # A faint cold air under the pulse, so the layer is never digital silence.
    air = dsp.periodic(dsp.bandpass, np.stack([dsp.pink(n, rng) for _ in range(2)]), 900.0, 0.7)
    x = x + 0.012 * air * (0.6 + 0.4 * _swell(n, 2.0))
    return _wet(x, rng, n, reverb_s=2.4, mix=0.25)


# --------------------------------------------------------------------------- the tide


@sound("mus_thalassa_tide", "music", -29.0, **LAYER)
def tide(rng: np.random.Generator) -> np.ndarray:
    """The sea coming in: rolling triplet arpeggios low in the bowed reed and
    pluck, each two-bar wave swelling and drawing back, surf noise breathing
    with it, a low drone on the root."""
    n = _n()
    buf = np.zeros((2, n + dsp.samples(3.0)))
    trip = BEAT / 3
    for bar in range(BARS):
        bass, voicing = _chord(bar)
        tones = [bass + 12, bass + 19, bass + 24, sorted(voicing)[2], bass + 24, bass + 19]
        rising = bar % 2 == 0
        for s in range(9):
            pos = (bar % 2) * 9 + s  # 0..17 through the two-bar wave
            g = np.sin(np.pi * pos / 18.0) ** 1.5
            m = tones[s % len(tones)] + (0 if rising or s < 5 else -12)
            note = _soft(pluck(H(m), rng, 0.25)) * (0.25 + 0.6 * g)
            dsp.place(buf, dsp.pan(note, -0.5 + pos / 18.0), dsp.samples(bar * BAR + s * trip))
        if rising:
            low = bowed(H(bass + 12), 2 * BAR * 0.9, rng, bright=2.2)
            dsp.place(buf, dsp.stereo(0.35 * low), dsp.samples(bar * BAR))
    x = dsp.wrap(buf, n)
    wave = _swell(n, 2.0, -np.pi / 3)
    surf = np.stack([dsp.pink(n, rng) for _ in range(2)])
    surf = dsp.periodic(dsp.sweep, surf, "bp", 500.0 + 1500.0 * wave, 0.7, block=256) * wave ** 2 * 0.12
    x = x + surf
    x = dsp.periodic(dsp.lowpass, x, 4200.0)
    return _wet(x, rng, n, reverb_s=4.0, mix=0.35)


# --------------------------------------------------------------------------- hits and stings


STING = dict(fmt="ogg", channels=2, folder="music/stings")


@sound("mus_hit_combat_thalassa_low", "sting", -24.0, min_seconds=1.5, max_seconds=3.6, **STING)
def hit_combat(rng: np.random.Generator) -> np.ndarray:
    buf = np.zeros((2, dsp.samples(4.0)))
    m = dsp.samples(1.0)
    u = dsp.time_axis(m) / 1.0
    drawn = dsp.sweep(dsp.pink(m, rng), "bp", 250.0 * 8.0 ** u, 0.8) * u ** 2.5 * 0.55  # a wave drawn in
    dsp.place(buf, dsp.stereo(drawn), 0)
    down = 1.0
    dsp.place(buf, dsp.stereo(0.9 * hull(rng, 60.0, 0.6)), dsp.samples(down - BEAT / 3))
    dsp.place(buf, dsp.stereo(1.2 * hull(rng, 46.0, 1.2)), dsp.samples(down))
    dsp.place(buf, dsp.stereo(0.5 * splash(rng, 0.6)), dsp.samples(down))
    low = bowed(H(42), 1.7, rng, bright=5.0)
    hi = bowed(H(54), 1.7, rng, bright=4.0)
    dsp.place(buf, dsp.stereo(0.5 * low + 0.3 * hi), dsp.samples(down))
    y = dsp.reverb(buf, rng, seconds=2.8, mix=0.32, predelay_ms=20.0, damp=0.6)
    y = dsp.trim_tail(dsp.dc_block(dsp.highpass(y, 30.0)), -60.0)[:, : dsp.samples(3.4)]
    return dsp.fade(y, 0.01, 0.8)


@sound("mus_hit_aftermath_thalassa_low", "sting", -25.0, min_seconds=2.5, max_seconds=5.6, **STING)
def hit_aftermath(rng: np.random.Generator) -> np.ndarray:
    buf = np.zeros((2, dsp.samples(6.5)))
    at = 0.1
    for m, beats in [(73, 0.75), (69, 0.75), (66, 2.5)]:  # C# A F#
        dur = beats * BEAT
        note = bowed(H(m), dur * 0.95, rng, bright=2.5)
        dsp.place(buf, dsp.pan(0.5 * note, -0.1), dsp.samples(at))
        at += dur
    dsp.place(buf, dsp.pan(0.4 * glass(H(78), 2.0, rng, attack=0.02, release=2.0), 0.3), dsp.samples(at - 2.0))
    y = dsp.reverb(buf, rng, seconds=4.0, mix=0.42, predelay_ms=25.0, damp=0.6)
    y = dsp.trim_tail(dsp.dc_block(dsp.highpass(y, 30.0)), -60.0)[:, : dsp.samples(5.4)]
    return dsp.fade(y, 0.01, 1.2)


ENDING = dict(STING, min_seconds=3.0, max_seconds=6.5)


@sound("mus_sting_victory_thalassa_low", "sting", -22.0, **ENDING)
def sting_victory(rng: np.random.Generator) -> np.ndarray:
    """The tide motif answered: F# D C#, then up to the high F# instead of falling."""
    beat = 0.45
    buf = np.zeros((2, dsp.samples(7.0)))
    at = 0.2
    for i, (m, beats) in enumerate([(78, 1.0), (86, 1.5), (85, 0.5), (90, 4.0)]):
        dsp.place(buf, dsp.pan(tide_voice(m, beats, 0.85 if i == 0 else 1.0, rng, beat), 0.05 * (i - 1.5)),
                  dsp.samples(at))
        at += beats * beat
    for k, m in enumerate([50, 57, 61, 64, 66]):  # D major 9 lifting to F#
        p = pad_voice(H(m), 1.6, rng, attack=0.5, release=1.0, brightness=3.0)
        dsp.place(buf, p * (0.45 if k == 0 else 0.3), 0)
    for k, m in enumerate([54, 61, 66, 68, 73]):  # F# with the ninth: open, not minor
        p = pad_voice(H(m), 2.6, rng, attack=0.6, release=2.0, brightness=3.2)
        dsp.place(buf, p * (0.45 if k == 0 else 0.3), dsp.samples(1.4))
    for k, m in enumerate([78, 81, 85, 90, 93]):
        note = _soft(pluck(H(m), rng, 0.6)) * 0.35
        dsp.place(buf, dsp.pan(note, -0.4 + 0.2 * k), dsp.samples(0.2 + 3.0 * beat + k * beat / 3))
    y = dsp.delay(buf, beat * 1.5, 0.3, 0.2, 2600.0, ping_pong=True)
    y = dsp.reverb(y, rng, seconds=4.0, mix=0.4, predelay_ms=25.0, damp=0.55)
    y = dsp.trim_tail(dsp.dc_block(y), -60.0)[:, : dsp.samples(5.8)]
    return dsp.fade(y, 0.002, 1.2)


@sound("mus_sting_defeat_thalassa_low", "sting", -22.0, **ENDING)
def sting_defeat(rng: np.random.Generator) -> np.ndarray:
    """The motif sinking: F# D C# A, then down to the low F#, the filter closing."""
    beat = 0.6
    buf = np.zeros((2, dsp.samples(7.5)))
    at = 0.3
    for i, (m, beats) in enumerate([(78, 1.0), (86, 1.5), (85, 0.5), (81, 1.0), (66, 3.0)]):
        v = dsp.lowpass(tide_voice(m, beats, 0.9, rng, beat), 3000.0 - 450.0 * i)
        dsp.place(buf, dsp.pan(v, -0.05 * i), dsp.samples(at))
        at += beats * beat
    for k, m in enumerate([42, 54, 57, 61, 62]):  # F#m with the flat sixth
        p = pad_voice(H(m), 4.5, rng, attack=1.2, release=2.0, brightness=2.2)
        dsp.place(buf, p * (0.45 if k == 0 else 0.28), 0)
    n = buf.shape[-1]
    closing = 2200.0 * (0.15 + 0.85 * np.exp(-dsp.time_axis(n) / 2.8))
    buf = dsp.sweep(buf, "lp", closing, 0.6, block=256)
    y = dsp.reverb(buf, rng, seconds=4.5, mix=0.45, predelay_ms=30.0, damp=0.65)
    y = dsp.trim_tail(dsp.dc_block(y), -60.0)[:, : dsp.samples(6.2)]
    return dsp.fade(y, 0.002, 1.4)
