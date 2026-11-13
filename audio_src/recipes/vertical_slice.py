"""Phase 6 (vertical slice): settings and pause interface, tutorial hints,
destructible props, and the Combine's Intel gain in the Survey race.

Interface (`ui`, dry, <= 0.3 s, Concord glass and wood):

  ui_pause_open / _close    the world stops: two marimba notes falling A -> D with a
                            soft low thump / rising D -> A, the thump reversed
  ui_slider_tick            a tiny wooden tick on F#6 (-34: a slider sends many)
  ui_toggle                 a two-part latch: a click and a glass G# (on and off alike)
  ui_hint_show              a tutorial hint appears: a soft chime B5 -> E6 with air
  ui_hint_dismiss           a short glass tick falling E6 -> B5

Props (`explosion` group, positional, Explosions bus; played by
CombatCues.death_events as `death_<sound_set>`):

  death_prop_crates     Combine metal crates: a crash, sheet metal buckling, lids rattling
  death_prop_tank       a fuel tank: a gas burst, a boom and a long hiss of venting
  death_prop_barrier    a fence barrier crumpling: wire twang, a post snapping
  death_prop_boulder    a boulder breaking: a crack, a rockfall, dust settling

Survey race:

  discovery_enemy_intel  the Combine banks Intel: a ring-modulated data chirp
                         falling a tritone, a "bank" thunk under it (Combine sound
                         world, flat on the Discovery bus, -24)
"""

from __future__ import annotations

import numpy as np

from synth import dsp
from synth.instruments import chime, marimba

from . import sound
from .interface import UI_LUFS, _done, _seq, tick

H = dsp.midi_hz


@sound("ui_pause_open", "ui", UI_LUFS, max_seconds=0.3)
def ui_pause_open(rng: np.random.Generator) -> np.ndarray:
    a = marimba(H(81), 0.04, rng, hardness=0.5, decay=0.05, tail=0.1)
    b = marimba(H(74), 0.04, rng, hardness=0.5, decay=0.09, tail=0.15)
    m = dsp.samples(0.15)
    thump = dsp.sine(180.0, m) * dsp.perc(m, 0.002, 0.03)
    x = _seq([(0.0, a), (0.06, b), (0.06, 0.6 * thump)], 0.3)
    return dsp.fade(dsp.trim_tail(dsp.dc_block(dsp.highpass(x, 120.0)), -55.0), 0.0005, 0.02)


@sound("ui_pause_close", "ui", UI_LUFS, max_seconds=0.3)
def ui_pause_close(rng: np.random.Generator) -> np.ndarray:
    a = marimba(H(74), 0.04, rng, hardness=0.5, decay=0.05, tail=0.1)
    b = marimba(H(81), 0.04, rng, hardness=0.55, decay=0.09, tail=0.15)
    m = dsp.samples(0.08)
    swell = dsp.sine(180.0, m) * dsp.env([(0, 0), (0.07, 1.0), (0.08, 0)], m)
    x = _seq([(0.0, 0.5 * swell), (0.03, a), (0.09, b)], 0.3)
    return dsp.fade(dsp.trim_tail(dsp.dc_block(dsp.highpass(x, 120.0)), -55.0), 0.0005, 0.02)


@sound("ui_slider_tick", "ui", UI_LUFS - 7.0, max_seconds=0.08)
def ui_slider_tick(rng: np.random.Generator) -> np.ndarray:
    note = marimba(H(90), 0.02, rng, hardness=0.6, decay=0.012, tail=0.03)
    return _done(dsp.mix(note, 0.3 * tick(rng, 3000.0, 0.003, 0.2, 0.3)))


@sound("ui_toggle", "ui", UI_LUFS, max_seconds=0.2)
def ui_toggle(rng: np.random.Generator) -> np.ndarray:
    click = tick(rng, 1900.0, 0.006, 0.4)
    glass = chime(H(92), 0.02, rng, brightness=0.5, decay=0.05, attack=0.002, tail=0.08)
    return _done(_seq([(0.0, click), (0.025, 0.5 * glass)], 0.2))


