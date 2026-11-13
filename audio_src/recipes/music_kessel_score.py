"""Kessel Reach, Phase 6: the rest of the adaptive score.

More synchronised layers of the explore clip (80 BPM, 4/4, 16 bars, 48 s, chords
Dmaj9, E/D, Bm(add9), Aadd9), so everything still fades on the beat without a
clip change:

  melody_b   variation: a second set of phrases over the same chords, on the
             chime-and-reed voice, closing on the hanging G#
  melody_c   variation: the motif augmented and low on marimba with a chime
             an octave up, sparse; the third colour of the explore score
  pulse_b    variation: the marimba pulse in a 3+3+2 figure instead of straight
             eighths, so the clock itself changes from loop to loop
  drums_b    variation of the combat drums: half-time taiko, tom runs, the
             frame drum moved to the off-beats
  urgency    base under attack: a muted sixteenth ostinato hammering D against
             G#, a reed siren rising a fourth every two bars, a high tick
  heavy      heavy combat: low reed "brass" in half notes on root and fifth,
             doubled taiko on every beat, a grinding sub on the downbeats

The MusicDirector picks one variant per loop (layers sharing a variant group),
so fifteen minutes in one state still moves through different material.

Transition hits (group `sting`, flat on the Music bus) cover the two cuts a
layer fade cannot hide:

  mus_hit_combat     into combat: a swell of air sucked in, two taiko strikes and a
                     low reed D on the downbeat
  mus_hit_aftermath  out of combat: the reed falls D A F# D and a soft bell rings

  mus_menu_theme     the mission-select theme (bed, 48 s loop): the Trail motif
                     stated in full on chime and reed, answered by its victory
                     form, over the four chords with a slow marimba pulse
  mus_sting_outsurveyed  lost the Survey race: the motif on the reed, then the
                     Combine's bent version (D A Bb) on ring-modulated saws
                     climbing over it into a hard tritone

Attacks stay at 8 ms or softer (native Vorbis pre-echo, ADR 0005).
"""

from __future__ import annotations

import numpy as np

from synth import dsp
from synth.instruments import chime, marimba, pad_voice, reed, soft_sine

from . import sound
from .music_kessel import ARP_VEL, BAR, BARS, BEAT, CHORDS, LOOP, _space, motif_voice
from .music_kessel_combat import LAYER, SIXTEENTH, _soft, frame_hit, taiko

H = dsp.midi_hz


def _n() -> int:
    return dsp.samples(LOOP)


def _phrases(rng: np.random.Generator, phrases, voice) -> np.ndarray:
    buf = np.zeros((2, _n() + dsp.samples(6.0)))
    for start, notes, vel, side in phrases:
        at = start
        for m, beats in notes:
            dsp.place(buf, dsp.pan(voice(m, beats, vel, rng), side), dsp.samples(at * BEAT))
            at += beats
    return buf


MELODY_B = [
    (2.0, [(81, 1.0), (78, 0.5), (80, 0.5), (81, 3.0)], 0.95, 0.15),
    (18.0, [(83, 1.0), (80, 1.0), (76, 3.0)], 0.9, -0.1),
    (26.0, [(85, 0.5), (83, 2.5)], 0.55, 0.3),
    (36.0, [(78, 0.5), (86, 1.5), (85, 0.5), (83, 3.0)], 0.9, 0.1),
    (50.0, [(76, 0.5), (78, 0.5), (81, 1.0), (80, 4.0)], 0.85, 0.0),
]


@sound("mus_kessel_explore_melody_b", "music", -27.0, **LAYER)
def melody_b(rng: np.random.Generator) -> np.ndarray:
    buf = _phrases(rng, MELODY_B, motif_voice)
    return _space(buf, rng, _n(), reverb_s=3.8, mix=0.4, echo_s=BEAT * 1.5, feedback=0.35, echo_mix=0.3)


