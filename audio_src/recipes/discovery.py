"""Discovery has a voice (PLAN §5.1, principle 2).

Everything here is built on the Trail motif, D A B G# (degrees 1 5 6 #4,
short-long-short-long):

  signal pulse   only the first interval, D -> A, then silence: a question with
                 no answer yet. Faint, slow, positional.
  scan loop      the same D-A interval pulsing fast, a sweeping band of noise
                 and, very faintly, the B that comes next: listening harder.
  scan cut       the dyad sags a tritone and closes: the line went dead.
  resolve        one phrase per discovery type that *answers* the pulse by
                 completing the motif in its own way:
    geological   low stone bars: D A B, then down to the low D, an anvil ring
                 and a rumble of rock. Grounded, it lands on the tonic.
    biological   breathy reeds that glide between the notes: D A B G#, and the
                 G# turns up to A in a trill, with chirps and a breath. Alive.
    antecedent   the whole motif on bells, chime and reed over a Lydian swell,
                 then the answer A C# D rising to the high D. The signature.
    enemy        the motif bent: D A Bb on detuned, ring-modulated saws, the
                 last note sagging from G# to G with a growl. Combine.

Also the codex, Intel and field-option interface sounds, the field options
themselves, the Advisor's two Phase 4 phrases and the antecedent swell.
"""

from __future__ import annotations

import numpy as np

from synth import dsp
from synth.instruments import bell, chime, marimba, pad_voice, reed, soft_sine

from . import sound
from .advisor import ADVISOR_LUFS, _phrase
from .interface import UI_LUFS, _done, _seq, tick
from .movement import lfo, qf
from .music_kessel import motif_voice
from .world import advisor_dyad

H = dsp.midi_hz
# The motif in semitones above its root and in beats (short-long-short-long).
MOTIF = [(0, 0.5), (7, 1.5), (9, 0.5), (6, 2.0)]


# --------------------------------------------------------------------------- the signal voice


def signal_tone(f: float, dur: float, decay: float, rng: np.random.Generator,
                vibrato: float = 0.0) -> np.ndarray:
    """A soft beacon tone: almost pure, a glassy octave on the attack, a slow
    rounded onset (a signal arriving, not something struck)."""
    n = dsp.samples(dur + decay * 5.0)
    t = dsp.time_axis(n)
    freq = f * (1.0 + (dsp.cents(vibrato) - 1.0) * np.clip(t / 0.4, 0, 1) * np.sin(2 * np.pi * 4.2 * t))
    body = dsp.sine(freq, n) + 0.12 * dsp.sine(freq * 3.0, n) * dsp.perc(n, 0.02, decay * 0.3)
    glass = 0.22 * dsp.fm(freq * 2.0, 2.5, 0.6 * dsp.perc(n, 0.01, 0.08), n) * dsp.perc(n, 0.012, decay * 0.25)
    e = dsp.perc(n, 0.018, decay, hold=dur)
    return (body * e + glass) * 0.5


@sound("signal_pulse", "signal", -30.0, loop=True, folder="discovery", min_seconds=3.19, max_seconds=3.21)
def signal_pulse(rng: np.random.Generator) -> np.ndarray:
    """An unresolved signal: D5 short, A5 long, then 2.5 s of air. The pair
    never continues; that is the point."""
    L = 3.2
    n = dsp.samples(L)
    buf = np.zeros(n + dsp.samples(6.0))
    dsp.place(buf, 0.8 * signal_tone(H(74), 0.05, 0.22, rng), dsp.samples(0.04))
    dsp.place(buf, signal_tone(H(81), 0.35, 0.75, rng, vibrato=6.0), dsp.samples(0.30))
    # A faint ghost of the same pair an octave up, a beat later: it carries
    # further than the fundamentals when the camera is far.
    dsp.place(buf, 0.18 * signal_tone(H(86), 0.03, 0.15, rng), dsp.samples(0.62))
    dsp.place(buf, 0.18 * signal_tone(H(93), 0.2, 0.5, rng), dsp.samples(0.88))
    tones = dsp.wrap(buf, n)
    air = dsp.periodic(dsp.bandpass, dsp.pink(n, rng), 3800.0, 1.2)
    air *= 0.025 * (0.6 + 0.4 * lfo(n, L, 1, 0.75))
    x = dsp.periodic(dsp.highpass, tones + air, 180.0)
    return x - x.mean()