@sound("ui_hint_show", "ui", UI_LUFS + 1.0, max_seconds=0.3)
def ui_hint_show(rng: np.random.Generator) -> np.ndarray:
    a = chime(H(83), 0.03, rng, brightness=0.5, decay=0.08, attack=0.004, tail=0.15)
    b = chime(H(88), 0.03, rng, brightness=0.5, decay=0.12, attack=0.004, tail=0.18)
    m = dsp.samples(0.2)
    air = dsp.bandpass(dsp.white(m, rng), 6000.0, 1.0) * dsp.env([(0, 0), (0.1, 1), (0.2, 0)], m) * 0.08
    x = _seq([(0.0, air), (0.02, a), (0.09, b)], 0.3)
    return dsp.fade(dsp.trim_tail(dsp.dc_block(dsp.highpass(x, 250.0)), -55.0), 0.0005, 0.03)


@sound("ui_hint_dismiss", "ui", UI_LUFS - 2.0, max_seconds=0.2)
def ui_hint_dismiss(rng: np.random.Generator) -> np.ndarray:
    a = chime(H(88), 0.02, rng, brightness=0.4, decay=0.04, attack=0.002, tail=0.08)
    b = chime(H(83), 0.02, rng, brightness=0.4, decay=0.06, attack=0.002, tail=0.1)
    return _done(_seq([(0.0, a), (0.05, b)], 0.2))


# --------------------------------------------------------------------------- props


def _prop_done(x: np.ndarray, rng: np.random.Generator, room: float = 0.18) -> np.ndarray:
    y = dsp.reverb(x, rng, seconds=1.2, mix=room, predelay_ms=12.0, damp=0.6).mean(axis=0)
    return dsp.fade(dsp.trim_tail(dsp.dc_block(dsp.highpass(y, 45.0)), -55.0), 0.001, 0.1)


def _metal(rng: np.random.Generator, n: int, freqs, q: float, decay: float) -> np.ndarray:
    exc = dsp.white(n, rng) * dsp.perc(n, 0.001, decay)
    return sum(dsp.bandpass(exc, f, q) for f in freqs)


@sound("death_prop_crates", "explosion", -23.0, max_seconds=2.4)
def death_prop_crates(rng: np.random.Generator) -> np.ndarray:
    buf = np.zeros(dsp.samples(2.2))
    n = dsp.samples(0.6)
    t = dsp.time_axis(n)
    crash = dsp.sine(110.0 * (1 + 0.6 * np.exp(-t / 0.015)), n) * dsp.perc(n, 0.001, 0.07)
    crash += 0.6 * dsp.bandpass(dsp.white(n, rng), 1500.0, 0.6) * dsp.perc(n, 0.001, 0.05)
    dsp.place(buf, crash, 0)
    dsp.place(buf, 0.7 * _metal(rng, dsp.samples(1.0), (347.0, 891.0, 1622.0), 25.0, 0.02), dsp.samples(0.02))
    at = 0.25
    for k in range(6):
        dsp.place(buf, 0.35 * (1 - k / 7) * _metal(rng, dsp.samples(0.4), (1210.0, 2470.0), 30.0, 0.005),
                  dsp.samples(at))
        at += float(rng.uniform(0.07, 0.2))
    return _prop_done(buf, rng)


@sound("death_prop_tank", "explosion", -21.0, max_seconds=3.2)
def death_prop_tank(rng: np.random.Generator) -> np.ndarray:
    buf = np.zeros(dsp.samples(3.0))
    n = dsp.samples(1.2)
    t = dsp.time_axis(n)
    boom = dsp.sine(55.0 * (1 + 0.8 * np.exp(-t / 0.03)), n) * dsp.perc(n, 0.002, 0.3)
    boom += 0.8 * dsp.lowpass(dsp.white(n, rng), 900.0) * dsp.perc(n, 0.002, 0.12)
    burst = dsp.bandpass(dsp.white(n, rng), 2600.0, 0.7) * dsp.perc(n, 0.001, 0.04)
    dsp.place(buf, dsp.saturate(boom + 0.6 * burst, 1.4), 0)
    dsp.place(buf, 0.6 * _metal(rng, dsp.samples(1.4), (260.0, 650.0), 35.0, 0.03), dsp.samples(0.03))
    m = dsp.samples(2.4)
    u = dsp.time_axis(m) / 2.4
    vent = dsp.sweep(dsp.white(m, rng), "bp", 4200.0 * 0.5 ** u, 1.5) * dsp.env([(0, 0), (0.15, 1), (2.4, 0)], m, 1.3)
    dsp.place(buf, 0.4 * vent, dsp.samples(0.4))
    return _prop_done(buf, rng, 0.22)