def low_voice(m: int, beats: float, vel: float, rng: np.random.Generator) -> np.ndarray:
    """Marimba roll with a soft chime an octave up: the motif low and wooden."""
    dur = beats * BEAT
    out = np.zeros(dsp.samples(dur + 2.5))
    strokes = max(int(dur / 0.15), 1) if beats >= 2 else 1
    for k in range(strokes):
        note = marimba(H(m), 0.08, rng, hardness=0.35, decay=0.4, tail=0.8)
        g = 1.0 if k == 0 else 0.35 * (1.0 - k / (strokes + 1))
        dsp.place(out, _soft(note) * g, dsp.samples(k * 0.15))
    bell = chime(H(m + 12), 0.05, rng, brightness=0.45, decay=0.4 + 0.3 * dur, attack=0.012, tail=2.0)
    dsp.place(out, 0.35 * bell, 0)
    return out * vel


MELODY_C = [
    (6.0, [(62, 1.0), (69, 5.0)], 0.9, -0.2),
    (22.0, [(64, 1.0), (71, 5.0)], 0.85, 0.2),
    (38.0, [(59, 1.0), (66, 1.0), (68, 5.0)], 0.9, -0.1),
    (54.0, [(57, 1.0), (64, 1.0), (61, 1.0), (62, 4.0)], 0.85, 0.1),
]


@sound("mus_kessel_explore_melody_c", "music", -27.0, **LAYER)
def melody_c(rng: np.random.Generator) -> np.ndarray:
    buf = _phrases(rng, MELODY_C, low_voice)
    return _space(buf, rng, _n(), reverb_s=4.2, mix=0.42, echo_s=BEAT * 0.75, feedback=0.3, echo_mix=0.25)


PULSE_B_STEPS = [0, 3, 6, 8, 11, 14]  # 3+3+2, 3+3+2 in sixteenths
PULSE_B_ORDER = [0, 2, 4, 1, 3, 2]


