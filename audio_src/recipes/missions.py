"""Missions (Phase 5): objectives, briefing and debrief, mission launch, and
the Survey mission's storm.

Objectives are the Advisor's: Meridian dyads through the ship channel (world.py),
never the unit instruments. Each objective event owns a contour:

  objective_new               a three-dyad pickup climbing into a held D+A, a high ping: "here is a task"
  objective_hidden            a muffled tritone (G#+D) that opens up and settles on A+E, a faint G# above: a secret
  objective_done              primary: A+E, B+F#, then D+A held with the octave, answered by a high D+A (-19)
  objective_done_secondary    the same idea, smaller: two dyads up a fourth, short-long (-22)
  objective_failed            D+A bending down three semitones while its filter closes, over a beating low D
  storm_warning               three dyads stepping down a whole tone each (out of key) over a rising gust
  detected                    six dyads climbing in semitones, staccato, into a held trembling tritone
  objective_time_low          a clock: tick-tock dyads (A+E, G#+D) four times, the last falling a tone

The briefing is "voiced" only by tone: there are no spoken words anywhere in
the game. Its bed is the Meridian family slowed to a pad (sine dyads with a slow
tremolo, through the ship channel, a low D, sparse telemetry pings), text
reveals tick softly, and the launch phrase plays when the mission begins.
"""

from __future__ import annotations

import numpy as np

from synth import dsp
from synth.instruments import chime, marimba, pad_voice, reed, soft_sine

from . import sound
from .advisor import ADVISOR_LUFS, _phrase, glide_dyad
from .interface import UI_LUFS, _done, _seq, tick
from .music_kessel import motif_voice
from .world import advisor_dyad, ship_channel

H = dsp.midi_hz


# --------------------------------------------------------------------------- objectives (Advisor)


@sound("advisor_objective_new", "advisor", ADVISOR_LUFS, max_seconds=1.6)
def advisor_objective_new(rng: np.random.Generator) -> np.ndarray:
    parts = [(0.0, 0.7, advisor_dyad(H(71), H(78), 0.045)),
             (0.07, 0.8, advisor_dyad(H(73), H(80), 0.045)),
             (0.14, 1.0, advisor_dyad(H(74), H(81), 0.38)),
             (0.3, 0.28, advisor_dyad(H(93), H(98), 0.05))]
    return _phrase(parts, rng, 1.4)


@sound("advisor_objective_hidden", "advisor", ADVISOR_LUFS, max_seconds=1.9)
def advisor_objective_hidden(rng: np.random.Generator) -> np.ndarray:
    total = 1.7
    buf = np.zeros(dsp.samples(total))
    secret = advisor_dyad(H(68), H(74), 0.42)
    n = len(secret)
    u = np.clip(dsp.time_axis(n) / 0.42, 0, 1)
    secret = dsp.sweep(secret, "lp", 700.0 * 6.0 ** u, 0.8) * (0.4 + 0.6 * u)
    dsp.place(buf, secret, 0)
    dsp.place(buf, advisor_dyad(H(69), H(76), 0.36), dsp.samples(0.46))
    dsp.place(buf, 0.22 * advisor_dyad(H(92), H(92), 0.2), dsp.samples(0.62))
    y = ship_channel(buf, rng)
    y = dsp.reverb(y, rng, seconds=0.9, mix=0.18, damp=0.7).mean(axis=0)
    return dsp.fade(dsp.trim_tail(dsp.dc_block(y), -55.0), 0.001, 0.05)


@sound("advisor_objective_done", "advisor", ADVISOR_LUFS + 1.0, max_seconds=2.0)
def advisor_objective_done(rng: np.random.Generator) -> np.ndarray:
    parts = [(0.0, 0.8, advisor_dyad(H(69), H(76), 0.09)),
             (0.13, 0.85, advisor_dyad(H(71), H(78), 0.09)),
             (0.26, 1.0, advisor_dyad(H(74), H(81), 0.5)),
             (0.26, 0.45, advisor_dyad(H(86), H(86), 0.5)),
             (0.62, 0.6, advisor_dyad(H(86), H(93), 0.3))]
    return _phrase(parts, rng, 1.8, room=0.16)


