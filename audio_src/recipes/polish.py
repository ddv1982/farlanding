"""Phase 9 (polish): the last few sounds.

Settings pages (Concord glass and wood, dry, short, like the rest of the
interface):

  ui_tab_changed      a page turns: a soft paper flick and a wooden D6 lifting to a glass A6
  ui_rebind_listen    "press a key": a glass E6 ringing into a held, open fifth (A5 + E6),
                      a faint pulse inside it, waiting
  ui_rebind_done      bound: a latch click and a glass B5 -> E6 closing a fourth
  ui_rebind_conflict  that key is taken: two muted wooden dyads on the D+G# tritone, a dull stop
  ui_credits_open     the credits begin: a slow glass D A D, the Trail motif's frame, rung softly

Hollow Meridian's engines:

  loop_engine_claim   a worker bringing an old engine back: a stone-and-metal ratchet
                      ticking six times a second through a resonance on D, a faint D+A
                      drone under it (2 s loop). MachineClaimSound raises its pitch with
                      the work done, so the ticks quicken and the tone rises.

Advisor:

  advisor_extraction_moved  the Infiltration's extraction point moved once the
                            enemy is alerted: D+A, then the dyad stepping sideways
                            a tritone to G#+D#... and landing on E+B, somewhere else
"""

from __future__ import annotations

import numpy as np

from synth import dsp
from synth.instruments import chime, marimba

from . import sound
from .advisor import ADVISOR_LUFS, _phrase, glide_dyad
from .interface import UI_LUFS, _done, _seq, tick
from .movement import _finish as move_finish, lfo, qf
from .world import advisor_dyad

H = dsp.midi_hz
CLAIM_LOOP = 2.0


def _flick(rng: np.random.Generator, dur: float = 0.03, fc: float = 4200.0) -> np.ndarray:
    n = dsp.samples(dur)
    return dsp.bandpass(dsp.white(n, rng), fc, 1.2) * dsp.perc(n, 0.001, dur * 0.35)


@sound("ui_tab_changed", "ui", UI_LUFS - 1.0, max_seconds=0.22)
def ui_tab_changed(rng: np.random.Generator) -> np.ndarray:
    parts = [(0.0, 0.35 * _flick(rng)),
             (0.008, 0.7 * marimba(H(86), 0.09, rng, hardness=0.6, tail=0.1)),
             (0.05, 0.5 * chime(H(93), 0.12, rng, brightness=0.6, decay=0.06, tail=0.1))]
    return _done(_seq(parts, 0.2))


@sound("ui_rebind_listen", "ui", UI_LUFS, max_seconds=0.3)
def ui_rebind_listen(rng: np.random.Generator) -> np.ndarray:
    n = dsp.samples(0.26)
    t = dsp.time_axis(n)
    pulse = 0.85 + 0.15 * np.sin(2 * np.pi * 14.0 * t)
    held = (dsp.sine(H(81), n) + 0.8 * dsp.sine(H(88), n)) * dsp.env([(0, 0), (0.03, 1), (0.18, 0.8), (0.26, 0)], n)
    parts = [(0.0, 0.6 * chime(H(88), 0.1, rng, brightness=0.7, decay=0.08, tail=0.15)), (0.02, 0.35 * held * pulse)]
    return _done(_seq(parts, 0.28))


@sound("ui_rebind_done", "ui", UI_LUFS, max_seconds=0.25)
def ui_rebind_done(rng: np.random.Generator) -> np.ndarray:
    parts = [(0.0, 0.8 * tick(rng, 1800.0, 0.004, 0.5)),
             (0.012, 0.5 * tick(rng, 900.0, 0.006, 0.2)),
             (0.03, 0.55 * chime(H(83), 0.06, rng, brightness=0.8, decay=0.04, tail=0.1)),
             (0.085, 0.65 * chime(H(88), 0.12, rng, brightness=0.8, decay=0.06, tail=0.1))]
    return _done(_seq(parts, 0.23))