@sound("scan_loop", "signal", -27.0, loop=True, folder="discovery", min_seconds=1.99, max_seconds=2.01)
def scan_loop(rng: np.random.Generator) -> np.ndarray:
    """Scanning: the D-A question pulsed fast (8 per second, alternating),
    a band of noise sweeping up twice a loop, data ticks, and the B that
    comes next in the motif, barely there."""
    L = 2.0
    n = dsp.samples(L)
    t = dsp.time_axis(n)
    d = dsp.sine(qf(H(74), L), n) + 0.1 * dsp.sine(qf(H(74) * 2, L), n)
    a = dsp.sine(qf(H(81), L), n) + 0.1 * dsp.sine(qf(H(81) * 2, L), n)
    # 16 pulses per loop; even ones on D, odd ones on A. Smooth bumps, whole periods.
    ph = (t / L * 16.0) % 1.0
    bump = np.sin(np.pi * ph) ** 4
    which = (np.floor(t / L * 16.0) % 2).astype(bool)
    dyad = np.where(which, a, d) * bump
    # The swap happens where bump is zero, so there is no step.
    beb = dsp.sine(qf(H(83), L), n) * 0.06 * (0.5 - 0.5 * np.cos(2 * np.pi * t / L))
    sweep_fc = 900.0 * 4.5 ** (0.5 - 0.5 * np.cos(2 * np.pi * 2 * t / L))
    band = dsp.periodic(dsp.sweep, dsp.pink(n, rng), "bp", sweep_fc, 2.5) * 0.12
    ticks = np.zeros(n + dsp.samples(0.05))
    for i in range(8):
        dsp.place(ticks, 0.12 * tick(rng, 3100.0 + 200.0 * (i % 3), 0.004, 0.2), dsp.samples(i * L / 8 + 0.031))
    x = 0.35 * dyad + beb + band + dsp.wrap(ticks, n)
    x = dsp.periodic(dsp.highpass, x, 200.0)
    return x - x.mean()


@sound("scan_interrupted", "signal", -26.0, folder="discovery", max_seconds=0.9)
def scan_interrupted(rng: np.random.Generator) -> np.ndarray:
    """The scan is cut: the D-A dyad sags a tritone while its filter closes,
    then a dull tick. Under half a second."""
    dur = 0.32
    n = dsp.samples(dur + 0.1)
    u = np.clip(dsp.time_axis(n) / dur, 0, 1)
    bend = 2.0 ** (-6.0 * u ** 1.5 / 12.0)
    x = dsp.sine(H(74) * bend, n) + dsp.sine(H(81) * bend, n) + 0.3 * dsp.warm_saw(H(62) * bend, n, 4.0)
    x *= dsp.env([(0.0, 0.0), (0.01, 1.0), (dur * 0.6, 0.7), (dur, 0.0)], n)
    x = dsp.sweep(x, "lp", 6000.0 * 0.06 ** u, 0.9)
    m = dsp.samples(0.08)
    thunk = dsp.sine(160.0, m) * dsp.perc(m, 0.001, 0.02) + 0.3 * dsp.bandpass(dsp.white(m, rng), 900.0, 1.5) * dsp.perc(m, 0.0005, 0.006)
    buf = _seq([(0.0, 0.5 * x), (dur - 0.02, 0.5 * thunk)], 0.6)
    return dsp.fade(dsp.trim_tail(dsp.dc_block(dsp.highpass(buf, 120.0)), -55.0), 0.002, 0.02)


# --------------------------------------------------------------------------- resolve phrases

RESOLVE_LUFS = -21.0
STEREO = dict(channels=2, folder="discovery")


def _resolve_finish(x: np.ndarray, rng: np.random.Generator, seconds: float, mix: float,
                    damp: float = 0.55, end: float = 6.0, fade_out: float = 0.6) -> np.ndarray:
    y = dsp.reverb(x, rng, seconds=seconds, mix=mix, predelay_ms=20.0, damp=damp)
    y = dsp.trim_tail(dsp.dc_block(dsp.highpass(y, 35.0)), -60.0)[:, : dsp.samples(end)]
    return dsp.fade(y, 0.002, fade_out)


