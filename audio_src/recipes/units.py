"""Unit acknowledgements: tonal signatures instead of voices.

Every Concord unit speaks in the same key (D, Lydian colour, shared with the
Kessel music) and through the same instrument family (chime / marimba / reed),
but each unit type owns a register, a rhythm and an interval:

  surveyor  high (D6-C#7), quick glassy triplets, thirds and sixths, a scan shimmer
  ranger    middle (A4-A5), two or three crisp marimba strokes, fourths and fifths
  bulwark   low (A1-A3), slow brassy reed with a sub, octaves and fifths, weight
  kite      upper-middle (E5-B5), gliding swoops with air, slides of a fifth/sixth
  hauler    low-middle (D3-B3), dotted short-long reed 'horn' dyads with a knock, steps
  fabricator upper (F#5-F#6), busy marimba grace-note flicks with tool ticks, seconds/fourths

The three kinds of reply follow one grammar for every unit, so players learn it
once: select rises (a question), move falls and resolves (an answer), attack
repeats a note with an accent (insistence).
"""

from __future__ import annotations

import numpy as np

from synth import dsp
from synth.instruments import chime, marimba, reed, soft_sine

from . import sound

UNIT_LUFS = -21.0
ROOM = dict(seconds=0.7, mix=0.16, predelay_ms=8.0, damp=0.6)


def _finish(x: np.ndarray, rng: np.random.Generator, room: dict = ROOM) -> np.ndarray:
    wet = dsp.reverb(x, rng, **room).mean(axis=0)
    return dsp.fade(dsp.trim_tail(dsp.dc_block(wet), -58.0), 0.001, 0.04)


def _sequence(notes: list[tuple[float, float]], voice, total: float) -> np.ndarray:
    """notes = [(start_seconds, *voice args)] rendered by voice(start_index)."""
    buf = np.zeros(dsp.samples(total))
    for i, (start, _) in enumerate(notes):
        dsp.place(buf, voice(i), dsp.samples(start))
    return buf


# --------------------------------------------------------------------------- surveyor


def surveyor(rng: np.random.Generator, midi: list[int], step: float, accent: bool = False,
             shimmer: bool = True) -> np.ndarray:
    total = step * len(midi) + 1.0
    buf = np.zeros(dsp.samples(total))
    for i, m in enumerate(midi):
        last = i == len(midi) - 1
        hard = 1.35 if accent and i < len(midi) - 1 else 1.0
        note = chime(dsp.midi_hz(m), 0.05, rng, brightness=0.8 * hard, decay=0.32 if last else 0.09, tail=0.6)
        dsp.place(buf, note * (0.8 if not last else 1.0), dsp.samples(i * step))
    if shimmer:
        # Scanner shimmer: a fast vibrato sine an octave above the last note.
        n = dsp.samples(0.35)
        f = dsp.midi_hz(midi[-1] + 12) * (1 + 0.012 * np.sin(2 * np.pi * 22 * dsp.time_axis(n)))
        sh = 0.07 * dsp.sine(f, n) * dsp.perc(n, 0.03, 0.09)
        dsp.place(buf, sh, dsp.samples(step * (len(midi) - 1)))
    return _finish(dsp.highpass(buf, 300.0), rng)


SURVEYOR = {
    "select": [([86, 90, 93], 0.055), ([88, 93, 97], 0.05), ([86, 93, 90, 95], 0.045)],
    "move": [([93, 90, 86], 0.055), ([97, 93, 88], 0.05), ([95, 93, 90, 86], 0.045)],
    "attack": [([93, 93, 86], 0.06), ([90, 90, 95], 0.06), ([86, 86, 93], 0.055)],
}

# --------------------------------------------------------------------------- ranger