@sound("advisor_objective_done_secondary", "advisor", ADVISOR_LUFS - 2.0, max_seconds=1.2)
def advisor_objective_done_secondary(rng: np.random.Generator) -> np.ndarray:
    parts = [(0.0, 0.85, advisor_dyad(H(81), H(88), 0.06)),
             (0.1, 1.0, advisor_dyad(H(86), H(93), 0.2))]
    return _phrase(parts, rng, 1.0, room=0.12)


@sound("advisor_objective_failed", "advisor", ADVISOR_LUFS, max_seconds=1.9)
def advisor_objective_failed(rng: np.random.Generator) -> np.ndarray:
    total = 1.7
    buf = np.zeros(dsp.samples(total))
    dsp.place(buf, 0.8 * advisor_dyad(H(74), H(81), 0.12), 0)
    fall = glide_dyad(H(74), H(81), 0.6, -3.0, 0.15)
    n = len(fall)
    u = np.clip(dsp.time_axis(n) / 0.6, 0, 1)
    fall = dsp.sweep(fall, "lp", 5000.0 * 0.15 ** u, 0.7)
    dsp.place(buf, fall, dsp.samples(0.2))
    m = dsp.samples(1.2)
    under = 0.28 * (dsp.sine(H(50), m) + dsp.sine(H(50) + 2.5, m)) * dsp.ar(m, 0.1, 0.5, 0.6)
    dsp.place(buf, under, dsp.samples(0.2))
    y = ship_channel(buf, rng)
    y = dsp.reverb(y, rng, seconds=0.8, mix=0.14, damp=0.7).mean(axis=0)
    return dsp.fade(dsp.trim_tail(dsp.dc_block(y), -55.0), 0.001, 0.08)


@sound("advisor_storm_warning", "advisor", ADVISOR_LUFS + 1.0, max_seconds=1.9)
def advisor_storm_warning(rng: np.random.Generator) -> np.ndarray:
    parts = [(0.0, 1.0, advisor_dyad(H(76), H(83), 0.15)),
             (0.24, 0.95, advisor_dyad(H(74), H(81), 0.15)),
             (0.48, 0.9, glide_dyad(H(72), H(79), 0.36, -0.7, 0.4))]
    n = dsp.samples(1.2)
    u = dsp.time_axis(n) / 1.2
    gust = dsp.sweep(dsp.pink(n, rng), "bp", 500.0 * 4.0 ** u, 1.5) * dsp.env([(0, 0), (0.7, 0.5), (1.2, 0)], n)
    parts.append((0.0, 0.5, gust))
    return _phrase(parts, rng, 1.7)


@sound("advisor_detected", "advisor", ADVISOR_LUFS + 1.0, max_seconds=1.6)
def advisor_detected(rng: np.random.Generator) -> np.ndarray:
    parts = []
    for k in range(6):
        lo = 73 + k
        parts.append((k * 0.065, 0.75 + 0.05 * k, advisor_dyad(H(lo), H(lo + 6), 0.04)))
    held = advisor_dyad(H(79), H(85), 0.4)
    n = len(held)
    held *= 0.75 + 0.25 * np.sin(2 * np.pi * 11.0 * dsp.time_axis(n))
    parts.append((0.42, 1.0, held))
    return _phrase(parts, rng, 1.4, room=0.1)


@sound("advisor_objective_time_low", "advisor", ADVISOR_LUFS, max_seconds=1.6)
def advisor_objective_time_low(rng: np.random.Generator) -> np.ndarray:
    parts = []
    for k in range(4):
        lo, hi = (81, 88) if k % 2 == 0 else (80, 86)
        parts.append((k * 0.2, 0.85 + 0.05 * k, advisor_dyad(H(lo), H(hi), 0.05)))
    parts.append((0.8, 1.0, glide_dyad(H(81), H(88), 0.3, -2.0, 0.3)))
    return _phrase(parts, rng, 1.5)


# --------------------------------------------------------------------------- interface


@sound("ui_objective_tick", "ui", UI_LUFS - 2.0, max_seconds=0.25)
def ui_objective_tick(rng: np.random.Generator) -> np.ndarray:
    """Progress on an objective: two glass ticks, A6 then D7."""
    a = tick(rng, H(93), 0.009, 0.12)
    b = 0.8 * tick(rng, H(98), 0.016, 0.05)
    return _done(_seq([(0.0, a), (0.032, b)], 0.2))