def stone(f: float, rng: np.random.Generator, decay: float = 0.7, hardness: float = 0.6) -> np.ndarray:
    """A lithophone bar: stone partials (1 : 2.76 : 5.4 : 8.9), a dry knock."""
    n = dsp.samples(decay * 5 + 0.1)
    x = dsp.partials(f, n, [(1.0, 1.0, decay), (2.76, 0.4 * hardness, decay * 0.35),
                            (5.4, 0.18 * hardness, decay * 0.12), (8.9, 0.08 * hardness, decay * 0.05)], rng)
    knock = 0.35 * dsp.lowpass(dsp.white(n, rng), f * 5.0) * dsp.perc(n, 0.0008, 0.01)
    return (x * dsp.perc(n, 0.002, 1e6) + knock) * 0.6


@sound("discovery_resolve_geological", "discovery", RESOLVE_LUFS, max_seconds=3.6, min_seconds=2.0, **STEREO)
def resolve_geological(rng: np.random.Generator) -> np.ndarray:
    beat = 0.34
    buf = np.zeros((2, dsp.samples(5.0)))
    at = 0.03
    for i, (m, beats) in enumerate([(50, 0.5), (57, 1.5), (59, 0.5)]):
        x = dsp.mix(stone(H(m), rng, decay=0.35 + 0.25 * beats), 0.25 * stone(H(m + 12), rng, 0.3, 0.3))
        dsp.place(buf, dsp.pan(x * (0.85 if i == 0 else 1.0), -0.25 + 0.2 * i), dsp.samples(at))
        at += beats * beat
    # It lands: the low D, a metal ring on top (brass in the rock), a rumble.
    land = stone(H(38), rng, decay=1.1, hardness=0.9) * 1.3
    dsp.place(buf, dsp.stereo(land), dsp.samples(at))
    dsp.place(buf, dsp.pan(0.45 * bell(H(62), rng, decay=0.9, brightness=0.6, strike=0.3), 0.15), dsp.samples(at))
    m = dsp.samples(1.8)
    tt = dsp.time_axis(m)
    thud = dsp.sine(H(38) * (1.0 + 0.4 * np.exp(-tt / 0.03)), m) * dsp.perc(m, 0.004, 0.2)
    rumble = dsp.lowpass(dsp.brown(m, rng), 200.0) * dsp.env([(0.0, 0.0), (0.05, 0.5), (1.8, 0.0)], m, 2.0)
    grit = dsp.bandpass(dsp.white(m, rng), 1800.0, 0.8) * dsp.env([(0.0, 0.0), (0.03, 0.08), (0.9, 0.0)], m)
    dsp.place(buf, dsp.stereo(0.7 * thud + 0.6 * rumble + grit), dsp.samples(at))
    return _resolve_finish(buf, rng, 1.6, 0.22, damp=0.7, end=3.4)


def breath_note(f0: float, f1: float, dur: float, rng: np.random.Generator, glide: float = 0.12,
                breath: float = 0.22) -> np.ndarray:
    """A breathy reed that glides from f0 into f1 (an organic portamento)."""
    n = dsp.samples(dur)
    u = np.clip(dsp.time_axis(n) / glide, 0, 1)
    f = f0 * (f1 / f0) ** (u * u * (3 - 2 * u))
    return reed(f, dur, rng, brightness=2.6, attack=0.05, release=0.25, breath=breath,
                vibrato_hz=5.6, vibrato_cents=14.0)


def chirp(rng: np.random.Generator, f0: float, f1: float, dur: float = 0.06) -> np.ndarray:
    n = dsp.samples(dur + 0.02)
    u = np.clip(dsp.time_axis(n) / dur, 0, 1)
    return dsp.sine(f0 * (f1 / f0) ** u, n) * dsp.ar(n, 0.006, 0.02, dur - 0.006)


