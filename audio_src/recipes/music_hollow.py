"""Hollow Meridian (Phase 8d): the adaptive score, the finale and the ending.

Kessel Reach is warm and dry in D Lydian at 80 BPM in four; Thalassa cold and
wide in F# Aeolian in three; Emberfall hot and heavy in C# Phrygian in four;
Verdance hushed and alive in B Dorian in 6/8. Hollow Meridian is the deck of
an Antecedent megastructure in the dark: vast, cold, reverent, mechanical, a
place that was built and is waiting. **G# Locrian** (G# A B C# D E F#: the
same seven pitches as the Concord's D Lydian, so replies, the Advisor and the
Trail motif never clash, but centred on G#, the raised fourth the Trail motif
has always hung on: here the question is the ground), **52.5 BPM in 5/4**
(3 + 2: a mechanism, not a dance). One loop is 12 bars, 60 beats, 68.57 s
(3 024 000 samples, a multiple of 64 for the native Vorbis encoder).

Chords, three bars each: G#m7(b5) (the tritone G#-D in the chord itself),
E6/9, C#m7(add11), Dmaj7(#11)/G# (the Concord's own chord over the planet's
note, never resolved), back to G#m7(b5) at the loop.

Timbres: no reed, no marimba, no taiko, no forge, no flute. *Bowed metal*
(plate partials 1 : 2 : 2.76 : 5.4, each with a beating twin, a slow swell,
bow noise), *struck stone* (short inharmonic knocks, a dull crack), *glass*
(beating sine pairs, a struck edge), *deep sub drones*, the *Antecedent bell*
(the Custodians' own instrument) and a very large room (6-9 s): a hall the size
of a moon.

The Hollow motif is the Trail motif read backwards: G# B A D (long, short,
short, very long). The place has the answer, but reversed, as if it remembers
it from the other end. The Trail motif itself (D A B G#) rings on the bell in
the `trail` layer and hangs on G#, which here is home: the question is the
ground the planet stands on.

Layers (all synchronised; the MusicDirector fades them on the beat):

  pad        bowed-metal chords, a sub drone on the root, glass halo above
  pulse      the mechanism: glass ticks every three eighths across the 5/4
             bar (a cycle of three bars), stone knocks on beats 1 and 4
  melody     the Hollow motif on bowed metal, a glass strike on each onset
  drive      tension: muted sub eighths on the root (3+3+2+2), metal clanks
  drums      combat: stone drums on 1 and 4, plates, glass grains
  brass      combat: bowed-metal sforzandi on root and fifth, the motif called
  trail      the Trail motif on the Antecedent bell, hanging on G#
  hush       stealth unaware: far glass on chord tones, a stone drop
  watch      stealth suspicious: a stone lub-dub, relay ticks, a D shadow
  melody_b   variation: high glass phrases ending on G#
  melody_c   variation: the motif augmented low on bowed metal, bells above
  pulse_b    variation: the bar the other way round (2 + 3), glass quarters
  drums_b    variation: half time, one huge stone drum, rolling plates
  urgency    base under attack: glass sixteenths of G# against the D-G#
             tritone, a bowed siren rising a fourth G# -> C# every two bars
  heavy      heavy combat: low bowed metal on root and fifth, doubled stone
             drums, a grinding sub
  core_1     the Beacon Core charging (a quarter): its heartbeat, a slow sub
             throb on D, and the Meridian's own dyad D+A shimmering high
  core_2     (half): the Trail motif arpeggiated on bells, climbing through
             the loop, bowed swells
  core_3     (three quarters): the motif as a spinning mechanism, bell and
             glass eighths, a band of light rising for ever

The finale (`mus_core_awakened`, 34 s, on the CoreSound's own player): the
air draws in, a great strike on the planet's tritone G#+D, the Trail motif
stated in full, broad, on bell, bowed metal and glass: D, A, B, and G# held
(the question, as it has been all campaign); then the answer: G# rises to A,
C#, the high D, the bass moves G# -> A -> D, and the Meridian's dyad D+A
sounds with the bells in Dmaj9(#11): the planet's G# becomes the Lydian #11
of the Concord's D, consonant at last. The peak swells and rings, then a calm
tail: the chord thins, one high bell, the dyad alone, the hall.

The ending theme (`res://data/sounds/music/ending.tres`, three layers in
`music/ending/`, 60 BPM, 16 bars, 64 s): quiet and resolved, in D at last:
Dmaj9 -> Bm(add9) -> E/D -> A(add9)/C#, and the A lands on D at every loop.
The Trail motif and its answer on the Meridian lead, Antecedent bells far off.

Attacks stay at 8 ms or softer (native Vorbis pre-echo, ADR 0005).
"""

from __future__ import annotations

import numpy as np

from synth import dsp
from synth.instruments import bell, chime, soft_sine

from . import sound
from .music_kessel_combat import _soft
from .music_meridian import glass_pad

H = dsp.midi_hz

BPM = 52.5
BEAT = 60.0 / BPM
EIGHTH = BEAT / 2.0
BAR_BEATS = 5
BAR = BAR_BEATS * BEAT
BARS = 12
BEATS = BAR_BEATS * BARS
LOOP = BAR * BARS  # 68.57 s
BLOCK_BARS = 3
BAR8 = 2 * BAR_BEATS  # eighths in a bar

# (sub root, voicing) per three-bar block, G# Locrian.
CHORDS = [
    (32, [56, 62, 66, 71, 74]),  # G#m7(b5): G# D F# B D
    (28, [52, 59, 66, 68, 73]),  # E6/9: E B F# G# C#
    (37, [49, 56, 64, 66, 71]),  # C#m7(add11): C# G# E F# B
    (32, [50, 57, 61, 66, 68]),  # Dmaj7(#11)/G#: D A C# F# G# over G#
]

# The Hollow motif: the Trail motif read backwards, G# B A D: (semitones above
# G#, eighths). Long, short, short, very long.
MOTIF = [(0, 4.0), (3, 2.0), (1, 2.0), (6, 8.0)]
# The Trail motif itself, D A B G#: (midi, eighths).
TRAIL = [(74, 2.0), (81, 4.0), (83, 2.0), (80, 8.0)]

LAYER = dict(fmt="ogg", channels=2, loop=True, folder="music/hollow", min_seconds=LOOP - 0.01,
             max_seconds=LOOP + 0.01, bpm=BPM, beats=BEATS, bar_beats=BAR_BEATS)

# Low strikes on the loop's first downbeat land this late, so the onset of a
# deep, slow waveform is not the seam itself. Inaudible as timing.
NUDGE = 0.004


def _n() -> int:
    return dsp.samples(LOOP)