BRIEFING_TICKS = [H(100), H(102), H(105)]  # E7 F#7 A7


def _briefing_tick(rng: np.random.Generator, f: float) -> np.ndarray:
    return _done(tick(rng, f, 0.0035, 0.12, 0.6))


for _i, _f in enumerate(BRIEFING_TICKS, start=1):
    sound(f"ui_briefing_tick_{_i}", "ui", UI_LUFS - 7.0, max_seconds=0.08,
          params={"recipe": "_briefing_tick"})(lambda rng, f=_f: _briefing_tick(rng, f))


def _soft_dyads(rng: np.random.Generator, pairs: list[tuple[int, int]], step: float, total: float) -> np.ndarray:
    buf = np.zeros(dsp.samples(total))
    for i, (lo, hi) in enumerate(pairs):
        dsp.place(buf, advisor_dyad(H(lo), H(hi), 0.05 if i < len(pairs) - 1 else 0.09), dsp.samples(i * step))
    y = dsp.bandpass(dsp.highpass(buf, 350.0), 1800.0, 0.6) * 1.4 + 0.5 * dsp.highpass(buf, 350.0)
    return _done(y)


@sound("ui_briefing_open", "ui", UI_LUFS, max_seconds=0.3)
def ui_briefing_open(rng: np.random.Generator) -> np.ndarray:
    return _soft_dyads(rng, [(74, 81), (81, 88)], 0.07, 0.3)


@sound("ui_briefing_close", "ui", UI_LUFS - 1.0, max_seconds=0.3)
def ui_briefing_close(rng: np.random.Generator) -> np.ndarray:
    return _soft_dyads(rng, [(81, 88), (74, 81)], 0.07, 0.3)


@sound("ui_debrief_open", "ui", UI_LUFS, max_seconds=0.3)
def ui_debrief_open(rng: np.random.Generator) -> np.ndarray:
    notes = [(0.0, 74), (0.05, 78), (0.1, 81)]
    parts = [(at, marimba(H(m), 0.03, rng, hardness=0.5, decay=0.05 if i < 2 else 0.09, tail=0.12))
             for i, (at, m) in enumerate(notes)]
    return _done(_seq(parts, 0.3))


@sound("ui_mission_select", "ui", UI_LUFS, max_seconds=0.3)
def ui_mission_select(rng: np.random.Generator) -> np.ndarray:
    click = dsp.mix(tick(rng, 2350.0, 0.007), 0.4 * tick(rng, 1175.0, 0.012, 0.0))
    glass = 0.5 * chime(H(86), 0.03, rng, brightness=0.6, decay=0.08, tail=0.15)
    return _done(_seq([(0.0, click), (0.02, glass)], 0.3))


# --------------------------------------------------------------------------- stings


STING = dict(fmt="ogg", channels=2, folder="music/stings")