def ranger(rng: np.random.Generator, midi: list[int], step: float, accent: bool = False) -> np.ndarray:
    total = step * len(midi) + 1.0
    buf = np.zeros(dsp.samples(total))
    for i, m in enumerate(midi):
        last = i == len(midi) - 1
        f = dsp.midi_hz(m)
        hard = 1.4 if accent and not last else 1.0
        wood = marimba(f, 0.1, rng, hardness=hard, decay=0.28 if last else 0.14)
        bell = 0.35 * chime(f, 0.1, rng, brightness=0.5, decay=0.25 if last else 0.12, tail=0.5)
        note = np.zeros(max(len(wood), len(bell)))
        note[: len(wood)] += wood
        note[: len(bell)] += bell
        dsp.place(buf, note * (1.15 if accent and not last else 1.0), dsp.samples(i * step))
    return _finish(dsp.highpass(buf, 120.0), rng)


RANGER = {
    "select": [([69, 74], 0.11), ([71, 76], 0.11), ([69, 76], 0.12)],
    "move": [([76, 69], 0.11), ([74, 69], 0.12), ([78, 74], 0.11)],
    "attack": [([69, 69, 76], 0.085), ([74, 74, 81], 0.085), ([69, 74, 81], 0.08)],
}

# --------------------------------------------------------------------------- bulwark


def bulwark(rng: np.random.Generator, midi: list[int], step: float, accent: bool = False) -> np.ndarray:
    hold = step * 0.8
    total = step * len(midi) + hold + 1.2
    buf = np.zeros(dsp.samples(total))
    for i, m in enumerate(midi):
        last = i == len(midi) - 1
        f = dsp.midi_hz(m)
        dur = hold * (1.4 if last else 0.85)
        body = reed(f, dur, rng, brightness=16.0 if accent else 12.0, attack=0.035, release=0.22,
                    breath=0.04, vibrato_hz=3.5, vibrato_cents=4.0)
        sub = 0.45 * soft_sine(f, dur, attack=0.03, release=0.25)
        # Two and three octaves up: a chime that lets the low voice read on small
        # speakers while the body still carries the weight.
        top = 0.5 * chime(f * 4.0, 0.1, rng, brightness=0.5, decay=0.3, tail=0.6)
        top = dsp.mix(top, 0.18 * chime(f * 8.0, 0.08, rng, brightness=0.4, decay=0.15, tail=0.4))
        note = np.zeros(max(len(body), len(sub), len(top)))
        note[: len(body)] += dsp.saturate(body * (1.6 if accent else 1.1), 1.5)
        note[: len(sub)] += sub
        note[: len(top)] += top
        dsp.place(buf, note, dsp.samples(i * step))
    buf = dsp.biquad(buf, "peak", 700.0, 0.7, 5.0)
    return _finish(dsp.highpass(buf, 38.0), rng, dict(seconds=0.9, mix=0.14, predelay_ms=10.0, damp=0.7))


BULWARK = {
    "select": [([38, 45], 0.26), ([38, 50], 0.28), ([40, 47], 0.26)],
    "move": [([45, 38], 0.26), ([50, 45], 0.28), ([47, 40], 0.26)],
    "attack": [([38, 38, 45], 0.17), ([38, 38, 50], 0.17), ([33, 33, 45], 0.18)],
}

# --------------------------------------------------------------------------- kite


def kite(rng: np.random.Generator, glides: list[tuple[int, int, float]], gap: float) -> np.ndarray:
    """glides = [(from_midi, to_midi, seconds)], played one after another."""
    total = sum(g[2] for g in glides) + gap * len(glides) + 1.0
    buf = np.zeros(dsp.samples(total))
    at = 0.0
    for a, b, dur in glides:
        n = dsp.samples(dur + 0.08)
        u = np.clip(dsp.time_axis(n) / dur, 0, 1)
        f = dsp.midi_hz(a) * (dsp.midi_hz(b) / dsp.midi_hz(a)) ** (u ** 0.6)
        tone = reed(f, dur, rng, brightness=3.0, attack=0.012, release=0.08, breath=0.0,
                    vibrato_cents=0.0)[:n]
        glass = 0.45 * dsp.fm(f * 2.0, 1.0, 0.6, n) * dsp.ar(n, 0.01, 0.08, dur - 0.01)
        air = dsp.sweep(dsp.white(n, rng), "bp", f * 2.0, 2.0)
        air *= 0.18 * dsp.ar(n, 0.02, 0.06, dur - 0.02)
        dsp.place(buf, tone + glass + air, dsp.samples(at))
        # A landing blip on the target note.
        blip = 0.5 * chime(dsp.midi_hz(b), 0.04, rng, brightness=0.7, decay=0.12, tail=0.4)
        dsp.place(buf, blip, dsp.samples(at + dur * 0.92))
        at += dur + gap
    return _finish(dsp.highpass(buf, 200.0), rng, dict(seconds=0.8, mix=0.2, predelay_ms=12.0, damp=0.5))