@sound("death_prop_barrier", "explosion", -24.0, max_seconds=2.0)
def death_prop_barrier(rng: np.random.Generator) -> np.ndarray:
    buf = np.zeros(dsp.samples(1.8))
    n = dsp.samples(0.8)
    t = dsp.time_axis(n)
    twang = dsp.sine(310.0 * (1 - 0.2 * t / 0.8), n) * dsp.perc(n, 0.001, 0.15)
    twang *= 1 + 0.3 * dsp.sine(23.0, n)
    dsp.place(buf, 0.6 * twang, 0)
    dsp.place(buf, 0.8 * _metal(rng, dsp.samples(0.8), (520.0, 1340.0, 2800.0), 18.0, 0.01), dsp.samples(0.05))
    m = dsp.samples(0.3)
    snap = dsp.bandpass(dsp.white(m, rng), 1100.0, 1.0) * dsp.perc(m, 0.0005, 0.02)
    dsp.place(buf, snap, dsp.samples(0.32))
    return _prop_done(buf, rng)


@sound("death_prop_boulder", "explosion", -22.0, max_seconds=3.0)
def death_prop_boulder(rng: np.random.Generator) -> np.ndarray:
    buf = np.zeros(dsp.samples(2.8))
    n = dsp.samples(0.5)
    t = dsp.time_axis(n)
    crack = dsp.bandpass(dsp.white(n, rng), 1800.0, 1.2) * dsp.perc(n, 0.0005, 0.02)
    crack += dsp.sine(80.0 * (1 + 0.5 * np.exp(-t / 0.02)), n) * dsp.perc(n, 0.002, 0.15)
    dsp.place(buf, crack, 0)
    at = 0.08
    for k in range(22):
        m = dsp.samples(0.12)
        exc = dsp.white(m, rng) * dsp.perc(m, 0.0008, 0.006)
        stone = dsp.bandpass(exc, float(rng.uniform(400, 1600)), 4.0)
        dsp.place(buf, stone * float(rng.uniform(0.3, 0.9)) * (1 - k / 26), dsp.samples(at))
        at += float(rng.exponential(0.06))
    m = dsp.samples(2.0)
    dust = dsp.lowpass(dsp.pink(m, rng), 2000.0) * dsp.env([(0, 0), (0.2, 1), (2.0, 0)], m, 1.5) * 0.25
    dsp.place(buf, dust, dsp.samples(0.3))
    return _prop_done(buf, rng)


# --------------------------------------------------------------------------- Survey race


@sound("discovery_enemy_intel", "discovery", -24.0, max_seconds=1.2)
def discovery_enemy_intel(rng: np.random.Generator) -> np.ndarray:
    n = dsp.samples(0.5)
    u = dsp.time_axis(n) / 0.5
    f = H(82) * 2.0 ** (-6.0 * np.minimum(u * 2.0, 1.0) / 12.0)  # Bb5 falling a tritone
    saw = dsp.warm_saw(f, n, 8.0) * (0.5 + 0.5 * dsp.sine(f * 1.37, n))
    chirp = dsp.saturate(saw, 1.5) * dsp.ar(n, 0.006, 0.15, 0.3)
    buf = np.zeros(dsp.samples(1.1))
    dsp.place(buf, 0.6 * dsp.lowpass(chirp, 4500.0), 0)
    for k in range(3):  # data ticks
        m = dsp.samples(0.03)
        dsp.place(buf, 0.3 * dsp.bandpass(dsp.white(m, rng), 5200.0, 6.0) * dsp.perc(m, 0.0005, 0.004),
                  dsp.samples(0.05 + 0.06 * k))
    m = dsp.samples(0.4)
    t = dsp.time_axis(m)
    thunk = dsp.sine(98.0 * (1 + 0.3 * np.exp(-t / 0.02)), m) * dsp.perc(m, 0.003, 0.07)
    thunk += 0.4 * _metal(rng, m, (433.0, 1170.0), 20.0, 0.006)
    dsp.place(buf, thunk, dsp.samples(0.42))
    y = dsp.reverb(buf, rng, seconds=0.8, mix=0.15, damp=0.6).mean(axis=0)
    return dsp.fade(dsp.trim_tail(dsp.dc_block(dsp.highpass(y, 60.0)), -55.0), 0.001, 0.05)
