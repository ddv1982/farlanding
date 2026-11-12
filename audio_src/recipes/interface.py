"""Interface sounds: short, dry, high and soft. They sit above the music and
under unit replies, and none is longer than a third of a second."""

from __future__ import annotations

import numpy as np

from synth import dsp
from synth.instruments import chime, marimba

from . import sound

UI_LUFS = -27.0


def tick(rng: np.random.Generator, freq: float, decay: float = 0.006, noise: float = 0.25,
         body: float = 1.0) -> np.ndarray:
    """A clean tick: short sine blip with a band-passed noise transient."""
    n = dsp.samples(decay * 8 + 0.01)
    tone = body * dsp.sine(freq * (1 + 0.15 * dsp.perc(n, 0.0, 0.002)), n) * dsp.perc(n, 0.0004, decay)
    click = noise * dsp.bandpass(dsp.white(n, rng), freq * 1.5, 1.5) * dsp.perc(n, 0.0002, 0.0015)
    return tone + click


def _seq(parts: list[tuple[float, np.ndarray]], total: float) -> np.ndarray:
    buf = np.zeros(dsp.samples(total))
    for at, x in parts:
        dsp.place(buf, x, dsp.samples(at))
    return buf


def _done(x: np.ndarray) -> np.ndarray:
    return dsp.fade(dsp.trim_tail(dsp.dc_block(dsp.highpass(x, 250.0)), -55.0), 0.0005, 0.008)


@sound("ui_click", "ui", UI_LUFS, max_seconds=0.12)
def ui_click(rng: np.random.Generator) -> np.ndarray:
    return _done(dsp.mix(tick(rng, 2350.0, 0.007), 0.4 * tick(rng, 1175.0, 0.012, 0.0)))


@sound("ui_hover", "ui", UI_LUFS - 7.0, max_seconds=0.08)
def ui_hover(rng: np.random.Generator) -> np.ndarray:
    return _done(tick(rng, 3140.0, 0.004, 0.1, 0.8))


@sound("ui_select", "ui", UI_LUFS, max_seconds=0.2)
def ui_select(rng: np.random.Generator) -> np.ndarray:
    a = marimba(dsp.midi_hz(93), 0.03, rng, hardness=0.6, decay=0.04, tail=0.08)
    b = marimba(dsp.midi_hz(98), 0.03, rng, hardness=0.6, decay=0.06, tail=0.1)
    return _done(_seq([(0.0, a), (0.035, b)], 0.2))


@sound("ui_deselect", "ui", UI_LUFS - 2.0, max_seconds=0.2)
def ui_deselect(rng: np.random.Generator) -> np.ndarray:
    a = marimba(dsp.midi_hz(95), 0.03, rng, hardness=0.4, decay=0.035, tail=0.08)
    b = marimba(dsp.midi_hz(88), 0.03, rng, hardness=0.4, decay=0.05, tail=0.1)
    return _done(_seq([(0.0, a), (0.04, b)], 0.2))


@sound("ui_order", "ui", UI_LUFS, max_seconds=0.3)
def ui_order(rng: np.random.Generator) -> np.ndarray:
    """Order accepted: a quick tick into a small D-A chime."""
    t = tick(rng, 2350.0, 0.005)
    a = chime(dsp.midi_hz(86), 0.03, rng, brightness=0.6, decay=0.05, tail=0.1)
    b = chime(dsp.midi_hz(93), 0.03, rng, brightness=0.6, decay=0.09, tail=0.15)
    return _done(_seq([(0.0, t), (0.012, 0.8 * a), (0.06, b)], 0.3))


@sound("ui_invalid", "ui", UI_LUFS + 1.0, max_seconds=0.3)
def ui_invalid(rng: np.random.Generator) -> np.ndarray:
    """Two muted low pulses a semitone apart: clearly 'no', never harsh."""
    def pulse(f: float) -> np.ndarray:
        n = dsp.samples(0.09)
        x = dsp.soft_square(f, n, 3.0) * dsp.perc(n, 0.003, 0.03)
        return dsp.lowpass(x, 1400.0)
    buf = _seq([(0.0, pulse(233.1)), (0.1, pulse(220.0))], 0.3)
    buf += 0.3 * _seq([(0.0, pulse(466.2)), (0.1, pulse(440.0))], 0.3)
    return dsp.fade(dsp.trim_tail(dsp.dc_block(dsp.highpass(buf, 120.0)), -55.0), 0.0005, 0.01)


