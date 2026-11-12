"""The Advisor's economy alerts: one short phrase per alert kind.

All are built from the *Meridian* timbre in world.py (sine dyads with a 7 Hz
tremolo, heard through the band-limited ship channel), never from the unit
instruments. Each phrase owns a contour and a rhythm a player can learn:

  low_power               WARNING: three tritone pulses (D+G#) that sag a semitone, the last one longest
  power_restored          relief: a dyad slides UP a semitone into D+A, then a high D+A answers
  insufficient_resources  'not yet': two quick identical staccato dyads, quiet and short
  construction_complete   success: three dyads climbing in steps D, F#, A to a held D, mid register
  unit_ready              ready: a high leap of a fifth, short-LONG ('da-DAA'), crisp
  deposit_depleted        running dry: three dyads falling and fading, each darker
  building_placed         acknowledged: one soft high dyad with an echo
"""

from __future__ import annotations

import numpy as np

from synth import dsp

from . import sound
from .world import advisor_dyad, ship_channel

ADVISOR_LUFS = -20.0
H = dsp.midi_hz


def glide_dyad(lo: float, hi: float, dur: float, bend_semitones: float, start: float = 0.4) -> np.ndarray:
    """A Meridian dyad whose pitch bends by `bend_semitones` over the part of
    the note after `start` (a fraction of dur)."""
    n = dsp.samples(dur + 0.25)
    u = np.clip((dsp.time_axis(n) / dur - start) / (1.0 - start), 0.0, 1.0)
    ratio = 2.0 ** (bend_semitones * (u * u * (3 - 2 * u)) / 12.0)
    return advisor_dyad(lo * ratio, hi * ratio, dur)


def _phrase(parts: list[tuple[float, float, np.ndarray]], rng: np.random.Generator, total: float,
            room: float = 0.12) -> np.ndarray:
    buf = np.zeros(dsp.samples(total))
    for at, gain, x in parts:
        dsp.place(buf, gain * x, dsp.samples(at))
    y = ship_channel(buf, rng)
    y = dsp.reverb(y, rng, seconds=0.6, mix=room, damp=0.7).mean(axis=0)
    return dsp.fade(dsp.trim_tail(dsp.dc_block(y), -55.0), 0.001, 0.05)


@sound("advisor_low_power", "advisor", ADVISOR_LUFS + 1.0, max_seconds=1.8)
def advisor_low_power(rng: np.random.Generator) -> np.ndarray:
    parts = [(0.0, 1.0, glide_dyad(H(74), H(80), 0.16, -1.0)),
             (0.27, 0.95, glide_dyad(H(74), H(80), 0.16, -1.0)),
             (0.54, 0.9, glide_dyad(H(74), H(80), 0.34, -2.0, 0.3))]
    # A low beating undertone (two sines 3 Hz apart) makes it uneasy.
    n = dsp.samples(1.0)
    under = 0.25 * (dsp.sine(H(62), n) + dsp.sine(H(62) + 3.0, n)) * dsp.ar(n, 0.05, 0.3, 0.6)
    parts.append((0.0, 1.0, under))
    return _phrase(parts, rng, 1.6)


@sound("advisor_power_restored", "advisor", ADVISOR_LUFS, max_seconds=1.6)
def advisor_power_restored(rng: np.random.Generator) -> np.ndarray:
    parts = [(0.0, 0.9, glide_dyad(H(73), H(80), 0.26, 1.0, 0.2)),  # C#+G# rises into D+A
             (0.32, 1.0, advisor_dyad(H(81), H(86), 0.24))]
    return _phrase(parts, rng, 1.4)


@sound("advisor_insufficient_resources", "advisor", ADVISOR_LUFS - 2.0, max_seconds=1.0)
def advisor_insufficient_resources(rng: np.random.Generator) -> np.ndarray:
    parts = [(0.0, 1.0, advisor_dyad(H(78), H(83), 0.055)),
             (0.11, 0.9, advisor_dyad(H(78), H(83), 0.055))]
    return _phrase(parts, rng, 0.8, room=0.08)


@sound("advisor_construction_complete", "advisor", ADVISOR_LUFS, max_seconds=1.8)
def advisor_construction_complete(rng: np.random.Generator) -> np.ndarray:
    parts = [(0.0, 0.85, advisor_dyad(H(74), H(78), 0.1)),
             (0.15, 0.9, advisor_dyad(H(78), H(81), 0.1)),
             (0.3, 1.0, advisor_dyad(H(81), H(86), 0.42))]
    return _phrase(parts, rng, 1.6)


@sound("advisor_unit_ready", "advisor", ADVISOR_LUFS, max_seconds=1.4)
def advisor_unit_ready(rng: np.random.Generator) -> np.ndarray:
    parts = [(0.0, 0.85, advisor_dyad(H(81), H(85), 0.06)),
             (0.09, 1.0, advisor_dyad(H(88), H(93), 0.26))]
    return _phrase(parts, rng, 1.2)


@sound("advisor_deposit_depleted", "advisor", ADVISOR_LUFS, max_seconds=1.8)
def advisor_deposit_depleted(rng: np.random.Generator) -> np.ndarray:
    parts = []
    for i, (lo, hi) in enumerate([(78, 83), (76, 81), (73, 78)]):
        x = advisor_dyad(H(lo), H(hi), 0.14 + 0.04 * i)
        x = dsp.lowpass(x, 4000.0 - 1100.0 * i)
        parts.append((0.2 * i, 1.0 - 0.25 * i, x))
    return _phrase(parts, rng, 1.6)


@sound("advisor_building_placed", "advisor", ADVISOR_LUFS - 3.0, max_seconds=1.0)
def advisor_building_placed(rng: np.random.Generator) -> np.ndarray:
    x = advisor_dyad(H(81), H(86), 0.07)
    return _phrase([(0.0, 1.0, x), (0.13, 0.35, dsp.lowpass(x, 2500.0))], rng, 0.8, room=0.1)