KITE = {
    "select": [[(76, 83, 0.13)], [(74, 81, 0.12)], [(76, 85, 0.13)]],
    "move": [[(83, 76, 0.15)], [(85, 78, 0.14)], [(81, 74, 0.15)]],
    "attack": [[(76, 83, 0.07), (76, 83, 0.09)], [(74, 81, 0.07), (74, 81, 0.09)], [(78, 85, 0.07), (78, 85, 0.09)]],
}

# --------------------------------------------------------------------------- hauler


def hauler(rng: np.random.Generator, midi: list[int], times: list[float], accent: bool = False) -> np.ndarray:
    """Six-wheeled harvester: a low reed 'horn' dyad (a third in key) with a
    wooden knock an octave up, dotted short-long rhythm, stepwise intervals."""
    third = {50: 54, 52: 56, 54: 57, 56: 59, 57: 61, 59: 62, 61: 64, 62: 66}
    total = times[-1] + 1.4
    buf = np.zeros(dsp.samples(total))
    for i, (m, at) in enumerate(zip(midi, times)):
        last = i == len(midi) - 1
        dur = 0.24 if last else 0.07
        hard = 1.5 if accent and not last else 1.0
        lo = reed(dsp.midi_hz(m), dur, rng, brightness=9.0 * hard, attack=0.012, release=0.09,
                  breath=0.03, vibrato_hz=4.0, vibrato_cents=3.0)
        hi = 0.7 * reed(dsp.midi_hz(third[m]), dur, rng, brightness=8.0, attack=0.014, release=0.09,
                        breath=0.0, vibrato_hz=4.3, vibrato_cents=3.0)
        knock = 0.9 * hard * marimba(dsp.midi_hz(m + 12), 0.06, rng, hardness=1.3, decay=0.09, tail=0.25)
        note = dsp.mix(dsp.saturate(dsp.mix(lo, hi) * 1.3, 1.2), knock)
        dsp.place(buf, note, dsp.samples(at))
    buf = dsp.biquad(buf, "peak", 900.0, 0.8, 4.0)
    return _finish(dsp.highpass(buf, 90.0), rng)


HAULER = {
    "select": [([50, 54], [0.0, 0.1]), ([52, 56], [0.0, 0.1]), ([50, 52, 54], [0.0, 0.08, 0.17])],
    "move": [([54, 50], [0.0, 0.1]), ([56, 52], [0.0, 0.1]), ([57, 54, 50], [0.0, 0.08, 0.17])],
    "attack": [([50, 50, 57], [0.0, 0.08, 0.16]), ([52, 52, 57], [0.0, 0.08, 0.16]), ([54, 54, 50], [0.0, 0.08, 0.16])],
}

# --------------------------------------------------------------------------- fabricator