def _chord(bar: int) -> tuple[int, list[int]]:
    return CHORDS[(bar // BLOCK_BARS) % len(CHORDS)]


def _at(bar: int, eighth: float, nudge: float = 0.0) -> int:
    return dsp.samples(bar * BAR + eighth * EIGHTH + nudge)


def _hall(x: np.ndarray, rng: np.random.Generator, n: int, reverb_s: float = 7.0, mix: float = 0.42,
          echo_s: float = 0.0, feedback: float = 0.0, echo_mix: float = 0.0, hp: float = 32.0) -> np.ndarray:
    """The Hollow room: very large and cold; tails fold back over the loop."""
    y = dsp.wrap(x, n)
    if echo_s > 0:
        y = dsp.wrap(dsp.delay(y, echo_s, feedback, echo_mix, 2200.0, ping_pong=True), n)
    y = dsp.wrap(dsp.reverb(y, rng, seconds=reverb_s, mix=mix, predelay_ms=70.0, damp=0.45), n)
    y = dsp.periodic(dsp.highpass, y, hp)
    return y - y.mean(axis=1, keepdims=True)


def _swell(n: int, bars: float, phase: float = 0.0) -> np.ndarray:
    """0..1, one rise and fall every `bars` bars, periodic over the loop."""
    t = dsp.time_axis(n)
    cycles = max(round(LOOP / (bars * BAR)), 1)
    return 0.5 - 0.5 * np.cos(2 * np.pi * cycles * t / LOOP + phase)


def _qf(f: float) -> float:
    """Nearest frequency completing a whole number of cycles in the loop."""
    return max(round(f * LOOP), 1) / LOOP


# --------------------------------------------------------------------------- voices


PLATE = [(1.0, 1.0), (2.0, 0.32), (2.76, 0.2), (4.0, 0.07), (5.4, 0.06)]


def bowed(f: float | np.ndarray, dur: float, rng: np.random.Generator, attack: float = 1.2,
          release: float = 2.0, bright: float = 1.0, bow: float = 0.12) -> np.ndarray:
    """Bowed metal: plate partials, each with a twin a few cents off (a slow
    cold beating), a swell, bow noise around the fundamental."""
    n = dsp.samples(dur + release)
    t = dsp.time_axis(n)
    base = np.full(n, float(f)) if np.ndim(f) == 0 else np.interp(np.arange(n), np.arange(len(f)), f)
    wob = base * (1.0 + 0.001 * np.sin(2 * np.pi * 0.37 * t + float(rng.random()) * 6.28))
    x = np.zeros(n)
    for ratio, amp in PLATE:
        if float(np.max(base)) * ratio >= dsp.NYQUIST * 0.8:
            continue
        a = amp * (bright if ratio > 2.5 else 1.0)
        x += a * (dsp.sine(wob * ratio, n, float(rng.random())) +
                  0.7 * dsp.sine(wob * ratio * dsp.cents(2.5 + ratio), n, float(rng.random())))
    centre = float(np.median(base))
    noise = dsp.bandpass(dsp.white(n, rng), min(centre * 2.0, 9000.0), 3.0) * bow
    return (0.22 * x + noise) * dsp.ar(n, attack, release, max(dur - attack, 0.0))


def stone(f: float, rng: np.random.Generator, decay: float = 0.25, length: float = 1.2,
          crack: float = 0.3) -> np.ndarray:
    """Struck stone: short inharmonic partials (the pitch settles a hair after
    the strike), a dull crack."""
    n = dsp.samples(length)
    t = dsp.time_axis(n)
    out = np.zeros(n)
    for ratio, amp, dk in [(1.0, 1.0, 1.0), (1.58, 0.45, 0.5), (2.31, 0.25, 0.3), (3.1, 0.12, 0.18)]:
        fr = f * ratio
        if fr >= dsp.NYQUIST * 0.8:
            continue
        bend = 1.0 + 0.05 * np.exp(-t / 0.015)
        out += amp * dsp.sine(fr * bend, n, float(rng.random())) * np.exp(-t / (decay * dk))
    hit = dsp.lowpass(dsp.white(n, rng), min(f * 6.0, 5000.0)) * dsp.perc(n, 0.0008, 0.012) * crack
    return _soft((out + hit) * 0.5, 0.008)


def glass(f: float, dur: float, rng: np.random.Generator, attack: float = 0.02, release: float = 1.6,
          beat_hz: float = 0.9, edge: float = 0.2) -> np.ndarray:
    """Glass: a sine and its beating twin, a faint twelfth, a struck edge."""
    n = dsp.samples(dur + release)
    body = dsp.sine(f, n, float(rng.random())) + 0.8 * dsp.sine(f + beat_hz, n, float(rng.random()))
    body += 0.08 * dsp.sine(3.0 * f, n)
    x = body * dsp.ar(n, attack, release, max(dur - attack, 0.0)) * 0.35
    if edge > 0:
        e = chime(min(f * 2.0, 9000.0), 0.02, rng, brightness=0.35, decay=0.2, attack=0.008, tail=0.4)
        x = dsp.mix(x, edge * e)
    return _soft(x, min(0.008, attack))


def ping(f: float, rng: np.random.Generator, decay: float = 0.5) -> np.ndarray:
    """A struck glass ping, short."""
    return glass(f, 0.02, rng, attack=0.008, release=decay, edge=0.3)


def sub(f: float, dur: float, attack: float = 1.5, release: float = 2.5, gain: float = 1.0) -> np.ndarray:
    return gain * soft_sine(f, dur, attack=attack, release=release, harmonics=(1.0, 0.22, 0.06))


def abell(m: float, rng: np.random.Generator, decay: float = 1.2, bright: float = 0.6,
          strike: float = 0.25) -> np.ndarray:
    """The Antecedent bell, softened for the score."""
    return _soft(dsp.lowpass(bell(H(m), rng, decay=decay, brightness=bright, strike=strike), 6000.0), 0.01)


def lead(m: int, eighths: float, vel: float, rng: np.random.Generator, eighth_s: float = EIGHTH) -> np.ndarray:
    """The lead: bowed metal holding the note, a glass strike on its onset."""
    dur = eighths * eighth_s
    b = bowed(H(m), dur * 0.95, rng, attack=min(0.35, dur * 0.3), release=1.6, bright=0.8, bow=0.1)
    g = ping(H(m + 12), rng, decay=0.8) * 0.25
    return dsp.mix(b, g) * vel


def _phrases(rng: np.random.Generator, phrases, voice, extra: float = 9.0) -> np.ndarray:
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


def _block8(block: int) -> float:
    return block * BLOCK_BARS * BAR8


def _drone(n: int, m: float, rng: np.random.Generator, beat: float = 0.12) -> np.ndarray:
    """A loop-periodic sub drone: a sine and its slowly beating twin."""
    f = _qf(H(m))
    f2 = _qf(H(m) + beat)
    return 0.5 * (dsp.sine(f, n, float(rng.random())) + dsp.sine(f2, n, float(rng.random())))


# --------------------------------------------------------------------------- explore


@sound("mus_hollow_explore_pad", "music", -25.0, **LAYER)
def pad(rng: np.random.Generator) -> np.ndarray:
    n = _n()
    buf = np.zeros((2, n + dsp.samples(10.0)))
    block = BLOCK_BARS * BAR
    for i, (root, voicing) in enumerate(CHORDS):
        at = dsp.samples(i * block)
        for k, m in enumerate(voicing):
            v = bowed(H(m), block, rng, attack=3.5, release=5.0, bright=0.55, bow=0.06)
            dsp.place(buf, dsp.pan(v * (0.55 if k == 0 else 0.38), -0.6 + 0.3 * k), at + dsp.samples(0.25 * k))
        for k, m in enumerate(sorted(voicing)[-2:]):  # a cold glass halo on the top notes
            g = glass(H(m + 12), block * 0.7, rng, attack=2.5, release=3.5, beat_hz=0.6, edge=0.0)
            dsp.place(buf, dsp.pan(0.14 * g, -0.5 + k), at + dsp.samples(BAR * (0.5 + k)))
        dsp.place(buf, dsp.stereo(sub(H(root + 12), block, 2.5, 3.5, 0.35)), at)
    x = dsp.wrap(buf, n)
    x += dsp.stereo(0.06 * _drone(n, 32, rng))  # the deck's G# under everything
    breathe = _swell(n, 3.0)
    x = dsp.periodic(dsp.sweep, x, "lp", 900.0 + 1500.0 * breathe, 0.7, block=512) * (0.85 + 0.15 * breathe)
    return _hall(x, rng, n, reverb_s=8.0, mix=0.45)


@sound("mus_hollow_explore_pulse", "music", -29.0, **LAYER)
def pulse(rng: np.random.Generator) -> np.ndarray:
    n = _n()
    buf = np.zeros((2, n + dsp.samples(3.0)))
    total = BARS * BAR8
    for k, e in enumerate(range(0, total, 3)):  # every three eighths: a cycle of three bars
        bar = e // BAR8
        tones = sorted(_chord(bar)[1])[1:]
        m = tones[k % len(tones)] + 12
        note = ping(H(m), rng, decay=0.55) * (0.9 if k % 5 == 0 else 0.6) * float(rng.uniform(0.85, 1.0))
        dsp.place(buf, dsp.pan(note, -0.4 if k % 2 else 0.4), dsp.samples(e * EIGHTH))
    for bar in range(BARS):
        root = _chord(bar)[0]
        dsp.place(buf, dsp.stereo(0.5 * stone(H(root + 24), rng, decay=0.3, length=1.2)), _at(bar, 0.0, NUDGE))
        dsp.place(buf, dsp.pan(0.3 * stone(H(root + 31), rng, decay=0.18, length=0.8), 0.25), _at(bar, 6.0))
    x = dsp.periodic(dsp.lowpass, dsp.wrap(buf, n), 5200.0)
    return _hall(x, rng, n, reverb_s=6.0, mix=0.36, echo_s=EIGHTH * 3, feedback=0.3, echo_mix=0.22)


# Phrases start in eighths; a block is 30 eighths.
PHRASES = [
    (4.0, _motif(68), 1.0, 0.1),                                       # over G#m7(b5): G# B A D
    (34.0, [(64, 4.0), (68, 2.0), (66, 2.0), (71, 8.0)], 0.9, -0.1),  # over E: E G# F# B
    (64.0, [(66, 4.0), (69, 2.0), (68, 2.0), (73, 8.0)], 0.9, 0.05),  # over C#m: F# A G# C#
    (94.0, [(74, 4.0), (71, 2.0), (69, 2.0), (68, 10.0)], 0.95, 0.0),  # over D/G#: D B A, back to G#
]


@sound("mus_hollow_explore_melody", "music", -27.0, **LAYER)
def melody(rng: np.random.Generator) -> np.ndarray:
    buf = _phrases(rng, PHRASES, lead)
    return _hall(buf, rng, _n(), reverb_s=7.5, mix=0.45, echo_s=EIGHTH * 3, feedback=0.3, echo_mix=0.2)


MELODY_B = [
    (8.0, [(80, 2.0), (83, 2.0), (85, 6.0)], 0.8, 0.3),
    (38.0, [(83, 2.0), (80, 2.0), (78, 6.0)], 0.75, -0.25),
    (68.0, [(85, 2.0), (83, 2.0), (80, 6.0)], 0.75, 0.2),
    (98.0, [(86, 2.0), (85, 2.0), (83, 2.0), (80, 10.0)], 0.8, -0.1),  # ends on G#
]


def _high_glass(m: int, eighths: float, vel: float, rng: np.random.Generator) -> np.ndarray:
    dur = eighths * EIGHTH
    return glass(H(m), dur * 0.9, rng, attack=0.04, release=2.0, beat_hz=1.3, edge=0.35) * vel


@sound("mus_hollow_explore_melody_b", "music", -27.0, **LAYER)
def melody_b(rng: np.random.Generator) -> np.ndarray:
    buf = _phrases(rng, MELODY_B, _high_glass)
    return _hall(buf, rng, _n(), reverb_s=8.0, mix=0.48, echo_s=EIGHTH * 2, feedback=0.35, echo_mix=0.25)


def _low_voice(m: int, eighths: float, vel: float, rng: np.random.Generator) -> np.ndarray:
    dur = eighths * EIGHTH
    low = bowed(H(m), dur * 0.95, rng, attack=0.6, release=2.2, bright=0.6, bow=0.15)
    top = abell(m + 24, rng, decay=0.9, bright=0.5) * 0.3
    return dsp.mix(low, top) * vel


MELODY_C = [(4.0, _motif(56, 2.0), 0.9, -0.15), (64.0, _motif(54, 2.0), 0.85, 0.15)]


@sound("mus_hollow_explore_melody_c", "music", -27.0, **LAYER)
def melody_c(rng: np.random.Generator) -> np.ndarray:
    buf = _phrases(rng, MELODY_C, _low_voice)
    return _hall(buf, rng, _n(), reverb_s=7.5, mix=0.42)


@sound("mus_hollow_explore_pulse_b", "music", -29.0, **LAYER)
def pulse_b(rng: np.random.Generator) -> np.ndarray:
    """The bar the other way round: 2 + 3, glass on the quarters."""
    n = _n()
    buf = np.zeros((2, n + dsp.samples(3.0)))
    for bar in range(BARS):
        root, voicing = _chord(bar)
        tones = sorted(voicing)[-3:]
        for q in range(BAR_BEATS):
            m = tones[(q + bar) % 3] + 12
            v = 0.8 if q in (0, 2) else 0.5
            dsp.place(buf, dsp.pan(ping(H(m), rng, decay=0.35) * v, -0.5 + 0.25 * q), _at(bar, 2.0 * q))
        dsp.place(buf, dsp.stereo(0.45 * stone(H(root + 24), rng, decay=0.25)), _at(bar, 0.0, NUDGE))
        dsp.place(buf, dsp.pan(0.35 * stone(H(root + 31), rng, decay=0.2), -0.25), _at(bar, 4.0))
    x = dsp.periodic(dsp.lowpass, dsp.wrap(buf, n), 5600.0)
    return _hall(x, rng, n, reverb_s=6.0, mix=0.34)


QUOTES = [  # the Trail motif on the Antecedent bell, where the melody rests
    (20.0, TRAIL, 1.0),
    (50.0, TRAIL[:2], 0.6),
    (80.0, [(71, 2.0), (78, 4.0), (80, 2.0), (76, 8.0)], 0.8),
    (110.0, TRAIL, 0.85),  # hangs on G#: here, home
]


@sound("mus_hollow_explore_trail", "music", -29.0, **LAYER)
def trail(rng: np.random.Generator) -> np.ndarray:
    n = _n()
    buf = np.zeros((2, n + dsp.samples(10.0)))
    for start, notes, vel in QUOTES:
        at = start
        for i, (m, eighths) in enumerate(notes):
            b = abell(m, rng, decay=0.8 + 0.12 * eighths, bright=0.45, strike=0.15)
            dsp.place(buf, dsp.pan(b * vel * (0.8 if i == 0 else 1.0), -0.3 + 0.2 * i), dsp.samples(at * EIGHTH))
            at += eighths
    x = dsp.wrap(buf, n)
    t = dsp.time_axis(n)
    for k, m in enumerate([68, 74]):  # a faint bell air on G# and D
        # Fullest at the loop point, so the seam sits in a steady tone rather
        # than in near-silence, where the codec's own noise decides the join.
        swell = 0.5 + 0.5 * np.cos(2 * np.pi * (2 + k) * t / LOOP)
        air = 0.5 * (dsp.sine(_qf(H(m)), n) + dsp.sine(_qf(H(m) + 0.3), n))
        x += dsp.pan(0.045 * air * (0.3 + 0.7 * swell), -0.4 + 0.8 * k)
    return _hall(x, rng, n, reverb_s=8.0, mix=0.48, echo_s=EIGHTH * 3, feedback=0.25, echo_mix=0.2)


# --------------------------------------------------------------------------- tension and combat


DRIVE_ACCENT = [1.0, 0.4, 0.45, 0.85, 0.4, 0.45, 0.8, 0.4, 0.75, 0.4]  # 3 + 3 + 2 + 2


@sound("mus_hollow_tension_drive", "music", -28.0, **LAYER)
def drive(rng: np.random.Generator) -> np.ndarray:
    n = _n()
    buf = np.zeros((2, n + dsp.samples(3.0)))
    for bar in range(BARS):
        root = _chord(bar)[0] + 24
        for s in range(BAR8):
            low = soft_sine(H(root), EIGHTH * 0.5, attack=0.01, release=0.12, harmonics=(1.0, 0.4, 0.15))
            dsp.place(buf, dsp.stereo(0.7 * DRIVE_ACCENT[s] * low), _at(bar, s))
            if DRIVE_ACCENT[s] > 0.7:  # a metal clank on the accents
                clank = stone(H(root + 36), rng, decay=0.05, length=0.3, crack=0.6)
                dsp.place(buf, dsp.pan(0.3 * clank, 0.35 if s % 2 else -0.35), _at(bar, s))
        if bar % 2 == 1:  # D, the tritone, as a shadow on the last eighth
            d = soft_sine(H(62), EIGHTH * 0.5, attack=0.01, release=0.1, harmonics=(1.0, 0.3))
            dsp.place(buf, dsp.pan(0.3 * d, -0.25), _at(bar, 9.0))
        if bar % BLOCK_BARS == BLOCK_BARS - 1:  # air drawn in before the next block
            m = dsp.samples(BAR)
            u = dsp.time_axis(m) / BAR
            air = dsp.sweep(dsp.pink(m, rng), "bp", 300.0 * 6.0 ** u, 1.0) * u ** 2 * 0.15
            dsp.place(buf, dsp.stereo(air), dsp.samples(bar * BAR))
    x = dsp.periodic(dsp.lowpass, dsp.wrap(buf, n), 2600.0)
    return _hall(x, rng, n, reverb_s=5.0, mix=0.3)


def grains(rng: np.random.Generator, gain: float) -> np.ndarray:
    """Glass grains shaken: a burst of tiny high pings."""
    m = dsp.samples(0.1)
    x = dsp.bandpass(dsp.white(m, rng), 7000.0, 2.0) * dsp.env([(0, 0), (0.01, 1.0), (0.1, 0)], m, 1.5)
    return x * gain


def plate(rng: np.random.Generator, f: float = 310.0, decay: float = 0.4) -> np.ndarray:
    """A struck metal plate: inharmonic, a little bright."""
    n = dsp.samples(decay * 4.0)
    x = dsp.partials(f, n, [(1.0, 1.0, decay), (2.76, 0.6, decay * 0.6), (5.4, 0.35, decay * 0.3),
                            (8.93, 0.15, decay * 0.15)], rng)
    return _soft(x * 0.5, 0.008)


@sound("mus_hollow_combat_drums", "music", -26.0, **LAYER)
def drums(rng: np.random.Generator) -> np.ndarray:
    n = _n()
    buf = np.zeros((2, n + dsp.samples(3.0)))
    for bar in range(BARS):
        root = _chord(bar)[0]
        fill = bar % 4 == 3
        for e, f, v, side in [(0.0, H(root + 12), 1.0, 0.0), (3.0, H(root + 19), 0.6, 0.25),
                              (6.0, H(root + 12), 0.9, 0.0), (8.0, H(root + 24), 0.55, -0.25)]:
            if fill and e >= 6.0:
                continue
            drum = stone(f, rng, decay=0.45, length=1.6, crack=0.5)
            dsp.place(buf, dsp.pan(v * drum, side), _at(bar, e, NUDGE if e == 0.0 else 0.0))
        if not fill:
            dsp.place(buf, dsp.pan(0.35 * plate(rng, 290.0), -0.3), _at(bar, 4.0))
        else:
            for k in range(8):  # plates falling through the bar's end
                dsp.place(buf, dsp.pan((0.25 + 0.04 * k) * plate(rng, 420.0 - 18.0 * k, 0.2), 0.4 - 0.1 * k),
                          _at(bar, 6.0 + 0.5 * k))
        for e in range(BAR8):
            dsp.place(buf, dsp.pan(grains(rng, 0.16 if e % 3 == 0 else 0.07), 0.5), _at(bar, e + 0.5))
    x = dsp.saturate(dsp.wrap(buf, n) * 1.1, 0.4)
    return _hall(x, rng, n, reverb_s=4.5, mix=0.26)


@sound("mus_hollow_combat_drums_b", "music", -26.0, **LAYER)
def drums_b(rng: np.random.Generator) -> np.ndarray:
    n = _n()
    buf = np.zeros((2, n + dsp.samples(3.0)))
    for bar in range(BARS):
        root = _chord(bar)[0]
        if bar % 2 == 0:
            dsp.place(buf, dsp.stereo(1.1 * stone(H(root + 12), rng, decay=0.9, length=2.4, crack=0.6)),
                      _at(bar, 0.0, NUDGE))
        dsp.place(buf, dsp.pan(0.5 * stone(H(root + 19), rng, decay=0.3), 0.25), _at(bar, 6.0))
        if bar % 4 == 3:
            for k in range(10):  # rolling plates into the next phrase
                dsp.place(buf, dsp.pan(0.22 * plate(rng, 500.0 - 20.0 * k, 0.18), -0.45 + 0.1 * k),
                          _at(bar, 3.0 + 0.5 * k))
        for e in (2.0, 7.0):
            dsp.place(buf, dsp.pan(grains(rng, 0.12), -0.45), _at(bar, e))
    x = dsp.saturate(dsp.wrap(buf, n), 0.4)
    return _hall(x, rng, n, reverb_s=5.0, mix=0.28)


def _stab(rng: np.random.Generator, m: int, dur: float, bright: float = 1.2) -> np.ndarray:
    """A bowed-metal sforzando: a hard bow, swelling, then let go."""
    x = bowed(H(m), dur, rng, attack=0.03, release=0.5, bright=bright, bow=0.3)
    k = len(x)
    return x * (1.0 + 0.6 * dsp.perc(k, 0.01, 0.12))


@sound("mus_hollow_combat_brass", "music", -27.0, **LAYER)
def brass(rng: np.random.Generator) -> np.ndarray:
    n = _n()
    buf = np.zeros((2, n + dsp.samples(4.0)))
    for bar in range(BARS):
        root = _chord(bar)[0] + 24
        calling = bar % BLOCK_BARS == 1
        steps = [(0.0, 1.0), (6.0, 0.8)] if not calling else [(0.0, 1.0)]
        for at, v in steps:
            for k, m in enumerate([root, root + 7, root + 12]):
                note = _stab(rng, m, EIGHTH * 1.6, 1.0 + 0.3 * k)
                dsp.place(buf, dsp.pan(note * v * (0.8 if k == 0 else 0.55), -0.3 + 0.3 * k), _at(bar, at))
            dsp.place(buf, dsp.pan(0.3 * abell(root + 24, rng, decay=0.5, bright=0.8, strike=0.5), 0.3),
                      _at(bar, at))
    for block, root in ((0, 56), (2, 54)):  # the motif called out, low
        at = _block8(block) + BAR8 + 1.0
        for m, eighths in _motif(root):
            dur = eighths * EIGHTH
            dsp.place(buf, dsp.pan(0.8 * _stab(rng, m, dur * 0.9, 0.9), 0.1), dsp.samples(at * EIGHTH))
            at += eighths
    x = dsp.periodic(dsp.lowpass, dsp.wrap(buf, n), 4000.0)
    return _hall(x, rng, n, reverb_s=5.0, mix=0.3)


@sound("mus_hollow_urgency", "music", -29.0, **LAYER)
def urgency(rng: np.random.Generator) -> np.ndarray:
    n = _n()
    buf = np.zeros((2, n + dsp.samples(3.0)))
    for bar in range(BARS):
        for s in range(2 * BAR8):  # sixteenths
            m = 80 if s % 4 else (74 if s % 8 == 0 else 80 + 6)  # G#, and the D-G# tritone on the beats
            note = ping(H(m + 12), rng, decay=0.08) * (0.55 if s % 4 == 0 else 0.3)
            dsp.place(buf, dsp.pan(note, 0.3 if s % 2 else -0.3), _at(bar, 0.5 * s))
        if bar % 2 == 0:  # the siren: bowed metal rising a fourth, G# -> C#
            m = dsp.samples(2 * BAR)
            u = np.clip(dsp.time_axis(m) / (BAR * 0.9), 0.0, 1.0)
            f = H(56) * 2.0 ** (5.0 * (u * u * (3 - 2 * u)) / 12.0)
            siren = bowed(f, 2 * BAR * 0.85, rng, attack=0.4, release=0.8, bright=1.0, bow=0.2)
            dsp.place(buf, dsp.pan(0.4 * siren, 0.15), _at(bar, 1.0))
    x = dsp.periodic(dsp.lowpass, dsp.wrap(buf, n), 6000.0)
    return _hall(x, rng, n, reverb_s=4.0, mix=0.24)


@sound("mus_hollow_heavy", "music", -27.0, **LAYER)
def heavy(rng: np.random.Generator) -> np.ndarray:
    n = _n()
    buf = np.zeros((2, n + dsp.samples(4.0)))
    for bar in range(BARS):
        root = _chord(bar)[0]
        for half, interval in ((0.0, 12), (5.0, 19)):
            dur = BAR * 0.46
            low = bowed(H(root + interval), dur, rng, attack=0.05, release=0.6, bright=1.3, bow=0.25)
            dsp.place(buf, dsp.stereo(0.7 * low), _at(bar, half))
        for e, v in ((0.0, 0.9), (3.0, 0.6), (6.0, 0.8)):
            dsp.place(buf, dsp.pan(v * stone(H(root + 12), rng, decay=0.4, length=1.4, crack=0.6), -0.2),
                      _at(bar, e, NUDGE if e == 0.0 else 0.0))
            dsp.place(buf, dsp.pan(0.4 * v * plate(rng, 240.0, 0.25), 0.2), _at(bar, e))
        k = dsp.samples(BAR * 0.6)
        tt = dsp.time_axis(k)
        growl = dsp.sine(H(root + 24) * (1 + 0.02 * np.sin(2 * np.pi * 5 * tt)), k) * dsp.perc(k, 0.01, 0.8)
        dsp.place(buf, dsp.stereo(0.35 * dsp.saturate(growl, 1.4)), _at(bar, 0.0))
    x = dsp.periodic(dsp.lowpass, dsp.wrap(buf, n), 3400.0)
    return _hall(x, rng, n, reverb_s=4.5, mix=0.25)


# --------------------------------------------------------------------------- stealth


@sound("mus_hollow_stealth_hush", "music", -31.0, **LAYER)
def hush(rng: np.random.Generator) -> np.ndarray:
    n = _n()
    buf = np.zeros((2, n + dsp.samples(8.0)))
    block = BLOCK_BARS * BAR
    for i, (root, voicing) in enumerate(CHORDS):
        for k, m in enumerate(sorted(voicing)[2:4]):
            g = glass(H(m + 12), block * 0.6, rng, attack=3.0, release=3.5, beat_hz=0.5, edge=0.0)
            dsp.place(buf, dsp.pan(0.35 * g, -0.6 + 1.2 * k), dsp.samples(i * block + BAR * k))
        dsp.place(buf, dsp.stereo(sub(H(root + 12), block, 2.5, 3.0, 0.2)), dsp.samples(i * block))
    for bar in range(1, BARS, 4):  # a stone drop now and then, far off
        m = sorted(_chord(bar)[1])[0] + 12
        dsp.place(buf, dsp.pan(0.25 * stone(H(m), rng, decay=0.3), 0.4 if bar % 2 else -0.4), _at(bar, 6.0))
    x = dsp.wrap(buf, n)
    air = dsp.periodic(dsp.bandpass, np.stack([dsp.pink(n, rng) for _ in range(2)]), 900.0, 0.5)
    x = x + 0.01 * air * (0.6 + 0.4 * _swell(n, 3.0))
    return _hall(x, rng, n, reverb_s=8.5, mix=0.5)


@sound("mus_hollow_stealth_watch", "music", -29.0, **LAYER)
def watch(rng: np.random.Generator) -> np.ndarray:
    n = _n()
    buf = np.zeros((2, n + dsp.samples(3.0)))
    for bar in range(BARS):
        root = _chord(bar)[0] + 24
        for e, g in ((0.0, 1.0), (1.0, 0.5)):  # lub-dub on the downbeat
            dsp.place(buf, dsp.stereo(0.6 * g * stone(H(root), rng, decay=0.2, length=0.8, crack=0.15)),
                      _at(bar, e, NUDGE))
        for e in (3.0, 5.5, 8.0):  # relay ticks
            m = dsp.samples(0.05)
            tk = dsp.bandpass(dsp.white(m, rng), 3200.0, 4.0) * dsp.perc(m, 0.008, 0.01)
            dsp.place(buf, dsp.pan(0.22 * tk, 0.45), _at(bar, e))
        if bar % 2 == 1:  # D, the tritone, as a shadow
            shadow = soft_sine(H(62), BEAT * 1.6, attack=0.05, release=0.4, harmonics=(1.0, 0.2))
            dsp.place(buf, dsp.pan(0.15 * shadow, -0.3), _at(bar, 6.0))
    x = dsp.periodic(dsp.lowpass, dsp.wrap(buf, n), 5000.0)
    air = dsp.periodic(dsp.bandpass, np.stack([dsp.pink(n, rng) for _ in range(2)]), 600.0, 0.7)
    x = x + 0.012 * air * (0.6 + 0.4 * _swell(n, 2.0))
    return _hall(x, rng, n, reverb_s=5.0, mix=0.3)


# --------------------------------------------------------------------------- the Core


@sound("mus_hollow_core_1", "music", -30.0, **LAYER)
def core_1(rng: np.random.Generator) -> np.ndarray:
    """A quarter charged: the Core's heartbeat (a sub throb on D, twice a
    bar), and the Meridian's own dyad D+A shimmering high above the planet."""
    n = _n()
    buf = np.zeros((2, n + dsp.samples(4.0)))
    for bar in range(BARS):
        for e, v in ((0.0, 1.0), (1.0, 0.55), (6.0, 0.8)):
            m = dsp.samples(EIGHTH * 1.8)
            tt = dsp.time_axis(m)
            beat = dsp.sine(H(38) * (1.0 + 0.08 * np.exp(-tt / 0.03)), m) + 0.3 * dsp.sine(H(50), m)
            beat *= dsp.env([(0, 0), (0.012, 1.0), (EIGHTH * 1.8, 0)], m, 2.0)
            dsp.place(buf, dsp.stereo(0.5 * v * beat), _at(bar, e, NUDGE))
    x = dsp.wrap(buf, n)
    t = dsp.time_axis(n)
    for k, m in enumerate([86, 93]):  # D6 + A6, the Meridian dyad, beating slowly
        sh = 0.5 * (dsp.sine(_qf(H(m)), n) + dsp.sine(_qf(H(m) + 0.8 + 0.3 * k), n))
        trem = 0.75 + 0.25 * np.sin(2 * np.pi * 24 * t / LOOP + k)
        x += dsp.pan(0.05 * sh * trem * (0.6 + 0.4 * _swell(n, 3.0, k)), -0.4 + 0.8 * k)
    return _hall(x, rng, n, reverb_s=6.0, mix=0.38)


@sound("mus_hollow_core_2", "music", -29.0, **LAYER)
def core_2(rng: np.random.Generator) -> np.ndarray:
    """Half charged: the Trail motif arpeggiated on bells in quarter notes,
    climbing an octave through each block, bowed swells under it."""
    n = _n()
    buf = np.zeros((2, n + dsp.samples(8.0)))
    notes = [m for m, _ in TRAIL]
    for bar in range(BARS):
        lift = 12 if bar % BLOCK_BARS == 2 else 0
        for q in range(BAR_BEATS):
            m = notes[(bar * BAR_BEATS + q) % 4] - 12 + lift
            b = abell(m, rng, decay=0.7, bright=0.55, strike=0.2) * (0.8 if q == 0 else 0.55)
            dsp.place(buf, dsp.pan(b, -0.5 + 0.25 * q), _at(bar, 2.0 * q))
    block = BLOCK_BARS * BAR
    for i, (root, voicing) in enumerate(CHORDS):
        top = sorted(voicing)[-1]
        sw = bowed(H(top), block * 0.7, rng, attack=block * 0.45, release=2.5, bright=0.9, bow=0.18)
        dsp.place(buf, dsp.stereo(0.5 * sw), dsp.samples(i * block))
    x = dsp.periodic(dsp.lowpass, dsp.wrap(buf, n), 6500.0)
    return _hall(x, rng, n, reverb_s=6.5, mix=0.4, echo_s=BEAT, feedback=0.25, echo_mix=0.18)


@sound("mus_hollow_core_3", "music", -29.0, **LAYER)
def core_3(rng: np.random.Generator) -> np.ndarray:
    """Three quarters: the motif spinning as a mechanism (bell and glass
    eighths, D A B G#), and a band of light that rises for ever (a Shepard
    figure of filtered noise and glass partials)."""
    n = _n()
    buf = np.zeros((2, n + dsp.samples(4.0)))
    cyc = [74, 81, 83, 80]
    for bar in range(BARS):
        for e in range(BAR8):
            m = cyc[(bar * BAR8 + e) % 4] + (12 if e % 5 == 0 else 0)
            note = ping(H(m), rng, decay=0.25) * (0.7 if e % 5 == 0 else 0.4)
            dsp.place(buf, dsp.pan(note, 0.4 * np.sin(e)), _at(bar, e))
    x = dsp.wrap(buf, n)
    t = dsp.time_axis(n)
    # The Shepard band: four octaves of a rising glide, each fading in and out
    # with its place in the cycle; one cycle per block, so it loops.
    cycles = len(CHORDS)
    u = (t * cycles / LOOP) % 1.0
    for k in range(4):
        pos = (u + k / 4.0) % 1.0
        f = 300.0 * 2.0 ** (4.0 * pos)
        amp = np.sin(np.pi * pos) ** 2
        cycles_total = float(np.sum(f)) / dsp.SR
        f = f * round(cycles_total) / cycles_total  # a whole number of cycles per loop: seamless
        tone = np.sin(2 * np.pi * np.cumsum(f) / dsp.SR)
        x += dsp.stereo(0.025 * amp * tone)
    light = dsp.periodic(dsp.sweep, np.stack([dsp.pink(n, rng) for _ in range(2)]), "bp",
                         1200.0 * 2.0 ** (2.0 * u), 2.0, block=256)
    x += 0.02 * light
    return _hall(x, rng, n, reverb_s=6.0, mix=0.36)


# --------------------------------------------------------------------------- hits and stings


STING = dict(fmt="ogg", channels=2, folder="music/stings")


def _draw_in(rng: np.random.Generator, seconds: float) -> np.ndarray:
    """Air drawn into the hall: a band of noise sweeping up, growing."""
    m = dsp.samples(seconds)
    u = dsp.time_axis(m) / seconds
    return dsp.sweep(dsp.pink(m, rng), "bp", 200.0 * 12.0 ** u, 0.9) * u ** 2.2


def _sting_space(buf: np.ndarray, rng: np.random.Generator, seconds: float, mix: float, keep: float,
                 fade_out: float) -> np.ndarray:
    y = dsp.reverb(buf, rng, seconds=seconds, mix=mix, predelay_ms=50.0, damp=0.5)
    y = dsp.trim_tail(dsp.dc_block(dsp.highpass(y, 30.0)), -60.0)[:, : dsp.samples(keep)]
    return dsp.fade(y, 0.01, fade_out)


@sound("mus_hit_combat_hollow_meridian", "sting", -24.0, min_seconds=1.5, max_seconds=3.6, **STING)
def hit_combat(rng: np.random.Generator) -> np.ndarray:
    buf = np.zeros((2, dsp.samples(4.0)))
    dsp.place(buf, dsp.pan(0.5 * _draw_in(rng, 0.9), np.linspace(-0.5, 0.5, dsp.samples(0.9))), 0)
    down = 0.9
    dsp.place(buf, dsp.stereo(1.1 * stone(H(44), rng, decay=0.8, length=2.0, crack=0.8)), dsp.samples(down))
    dsp.place(buf, dsp.pan(0.6 * stone(H(51), rng, decay=0.5, length=1.4, crack=0.6), 0.2),
              dsp.samples(down + EIGHTH))
    dsp.place(buf, dsp.stereo(0.6 * _stab(rng, 44, 1.4, 1.2) + 0.4 * _stab(rng, 50, 1.4, 1.0)), dsp.samples(down))
    return _sting_space(buf, rng, 3.0, 0.3, 3.4, 0.8)


@sound("mus_hit_aftermath_hollow_meridian", "sting", -25.0, min_seconds=2.5, max_seconds=5.6, **STING)
def hit_aftermath(rng: np.random.Generator) -> np.ndarray:
    buf = np.zeros((2, dsp.samples(6.0)))
    at = 0.1
    for m, eighths in [(69, 3.0), (68, 7.0)]:  # A -> G#: the metal sighs back to the deck
        dur = eighths * EIGHTH * 0.6
        dsp.place(buf, dsp.pan(0.7 * bowed(H(m), dur, rng, attack=0.2, release=1.5, bright=0.7), -0.1),
                  dsp.samples(at))
        at += dur
    dsp.place(buf, dsp.pan(0.45 * abell(80, rng, decay=1.3, bright=0.5), 0.25), dsp.samples(0.1 + 3 * EIGHTH * 0.6))
    dsp.place(buf, dsp.stereo(0.3 * stone(H(44), rng, decay=1.0, length=2.4, crack=0.1)),
              dsp.samples(0.1 + 3 * EIGHTH * 0.6))
    return _sting_space(buf, rng, 5.0, 0.42, 5.4, 1.2)


ENDING = dict(STING, min_seconds=3.0, max_seconds=6.5)


@sound("mus_sting_victory_hollow_meridian", "sting", -22.0, **ENDING)
def sting_victory(rng: np.random.Generator) -> np.ndarray:
    """The deck answers: G# lifts to A, then D: the planet's ground turns into
    the Concord's home chord, bells and glass climbing."""
    e = 0.24
    buf = np.zeros((2, dsp.samples(7.0)))
    at = 0.2
    for i, (m, eighths) in enumerate([(68, 2.0), (71, 1.0), (69, 1.0), (73, 1.0), (74, 8.0)]):
        dsp.place(buf, dsp.pan(lead(m, eighths, 0.9 if i < 4 else 1.0, rng, e), 0.05 * (i - 2)), dsp.samples(at))
        at += eighths * e
    for k, m in enumerate([44, 56, 62, 66, 71]):  # G#m7(b5) under the rise
        dsp.place(buf, dsp.stereo(bowed(H(m), 1.2, rng, attack=0.3, release=0.8, bright=0.6) * (0.5 if k == 0 else 0.3)), 0)
    lift = 0.2 + 5.0 * e
    for k, m in enumerate([38, 50, 57, 61, 66, 68]):  # Dmaj7(#11): G# is the #11, home
        dsp.place(buf, dsp.stereo(bowed(H(m), 2.8, rng, attack=0.3, release=2.0, bright=0.8) * (0.5 if k == 0 else 0.3)),
                  dsp.samples(lift))
    dsp.place(buf, dsp.stereo(0.6 * abell(62, rng, decay=1.6, bright=0.7, strike=0.4)), dsp.samples(lift))
    for k, m in enumerate([74, 78, 81, 86, 92]):
        dsp.place(buf, dsp.pan(0.3 * ping(H(m), rng, decay=1.2), -0.4 + 0.2 * k), dsp.samples(lift + 0.1 + k * e * 0.7))
    return _sting_space(buf, rng, 4.5, 0.4, 5.9, 1.2)


@sound("mus_sting_defeat_hollow_meridian", "sting", -22.0, **ENDING)
def sting_defeat(rng: np.random.Generator) -> np.ndarray:
    """The motif falls into the dark: G# B A, then down to the low G#, the hall
    swallowing it as the filter closes."""
    e = 0.3
    buf = np.zeros((2, dsp.samples(7.5)))
    at = 0.3
    for i, (m, eighths) in enumerate([(68, 2.0), (71, 1.0), (69, 1.0), (56, 8.0)]):
        v = dsp.lowpass(lead(m, eighths, 0.9, rng, e), 3200.0 - 500.0 * i)
        dsp.place(buf, dsp.pan(v, -0.05 * i), dsp.samples(at))
        at += eighths * e
    for k, m in enumerate([44, 56, 62, 66]):
        dsp.place(buf, dsp.stereo(bowed(H(m), 4.5, rng, attack=1.0, release=2.0, bright=0.5) * (0.5 if k == 0 else 0.28)), 0)
    dsp.place(buf, dsp.stereo(0.6 * stone(H(32 + 12), rng, decay=1.0, length=2.6, crack=0.3)), dsp.samples(0.3 + 4.0 * e))
    n = buf.shape[-1]
    closing = 2600.0 * (0.12 + 0.88 * np.exp(-dsp.time_axis(n) / 2.4))
    buf = dsp.sweep(buf, "lp", closing, 0.6, block=256)
    return _sting_space(buf, rng, 6.0, 0.48, 6.2, 1.4)


# --------------------------------------------------------------------------- the awakening


AWAKE = dict(fmt="ogg", channels=2, folder="music/finale")


def _dyad(lo: float, hi: float, dur: float, attack: float = 0.6, release: float = 3.0) -> np.ndarray:
    """The Meridian's own voice, as music: a pure sine dyad with its slow
    tremolo (the Advisor's colour, without the ship channel)."""
    x = soft_sine(lo, dur, attack, release, (1.0, 0.06)) + 0.8 * soft_sine(hi, dur, attack, release, (1.0, 0.04))
    t = dsp.time_axis(len(x))
    return x * (1.0 - 0.15 * (0.5 + 0.5 * np.sin(2 * np.pi * 5.5 * t)))


@sound("mus_core_awakened", "sting", -21.0, min_seconds=30.0, max_seconds=36.0, **AWAKE)
def core_awakened(rng: np.random.Generator) -> np.ndarray:
    """The end of the Trail: the motif stated in full and answered (see the
    module notes). 0-4 s the air draws in; 4 s the strike; 4.5-15 s the
    motif D A B G# (G# held); 15-19 s the answer A, C#, high D; 19-26 s the
    peak in Dmaj9(#11) with the Meridian dyad; 26-34 s the calm tail."""
    total = 34.0
    buf = np.zeros((2, dsp.samples(total + 2.0)))
    # 0-4 s: the hall draws breath; a sub rises under it; bells swelled backwards.
    k = dsp.samples(4.0)
    u = dsp.time_axis(k) / 4.0
    dsp.place(buf, dsp.pan(0.7 * _draw_in(rng, 4.0), np.linspace(-0.6, 0.6, k)), 0)
    rise = dsp.sine(H(32) * 2.0 ** (12.0 * u ** 2 / 12.0), k) * u ** 2 * 0.5
    dsp.place(buf, dsp.stereo(rise), 0)
    for j, m in enumerate([68, 74]):
        rev = abell(m, rng, decay=1.0, bright=0.6)[: dsp.samples(2.5)][::-1]
        dsp.place(buf, dsp.pan(0.5 * rev, -0.4 + 0.8 * j), dsp.samples(1.5))
    # 4 s: the strike on the planet's tritone, G# and D.
    strike = 4.0
    for j, (m, g) in enumerate([(44, 1.0), (50, 0.8), (56, 0.6), (62, 0.5)]):
        b = _soft(bell(H(m), rng, decay=2.5, brightness=0.8, strike=0.8), 0.008)
        dsp.place(buf, dsp.pan(g * b, -0.3 + 0.2 * j), dsp.samples(strike))
    dsp.place(buf, dsp.stereo(1.0 * stone(H(32 + 12), rng, decay=1.5, length=3.0, crack=0.8)), dsp.samples(strike))
    # The ground: G#m7(b5) bowed, 4-15 s.
    for j, m in enumerate([44, 56, 62, 66, 71]):
        dsp.place(buf, dsp.pan(bowed(H(m), 11.0, rng, attack=2.5, release=3.0, bright=0.6) * (0.45 if j == 0 else 0.3),
                               -0.5 + 0.25 * j), dsp.samples(strike))
    dsp.place(buf, dsp.stereo(sub(H(44), 11.0, 2.0, 3.0, 0.4)), dsp.samples(strike))
    # 4.5-15 s: the Trail motif in full, broad: D (1.6), A (3.2), B (1.6), G# (held 4.1).
    at = 4.5
    for i, (m, dur) in enumerate([(74, 1.6), (81, 3.2), (83, 1.6), (80, 4.1)]):
        b = abell(m, rng, decay=1.2 + 0.5 * dur, bright=0.7, strike=0.4)
        bw = bowed(H(m - 12), dur, rng, attack=0.25, release=1.8, bright=0.8, bow=0.12)
        g = glass(H(m + 12), dur, rng, attack=0.15, release=2.0, beat_hz=1.1, edge=0.25)
        dsp.place(buf, dsp.pan(dsp.mix(0.6 * b, 0.55 * bw, 0.25 * g), -0.2 + 0.13 * i), dsp.samples(at))
        at += dur
    # 15-19 s: the answer. G# rises to A, C#, the high D; the bass G# -> A -> D.
    ans = 15.0
    for i, (m, dur) in enumerate([(81, 1.3), (85, 1.3), (86, 9.0)]):
        b = abell(m, rng, decay=1.4 + 0.3 * dur, bright=0.75, strike=0.5)
        bw = bowed(H(m - 12), dur, rng, attack=0.2, release=3.0, bright=0.9, bow=0.12)
        g = glass(H(m + 12), dur, rng, attack=0.1, release=3.0, beat_hz=0.8, edge=0.3)
        dsp.place(buf, dsp.pan(dsp.mix(0.65 * b, 0.6 * bw, 0.3 * g), 0.15 * (i - 1)), dsp.samples(ans + 1.3 * i))
    for j, (m, at_s, dur) in enumerate([(45, ans, 1.3), (50 - 12, ans + 2.6, 11.0)]):  # A, then D
        dsp.place(buf, dsp.stereo(sub(H(m + 12), dur, 0.4, 3.5, 0.45)), dsp.samples(at_s))
    # 17.6-30 s: home. Dmaj9(#11): D A C# E F# G#, the planet's G# as the #11.
    home = ans + 2.6
    for j, m in enumerate([38, 50, 57, 61, 64, 66, 68]):
        p = bowed(H(m), 9.0, rng, attack=1.6, release=5.0, bright=0.8, bow=0.08)
        dsp.place(buf, dsp.pan(p * (0.45 if j == 0 else 0.3), -0.6 + 0.2 * j), dsp.samples(home))
    for j, m in enumerate([50, 57, 62, 69]):  # the bells ring home
        dsp.place(buf, dsp.pan(0.55 * abell(m, rng, decay=3.0, bright=0.7, strike=0.4), -0.45 + 0.3 * j),
                  dsp.samples(home + 0.05 * j))
    # The Meridian's dyad joins the bells: D+A, then its octave.
    dsp.place(buf, dsp.stereo(0.5 * _dyad(H(74), H(81), 8.0, 1.0, 4.0)), dsp.samples(home + 0.6))
    dsp.place(buf, dsp.stereo(0.3 * _dyad(H(86), H(93), 6.0, 1.5, 4.0)), dsp.samples(home + 2.0))
    # The peak's shimmer: glass on the chord tones, falling like light.
    for j, m in enumerate([93, 90, 88, 86, 85, 81, 80, 78]):
        dsp.place(buf, dsp.pan(0.18 * ping(H(m), rng, decay=1.6), 0.6 - 0.15 * j), dsp.samples(home + 1.2 + 0.45 * j))
    # 26-34 s: the calm tail. One high bell D, the dyad alone, the hall.
    tail = 26.5
    dsp.place(buf, dsp.pan(0.35 * abell(86, rng, decay=2.5, bright=0.5, strike=0.2), 0.2), dsp.samples(tail))
    dsp.place(buf, dsp.stereo(0.28 * _dyad(H(62), H(69), 4.0, 2.0, 3.5)), dsp.samples(tail + 0.8))
    # The arc of the whole: a gentle level shape (draw in, peak, settle).
    n = buf.shape[-1]
    shape = dsp.env([(0, 0.7), (4.0, 0.9), (15.0, 0.95), (19.0, 1.1), (26.0, 1.0), (total, 0.7),
                     (n / dsp.SR, 0.7)], n, 1.0)
    buf = buf * shape
    y = dsp.reverb(buf, rng, seconds=8.0, mix=0.4, predelay_ms=60.0, damp=0.45)
    y = dsp.dc_block(dsp.highpass(y, 30.0))[:, : dsp.samples(total)]
    return dsp.fade(y, 0.02, 4.0)


# --------------------------------------------------------------------------- the ending theme


END_BPM = 60.0
END_BEAT = 60.0 / END_BPM
END_BAR = 4 * END_BEAT
END_BARS = 16
END_LOOP = END_BAR * END_BARS  # 64 s: 2 822 400 samples, a multiple of 64
END_CHORDS = [
    (38, [50, 57, 61, 64, 66]),  # Dmaj9: D A C# E F#
    (35, [47, 54, 61, 62, 66]),  # Bm(add9)
    (38, [52, 56, 59, 64, 66]),  # E(add9)/D: the Lydian II over D, the ship's colour
    (37, [45, 52, 57, 59, 64]),  # A(add9)/C#: and home to D at the loop
]
END = dict(fmt="ogg", channels=2, loop=True, folder="music/ending", min_seconds=END_LOOP - 0.01,
           max_seconds=END_LOOP + 0.01, bpm=END_BPM, beats=4 * END_BARS)


def _end_n() -> int:
    return dsp.samples(END_LOOP)


def _end_room(x: np.ndarray, rng: np.random.Generator, n: int, reverb_s: float, mix: float) -> np.ndarray:
    y = dsp.wrap(dsp.reverb(dsp.wrap(x, n), rng, seconds=reverb_s, mix=mix, predelay_ms=40.0, damp=0.55), n)
    y = dsp.periodic(dsp.highpass, y, 32.0)
    return y - y.mean(axis=1, keepdims=True)


@sound("mus_ending_pad", "music", -27.0, **END)
def ending_pad(rng: np.random.Generator) -> np.ndarray:
    """The Meridian's glass pad and a soft bass, four bars a chord, resolved."""
    n = _end_n()
    buf = np.zeros((2, n + dsp.samples(10.0)))
    block = 4 * END_BAR
    for i, (bass, voicing) in enumerate(END_CHORDS):
        at = dsp.samples(i * block)
        for k, m in enumerate(voicing):
            p = glass_pad(H(m), block, rng, attack=3.0, release=4.5)
            dsp.place(buf, p * (0.5 if k == 0 else 0.34), at + dsp.samples(0.2 * k))
        dsp.place(buf, dsp.stereo(sub(H(bass), block, 2.5, 3.5, 0.4)), at)
    return _end_room(buf, rng, n, 4.5, 0.38)


# The Trail motif and its answer, calm, twice a loop: D A B G#, A C# D.
END_MELODY = [
    (2.0, [(74, 1.0), (81, 2.0), (83, 1.0), (80, 3.0), (81, 1.0), (85, 1.0), (86, 5.0)], 0.9, 0.0),
    (34.0, [(78, 1.0), (81, 2.0), (83, 1.0), (80, 2.0), (81, 2.0), (74, 6.0)], 0.8, -0.1),
]


def _end_lead(m: int, beats: float, vel: float, rng: np.random.Generator) -> np.ndarray:
    dur = beats * END_BEAT
    tone = soft_sine(H(m), dur * 0.95, attack=0.12, release=1.4, harmonics=(1.0, 0.08, 0.02))
    touch = chime(H(m), 0.03, rng, brightness=0.35, decay=0.6, attack=0.008, tail=1.4) * 0.3
    return dsp.mix(0.5 * tone, touch) * vel


@sound("mus_ending_melody", "music", -28.0, **END)
def ending_melody(rng: np.random.Generator) -> np.ndarray:
    n = _end_n()
    buf = np.zeros((2, n + dsp.samples(8.0)))
    for start, notes, vel, side in END_MELODY:
        at = start
        for m, beats in notes:
            dsp.place(buf, dsp.pan(_end_lead(m, beats, vel, rng), side), dsp.samples(at * END_BEAT))
            at += beats
    y = dsp.wrap(dsp.delay(dsp.wrap(buf, n), END_BEAT * 1.5, 0.3, 0.2, 2400.0, ping_pong=True), n)
    return _end_room(y, rng, n, 5.0, 0.42)


@sound("mus_ending_bells", "music", -31.0, **END)
def ending_bells(rng: np.random.Generator) -> np.ndarray:
    """Antecedent bells far off, on the chord tones, and the deck's G# now and
    then, at peace inside D (the #11)."""
    n = _end_n()
    buf = np.zeros((2, n + dsp.samples(10.0)))
    for bar in range(END_BARS):
        voicing = END_CHORDS[(bar // 4) % 4][1]
        m = sorted(voicing)[(bar * 2) % len(voicing)] + 12
        if bar % 4 == 3:
            m = 80  # G#: the Antecedents' note, consonant here
        b = abell(m, rng, decay=2.0, bright=0.4, strike=0.15)
        dsp.place(buf, dsp.pan(0.5 * b, -0.5 + (bar % 5) * 0.25), dsp.samples(bar * END_BAR + END_BEAT * 2))
    return _end_room(buf, rng, n, 6.0, 0.5)