@sound("discovery_resolve_biological", "discovery", RESOLVE_LUFS, max_seconds=3.8, min_seconds=2.0, **STEREO)
def resolve_biological(rng: np.random.Generator) -> np.ndarray:
    beat = 0.3
    buf = np.zeros((2, dsp.samples(5.0)))
    notes = [(62, 62, 0.5), (62, 69, 1.5), (69, 71, 0.5), (71, 68, 1.0)]
    at = 0.05
    for i, (a, b, beats) in enumerate(notes):
        x = breath_note(H(a), H(b), beats * beat + 0.08, rng)
        dsp.place(buf, dsp.pan(x, -0.3 + 0.2 * i), dsp.samples(at))
        at += beats * beat
    # G# does not hang here: it turns up to A in a little trill, alive.
    for k in range(6):
        m = 69 if k % 2 == 0 else 68
        x = breath_note(H(m), H(m), 0.09, rng, breath=0.15)
        dsp.place(buf, dsp.pan(0.8 * x, 0.25), dsp.samples(at + k * 0.075))
    tail = breath_note(H(69), H(69), 0.9, rng, breath=0.3)
    dsp.place(buf, dsp.pan(tail, 0.2), dsp.samples(at + 6 * 0.075))
    # Chirps around it: something answering from the undergrowth.
    for k, (t0, f0, f1) in enumerate([(0.18, 2600, 3400), (0.62, 3100, 2500), (1.15, 2900, 3800),
                                      (1.24, 3000, 3900), (1.85, 2400, 3100)]):
        dsp.place(buf, dsp.pan(0.07 * chirp(rng, f0, f1, 0.05 + 0.01 * k), 0.6 if k % 2 else -0.6),
                  dsp.samples(t0))
    m = dsp.samples(2.6)
    breath = dsp.sweep(dsp.pink(m, rng), "bp", 700.0 + 900.0 * dsp.env([(0, 0), (1.3, 1), (2.6, 0.3)], m), 0.7)
    breath *= dsp.env([(0.0, 0.0), (1.2, 0.06), (2.6, 0.0)], m)
    dsp.place(buf, dsp.stereo(breath), dsp.samples(0.1))
    return _resolve_finish(buf, rng, 2.0, 0.28, damp=0.6, end=3.6)


@sound("discovery_resolve_antecedent", "discovery", RESOLVE_LUFS + 1.0, max_seconds=6.6, min_seconds=4.0, **STEREO)
def resolve_antecedent(rng: np.random.Generator) -> np.ndarray:
    """The signature: the whole motif, then its answer."""
    beat = 0.4
    buf = np.zeros((2, dsp.samples(9.0)))
    at = 0.08
    for i, (step, beats) in enumerate(MOTIF):
        m = 74 + step
        v = motif_voice(m, beats, 0.85 if i == 0 else 1.0, rng, beat)
        b = bell(H(m), rng, decay=0.8 + 0.3 * beats, brightness=0.55, strike=0.25)
        dsp.place(buf, dsp.pan(dsp.mix(v, 0.5 * b), -0.15 + 0.1 * i), dsp.samples(at))
        at += beats * beat
    # The answer: A C# rising to the high D, bells doubling, the octave below in the reed.
    for k, (m, beats) in enumerate([(81, 0.5), (85, 0.5), (86, 3.0)]):
        v = motif_voice(m, beats, 0.9 + 0.05 * k, rng, beat)
        dsp.place(buf, dsp.pan(v, 0.1), dsp.samples(at))
        if k == 2:
            dsp.place(buf, dsp.stereo(0.55 * bell(H(86), rng, decay=2.2, brightness=0.6, strike=0.3)), dsp.samples(at))
            dsp.place(buf, dsp.stereo(0.5 * bell(H(62), rng, decay=2.6, brightness=0.4, strike=0.2)), dsp.samples(at))
            low = reed(H(74), 2.0, rng, brightness=2.0, attack=0.15, release=1.2, breath=0.04, vibrato_cents=5.0)
            dsp.place(buf, dsp.stereo(0.3 * low), dsp.samples(at))
            for j, mm in enumerate([93, 98, 102]):  # a sparkle above
                s = chime(H(mm), 0.04, rng, brightness=0.5, decay=0.9, attack=0.02, tail=2.0)
                dsp.place(buf, dsp.pan(0.18 * s, -0.5 + 0.5 * j), dsp.samples(at + 0.12 + 0.11 * j))
        at += beats * beat
    # The Lydian swell under it: D A E G# (the question chord), opening to Dmaj9 for the answer.
    for k, m in enumerate([50, 57, 64, 68]):
        p = pad_voice(H(m), 2.0, rng, attack=0.8, release=1.6, brightness=3.0)
        dsp.place(buf, p * (0.42 if k == 0 else 0.28), dsp.samples(0.05))
    for k, m in enumerate([38, 50, 57, 61, 64, 66]):
        p = pad_voice(H(m), 2.6, rng, attack=0.7, release=2.4, brightness=3.2)
        dsp.place(buf, p * (0.5 if k < 2 else 0.26), dsp.samples(1.85))
    y = dsp.delay(buf, beat * 1.5, 0.28, 0.2, 2800.0, ping_pong=True)
    return _resolve_finish(y, rng, 3.4, 0.36, end=6.2, fade_out=1.2)