@sound("mus_sting_launch", "sting", -22.0, min_seconds=2.5, max_seconds=4.6, **STING)
def sting_launch(rng: np.random.Generator) -> np.ndarray:
    """Mission start: a Meridian dyad lifts off (D+A rising to A+E), the
    Concord answers with a rising marimba-and-chime D F# A D, a soft drum
    lands on the downbeat and the motif's opening leap D -> A rings out on
    the reed over a Dmaj9 swell."""
    buf = np.zeros((2, dsp.samples(5.0)))
    lift = glide_dyad(H(74), H(81), 0.5, 7.0, 0.1)
    lift = ship_channel(lift, rng)
    dsp.place(buf, dsp.stereo(0.5 * lift), 0)
    for k, m in enumerate([62, 66, 69, 74, 78, 81]):
        note = marimba(H(m), 0.08, rng, hardness=0.55, decay=0.3, tail=0.6)
        note = dsp.mix(note, 0.35 * chime(H(m + 12), 0.05, rng, brightness=0.5, decay=0.25, tail=0.6))
        note *= dsp.ar(len(note), 0.008, 0.05, len(note) / dsp.SR - 0.06)
        dsp.place(buf, dsp.pan(0.45 * note, -0.5 + 0.2 * k), dsp.samples(0.3 + 0.07 * k))
    downbeat = 0.8
    m = dsp.samples(0.8)
    t = dsp.time_axis(m)
    drum = dsp.sine(62.0 * (1.0 + 0.5 * np.exp(-t / 0.025)), m) * dsp.perc(m, 0.008, 0.18)
    drum += 0.3 * dsp.lowpass(dsp.white(m, rng), 400.0) * dsp.perc(m, 0.008, 0.03)
    dsp.place(buf, dsp.stereo(0.9 * drum), dsp.samples(downbeat))
    at = downbeat
    for i, (mm, beats) in enumerate([(74, 0.5), (81, 3.0)]):
        v = motif_voice(mm, beats, 0.9 if i == 0 else 1.0, rng, 0.42)
        dsp.place(buf, dsp.pan(v, 0.1), dsp.samples(at))
        at += beats * 0.42
    for k, mm in enumerate([50, 57, 61, 64, 66]):
        p = pad_voice(H(mm), 2.2, rng, attack=0.5, release=1.6, brightness=3.2)
        dsp.place(buf, p * (0.45 if k == 0 else 0.28), dsp.samples(downbeat))
    low = soft_sine(H(38), 2.2, attack=0.05, release=1.5, harmonics=(1.0, 0.3, 0.1))
    dsp.place(buf, dsp.stereo(0.5 * low), dsp.samples(downbeat))
    y = dsp.delay(buf, 0.315, 0.25, 0.18, 2600.0, ping_pong=True)
    y = dsp.reverb(y, rng, seconds=2.6, mix=0.32, predelay_ms=20.0, damp=0.55)
    y = dsp.trim_tail(dsp.dc_block(dsp.highpass(y, 30.0)), -60.0)[:, : dsp.samples(4.2)]
    return dsp.fade(y, 0.004, 1.0)


def thunder(rng: np.random.Generator, dur: float, crack: float = 0.0) -> np.ndarray:
    """Distant thunder: brown noise rolls with a few swells; `crack` adds a
    sharper close strike at the start. Mono."""
    n = dsp.samples(dur)
    rolls = 0.5 + 0.5 * dsp.smooth_random(n, rng, 3.0, periodic=False)
    body = dsp.lowpass(dsp.brown(n, rng), 180.0) * rolls ** 2
    body *= dsp.env([(0.0, 0.0), (0.12, 1.0), (dur * 0.4, 0.7), (dur, 0.0)], n, 1.2)
    out = body
    if crack > 0.0:
        snap = dsp.bandpass(dsp.white(n, rng), 2400.0, 0.5) * dsp.perc(n, 0.002, 0.05)
        boom = dsp.sine(45.0 + 40.0 * np.exp(-dsp.time_axis(n) / 0.06), n) * dsp.perc(n, 0.003, 0.35)
        out = out + crack * (0.6 * snap + boom)
    return out


@sound("mus_storm_minute", "sting", -22.0, min_seconds=3.0, max_seconds=5.6, **STING)
def storm_minute(rng: np.random.Generator) -> np.ndarray:
    """One minute left (Survey): distant thunder rolls in, the wind rises and
    a low reed states the motif's opening leap, darkened: D -> A, sagging to G#."""
    buf = np.zeros((2, dsp.samples(6.0)))
    dsp.place(buf, dsp.pan(thunder(rng, 3.6), -0.3), dsp.samples(0.05))
    dsp.place(buf, dsp.pan(0.6 * thunder(rng, 2.6), 0.5), dsp.samples(1.3))
    n = dsp.samples(4.5)
    u = dsp.time_axis(n) / 4.5
    for ch in range(2):
        wind = dsp.sweep(dsp.pink(n, rng), "bp", 300.0 * 5.0 ** u, 0.9)
        dsp.place(buf[ch], 0.35 * wind * dsp.env([(0, 0), (2.8, 1.0), (4.5, 0)], n), 0)
    at = 0.6
    for i, (m0, beats) in enumerate([(50, 0.5), (57, 1.5), (56, 2.0)]):
        dur = beats * 0.55
        note = reed(H(m0), dur * 0.95, rng, brightness=4.0, attack=0.05, release=0.4, breath=0.05, vibrato_cents=4.0)
        dsp.place(buf, dsp.stereo(0.55 * note), dsp.samples(at))
        at += dur
    y = dsp.reverb(buf, rng, seconds=3.0, mix=0.35, predelay_ms=25.0, damp=0.6)
    y = dsp.trim_tail(dsp.dc_block(dsp.highpass(y, 30.0)), -60.0)[:, : dsp.samples(5.2)]
    return dsp.fade(y, 0.01, 1.2)