@sound("ui_rebind_conflict", "ui", UI_LUFS + 1.0, max_seconds=0.3)
def ui_rebind_conflict(rng: np.random.Generator) -> np.ndarray:
    def dyad(at_semitone: int) -> np.ndarray:
        lo = marimba(H(62 + at_semitone), 0.07, rng, hardness=0.4)
        hi = marimba(H(68 + at_semitone), 0.07, rng, hardness=0.4)
        m = min(len(lo), len(hi))
        return dsp.lowpass(lo[:m] + 0.8 * hi[:m], 2200.0)

    n = dsp.samples(0.05)
    stop = dsp.lowpass(dsp.white(n, rng), 700.0) * dsp.perc(n, 0.001, 0.012)
    parts = [(0.0, 0.7 * dyad(12)), (0.1, 0.75 * dyad(11)), (0.19, 0.5 * stop)]
    return _done(_seq(parts, 0.28))


@sound("ui_credits_open", "ui", UI_LUFS - 1.0, max_seconds=1.6)
def ui_credits_open(rng: np.random.Generator) -> np.ndarray:
    """The one long interface sound: the credits roll under the ending theme,
    so this is soft, slow glass: D, A, the high D, ringing out."""
    parts = [(0.0, 0.6 * chime(H(74), 0.9, rng, brightness=0.5)),
             (0.28, 0.55 * chime(H(81), 0.9, rng, brightness=0.5)),
             (0.56, 0.6 * chime(H(86), 1.0, rng, brightness=0.5))]
    x = _seq(parts, 1.55)
    x = dsp.reverb(x, rng, seconds=1.2, mix=0.18, damp=0.6).mean(axis=0)[: dsp.samples(1.55)]
    return dsp.fade(dsp.trim_tail(dsp.dc_block(dsp.highpass(x, 250.0)), -55.0), 0.0005, 0.08)


@sound("loop_engine_claim", "machine", -27.0, loop=True, folder="machines", min_seconds=CLAIM_LOOP - 0.05,
       max_seconds=CLAIM_LOOP + 0.05)
def loop_engine_claim(rng: np.random.Generator) -> np.ndarray:
    """A worker at an old engine: a ratchet of stone on metal, six ticks a
    second (twelve a loop), each ringing a resonance on D4/A4 in turn, over a
    faint D3+A3 drone that swells with each pair of ticks."""
    L = CLAIM_LOOP
    n = dsp.samples(L)
    buf = np.zeros(n)
    for k in range(12):
        m = dsp.samples(0.09)
        click = dsp.white(m, rng) * dsp.perc(m, 0.0005, 0.006)
        ring_f = H(62) if k % 2 == 0 else H(69)
        ring = dsp.sine(ring_f, m) * dsp.perc(m, 0.001, 0.03)
        stone = dsp.lowpass(dsp.white(m, rng), 1500.0) * dsp.perc(m, 0.001, 0.012)
        x = 0.5 * dsp.bandpass(click, 3200.0, 2.0) + 0.35 * ring + 0.4 * stone
        x *= 1.0 if k % 2 == 0 else 0.8
        at = dsp.samples(k * L / 12)
        seg = buf[at:at + len(x)]
        seg += x[: len(seg)]
        if len(seg) < len(x):  # wrap the tail of the last tick round to the start
            buf[: len(x) - len(seg)] += x[len(seg):]
    swell = 0.6 + 0.4 * (0.5 + 0.5 * lfo(n, L, 6, 0.25))
    drone = (dsp.sine(qf(H(50), L), n) + 0.6 * dsp.sine(qf(H(57), L), n)) * swell * 0.08
    return move_finish(buf + drone)


@sound("advisor_extraction_moved", "advisor", ADVISOR_LUFS + 1.0, max_seconds=1.8)
def advisor_extraction_moved(rng: np.random.Generator) -> np.ndarray:
    """The extraction point moved: D+A, then a sideways slide a tritone off
    (G#+D#), landing on E+B: the same shape, somewhere else."""
    return _phrase([(0.0, 0.9, advisor_dyad(H(74), H(81), 0.14)),
                    (0.2, 1.0, glide_dyad(H(80), H(87), 0.24, 0.0)),
                    (0.5, 1.0, glide_dyad(H(80), H(87), 0.4, -4.0, 0.2))], rng, 1.5)