def combine_voice(f0: float, f1: float, dur: float, rng: np.random.Generator, bend_at: float = 0.5) -> np.ndarray:
    """Detuned saws with an inharmonic ring modulator and grit: the Combine's
    sound world. The pitch bends from f0 to f1 after `bend_at` of the note."""
    n = dsp.samples(dur + 0.15)
    u = np.clip((dsp.time_axis(n) / dur - bend_at) / max(1.0 - bend_at, 1e-3), 0, 1)
    f = f0 * (f1 / f0) ** (u * u)
    x = dsp.warm_saw(f * dsp.cents(-13.0), n, 14.0) + dsp.warm_saw(f * dsp.cents(11.0), n, 14.0)
    x *= 0.75 + 0.25 * dsp.sine(f * 1.37, n)  # ring modulation, off any harmonic
    x = dsp.saturate(x * 1.4, 2.0)
    x = np.round(x * 24.0) / 24.0  # a little decimation grit
    return dsp.lowpass(x, 3200.0) * dsp.ar(n, 0.012, 0.12, dur - 0.012) * 0.4


@sound("discovery_resolve_enemy", "discovery", RESOLVE_LUFS, max_seconds=3.4, min_seconds=1.8, **STEREO)
def resolve_enemy(rng: np.random.Generator) -> np.ndarray:
    beat = 0.3
    buf = np.zeros((2, dsp.samples(4.5)))
    at = 0.03
    # D A Bb, then G# sagging to G: the motif, but wrong.
    for i, (m0, m1, beats) in enumerate([(62, 62, 0.5), (69, 69, 1.5), (70, 70, 0.5), (68, 67, 2.5)]):
        x = combine_voice(H(m0), H(m1), beats * beat * 0.95, rng, bend_at=0.35)
        x = dsp.mix(x, 0.4 * signal_tone(H(m0 + 12), 0.03, 0.12, rng))  # the signal still under it
        dsp.place(buf, dsp.pan(x, -0.2 + 0.13 * i), dsp.samples(at))
        if i == 3:
            m = dsp.samples(1.4)
            tt = dsp.time_axis(m)
            growl = dsp.warm_saw(H(43) * (1.0 - 0.06 * tt), m, 10.0) * (0.6 + 0.4 * dsp.sine(23.0, m))
            growl = dsp.saturate(dsp.lowpass(growl, 600.0) * 1.5, 2.0) * dsp.env([(0, 0), (0.08, 0.5), (1.4, 0)], m)
            dsp.place(buf, dsp.stereo(growl), dsp.samples(at))
            crackle = np.zeros(m)
            pos = (m * rng.random(40) ** 1.5).astype(int)
            crackle[pos] = rng.uniform(-1, 1, 40)
            dsp.place(buf, dsp.pan(0.5 * dsp.bandpass(crackle, 4800.0, 0.8), 0.4), dsp.samples(at + 0.1))
        at += beats * beat
    return _resolve_finish(buf, rng, 0.9, 0.16, damp=0.7, end=3.2, fade_out=0.4)


# --------------------------------------------------------------------------- codex, intel, options


@sound("ui_codex_entry", "ui", UI_LUFS, max_seconds=0.6)
def ui_codex_entry(rng: np.random.Generator) -> np.ndarray:
    """Written down: the motif's last step, B -> G#, on two soft glass notes,
    with a paper flick."""
    a = chime(H(95), 0.03, rng, brightness=0.6, decay=0.08, tail=0.25)
    b = chime(H(92), 0.03, rng, brightness=0.6, decay=0.14, tail=0.35)
    m = dsp.samples(0.05)
    flick = dsp.bandpass(dsp.white(m, rng), 5200.0, 1.0) * dsp.perc(m, 0.002, 0.012) * 0.35
    return _done(_seq([(0.0, flick), (0.01, 0.6 * a), (0.09, 0.6 * b)], 0.55))