@sound("mus_storm_countdown", "sting", -21.0, min_seconds=10.5, max_seconds=12.5, **STING)
def storm_countdown(rng: np.random.Generator) -> np.ndarray:
    """The last ten seconds (Survey): one tick a second, each a semitone
    higher with a low thump under it, the wind rising to a roar, and the storm
    breaking with a thunder crack on the tenth second."""
    total = 12.0
    buf = np.zeros((2, dsp.samples(total)))
    for k in range(10):
        f = H(81 + k)
        m = dsp.samples(0.3)
        tk = dsp.sine(f, m) * dsp.perc(m, 0.008, 0.04) + 0.3 * dsp.sine(f * 2.0, m) * dsp.perc(m, 0.008, 0.015)
        tt = dsp.time_axis(m)
        thump = dsp.sine(55.0 * (1.0 + 0.4 * np.exp(-tt / 0.02)), m) * dsp.perc(m, 0.008, 0.08)
        gain = 0.45 + 0.05 * k
        dsp.place(buf, dsp.pan(gain * tk, 0.15 if k % 2 else -0.15), dsp.samples(k * 1.0))
        dsp.place(buf, dsp.stereo(gain * 0.8 * thump), dsp.samples(k * 1.0))
    n = dsp.samples(10.2)
    u = dsp.time_axis(n) / 10.2
    for ch in range(2):
        wind = dsp.sweep(dsp.pink(n, rng), "bp", 250.0 * 8.0 ** u, 0.8)
        dsp.place(buf[ch], 0.5 * wind * u ** 1.6, 0)
    strike = thunder(rng, 1.8, crack=1.0)
    dsp.place(buf, dsp.stereo(0.9 * strike), dsp.samples(10.0))
    y = dsp.reverb(buf, rng, seconds=2.4, mix=0.25, predelay_ms=15.0, damp=0.6)
    y = dsp.trim_tail(dsp.dc_block(dsp.highpass(y, 30.0)), -60.0)[:, : dsp.samples(11.8)]
    return dsp.fade(y, 0.01, 0.8)


# --------------------------------------------------------------------------- beds


BED = dict(fmt="ogg", channels=2, loop=True, folder="music/beds")
BED_SECONDS = 32.0  # a multiple of 64 samples: the native Vorbis encoder pads to that


def _loop_space(x: np.ndarray, rng: np.random.Generator, n: int, seconds: float, mix: float) -> np.ndarray:
    y = dsp.wrap(x, n)
    y = dsp.wrap(dsp.reverb(y, rng, seconds=seconds, mix=mix, predelay_ms=25.0, damp=0.6), n)
    y = dsp.periodic(dsp.highpass, y, 35.0)
    return y - y.mean(axis=1, keepdims=True)


def _whole(f: float, seconds: float) -> float:
    return max(round(f * seconds), 1) / seconds