def fabricator(rng: np.random.Generator, notes: list[tuple[int, float]], accent: bool = False) -> np.ndarray:
    """Builder drone: busy little marimba 'hands' with a grace-note flick into
    each landing note, a tool tick under every stroke and a soft chime on the
    last. Upper register (F#5-F#6), seconds and fourths."""
    total = notes[-1][1] + 0.9
    buf = np.zeros(dsp.samples(total))
    for i, (m, at) in enumerate(notes):
        last = i == len(notes) - 1
        f = dsp.midi_hz(m)
        hard = 1.4 if accent and not last else 0.9
        wood = marimba(f, 0.04, rng, hardness=hard, decay=0.12 if last else 0.035, tail=0.3)
        n = dsp.samples(0.03)
        tool = 0.35 * dsp.bandpass(dsp.white(n, rng), 5200.0, 3.0) * dsp.perc(n, 0.0003, 0.0025)
        note = dsp.mix(wood * (1.0 if last else 0.75), tool)
        if last:
            note = dsp.mix(note, 0.45 * chime(f, 0.05, rng, brightness=0.6, decay=0.16, tail=0.4))
        dsp.place(buf, note, dsp.samples(at))
    return _finish(dsp.highpass(buf, 280.0), rng, dict(seconds=0.6, mix=0.14, predelay_ms=6.0, damp=0.6))


FABRICATOR = {
    "select": [[(81, 0.0), (83, 0.032), (88, 0.12)], [(80, 0.0), (81, 0.03), (85, 0.11)],
               [(83, 0.0), (85, 0.032), (90, 0.12)]],
    "move": [[(88, 0.0), (86, 0.032), (81, 0.12)], [(85, 0.0), (83, 0.03), (78, 0.11)],
             [(90, 0.0), (88, 0.032), (83, 0.12)]],
    "attack": [[(83, 0.0), (83, 0.065), (83, 0.13), (88, 0.2)], [(81, 0.0), (81, 0.065), (81, 0.13), (86, 0.2)],
               [(85, 0.0), (85, 0.065), (85, 0.13), (90, 0.2)]],
}


# --------------------------------------------------------------------------- registry


def _register() -> None:
    for kind, variants in SURVEYOR.items():
        for i, (notes, step) in enumerate(variants, start=1):
            sound(f"unit_surveyor_{kind}_{i}", "unit", UNIT_LUFS + 1.0, folder="units/surveyor", max_seconds=1.4,
                  params={"recipe": f"surveyor({notes}, step={step})"})(
                lambda rng, n=notes, s=step, k=kind: surveyor(rng, n, s, accent=k == "attack", shimmer=k != "attack"))
    for kind, variants in RANGER.items():
        for i, (notes, step) in enumerate(variants, start=1):
            sound(f"unit_ranger_{kind}_{i}", "unit", UNIT_LUFS, folder="units/ranger", max_seconds=1.4,
                  params={"recipe": f"ranger({notes}, step={step})"})(
                lambda rng, n=notes, s=step, k=kind: ranger(rng, n, s, accent=k == "attack"))
    for kind, variants in BULWARK.items():
        for i, (notes, step) in enumerate(variants, start=1):
            sound(f"unit_bulwark_{kind}_{i}", "unit", UNIT_LUFS, folder="units/bulwark", max_seconds=2.2,
                  params={"recipe": f"bulwark({notes}, step={step})"})(
                lambda rng, n=notes, s=step, k=kind: bulwark(rng, n, s, accent=k == "attack"))
    for kind, variants in KITE.items():
        for i, glides in enumerate(variants, start=1):
            sound(f"unit_kite_{kind}_{i}", "unit", UNIT_LUFS, folder="units/kite", max_seconds=1.6,
                  params={"recipe": f"kite({glides}, gap=0.03)"})(
                lambda rng, g=glides: kite(rng, g, 0.03))
    for kind, variants in HAULER.items():
        for i, (notes, times) in enumerate(variants, start=1):
            sound(f"unit_hauler_{kind}_{i}", "unit", UNIT_LUFS, folder="units/hauler", max_seconds=1.8,
                  params={"recipe": f"hauler({notes}, {times})"})(
                lambda rng, n=notes, t=times, k=kind: hauler(rng, n, t, accent=k == "attack"))
    for kind, variants in FABRICATOR.items():
        for i, notes in enumerate(variants, start=1):
            sound(f"unit_fabricator_{kind}_{i}", "unit", UNIT_LUFS, folder="units/fabricator", max_seconds=1.4,
                  params={"recipe": f"fabricator({notes})"})(
                lambda rng, n=notes, k=kind: fabricator(rng, n, accent=k == "attack"))


_register()