@sound("ui_codex_open", "ui", UI_LUFS - 2.0, max_seconds=0.35)
def ui_codex_open(rng: np.random.Generator) -> np.ndarray:
    a = marimba(H(86), 0.03, rng, hardness=0.4, decay=0.06, tail=0.12)
    b = marimba(H(93), 0.03, rng, hardness=0.4, decay=0.09, tail=0.15)
    m = dsp.samples(0.12)
    swish = dsp.sweep(dsp.white(m, rng), "bp", 1500.0 * 4.0 ** (dsp.time_axis(m) / 0.12), 1.2) * dsp.ar(m, 0.03, 0.06, 0.03) * 0.12
    return _done(_seq([(0.0, swish), (0.02, 0.6 * a), (0.07, 0.6 * b)], 0.3))


@sound("ui_codex_close", "ui", UI_LUFS - 3.0, max_seconds=0.35)
def ui_codex_close(rng: np.random.Generator) -> np.ndarray:
    a = marimba(H(93), 0.03, rng, hardness=0.35, decay=0.05, tail=0.1)
    b = marimba(H(86), 0.03, rng, hardness=0.35, decay=0.08, tail=0.14)
    m = dsp.samples(0.1)
    swish = dsp.sweep(dsp.white(m, rng), "bp", 5000.0 * 0.3 ** (dsp.time_axis(m) / 0.1), 1.2) * dsp.ar(m, 0.02, 0.05, 0.03) * 0.1
    return _done(_seq([(0.0, swish), (0.01, 0.55 * a), (0.06, 0.55 * b)], 0.3))


@sound("ui_intel_tick", "ui", UI_LUFS - 2.0, max_seconds=0.3)
def ui_intel_tick(rng: np.random.Generator) -> np.ndarray:
    """Intel gained: a tiny glass tick on A6 with a sparkle on E7."""
    a = chime(H(93), 0.02, rng, brightness=0.7, decay=0.04, tail=0.12)
    b = chime(H(100), 0.02, rng, brightness=0.4, decay=0.03, tail=0.1)
    return _done(_seq([(0.0, 0.6 * a), (0.035, 0.3 * b)], 0.25))


@sound("ui_option_button", "ui", UI_LUFS, max_seconds=0.3)
def ui_option_button(rng: np.random.Generator) -> np.ndarray:
    """A field-option button: a click with a glass G# above it (the motif's
    raised fourth: this spends Intel)."""
    c = tick(rng, 2400.0, 0.004, 0.3)
    g = chime(H(80), 0.03, rng, brightness=0.6, decay=0.06, tail=0.15)
    g2 = chime(H(92), 0.02, rng, brightness=0.4, decay=0.04, tail=0.12)
    return _done(_seq([(0.0, 0.5 * c), (0.012, 0.55 * g), (0.04, 0.25 * g2)], 0.25))


# --------------------------------------------------------------------------- field options

FIELD_LUFS = -22.0
FIELD = dict(channels=2, folder="discovery", min_seconds=1.5, max_seconds=4.0)


