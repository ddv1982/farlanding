"""Verdance (Phase 8c): the adaptive score.

Kessel Reach is warm and dry in D Lydian at 80 BPM in four; Thalassa cold and
wide in F# Aeolian at 63 BPM in three; Emberfall hot and heavy in C# Phrygian
at 56 BPM in four. Verdance is hushed, alive and watchful: **B Dorian** (B C#
D E F# G# A: the same seven pitches as the Concord's D Lydian, so unit
replies, the Advisor and the Trail motif never clash with it, but centred on B
minor with the bright Dorian sixth G#), **70 BPM in 6/8** (two dotted-quarter
beats a bar, six eighths that sway and patter like something moving in the
leaves). One loop is 40 bars, 80 beats, 68.57 s (3 024 000 samples, a multiple
of 64 for the native Vorbis encoder).

Chords, eight bars each: Bm(add9), E(add9) (the Dorian IV: G# in a major
chord, the planet's light), Dmaj7(#11), A(add9)/C#, F#m7(add11), which leans
back into Bm at the loop.

Timbres: wood and breath. No glass, no taiko, no forge. A *marimba* (the
Concord's own wood, here soft-malleted), *log drums* (slit drums: two tongues
a little over an octave apart, a wooden knock), a breathy wooden *flute*,
a low *reed*, *hand percussion* (palm drums, seed shakers, finger taps).
Rooms are medium and soft (2.5-3.5 s), like a space under leaves.

The Verdance motif (the canopy call): F# up a fourth to B (a call), then A,
G#, F# falling (an answer from somewhere else); short-long, short-short-long:
two voices in the trees, not quite sure of each other.

Layers (all synchronised; the MusicDirector fades them on the beat):

  pad        soft reed-and-breath chords, a flute air on the top notes
  pulse      soft marimba in the 6/8 sway (eighths 1, 3, 4, 6) over a log drum
  melody     the canopy call and its answers on the flute, marimba doubling
  drive      tension: muted log-drum eighths on the bass, G# shadow on the last
  drums      combat: log drums and palm drums in 6/8, seed shaker in eighths
  brass      combat: reed stabs on root and fifth, the call as a horn signal
  trail      the Trail motif (D A B G#) on the Antecedent bell, in the gaps
  hush       stealth unaware: breath on chord tones, a far marimba drop
  watch      stealth suspicious: a low log-drum lub-dub, finger taps, a G# shadow
  melody_b   variation: high flute answers, ending on G# (the Dorian sixth)
  melody_c   variation: the call augmented low on the reed, marimba above
  pulse_b    variation: plucked wood in quarter notes, three against the two
  drums_b    variation: half time, one deep log drum, rolling palm drums
  urgency    base under attack: marimba tremolo of B against the D-G#
             tritone, a reed siren rising a fourth F# -> B every two bars
  heavy      heavy combat: low reeds in dotted halves, doubled drums, a growl

Re-voiced hits and stings (`<id>_verdance`): the combat hit (leaves rushing in,
two log drums, a low reed B), the aftermath hit (the flute sighs C# -> B, a
marimba ring, leaves settling), victory (the call answered upward, landing on
the Concord's D major with the high D: the planet's B minor opens into its
relative major) and defeat (the call falling to the low B under a breath that
thins as the filter closes).

Attacks stay at 8 ms or softer (native Vorbis pre-echo, ADR 0005).
"""

from __future__ import annotations

import numpy as np

from synth import dsp
from synth.instruments import bell, marimba, pad_voice, reed, soft_sine

from . import sound
from .music_kessel import _space
from .music_kessel_combat import _soft

H = dsp.midi_hz

BPM = 70.0  # dotted quarters
BEAT = 60.0 / BPM
EIGHTH = BEAT / 3.0
BAR_BEATS = 2
BAR = BAR_BEATS * BEAT
BARS = 40
BEATS = BAR_BEATS * BARS
LOOP = BAR * BARS  # 68.57 s
BLOCK_BARS = 8

# (bass, voicing) per eight-bar block, B Dorian.
CHORDS = [
    (35, [47, 54, 61, 62, 66]),  # Bm(add9): B F# C# D F#
    (40, [52, 56, 59, 66, 68]),  # E(add9): E G# B F# G#
    (38, [50, 57, 61, 66, 68]),  # Dmaj7(#11): D A C# F# G#
    (37, [49, 57, 64, 69, 71]),  # A(add9)/C#: C# A E A B
    (42, [54, 61, 64, 69, 71]),  # F#m7(add11): F# C# E A B
]

# The canopy call: (semitones above F#, eighths).
MOTIF = [(0, 1.0), (5, 3.0), (3, 1.0), (2, 1.0), (0, 4.0)]

LAYER = dict(fmt="ogg", channels=2, loop=True, folder="music/verdance", min_seconds=LOOP - 0.01,
             max_seconds=LOOP + 0.01, bpm=BPM, beats=BEATS, bar_beats=BAR_BEATS)


def _n() -> int:
    return dsp.samples(LOOP)