@sound("mus_briefing_bed", "bed", -28.0, min_seconds=BED_SECONDS - 0.01, max_seconds=BED_SECONDS + 0.01, **BED)
def briefing_bed(rng: np.random.Generator) -> np.ndarray:
    """Under the briefing panel: the Meridian's sine dyads slowed into a pad
    (D+A, E+B, B+F#, A+E, eight seconds each, slow tremolo), a low D, the ship
    channel's faint carrier, and a telemetry ping on A6 or E7 every 3.2
    seconds. Calm, attentive, no melody to talk over the text."""
    L = BED_SECONDS
    n = dsp.samples(L)
    t = dsp.time_axis(n)
    buf = np.zeros((2, n + dsp.samples(8.0)))
    seg = L / 4
    for i, (lo, hi) in enumerate([(62, 69), (64, 71), (59, 66), (57, 64)]):
        m = dsp.samples(seg + 3.0)
        tt = dsp.time_axis(m)
        trem = 1.0 - 0.15 * (0.5 + 0.5 * np.sin(2 * np.pi * 0.5 * tt))
        x = soft_sine(H(lo), seg, attack=2.2, release=3.0, harmonics=(1.0, 0.06))[:m]
        y = 0.8 * soft_sine(H(hi), seg, attack=2.6, release=3.0, harmonics=(1.0, 0.04))[:m]
        z = 0.25 * soft_sine(H(hi + 12), seg, attack=3.0, release=3.0, harmonics=(1.0,))[:m]
        k = min(len(x), len(y), len(z))
        dyad = (x[:k] + y[:k] + z[:k]) * trem[:k]
        dsp.place(buf, dsp.pan(dyad, -0.25), dsp.samples(i * seg))
        dsp.place(buf, dsp.pan(0.8 * dyad, 0.3), dsp.samples(i * seg + 0.012))
    x = dsp.wrap(buf, n)
    drone = 0.35 * (dsp.sine(_whole(H(38), L), n) + 0.3 * dsp.sine(_whole(H(50), L), n))
    drone *= 0.85 + 0.15 * np.sin(2 * np.pi * 2 * t / L)
    x += dsp.stereo(drone)
    pings = np.zeros((2, n + dsp.samples(3.0)))
    for k in range(10):
        f = H(93) if k % 3 != 2 else H(100)
        p = chime(f, 0.03, rng, brightness=0.4, decay=0.35, attack=0.012, tail=1.2)
        p *= dsp.ar(len(p), 0.01, 0.2, len(p) / dsp.SR - 0.22)
        dsp.place(pings, dsp.pan(0.12 * p, -0.5 + 0.33 * (k % 4)), dsp.samples(k * 3.2 + 1.1))
    x += dsp.wrap(pings, n)
    carrier = np.stack([dsp.periodic(dsp.bandpass, dsp.pink(n, rng), 4200.0, 0.8) for _ in range(2)])
    x += 0.012 * carrier
    x = dsp.periodic(dsp.lowpass, x, 5200.0)
    return _loop_space(x, rng, n, 3.2, 0.35)


@sound("mus_debrief_bed", "bed", -28.0, min_seconds=BED_SECONDS - 0.01, max_seconds=BED_SECONDS + 0.01, **BED)
def debrief_bed(rng: np.random.Generator) -> np.ndarray:
    """Under the debrief: a slow Dmaj9 -> Bm(add9) pad, a low D, and the Trail
    motif once per loop on a soft chime, slowed and far away: what was found,
    looked back on. Neither a victory nor a defeat; the sting has said that."""
    L = BED_SECONDS
    n = dsp.samples(L)
    buf = np.zeros((2, n + dsp.samples(8.0)))
    for i, voicing in enumerate([[50, 57, 61, 64, 66], [47, 54, 61, 62, 66]]):
        for k, m in enumerate(voicing):
            p = pad_voice(H(m), L / 2, rng, attack=3.0, release=4.0, brightness=2.6 + 0.3 * k, detune_cents=6.0)
            dsp.place(buf, p * (0.55 if k == 0 else 0.32), dsp.samples(i * L / 2))
    low = soft_sine(H(38), L / 2, attack=2.0, release=3.0, harmonics=(1.0, 0.2))
    dsp.place(buf, dsp.stereo(0.45 * low), 0)
    dsp.place(buf, dsp.stereo(0.45 * soft_sine(H(35), L / 2, attack=2.0, release=3.0, harmonics=(1.0, 0.2))),
              dsp.samples(L / 2))
    at = 3.0
    for i, (m, beats) in enumerate([(74, 0.5), (81, 1.5), (83, 0.5), (80, 3.0)]):
        v = motif_voice(m, beats, 0.5, rng, 1.0)
        dsp.place(buf, dsp.pan(dsp.lowpass(v, 3000.0), 0.2 - 0.12 * i), dsp.samples(at))
        at += beats * 1.0
    x = dsp.periodic(dsp.lowpass, dsp.wrap(buf, n), 3600.0)
    y = dsp.wrap(dsp.delay(x, 1.5, 0.3, 0.25, 2400.0, ping_pong=True), n)
    return _loop_space(y, rng, n, 4.5, 0.42)