@sound("field_orbital_scan", "field", FIELD_LUFS, **FIELD)
def field_orbital_scan(rng: np.random.Generator) -> np.ndarray:
    """The Meridian sweeps the surface from orbit: a high whoosh falling out of
    the sky, a broad sonar sweep left to right, two wide pings and data rain."""
    total = 3.2
    n = dsp.samples(total)
    t = dsp.time_axis(n)
    buf = np.zeros((2, n))
    m = dsp.samples(1.0)
    u = dsp.time_axis(m) / 1.0
    whoosh = dsp.sweep(dsp.pink(m, rng), "bp", 7000.0 * 0.08 ** u, 1.0) * dsp.env([(0, 0), (0.5, 0.5), (1.0, 0)], m)
    dsp.place(buf, dsp.stereo(whoosh), 0)
    sweep_n = dsp.samples(1.8)
    su = dsp.time_axis(sweep_n) / 1.8
    tone = dsp.sine(H(74), sweep_n) + 0.6 * dsp.sine(H(81), sweep_n) + 0.25 * dsp.sine(H(86), sweep_n)
    tone *= dsp.env([(0, 0), (0.2, 0.35), (1.4, 0.3), (1.8, 0)], sweep_n)
    tone = dsp.sweep(tone, "lp", 900.0 + 5000.0 * su, 0.8)
    dsp.place(buf, dsp.pan(tone, -0.9 + 1.8 * su), dsp.samples(0.45))
    for k, at in enumerate([0.55, 1.35]):
        p = signal_tone(H(86 - 5 * k), 0.04, 0.4, rng)
        dsp.place(buf, dsp.pan(0.5 * p, -0.6 + 1.2 * k), dsp.samples(at))
    rain = np.zeros(n)
    for _ in range(40):
        at = float(rng.uniform(0.6, 2.4))
        dsp.place(rain, 0.08 * tick(rng, float(rng.choice([2349.0, 2794.0, 3136.0, 3520.0])), 0.003, 0.1),
                  dsp.samples(at))
    buf += dsp.pan(rain, 0.0) * 0.9
    buf *= dsp.env([(0, 1), (total - 0.6, 1), (total, 0)], n)
    del t
    return _resolve_finish(buf, rng, 1.6, 0.25, end=3.6, fade_out=0.4)


@sound("field_supply_drop", "field", FIELD_LUFS, **FIELD)
def field_supply_drop(rng: np.random.Generator) -> np.ndarray:
    """A supply pod arrives: a falling whistle with a Doppler drop, a heavy
    landing thump, dust, and a Concord chime D+A: delivered."""
    buf = np.zeros((2, dsp.samples(3.6)))
    m = dsp.samples(1.3)
    u = dsp.time_axis(m) / 1.3
    whistle = dsp.sine(1900.0 * 0.45 ** (u ** 2), m) * dsp.env([(0, 0), (0.9, 0.25), (1.3, 0.4)], m)
    air = dsp.sweep(dsp.pink(m, rng), "bp", 3000.0 * 0.3 ** u, 1.4) * dsp.env([(0, 0), (1.2, 0.5), (1.3, 0.6)], m)
    dsp.place(buf, dsp.pan(whistle + air, -0.6 + 0.6 * u), 0)
    land = dsp.samples(1.6)
    tt = dsp.time_axis(land)
    thump = dsp.sine(55.0 * (1.0 + 0.8 * np.exp(-tt / 0.03)), land) * dsp.perc(land, 0.002, 0.18)
    crack = dsp.bandpass(dsp.white(land, rng), 1400.0, 0.7) * dsp.perc(land, 0.001, 0.03)
    dust = dsp.lowpass(dsp.brown(land, rng), 900.0) * dsp.env([(0, 0), (0.05, 0.3), (1.6, 0)], land, 2.0)
    dsp.place(buf, dsp.stereo(0.9 * thump + 0.5 * crack + 0.4 * dust), dsp.samples(1.3))
    for k, mm in enumerate([62, 69, 74]):
        c = dsp.mix(marimba(H(mm), 0.1, rng, hardness=0.6, decay=0.3, tail=0.6), 0.5 * chime(H(mm + 12), 0.05, rng, 0.6, 0.4))
        dsp.place(buf, dsp.pan(0.45 * c, -0.2 + 0.2 * k), dsp.samples(1.75 + 0.09 * k))
    return _resolve_finish(buf, rng, 1.4, 0.2, damp=0.65, end=3.4, fade_out=0.4)