def _chord(bar: int) -> tuple[int, list[int]]:
    return CHORDS[(bar // BLOCK_BARS) % len(CHORDS)]


def _leaves(x: np.ndarray, rng: np.random.Generator, n: int, reverb_s: float = 2.8, mix: float = 0.32,
            echo_s: float = 0.0, feedback: float = 0.0, echo_mix: float = 0.0) -> np.ndarray:
    """The Verdance room: soft and medium, a space under leaves."""
    return _space(x, rng, n, reverb_s=reverb_s, mix=mix, echo_s=echo_s, feedback=feedback, echo_mix=echo_mix)


def _swell(n: int, bars: float, phase: float = 0.0) -> np.ndarray:
    """0..1, one rise and fall every `bars` bars, periodic over the loop."""
    t = dsp.time_axis(n)
    cycles = round(LOOP / (bars * BAR))
    return 0.5 - 0.5 * np.cos(2 * np.pi * cycles * t / LOOP + phase)


# Low strikes on the loop's first downbeat land this late, so the onset of a
# deep, slow waveform is not the seam itself (the seam check compares the step
# there with the 20 ms around it). Inaudible as timing.
NUDGE = 0.004


def _at(bar: int, eighth: float, nudge: float = 0.0) -> int:
    return dsp.samples(bar * BAR + eighth * EIGHTH + nudge)


# --------------------------------------------------------------------------- voices


def flute(f: float | np.ndarray, dur: float, rng: np.random.Generator, breath: float = 0.3,
          attack: float = 0.06, release: float = 0.22, vibrato_cents: float = 9.0) -> np.ndarray:
    """A breathy wooden flute: a near-sine with a little second harmonic, a
    vibrato that grows in, a breath tuned to the note and a soft chiff."""
    n = dsp.samples(dur + release)
    t = dsp.time_axis(n)
    base = np.full(n, float(f)) if np.ndim(f) == 0 else np.interp(np.arange(n), np.arange(len(f)), f)
    vib = 1.0 + (dsp.cents(vibrato_cents) - 1.0) * np.clip((t - 0.15) / 0.35, 0, 1) * np.sin(2 * np.pi * 5.2 * t)
    fv = base * vib
    tone = dsp.sine(fv, n) + 0.16 * dsp.sine(2 * fv, n) + 0.05 * dsp.sine(3 * fv, n)
    centre = float(np.median(base))
    air = dsp.bandpass(dsp.white(n, rng), centre, 2.5) * 1.2 + 0.25 * dsp.bandpass(dsp.white(n, rng),
                                                                                   min(centre * 4, 9000.0), 0.8)
    chiff = dsp.bandpass(dsp.white(n, rng), min(centre * 3, 8000.0), 1.0) * dsp.perc(n, 0.008, 0.03) * 0.3
    e = dsp.ar(n, attack, release, max(dur - attack, 0.0))
    return (tone + breath * air) * e * 0.5 + chiff


LOG_TONGUES = [(1.0, 1.0, 1.0), (2.42, 0.32, 0.4), (3.95, 0.1, 0.18)]


def log_drum(f: float, rng: np.random.Generator, decay: float = 0.28, length: float = 1.0,
             knock: float = 0.3) -> np.ndarray:
    """A slit drum: a wooden tongue (pitch settles a hair after the strike),
    a second tongue a little over an octave up, a dull knock."""
    n = dsp.samples(length)
    t = dsp.time_axis(n)
    out = np.zeros(n)
    for ratio, amp, dk in LOG_TONGUES:
        fr = f * ratio
        if fr >= dsp.NYQUIST * 0.8:
            continue
        bend = 1.0 + 0.03 * np.exp(-t / 0.012)
        out += amp * dsp.sine(fr * bend, n, float(rng.random())) * np.exp(-t / (decay * dk))
    hit = dsp.lowpass(dsp.white(n, rng), min(f * 5.0, 6000.0)) * dsp.perc(n, 0.0008, 0.01) * knock
    return _soft((out + hit) * 0.5, 0.008)


def palm(rng: np.random.Generator, f: float = 165.0, slap: float = 0.3, dur: float = 0.4) -> np.ndarray:
    """A palm on a skin drum: a short pitched body and a soft slap of skin."""
    n = dsp.samples(dur)
    t = dsp.time_axis(n)
    body = dsp.sine(f * (1.0 + 0.25 * np.exp(-t / 0.02)), n) * dsp.perc(n, 0.008, dur * 0.25)
    skin = dsp.bandpass(dsp.white(n, rng), 1600.0, 0.8) * dsp.perc(n, 0.008, 0.035) * slap
    return body + skin


def shaker(rng: np.random.Generator, gain: float) -> np.ndarray:
    """Seeds in a dry pod."""
    m = dsp.samples(0.09)
    x = dsp.bandpass(dsp.white(m, rng), 6200.0, 1.1) * dsp.env([(0, 0), (0.012, 1.0), (0.09, 0)], m, 1.5)
    return x * gain


def wood(f: float, rng: np.random.Generator, decay: float = 0.3, hardness: float = 0.6) -> np.ndarray:
    """The soft-malleted marimba of the planet."""
    return _soft(marimba(f, 0.05, rng, hardness=hardness, decay=decay, tail=max(0.6, decay * 2.5)), 0.008)


def low_reed(f: float | np.ndarray, dur: float, rng: np.random.Generator, bright: float = 3.0,
             attack: float = 0.08) -> np.ndarray:
    """A low wooden reed, breathy, a little saturated."""
    x = reed(f, dur, rng, brightness=bright, attack=attack, release=0.25, breath=0.12, vibrato_hz=4.2,
             vibrato_cents=5.0)
    return dsp.saturate(x * 1.1, 0.6)


def lead(m: int, eighths: float, vel: float, rng: np.random.Generator, eighth_s: float = EIGHTH) -> np.ndarray:
    """The lead: the flute, with a marimba stroke marking the onset."""
    dur = eighths * eighth_s
    fl = flute(H(m), dur * 0.92, rng, breath=0.28, attack=min(0.06, dur * 0.3))
    knock = wood(H(m), rng, decay=0.2, hardness=0.5) * 0.35
    return dsp.mix(fl, knock) * vel


def _phrases(rng: np.random.Generator, phrases, voice, extra: float = 6.0) -> np.ndarray:
    """phrases = [(start in eighths, [(midi, eighths)], vel, pan)]."""
    buf = np.zeros((2, _n() + dsp.samples(extra)))
    for start, notes, vel, side in phrases:
        at = start
        for m, eighths in notes:
            dsp.place(buf, dsp.pan(voice(m, eighths, vel, rng), side), dsp.samples(at * EIGHTH))
            at += eighths
    return buf


def _motif(root: int, stretch: float = 1.0) -> list[tuple[int, float]]:
    return [(root + step, eighths * stretch) for step, eighths in MOTIF]


def _bar8(bar: int) -> float:
    """The start of `bar` in eighths."""
    return bar * 6.0


# --------------------------------------------------------------------------- explore


@sound("mus_verdance_explore_pad", "music", -25.0, **LAYER)
def pad(rng: np.random.Generator) -> np.ndarray:
    n = _n()
    buf = np.zeros((2, n + dsp.samples(8.0)))
    block = BLOCK_BARS * BAR
    for i, (bass, voicing) in enumerate(CHORDS):
        at = dsp.samples(i * block)
        for k, m in enumerate(voicing):
            v = pad_voice(H(m), block, rng, attack=2.8, release=3.5, detune_cents=9.0, brightness=1.6 + 0.2 * k)
            dsp.place(buf, v * (0.7 if k == 0 else 0.4), at)
            if k >= len(voicing) - 2:  # a breath of flute on the top notes
                fl = flute(H(m + 12), block * 0.8, rng, breath=0.8, attack=2.0, release=2.5, vibrato_cents=4.0)
                dsp.place(buf, dsp.pan(0.18 * fl, -0.5 if k % 2 else 0.5), at + dsp.samples(BAR * (k % 2)))
        bass_note = soft_sine(H(bass + 12), block, attack=2.0, release=3.0, harmonics=(1.0, 0.35, 0.1))
        dsp.place(buf, dsp.stereo(bass_note * 0.5), at)
    x = dsp.wrap(buf, n)
    breathe = _swell(n, 4.0)
    x = dsp.periodic(dsp.sweep, x, "lp", 700.0 + 900.0 * breathe, 0.7, block=512) * (0.85 + 0.15 * breathe)
    return _leaves(x, rng, n, reverb_s=3.4, mix=0.36)


PULSE_STEPS = [(0.0, 1.0, 1), (2.0, 0.55, 3), (3.0, 0.8, 2), (5.0, 0.5, 4)]  # the sway: 1, 3, 4, 6


@sound("mus_verdance_explore_pulse", "music", -29.0, **LAYER)
def pulse(rng: np.random.Generator) -> np.ndarray:
    n = _n()
    buf = np.zeros((2, n + dsp.samples(2.0)))
    for bar in range(BARS):
        bass, voicing = _chord(bar)
        tones = sorted(voicing)[1:]
        for at, v, k in PULSE_STEPS:
            m = tones[(bar + k) % len(tones)] + 12
            note = wood(H(m), rng, decay=0.22, hardness=0.45) * v * float(rng.uniform(0.88, 1.0))
            dsp.place(buf, dsp.pan(note, -0.35 if k % 2 else 0.35), _at(bar, at))
        dsp.place(buf, dsp.stereo(log_drum(H(bass + 12), rng, decay=0.22, length=0.8) * 0.45), _at(bar, 0.0))
    x = dsp.periodic(dsp.lowpass, dsp.wrap(buf, n), 3600.0)
    return _leaves(x, rng, n, reverb_s=2.4, mix=0.28, echo_s=EIGHTH * 3, feedback=0.28, echo_mix=0.2)


# Phrases start in eighths; a block is 48 eighths.
PHRASES = [
    (6.0, _motif(66), 1.0, 0.1),                                                 # over Bm: the call
    (54.0, [(68, 1.0), (71, 3.0), (69, 1.0), (68, 1.0), (64, 4.0)], 0.9, -0.1),  # over E: answered lower
    (102.0, [(66, 1.0), (73, 3.0), (71, 1.0), (69, 1.0), (68, 4.0)], 0.9, 0.05),  # over D: up to C#, G#
    (150.0, [(64, 1.0), (69, 3.0), (68, 1.0), (66, 1.0), (64, 4.0)], 0.85, -0.05),  # over A/C#
    (198.0, [(66, 1.0), (71, 3.0), (69, 2.0), (73, 2.0), (71, 6.0)], 0.95, 0.0),  # over F#m: home to B
]


@sound("mus_verdance_explore_melody", "music", -27.0, **LAYER)
def melody(rng: np.random.Generator) -> np.ndarray:
    buf = _phrases(rng, PHRASES, lead)
    return _leaves(buf, rng, _n(), reverb_s=3.0, mix=0.34, echo_s=EIGHTH * 3, feedback=0.3, echo_mix=0.2)


MELODY_B = [
    (12.0, [(78, 2.0), (81, 1.0), (83, 3.0)], 0.8, 0.25),
    (60.0, [(80, 1.0), (78, 1.0), (76, 4.0)], 0.75, -0.2),
    (108.0, [(81, 2.0), (80, 1.0), (78, 3.0)], 0.75, 0.15),
    (156.0, [(76, 1.0), (78, 2.0), (81, 3.0)], 0.75, -0.15),
    (204.0, [(83, 1.0), (81, 1.0), (78, 2.0), (80, 8.0)], 0.8, 0.05),  # ends on G#
]


def _high_flute(m: int, eighths: float, vel: float, rng: np.random.Generator) -> np.ndarray:
    dur = eighths * EIGHTH
    return flute(H(m), dur * 0.9, rng, breath=0.4, attack=min(0.08, dur * 0.3), vibrato_cents=11.0) * vel


@sound("mus_verdance_explore_melody_b", "music", -27.0, **LAYER)
def melody_b(rng: np.random.Generator) -> np.ndarray:
    buf = _phrases(rng, MELODY_B, _high_flute)
    return _leaves(buf, rng, _n(), reverb_s=3.2, mix=0.38, echo_s=EIGHTH * 2, feedback=0.32, echo_mix=0.26)


def _low_voice(m: int, eighths: float, vel: float, rng: np.random.Generator) -> np.ndarray:
    dur = eighths * EIGHTH
    low = low_reed(H(m), dur * 0.95, rng, bright=2.6, attack=0.12)
    top = wood(H(m + 24), rng, decay=0.35, hardness=0.5) * 0.4
    return dsp.mix(0.8 * low, top) * vel


MELODY_C = [(12.0, _motif(54, 2.0), 0.9, -0.15), (108.0, _motif(50, 2.0), 0.85, 0.15),
            (204.0, _motif(54, 1.5), 0.8, 0.0)]


@sound("mus_verdance_explore_melody_c", "music", -27.0, **LAYER)
def melody_c(rng: np.random.Generator) -> np.ndarray:
    buf = _phrases(rng, MELODY_C, _low_voice)
    return _leaves(buf, rng, _n(), reverb_s=3.0, mix=0.32)


@sound("mus_verdance_explore_pulse_b", "music", -29.0, **LAYER)
def pulse_b(rng: np.random.Generator) -> np.ndarray:
    """Plucked wood in quarter notes: three against the bar's two beats."""
    n = _n()
    buf = np.zeros((2, n + dsp.samples(2.0)))
    for bar in range(BARS):
        bass, voicing = _chord(bar)
        tones = sorted(voicing)[-3:]
        for k in range(3):
            m = tones[(k + bar) % 3] + 12
            note = wood(H(m), rng, decay=0.12, hardness=0.8) * (0.8 if k == 0 else 0.55)
            dsp.place(buf, dsp.pan(note, -0.4 + 0.4 * k), _at(bar, 2.0 * k))
        for e in (1.0, 4.0):
            dsp.place(buf, dsp.pan(shaker(rng, 0.12), 0.5), _at(bar, e))
        dsp.place(buf, dsp.stereo(log_drum(H(bass + 12), rng, decay=0.2, length=0.7) * 0.4), _at(bar, 0.0))
    x = dsp.periodic(dsp.lowpass, dsp.wrap(buf, n), 4800.0)
    return _leaves(x, rng, n, reverb_s=2.2, mix=0.26)


QUOTES = [  # the Trail motif on the Antecedent bell, where the melody rests
    (30.0, [(74, 1.0), (81, 2.0), (83, 1.0), (80, 4.0)], 1.0),
    (78.0, [(74, 1.0), (81, 4.0)], 0.6),
    (126.0, [(71, 1.0), (78, 2.0), (80, 1.0), (76, 4.0)], 0.85),
    (222.0, [(74, 1.0), (81, 2.0), (83, 1.0), (80, 5.0)], 0.8),  # hangs on G#, the Dorian sixth
]


@sound("mus_verdance_explore_trail", "music", -29.0, **LAYER)
def trail(rng: np.random.Generator) -> np.ndarray:
    n = _n()
    buf = np.zeros((2, n + dsp.samples(8.0)))
    for start, notes, vel in QUOTES:
        at = start
        for i, (m, eighths) in enumerate(notes):
            b = bell(H(m), rng, decay=0.6 + 0.15 * eighths, brightness=0.45, strike=0.15)
            b = _soft(dsp.lowpass(b, 5500.0), 0.01)
            dsp.place(buf, dsp.pan(b * vel * (0.8 if i == 0 else 1.0), -0.3 + 0.2 * i), dsp.samples(at * EIGHTH))
            at += eighths
    x = dsp.wrap(buf, n)
    t = dsp.time_axis(n)
    for k, m in enumerate([59, 66]):  # a faint bell air on B and F#
        f = round(H(m) * LOOP) / LOOP
        f2 = round((H(m) + 0.3) * LOOP) / LOOP
        swell = 0.5 - 0.5 * np.cos(2 * np.pi * (2 + k) * t / LOOP)
        x += dsp.pan(0.03 * 0.5 * (dsp.sine(f, n) + dsp.sine(f2, n)) * swell, -0.4 + 0.8 * k)
    return _leaves(x, rng, n, reverb_s=3.4, mix=0.4, echo_s=EIGHTH * 3, feedback=0.25, echo_mix=0.2)


# --------------------------------------------------------------------------- tension and combat


@sound("mus_verdance_tension_drive", "music", -28.0, **LAYER)
def drive(rng: np.random.Generator) -> np.ndarray:
    n = _n()
    buf = np.zeros((2, n + dsp.samples(2.0)))
    accents = [1.0, 0.4, 0.55, 0.85, 0.4, 0.6]
    for bar in range(BARS):
        bass = _chord(bar)[0] + 12
        for s in range(6):
            m = bass
            low = soft_sine(H(m), EIGHTH * 0.55, attack=0.01, release=0.1, harmonics=(1.0, 0.4, 0.15))
            knock = log_drum(H(m + 12), rng, decay=0.06, length=0.25, knock=0.5) * 0.6
            dsp.place(buf, dsp.stereo(dsp.mix(low, knock) * accents[s] * 0.7), _at(bar, s))
        if bar % 2 == 1:  # G#, the Dorian sixth, as a shadow on the last eighth
            g = soft_sine(H(68), EIGHTH * 0.5, attack=0.01, release=0.1, harmonics=(1.0, 0.3))
            dsp.place(buf, dsp.pan(g * 0.3, -0.25), _at(bar, 5.0))
        for s in (1.5, 4.5):
            dsp.place(buf, dsp.pan(shaker(rng, 0.18), 0.45), _at(bar, s))
        if bar % BLOCK_BARS == BLOCK_BARS - 1:  # leaves stirring before the next block
            m = dsp.samples(BAR)
            u = dsp.time_axis(m) / BAR
            air = dsp.sweep(dsp.pink(m, rng), "bp", 600.0 * 6.0 ** u, 0.9) * u ** 2 * 0.18
            dsp.place(buf, dsp.stereo(air), dsp.samples(bar * BAR))
    x = dsp.periodic(dsp.lowpass, dsp.wrap(buf, n), 2400.0)
    return _leaves(x, rng, n, reverb_s=2.2, mix=0.24)


@sound("mus_verdance_combat_drums", "music", -26.0, **LAYER)
def drums(rng: np.random.Generator) -> np.ndarray:
    n = _n()
    buf = np.zeros((2, n + dsp.samples(2.0)))
    for bar in range(BARS):
        bass = _chord(bar)[0]
        fill = bar % 4 == 3
        for e, f, v, side in [(0.0, H(bass + 12), 1.0, 0.0), (2.0, H(bass + 19), 0.55, 0.25),
                              (3.0, H(bass + 12), 0.85, 0.0), (5.0, H(bass + 24), 0.5, -0.25)]:
            if fill and e >= 3.0:
                continue
            dsp.place(buf, dsp.pan(v * log_drum(f, rng, decay=0.3, length=0.9, knock=0.5), side), _at(bar, e))
        if not fill:
            for e in (1.5, 4.5):
                dsp.place(buf, dsp.pan(0.5 * palm(rng, 190.0, 0.6), -0.2), _at(bar, e))
        else:
            for k in range(6):  # palm drums falling through the second beat
                dsp.place(buf, dsp.pan((0.4 + 0.06 * k) * palm(rng, 230.0 - 14.0 * k, 0.4), 0.4 - 0.15 * k),
                          _at(bar, 3.0 + 0.5 * k))
        for e in range(6):
            dsp.place(buf, dsp.pan(shaker(rng, 0.22 if e % 3 == 0 else 0.1), 0.5), _at(bar, e + 0.5))
    x = dsp.saturate(dsp.wrap(buf, n) * 1.1, 0.5)
    return _leaves(x, rng, n, reverb_s=1.9, mix=0.2)


@sound("mus_verdance_combat_drums_b", "music", -26.0, **LAYER)
def drums_b(rng: np.random.Generator) -> np.ndarray:
    n = _n()
    buf = np.zeros((2, n + dsp.samples(2.0)))
    for bar in range(BARS):
        bass = _chord(bar)[0]
        if bar % 2 == 0:
            dsp.place(buf, dsp.stereo(1.1 * log_drum(H(bass), rng, decay=0.6, length=1.6, knock=0.6)),
                      _at(bar, 0.0, NUDGE))
        dsp.place(buf, dsp.pan(0.5 * palm(rng, 150.0, 0.5), 0.25), _at(bar, 3.0))
        if bar % 4 == 3:
            for k in range(9):  # rolling palm drums into the next phrase
                dsp.place(buf, dsp.pan(0.35 * palm(rng, 260.0 - 12.0 * k, 0.35), -0.4 + 0.1 * k),
                          _at(bar, 1.5 + 0.5 * k))
        for e in (1.0, 4.0):
            dsp.place(buf, dsp.pan(shaker(rng, 0.14), -0.45), _at(bar, e))
    x = dsp.saturate(dsp.wrap(buf, n), 0.5)
    return _leaves(x, rng, n, reverb_s=2.4, mix=0.22)


def _stab(rng: np.random.Generator, m: int, dur: float, bright: float = 6.0) -> np.ndarray:
    return low_reed(H(m), dur, rng, bright=bright, attack=0.02)


@sound("mus_verdance_combat_brass", "music", -27.0, **LAYER)
def brass(rng: np.random.Generator) -> np.ndarray:
    n = _n()
    buf = np.zeros((2, n + dsp.samples(3.0)))
    for bar in range(BARS):
        root = _chord(bar)[0] + 12
        calling = bar % BLOCK_BARS in (2, 3)
        steps = [(0.0, 1.0), (3.0, 0.8), (5.0, 0.6)] if not calling else [(0.0, 1.0)]
        for at, v in steps:
            for k, m in enumerate([root, root + 7, root + 12]):
                note = _stab(rng, m, EIGHTH * 0.8, 5.0 + 1.5 * k)
                dsp.place(buf, dsp.pan(note * v * (0.75 if k == 0 else 0.5), -0.3 + 0.3 * k), _at(bar, at))
            dsp.place(buf, dsp.pan(0.35 * wood(H(root + 24), rng, decay=0.15, hardness=1.0), 0.3), _at(bar, at))
    for start_bar, root in ((2, 66), (18, 64), (34, 66)):  # the call as a horn signal
        at = _bar8(start_bar) + 1.0
        for m, eighths in _motif(root):
            dur = eighths * EIGHTH
            dsp.place(buf, dsp.pan(0.85 * _stab(rng, m, dur * 0.9, 5.0), 0.1), dsp.samples(at * EIGHTH))
            at += eighths
    x = dsp.periodic(dsp.lowpass, dsp.wrap(buf, n), 3600.0)
    return _leaves(x, rng, n, reverb_s=2.2, mix=0.24)


@sound("mus_verdance_urgency", "music", -29.0, **LAYER)
def urgency(rng: np.random.Generator) -> np.ndarray:
    n = _n()
    buf = np.zeros((2, n + dsp.samples(3.0)))
    for bar in range(BARS):
        for s in range(12):  # sixteenths in 6/8
            m = 71 if s % 3 else (74 if s % 6 == 0 else 80)  # B, and the D-G# tritone on the beats
            note = wood(H(m + 12), rng, decay=0.06, hardness=0.7) * (0.55 if s % 3 == 0 else 0.3)
            dsp.place(buf, dsp.pan(note, 0.3 if s % 2 else -0.3), _at(bar, 0.5 * s))
        if bar % 2 == 0:  # the siren: a reed rising a fourth, F# -> B
            m = dsp.samples(2 * BAR)
            u = np.clip(dsp.time_axis(m) / (BAR * 0.9), 0.0, 1.0)
            f = H(54) * 2.0 ** (5.0 * (u * u * (3 - 2 * u)) / 12.0)
            siren = low_reed(f, 2 * BAR * 0.85, rng, bright=4.0, attack=0.3)
            dsp.place(buf, dsp.pan(0.3 * siren, 0.15), _at(bar, 1.0))
    x = dsp.periodic(dsp.lowpass, dsp.wrap(buf, n), 5000.0)
    return _leaves(x, rng, n, reverb_s=1.8, mix=0.2)


@sound("mus_verdance_heavy", "music", -27.0, **LAYER)
def heavy(rng: np.random.Generator) -> np.ndarray:
    n = _n()
    buf = np.zeros((2, n + dsp.samples(3.0)))
    for bar in range(BARS):
        root = _chord(bar)[0]
        m = root + (12 if bar % 2 == 0 else 19)
        dur = BAR * 0.92
        dsp.place(buf, dsp.stereo(0.45 * low_reed(H(m), dur, rng, bright=6.0, attack=0.04)
                                  + 0.25 * low_reed(H(m + 12), dur, rng, bright=5.0, attack=0.04)), _at(bar, 0.0))
        for e, v in ((0.0, 0.9), (3.0, 0.75)):
            dsp.place(buf, dsp.pan(v * log_drum(H(root + 12), rng, decay=0.35, length=1.0, knock=0.6), -0.2),
                      _at(bar, e))
            dsp.place(buf, dsp.pan(0.5 * v * palm(rng, 120.0, 0.6), 0.2), _at(bar, e))
        k = dsp.samples(BAR * 0.6)
        tt = dsp.time_axis(k)
        growl = dsp.sine(H(root + 12) * (1 + 0.02 * np.sin(2 * np.pi * 6 * tt)), k) * dsp.perc(k, 0.01, 0.6)
        dsp.place(buf, dsp.stereo(0.4 * dsp.saturate(growl, 1.4)), _at(bar, 0.0))
    x = dsp.periodic(dsp.lowpass, dsp.wrap(buf, n), 3200.0)
    return _leaves(x, rng, n, reverb_s=2.0, mix=0.2)


# --------------------------------------------------------------------------- stealth


@sound("mus_verdance_stealth_hush", "music", -31.0, **LAYER)
def hush(rng: np.random.Generator) -> np.ndarray:
    n = _n()
    buf = np.zeros((2, n + dsp.samples(6.0)))
    block = BLOCK_BARS * BAR
    for i, (bass, voicing) in enumerate(CHORDS):
        for k, m in enumerate(sorted(voicing)[2:4]):
            fl = flute(H(m + 12), block * 0.6, rng, breath=1.2, attack=3.0, release=3.0, vibrato_cents=3.0)
            dsp.place(buf, dsp.pan(0.3 * fl, -0.6 + 1.2 * k), dsp.samples(i * block + 2 * BAR * k))
        bass_note = soft_sine(H(bass + 12), block, attack=2.5, release=3.0, harmonics=(1.0, 0.2))
        dsp.place(buf, dsp.stereo(0.2 * bass_note), dsp.samples(i * block))
    for bar in range(3, BARS, 5):  # a marimba drop now and then, far off
        m = sorted(_chord(bar)[1])[-1] + 12
        dsp.place(buf, dsp.pan(wood(H(m), rng, decay=0.4, hardness=0.3) * 0.25, 0.4 if bar % 2 else -0.4),
                  _at(bar, 3.0))
    x = dsp.wrap(buf, n)
    leaves = dsp.periodic(dsp.bandpass, np.stack([dsp.pink(n, rng) for _ in range(2)]), 3200.0, 0.6)
    x = x + 0.012 * leaves * (0.6 + 0.4 * _swell(n, 4.0))
    return _leaves(x, rng, n, reverb_s=3.6, mix=0.42)


@sound("mus_verdance_stealth_watch", "music", -29.0, **LAYER)
def watch(rng: np.random.Generator) -> np.ndarray:
    n = _n()
    buf = np.zeros((2, n + dsp.samples(2.0)))
    for bar in range(BARS):
        bass = _chord(bar)[0] + 12
        for e, g in ((0.0, 1.0), (1.0, 0.5)):  # lub-dub on the downbeat
            dsp.place(buf, dsp.stereo(0.6 * g * log_drum(H(bass), rng, decay=0.15, length=0.5, knock=0.15)),
                      _at(bar, e, NUDGE))
        for e in (2.0, 3.5, 5.0):  # finger taps
            m = dsp.samples(0.07)
            tk = dsp.bandpass(dsp.white(m, rng), 2600.0, 3.0) * dsp.perc(m, 0.008, 0.014)
            dsp.place(buf, dsp.pan(0.22 * tk, 0.4), _at(bar, e))
        if bar % 2 == 1:  # the Dorian G# as a shadow
            shadow = soft_sine(H(68), BEAT * 0.9, attack=0.04, release=0.3, harmonics=(1.0, 0.2))
            dsp.place(buf, dsp.pan(0.15 * shadow, -0.3), _at(bar, 3.0))
    x = dsp.periodic(dsp.lowpass, dsp.wrap(buf, n), 5000.0)
    air = dsp.periodic(dsp.bandpass, np.stack([dsp.pink(n, rng) for _ in range(2)]), 1400.0, 0.7)
    x = x + 0.01 * air * (0.6 + 0.4 * _swell(n, 2.0))
    return _leaves(x, rng, n, reverb_s=2.0, mix=0.22)


# --------------------------------------------------------------------------- hits and stings


STING = dict(fmt="ogg", channels=2, folder="music/stings")


def _rush(rng: np.random.Generator, seconds: float, rising: bool = True) -> np.ndarray:
    """Leaves rushing: a band of noise sweeping up (or settling down)."""
    m = dsp.samples(seconds)
    u = dsp.time_axis(m) / seconds
    fc = 500.0 * 9.0 ** (u if rising else 1.0 - u)
    shape = u ** 2.2 if rising else (1.0 - u) ** 1.5
    return dsp.sweep(dsp.pink(m, rng), "bp", fc, 0.8) * shape


@sound("mus_hit_combat_verdance", "sting", -24.0, min_seconds=1.5, max_seconds=3.6, **STING)
def hit_combat(rng: np.random.Generator) -> np.ndarray:
    buf = np.zeros((2, dsp.samples(4.0)))
    dsp.place(buf, dsp.pan(0.5 * _rush(rng, 0.9), np.linspace(-0.5, 0.5, dsp.samples(0.9))), 0)
    down = 0.9
    dsp.place(buf, dsp.stereo(1.1 * log_drum(H(35), rng, decay=0.6, length=1.6, knock=0.7)), dsp.samples(down))
    dsp.place(buf, dsp.pan(0.7 * log_drum(H(42), rng, decay=0.4, length=1.2, knock=0.6), 0.2),
              dsp.samples(down + EIGHTH))
    horn = low_reed(H(47), 1.5, rng, bright=6.0, attack=0.02) + 0.6 * low_reed(H(54), 1.5, rng, bright=5.0,
                                                                                attack=0.02)
    dsp.place(buf, dsp.stereo(0.45 * horn), dsp.samples(down))
    y = dsp.reverb(buf, rng, seconds=2.4, mix=0.28, predelay_ms=15.0, damp=0.6)
    y = dsp.trim_tail(dsp.dc_block(dsp.highpass(y, 30.0)), -60.0)[:, : dsp.samples(3.4)]
    return dsp.fade(y, 0.01, 0.8)


@sound("mus_hit_aftermath_verdance", "sting", -25.0, min_seconds=2.5, max_seconds=5.6, **STING)
def hit_aftermath(rng: np.random.Generator) -> np.ndarray:
    buf = np.zeros((2, dsp.samples(6.0)))
    at = 0.1
    for m, eighths in [(73, 3.0), (71, 7.0)]:  # C# -> B: the flute sighs home
        dur = eighths * EIGHTH
        dsp.place(buf, dsp.pan(0.6 * flute(H(m), dur * 0.95, rng, breath=0.45, attack=0.1), -0.1),
                  dsp.samples(at))
        at += dur
    dsp.place(buf, dsp.pan(0.5 * _rush(rng, 3.0, rising=False), 0.35), dsp.samples(0.4))
    dsp.place(buf, dsp.pan(0.45 * wood(H(71), rng, decay=1.0, hardness=0.4), 0.25), dsp.samples(0.1 + 3 * EIGHTH))
    dsp.place(buf, dsp.stereo(0.3 * log_drum(H(47), rng, decay=0.8, length=2.0, knock=0.1)),
              dsp.samples(0.1 + 3 * EIGHTH))
    y = dsp.reverb(buf, rng, seconds=3.2, mix=0.36, predelay_ms=20.0, damp=0.6)
    y = dsp.trim_tail(dsp.dc_block(dsp.highpass(y, 30.0)), -60.0)[:, : dsp.samples(5.4)]
    return dsp.fade(y, 0.01, 1.2)


ENDING = dict(STING, min_seconds=3.0, max_seconds=6.5)


@sound("mus_sting_victory_verdance", "sting", -22.0, **ENDING)
def sting_victory(rng: np.random.Generator) -> np.ndarray:
    """The call answered upward: F# B, then A B C# landing on the high D over D
    major: the planet's B minor opens into its relative major, the Concord's D."""
    e = 0.2
    buf = np.zeros((2, dsp.samples(7.0)))
    at = 0.2
    notes = [(66, 1.0), (71, 2.0), (69, 1.0), (71, 1.0), (73, 1.0), (74, 8.0)]
    for i, (m, eighths) in enumerate(notes):
        dsp.place(buf, dsp.pan(lead(m, eighths, 0.85 if i < 5 else 1.0, rng, e), 0.05 * (i - 2)),
                  dsp.samples(at))
        at += eighths * e
    for k, m in enumerate([35, 47, 54, 62, 66]):  # Bm under the call
        p = pad_voice(H(m), 1.3, rng, attack=0.4, release=0.8, brightness=2.2)
        dsp.place(buf, p * (0.45 if k == 0 else 0.28), 0)
    lift = 0.2 + 6.0 * e
    for k, m in enumerate([38, 50, 57, 62, 66, 69]):  # D major: home for the Concord
        p = pad_voice(H(m), 2.8, rng, attack=0.35, release=2.0, brightness=3.0)
        dsp.place(buf, p * (0.45 if k == 0 else 0.28), dsp.samples(lift))
    dsp.place(buf, dsp.stereo(0.9 * log_drum(H(38), rng, decay=0.7, length=1.8, knock=0.5)), dsp.samples(lift))
    for k, m in enumerate([74, 78, 81, 86, 90]):
        dsp.place(buf, dsp.pan(0.35 * wood(H(m), rng, decay=0.5, hardness=0.6), -0.4 + 0.2 * k),
                  dsp.samples(lift + 0.08 + k * e * 0.75))
    y = dsp.reverb(buf, rng, seconds=3.2, mix=0.35, predelay_ms=20.0, damp=0.55)
    y = dsp.trim_tail(dsp.dc_block(dsp.highpass(y, 30.0)), -60.0)[:, : dsp.samples(5.8)]
    return dsp.fade(y, 0.002, 1.2)


@sound("mus_sting_defeat_verdance", "sting", -22.0, **ENDING)
def sting_defeat(rng: np.random.Generator) -> np.ndarray:
    """The call falling: F# B A G#, then down to the low B, a breath thinning
    under it as the filter closes."""
    e = 0.27
    buf = np.zeros((2, dsp.samples(7.5)))
    at = 0.3
    for i, (m, eighths) in enumerate([(66, 1.0), (71, 2.0), (69, 1.0), (68, 2.0), (59, 7.0)]):
        v = dsp.lowpass(lead(m, eighths, 0.9, rng, e), 3000.0 - 450.0 * i)
        dsp.place(buf, dsp.pan(v, -0.05 * i), dsp.samples(at))
        at += eighths * e
    for k, m in enumerate([35, 47, 54, 62]):  # Bm, darkening
        p = pad_voice(H(m), 4.5, rng, attack=1.0, release=2.0, brightness=1.8)
        dsp.place(buf, p * (0.45 if k == 0 else 0.25), 0)
    k = dsp.samples(6.0)
    breath = dsp.bandpass(dsp.pink(k, rng), 900.0, 0.6) * dsp.env([(0, 0), (2.5, 1.0), (6.0, 0)], k, 1.0) * 0.35
    dsp.place(buf, dsp.stereo(breath), dsp.samples(0.3))
    dsp.place(buf, dsp.stereo(0.6 * log_drum(H(35), rng, decay=0.9, length=2.4, knock=0.2)),
              dsp.samples(0.3 + 6.0 * e))
    n = buf.shape[-1]
    closing = 2400.0 * (0.15 + 0.85 * np.exp(-dsp.time_axis(n) / 2.6))
    buf = dsp.sweep(buf, "lp", closing, 0.6, block=256)
    y = dsp.reverb(buf, rng, seconds=3.6, mix=0.4, predelay_ms=25.0, damp=0.65)
    y = dsp.trim_tail(dsp.dc_block(dsp.highpass(y, 30.0)), -60.0)[:, : dsp.samples(6.2)]
    return dsp.fade(y, 0.002, 1.4)