@sound("ui_group_assign", "ui", UI_LUFS, max_seconds=0.3)
def ui_group_assign(rng: np.random.Generator) -> np.ndarray:
    """Three rising ticks and a wooden 'lock'."""
    parts = [(0.0, tick(rng, 1760.0, 0.005)), (0.04, tick(rng, 2217.0, 0.005)), (0.08, tick(rng, 2637.0, 0.005))]
    parts.append((0.12, marimba(dsp.midi_hz(74), 0.04, rng, hardness=1.2, decay=0.05, tail=0.1)))
    return _done(_seq(parts, 0.3))


@sound("ui_group_recall", "ui", UI_LUFS - 1.0, max_seconds=0.25)
def ui_group_recall(rng: np.random.Generator) -> np.ndarray:
    """Two quick ticks with a small chime: 'here they are'."""
    parts = [(0.0, tick(rng, 2637.0, 0.005)), (0.035, tick(rng, 2637.0, 0.005))]
    parts.append((0.05, 0.6 * chime(dsp.midi_hz(90), 0.03, rng, brightness=0.5, decay=0.06, tail=0.12)))
    return _done(_seq(parts, 0.25))


# --------------------------------------------------------------------------- base building


@sound("ui_build_button", "ui", UI_LUFS, max_seconds=0.15)
def ui_build_button(rng: np.random.Generator) -> np.ndarray:
    """Build-menu button: woodier than ui_click, a tick with a low marimba 'tock'."""
    tock = marimba(dsp.midi_hz(74), 0.02, rng, hardness=1.1, decay=0.025, tail=0.06)
    return _done(_seq([(0.0, 0.7 * tick(rng, 1760.0, 0.005)), (0.004, tock)], 0.15))


@sound("ui_queue", "ui", UI_LUFS, max_seconds=0.25)
def ui_queue(rng: np.random.Generator) -> np.ndarray:
    """A unit is queued: two ratchet ticks and a small marimba E, 'added'."""
    parts = [(0.0, tick(rng, 2637.0, 0.004, 0.4)), (0.03, tick(rng, 2637.0, 0.004, 0.4)),
             (0.06, marimba(dsp.midi_hz(88), 0.03, rng, hardness=0.7, decay=0.05, tail=0.1))]
    return _done(_seq(parts, 0.25))


@sound("ui_rally_set", "ui", UI_LUFS, max_seconds=0.3)
def ui_rally_set(rng: np.random.Generator) -> np.ndarray:
    """Rally point set: a tick and a planted-flag chime fifth, A up to E."""
    parts = [(0.0, tick(rng, 2350.0, 0.005)),
             (0.015, 0.7 * chime(dsp.midi_hz(81), 0.03, rng, brightness=0.6, decay=0.04, tail=0.1)),
             (0.07, chime(dsp.midi_hz(88), 0.03, rng, brightness=0.6, decay=0.08, tail=0.15))]
    return _done(_seq(parts, 0.3))


@sound("ui_invalid_placement", "ui", UI_LUFS + 1.0, max_seconds=0.3)
def ui_invalid_placement(rng: np.random.Generator) -> np.ndarray:
    """Cannot build here: one muted buzzing thunk on a C#-D cluster. Shorter
    and lower than ui_invalid, so it can repeat while the cursor moves."""
    n = dsp.samples(0.14)
    x = dsp.soft_square(dsp.midi_hz(49), n, 4.0) + 0.8 * dsp.soft_square(dsp.midi_hz(50), n, 4.0)
    x = dsp.lowpass(x, 1100.0) * dsp.perc(n, 0.003, 0.045)
    thunk = 0.5 * dsp.lowpass(dsp.white(n, rng), 600.0) * dsp.perc(n, 0.001, 0.01)
    return dsp.fade(dsp.trim_tail(dsp.dc_block(dsp.highpass(x + thunk, 100.0)), -55.0), 0.0005, 0.01)


@sound("ui_not_enough_resources", "ui", UI_LUFS + 1.0, max_seconds=0.3)
def ui_not_enough_resources(rng: np.random.Generator) -> np.ndarray:
    """Cannot afford: two dull marimba notes falling a third (F#-D) and a
    hollow 'empty' tick, softer than a hard 'no'."""
    a = marimba(dsp.midi_hz(66), 0.03, rng, hardness=0.3, decay=0.05, tail=0.1)
    b = marimba(dsp.midi_hz(62), 0.03, rng, hardness=0.3, decay=0.08, tail=0.12)
    empty = 0.5 * tick(rng, 900.0, 0.01, 0.3)
    buf = _seq([(0.0, empty), (0.01, a), (0.09, b)], 0.3)
    return dsp.fade(dsp.trim_tail(dsp.dc_block(dsp.highpass(buf, 150.0)), -55.0), 0.0005, 0.01)