@sound("field_antecedent_power", "field", FIELD_LUFS + 1.0, **FIELD)
def field_antecedent_power(rng: np.random.Generator) -> np.ndarray:
    """An Antecedent power wakes: bells swell up out of silence (reversed),
    strike together on D and G# (the motif's frame), and ring out over a rising
    shimmer."""
    buf = np.zeros((2, dsp.samples(4.2)))
    swell_len = 1.0
    for k, m in enumerate([62, 68, 74]):
        b = bell(H(m), rng, decay=0.5, brightness=0.6, strike=0.0, length=swell_len)
        dsp.place(buf, dsp.pan(0.5 * b[::-1] * np.linspace(0, 1, len(b)) ** 2, -0.4 + 0.4 * k), 0)
    at = swell_len
    for k, (m, g) in enumerate([(50, 0.8), (62, 1.0), (68, 0.7), (86, 0.3)]):
        b = bell(H(m), rng, decay=1.6 if m < 70 else 0.8, brightness=0.7, strike=0.4)
        dsp.place(buf, dsp.pan(g * b, -0.3 + 0.2 * k), dsp.samples(at))
    m = dsp.samples(2.6)
    u = dsp.time_axis(m) / 2.6
    shimmer = dsp.sweep(dsp.pink(m, rng), "bp", 2000.0 * 3.0 ** u, 4.0) * dsp.env([(0, 0), (0.3, 0.2), (2.6, 0)], m)
    dsp.place(buf, dsp.stereo(shimmer), dsp.samples(at))
    return _resolve_finish(buf, rng, 2.6, 0.3, end=3.9, fade_out=0.8)


# --------------------------------------------------------------------------- the Advisor


@sound("advisor_discovery", "advisor", ADVISOR_LUFS, max_seconds=1.6)
def advisor_discovery(rng: np.random.Generator) -> np.ndarray:
    """Discovery logged: the motif's opening interval as two Meridian dyads,
    D+A then A+D, the second long: the ship heard it too."""
    parts = [(0.0, 0.85, advisor_dyad(H(74), H(81), 0.08)),
             (0.12, 1.0, advisor_dyad(H(81), H(86), 0.3))]
    return _phrase(parts, rng, 1.4)


@sound("advisor_field_option_ready", "advisor", ADVISOR_LUFS, max_seconds=1.6)
def advisor_field_option_ready(rng: np.random.Generator) -> np.ndarray:
    """A field option is ready: a dyad on the raised fourth (G#+D) twice, then
    it lifts a semitone into A+D: something can be spent."""
    from .advisor import glide_dyad

    parts = [(0.0, 0.9, advisor_dyad(H(80), H(86), 0.06)),
             (0.1, 0.9, advisor_dyad(H(80), H(86), 0.06)),
             (0.22, 1.0, glide_dyad(H(80), H(86), 0.3, 1.0, 0.3))]
    return _phrase(parts, rng, 1.4)


# --------------------------------------------------------------------------- music


@sound("mus_swell_antecedent", "sting", -23.0, fmt="ogg", channels=2, folder="music/stings",
       min_seconds=5.0, max_seconds=9.5)
def swell_antecedent(rng: np.random.Generator) -> np.ndarray:
    """Played with the antecedent resolve phrase and built to stay out of its
    way: no melody, nothing in the phrase's register, almost silent for its
    first 2.5 s, then a low Lydian chord (D A E G# C#) blooms under the
    phrase's last note and a high air of bells rises after it."""
    total = 9.0
    n = dsp.samples(total)
    buf = np.zeros((2, n + dsp.samples(4.0)))
    for k, m in enumerate([38, 45, 52, 56, 61]):
        p = pad_voice(H(m), 4.0, rng, attack=3.2, release=3.2, brightness=2.6 + 0.3 * k, detune_cents=7.0)
        dsp.place(buf, p * (0.6 if k == 0 else 0.35), dsp.samples(0.8))
    low = soft_sine(H(26 + 12), 4.5, attack=3.0, release=3.0, harmonics=(1.0, 0.3, 0.1))
    dsp.place(buf, dsp.stereo(0.4 * low), dsp.samples(1.0))
    for j, mm in enumerate([98, 105, 110]):
        b = bell(H(mm - 24), rng, decay=1.6, brightness=0.3, strike=0.0)
        dsp.place(buf, dsp.pan(0.08 * b, -0.6 + 0.6 * j), dsp.samples(4.7 + 0.35 * j))
    y = buf[:, :n]
    y = dsp.reverb(y, rng, seconds=4.0, mix=0.42, predelay_ms=30.0, damp=0.55)[:, :n]
    y *= dsp.env([(0.0, 0.0), (2.5, 0.15), (4.6, 1.0), (total, 0.0)], n, 0.0)
    y = dsp.dc_block(dsp.highpass(y, 30.0))
    return dsp.fade(y, 0.01, 1.5)
