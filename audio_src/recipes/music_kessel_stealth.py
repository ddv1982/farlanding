"""Kessel Reach: stealth and storm layers of the explore clip.

Three more synchronised layers on the explore grid (80 BPM, 4/4, 16 bars,
48 s, chords Dmaj9, E/D, Bm(add9), Aadd9), so the MusicDirector can bring them
in on the beat without a clip change:

  hush    (Unaware)    sparse: a held high air on two chord tones per block that
                       swells and fades, a muted marimba drop on the first beat of
                       every other bar, a faint low D. Room to hear footsteps.
  watch   (Suspicious) the pulse: a low two-stroke heartbeat on beats 1 and 3,
                       a closed tick on every off-beat, the raised fourth (G#)
                       shadowing the last beat of every second bar. The drive and
                       drums layers join it at Alerted.
  storm   (Survey)     the storm approaching: a low rumble that breathes with the
                       4-bar phrase, gusts sweeping across the stereo field, a
                       half-time sub throb on D, distant thunder in bars 3, 9 and 14.

Attacks stay at 8 ms or softer (native Vorbis pre-echo, ADR 0005).
"""

from __future__ import annotations

import numpy as np

from synth import dsp
from synth.instruments import marimba, soft_sine

from . import sound
from .missions import thunder
from .music_kessel import BAR, BARS, BEAT, CHORDS, LOOP, _space
from .music_kessel_combat import LAYER, _soft

H = dsp.midi_hz


@sound("mus_kessel_stealth_hush", "music", -31.0, **LAYER)
def hush(rng: np.random.Generator) -> np.ndarray:
    n = dsp.samples(LOOP)
    buf = np.zeros((2, n + dsp.samples(6.0)))
    block = 4 * BAR
    for i, (bass, voicing) in enumerate(CHORDS):
        top = sorted(voicing)[-2:]
        for k, m in enumerate(top):
            tone = soft_sine(H(m + 12), block * 0.8, attack=3.5, release=4.0, harmonics=(1.0, 0.05))
            dsp.place(buf, dsp.pan(0.18 * tone, -0.5 + 1.0 * k), dsp.samples(i * block + 0.5 * BAR * k))
        low = soft_sine(H(bass + 12), block, attack=3.0, release=3.0, harmonics=(1.0, 0.15))
        dsp.place(buf, dsp.stereo(0.22 * low), dsp.samples(i * block))
    for bar in range(0, BARS, 2):
        bass, voicing = CHORDS[bar // 4]
        m = sorted(voicing)[1] + 12
        drop = _soft(marimba(H(m), 0.08, rng, hardness=0.25, decay=0.5, tail=1.0), 0.01)
        dsp.place(buf, dsp.pan(0.3 * dsp.lowpass(drop, 2500.0), 0.25 if bar % 4 else -0.25), dsp.samples(bar * BAR))
    x = dsp.wrap(buf, n)
    return _space(x, rng, n, reverb_s=4.5, mix=0.45, echo_s=BEAT * 1.5, feedback=0.3, echo_mix=0.25)


@sound("mus_kessel_stealth_watch", "music", -29.0, **LAYER)
def watch(rng: np.random.Generator) -> np.ndarray:
    n = dsp.samples(LOOP)
    buf = np.zeros((2, n + dsp.samples(2.0)))
    for bar in range(BARS):
        bass = CHORDS[bar // 4][0] + 12
        for beat in (0, 2):
            for k, (offset, gain) in enumerate([(0.0, 1.0), (0.22, 0.6)]):  # lub-dub
                beat_note = soft_sine(H(bass), 0.12, attack=0.01, release=0.18, harmonics=(1.0, 0.35, 0.1))
                dsp.place(buf, dsp.stereo(0.55 * gain * beat_note), dsp.samples(bar * BAR + (beat + offset) * BEAT))
        for s in range(4):
            m = dsp.samples(0.07)
            tk = dsp.bandpass(dsp.white(m, rng), 5200.0, 2.5) * dsp.perc(m, 0.008, 0.012)
            dsp.place(buf, dsp.pan(0.25 * tk, 0.4), dsp.samples(bar * BAR + (s + 0.5) * BEAT))
        if bar % 2 == 1:
            shadow = soft_sine(H(68), BEAT * 0.8, attack=0.03, release=0.3, harmonics=(1.0, 0.2))
            dsp.place(buf, dsp.pan(0.18 * shadow, -0.3), dsp.samples(bar * BAR + 3 * BEAT))
    x = dsp.periodic(dsp.lowpass, dsp.wrap(buf, n), 6000.0)
    return _space(x, rng, n, reverb_s=1.8, mix=0.2)


@sound("mus_kessel_storm", "music", -29.0, **LAYER)
def storm(rng: np.random.Generator) -> np.ndarray:
    n = dsp.samples(LOOP)
    t = dsp.time_axis(n)
    phrase = 0.5 - 0.5 * np.cos(2 * np.pi * 4 * t / LOOP)  # breathes once per 4 bars
    rumble = np.stack([dsp.periodic(dsp.lowpass, dsp.brown(n, rng), 160.0) for _ in range(2)])
    rumble *= 0.5 * (0.6 + 0.4 * phrase)
    pan_lfo = np.sin(2 * np.pi * 3 * t / LOOP)
    gust_fc = 400.0 * 3.0 ** (0.5 + 0.5 * np.sin(2 * np.pi * 8 * t / LOOP))
    gust = dsp.periodic(dsp.sweep, dsp.pink(n, rng), "bp", gust_fc, 1.0)
    gust *= 0.22 * (0.3 + 0.7 * phrase)
    gusts = dsp.pan(gust, 0.6 * pan_lfo)
    f = round(H(26) * 2 * LOOP) / LOOP  # D2, whole cycles per loop
    throb = dsp.sine(f, n) * (0.5 - 0.5 * np.cos(2 * np.pi * (BARS * 2) * t / LOOP)) ** 2  # half notes
    throb = dsp.stereo(0.3 * throb)
    rolls = np.zeros((2, n + dsp.samples(5.0)))
    for bar, side in [(2, -0.4), (8, 0.5), (13, -0.1)]:
        dsp.place(rolls, dsp.pan(0.8 * thunder(rng, 3.5), side), dsp.samples(bar * BAR + 0.4 * BEAT))
    x = rumble + gusts + throb + dsp.wrap(rolls, n)
    return _space(x, rng, n, reverb_s=3.0, mix=0.3)