@sound("mus_kessel_explore_pulse_b", "music", -29.0, **LAYER)
def pulse_b(rng: np.random.Generator) -> np.ndarray:
    n = _n()
    buf = np.zeros((2, n + dsp.samples(2.0)))
    for bar in range(BARS):
        bass, voicing = CHORDS[bar // 4]
        tones = sorted(m + 12 if m < 62 else m for m in voicing)
        steps = PULSE_B_STEPS[:5] if bar % 4 == 3 else PULSE_B_STEPS
        for k, s in enumerate(steps):
            m = tones[PULSE_B_ORDER[k] % len(tones)]
            note = marimba(H(m), 0.1, rng, hardness=0.4, decay=0.3, tail=0.5)
            v = ARP_VEL[k % len(ARP_VEL)] * float(rng.uniform(0.9, 1.0))
            dsp.place(buf, dsp.pan(_soft(note) * v, 0.35 if k % 2 else -0.35),
                      dsp.samples(bar * BAR + s * SIXTEENTH))
        heart = soft_sine(H(bass + 12), 0.25, attack=0.015, release=0.4, harmonics=(1.0, 0.1))
        dsp.place(buf, dsp.stereo(heart * 0.45), dsp.samples(bar * BAR))
    x = dsp.periodic(dsp.lowpass, dsp.wrap(buf, n), 3000.0)
    return _space(x, rng, n, reverb_s=2.6, mix=0.3, echo_s=BEAT * 0.5, feedback=0.28, echo_mix=0.25)


@sound("mus_kessel_combat_drums_b", "music", -26.0, **LAYER)
def drums_b(rng: np.random.Generator) -> np.ndarray:
    n = _n()
    buf = np.zeros((2, n + dsp.samples(2.0)))
    for bar in range(BARS):
        at0 = bar * BAR
        dsp.place(buf, dsp.stereo(taiko(rng, 55.0, 0.7)), dsp.samples(at0))
        dsp.place(buf, dsp.stereo(0.85 * taiko(rng, 55.0, 0.6)), dsp.samples(at0 + 2.5 * BEAT))
        for b in range(4):
            dsp.place(buf, dsp.pan(0.35 * frame_hit(rng), 0.25), dsp.samples(at0 + (b + 0.5) * BEAT))
        if bar % 2 == 1:
            for k, f in enumerate([140.0, 120.0, 100.0, 85.0]):
                tom = taiko(rng, f, 0.3) * (0.45 + 0.08 * k)
                dsp.place(buf, dsp.pan(tom, -0.4 + 0.25 * k), dsp.samples(at0 + 3 * BEAT + k * SIXTEENTH))
        for s in range(16):
            m = dsp.samples(0.06)
            sh = dsp.highpass(dsp.white(m, rng), 7000.0) * dsp.perc(m, 0.008, 0.015)
            dsp.place(buf, dsp.pan(sh * (0.12 if s % 4 == 2 else 0.05), -0.3), dsp.samples(at0 + s * SIXTEENTH))
    x = dsp.wrap(buf, n)
    return _space(x, rng, n, reverb_s=1.8, mix=0.2)


@sound("mus_kessel_urgency", "music", -29.0, **LAYER)
def urgency(rng: np.random.Generator) -> np.ndarray:
    n = _n()
    buf = np.zeros((2, n + dsp.samples(3.0)))
    for bar in range(BARS):
        at0 = bar * BAR
        for s in range(16):
            m = 62 if s % 4 != 3 else 68  # D, with G# on every fourth sixteenth
            note = marimba(H(m + 12), 0.04, rng, hardness=0.5, decay=0.06, tail=0.1)
            v = 0.55 if s % 4 == 0 else 0.3
            dsp.place(buf, dsp.pan(_soft(note) * v, 0.3 if s % 2 else -0.3), dsp.samples(at0 + s * SIXTEENTH))
        if bar % 2 == 0:  # the siren: a reed rising a fourth (A -> D), held
            m = dsp.samples(2 * BAR)
            u = np.clip(dsp.time_axis(m) / (BAR * 0.8), 0.0, 1.0)
            f = H(69) * 2.0 ** (5.0 * (u * u * (3 - 2 * u)) / 12.0)
            siren = reed(f, 2 * BAR * 0.9, rng, brightness=4.5, attack=0.3, release=1.2, breath=0.03,
                         vibrato_cents=12.0)
            dsp.place(buf, dsp.pan(0.35 * siren, 0.15), dsp.samples(at0 + BEAT))
        for s in (2, 6, 10, 14):
            m = dsp.samples(0.05)
            tk = dsp.bandpass(dsp.white(m, rng), 6500.0, 4.0) * dsp.perc(m, 0.008, 0.01)
            dsp.place(buf, dsp.pan(0.2 * tk, 0.6), dsp.samples(at0 + s * SIXTEENTH))
    x = dsp.periodic(dsp.lowpass, dsp.wrap(buf, n), 5000.0)
    return _space(x, rng, n, reverb_s=1.6, mix=0.2)


@sound("mus_kessel_heavy", "music", -27.0, **LAYER)
def heavy(rng: np.random.Generator) -> np.ndarray:
    n = _n()
    buf = np.zeros((2, n + dsp.samples(3.0)))
    for bar in range(BARS):
        at0 = bar * BAR
        root = CHORDS[bar // 4][0]
        for half, m in enumerate([root, root + 7]):
            dur = 2 * BEAT * 0.9
            low = reed(H(m), dur, rng, brightness=7.0, attack=0.04, release=0.25, breath=0.02, vibrato_cents=0.0)
            octv = reed(H(m + 12), dur, rng, brightness=6.0, attack=0.05, release=0.25, breath=0.02,
                        vibrato_cents=0.0)
            dsp.place(buf, dsp.stereo(0.5 * low + 0.3 * octv), dsp.samples(at0 + half * 2 * BEAT))
        for b in range(4):
            v = 0.8 if b % 2 == 0 else 0.55
            dsp.place(buf, dsp.pan(v * taiko(rng, 70.0, 0.4), -0.2), dsp.samples(at0 + b * BEAT))
            dsp.place(buf, dsp.pan(0.6 * v * taiko(rng, 70.0, 0.3), 0.2), dsp.samples(at0 + b * BEAT + SIXTEENTH))
        m = dsp.samples(BAR * 0.6)
        tt = dsp.time_axis(m)
        sub = dsp.sine(H(root + 12) * (1 + 0.02 * np.sin(2 * np.pi * 9 * tt)), m) * dsp.perc(m, 0.01, 0.5)
        dsp.place(buf, dsp.stereo(0.5 * sub), dsp.samples(at0))
    x = dsp.periodic(dsp.lowpass, dsp.wrap(buf, n), 3600.0)
    return _space(x, rng, n, reverb_s=1.8, mix=0.2)


# --------------------------------------------------------------------------- transition hits


STING = dict(fmt="ogg", channels=2, folder="music/stings")


@sound("mus_hit_combat", "sting", -24.0, min_seconds=1.5, max_seconds=3.6, **STING)
def hit_combat(rng: np.random.Generator) -> np.ndarray:
    buf = np.zeros((2, dsp.samples(4.0)))
    m = dsp.samples(0.9)
    u = dsp.time_axis(m) / 0.9
    suck = dsp.sweep(dsp.pink(m, rng), "bp", 300.0 * 10.0 ** u, 1.0) * u ** 3 * 0.5
    dsp.place(buf, dsp.stereo(suck), 0)
    downbeat = 0.9
    dsp.place(buf, dsp.stereo(1.0 * taiko(rng, 55.0, 0.9)), dsp.samples(downbeat - 2 * SIXTEENTH))
    dsp.place(buf, dsp.stereo(1.2 * taiko(rng, 50.0, 1.2)), dsp.samples(downbeat))
    low = reed(H(38), 1.8, rng, brightness=6.0, attack=0.03, release=0.9, breath=0.02, vibrato_cents=0.0)
    hi = reed(H(50), 1.8, rng, brightness=5.0, attack=0.04, release=0.9, breath=0.02, vibrato_cents=3.0)
    dsp.place(buf, dsp.stereo(0.5 * low + 0.35 * hi), dsp.samples(downbeat))
    y = dsp.reverb(buf, rng, seconds=2.2, mix=0.28, predelay_ms=15.0, damp=0.6)
    y = dsp.trim_tail(dsp.dc_block(dsp.highpass(y, 30.0)), -60.0)[:, : dsp.samples(3.4)]
    return dsp.fade(y, 0.01, 0.8)


@sound("mus_hit_aftermath", "sting", -25.0, min_seconds=2.5, max_seconds=5.6, **STING)
def hit_aftermath(rng: np.random.Generator) -> np.ndarray:
    buf = np.zeros((2, dsp.samples(6.5)))
    at = 0.1
    for m, beats in [(74, 0.75), (69, 0.75), (66, 0.75), (62, 2.5)]:
        dur = beats * BEAT
        note = reed(H(m), dur * 0.95, rng, brightness=3.0, attack=0.06, release=0.5, breath=0.05,
                    vibrato_cents=6.0)
        dsp.place(buf, dsp.pan(0.5 * note, -0.1), dsp.samples(at))
        at += dur
    from synth.instruments import bell

    dsp.place(buf, dsp.pan(0.25 * bell(H(62), rng, decay=1.6, brightness=0.5), 0.3), dsp.samples(at - 1.8))
    y = dsp.reverb(buf, rng, seconds=3.2, mix=0.38, predelay_ms=25.0, damp=0.55)
    y = dsp.trim_tail(dsp.dc_block(dsp.highpass(y, 30.0)), -60.0)[:, : dsp.samples(5.4)]
    return dsp.fade(y, 0.01, 1.2)


# --------------------------------------------------------------------------- menu


MENU_LUFS = -26.0


@sound("mus_menu_theme", "bed", MENU_LUFS, fmt="ogg", channels=2, loop=True, folder="music/beds",
       min_seconds=LOOP - 0.01, max_seconds=LOOP + 0.01)
def menu_theme(rng: np.random.Generator) -> np.ndarray:
    n = _n()
    buf = np.zeros((2, n + dsp.samples(10.0)))
    block = 4 * BAR
    for i, (bass, voicing) in enumerate(CHORDS):
        at = dsp.samples(i * block)
        for k, m in enumerate(voicing):
            v = pad_voice(H(m), block, rng, attack=2.5, release=4.0, detune_cents=7.0, brightness=3.2 + 0.4 * k)
            dsp.place(buf, v * (0.8 if k == 0 else 0.5), at)
        low = soft_sine(H(bass), block, attack=2.0, release=3.5, harmonics=(1.0, 0.25, 0.08))
        dsp.place(buf, dsp.stereo(low * 0.7), at)
    for bar in range(BARS):  # a slow marimba pulse: quarter notes, chord tones
        voicing = CHORDS[bar // 4][1]
        for b in range(4):
            m = sorted(voicing)[(b * 2 + bar) % len(voicing)] + 12
            note = marimba(H(m), 0.1, rng, hardness=0.35, decay=0.35, tail=0.6)
            dsp.place(buf, dsp.pan(_soft(note) * (0.4 if b == 0 else 0.25), 0.3 if b % 2 else -0.3),
                      dsp.samples(bar * BAR + b * BEAT))
    phrases = [
        (4.0, [(74, 1.0), (81, 3.0), (83, 1.0), (80, 5.0)], 1.0),       # the motif, in full, broad
        (20.0, [(76, 1.0), (83, 3.0), (85, 1.0), (81, 5.0)], 0.95),     # up a step
        (36.0, [(78, 1.0), (85, 2.0), (86, 1.0), (83, 4.0)], 0.9),
        (52.0, [(74, 1.0), (81, 2.0), (83, 1.0), (86, 6.0)], 1.0),      # answered: rises to the high D
    ]
    for start, notes, vel in phrases:
        at = start
        for m, beats in notes:
            dsp.place(buf, dsp.pan(motif_voice(m, beats, vel, rng), 0.1), dsp.samples(at * BEAT))
            at += beats
    return _space(buf, rng, n, reverb_s=4.5, mix=0.42, echo_s=BEAT * 1.5, feedback=0.3, echo_mix=0.25)


@sound("mus_sting_outsurveyed", "sting", -22.0, min_seconds=3.5, max_seconds=6.6, **STING)
def sting_outsurveyed(rng: np.random.Generator) -> np.ndarray:
    buf = np.zeros((2, dsp.samples(7.0)))
    at = 0.1
    for m, beats in [(74, 0.5), (81, 1.0), (83, 0.5), (80, 2.5)]:
        v = motif_voice(m, beats, 0.75, rng, 0.42)
        dsp.place(buf, dsp.pan(dsp.lowpass(v, 2600.0), -0.25), dsp.samples(at))
        at += beats * 0.42
    at2 = 1.1
    for m, dur in [(62, 0.35), (69, 0.35), (70, 0.35), (71, 0.35), (72, 0.4), (68, 2.2)]:
        k = dsp.samples(dur + 0.3)
        f = H(m)
        saw = dsp.warm_saw(f, k, 9.0) + dsp.warm_saw(f * 1.012, k, 9.0)
        ring = saw * (0.6 + 0.4 * dsp.sine(f * 1.414, k))
        ring = dsp.saturate(ring, 1.6) * dsp.ar(k, 0.01, 0.25, dur)
        ring = dsp.lowpass(ring, 3200.0)
        dsp.place(buf, dsp.pan(0.35 * ring, 0.3), dsp.samples(at2))
        at2 += dur
    m = dsp.samples(2.6)
    cluster = sum(dsp.warm_saw(H(n0), m, 6.0) for n0 in (50, 56, 57)) * dsp.ar(m, 0.02, 1.2, 1.3)
    dsp.place(buf, dsp.stereo(0.18 * dsp.lowpass(cluster, 1600.0)), dsp.samples(at2 - 2.2))
    y = dsp.reverb(buf, rng, seconds=2.6, mix=0.3, predelay_ms=20.0, damp=0.6)
    y = dsp.trim_tail(dsp.dc_block(dsp.highpass(y, 30.0)), -60.0)[:, : dsp.samples(6.2)]
    return dsp.fade(y, 0.01, 1.2)
