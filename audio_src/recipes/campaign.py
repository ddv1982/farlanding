"""Phase 7: aboard the survey ship *Meridian* between landings.

Ship ambience (`ambience` beds on the AmbienceDirector's own players, and
`shipdetail` one-shots, flat stereo with the pan in the file):

  amb_ship_hum        the hull: a hum on D2 with its octave and fifth, two
                      generators a hair apart so it beats slowly, a low rumble,
                      a faint hull resonance (41 s loop, -31)
  amb_ship_air        air handling: a fan band breathing at its blade rate, a
                      vent hiss, a far pump that sighs five times a loop (29 s, -33)
  amb_ship_relay_*    a relay ticking over: two clicks and a tiny telemetry beep
  amb_ship_creak_*    the hull settling: stick-slip friction through hull
                      resonances, low and slow
  amb_ship_machine_*  a deck away: a soft clunk and a servo whirring up
  amb_ship_ping_*     a coolant line ticking as it cools: a small metal ping, far

Interface (`ui`, Concord glass and wood like the rest of the interface; the
star map adds a sonar colour):

  ui_title_open        a Meridian dyad swelling D+A -> A+E with a glass touch
  ui_map_open          the map unfolds: an air sweep, chimes A5 -> E6, a sonar tick
  ui_map_node_hover_*  tiny glass ticks on E7, F#7, A7, B7 (-35; the router also
                       rate-limits them)
  ui_map_node_select   locking on: a wooden D6, a glass A6 and a short sonar ping
  ui_map_launch        launch: Meridian dyads climbing D+A, F#+C#, A+E to a high
                       D+A over rising air, ending on the briefing bed's own voice
  ui_tech_open         the web lights up: glass B5 D6 F#6 A6
  ui_tech_hover_*      softer, lower glass ticks (C#7, E7, G#6)
  ui_tech_buy          bought: a wooden D5 and a glass D6+A6, sealed by a low
                       Antecedent-free bell on D3 that rings on: permanent
  ui_tech_unlocked     the seal alone, for a tech granted without a purchase click
  ui_tech_denied       two muted wooden notes falling a semitone, a dull stop
  ui_loadout_open      a latch, a slide, marimba A4 -> D5
  ui_loadout_change    a clack and a glass F#6
  ui_campaign_saved    two tiny glass ticks and a soft latch (-31)

Advisor (Meridian dyads through the ship channel, like every Advisor phrase):

  advisor_campaign_route_open      D+A, E+B, then F#+C# held, opening up, a high ping: new ways
  advisor_campaign_tech_available  G#+D twice, lifting into A+E, a bright answer
  advisor_campaign_intel_banked    four counting dyads climbing, a held D+A, a low "bank" thunk
  advisor_campaign_return_won      home: A+E, C#+G#, D+A held with its octave, warm
  advisor_campaign_return_lost     home, quietly: D+A sinking to B+F#, the filter closing, a low D
"""

from __future__ import annotations

import numpy as np

from synth import dsp
from synth.instruments import bell, chime, marimba, soft_sine

from . import sound
from .advisor import ADVISOR_LUFS, _phrase, glide_dyad
from .ambience import _bounds, _decorrelated, _loop_n
from .interface import UI_LUFS, _done, _seq, tick
from .world import advisor_dyad, ship_channel

H = dsp.midi_hz


def _whole(f: float, seconds: float) -> float:
    return max(round(f * seconds), 1) / seconds


# --------------------------------------------------------------------------- ship beds

N_HUM = _loop_n(41.0)
N_AIR = _loop_n(29.0)
SHIP_BED = dict(fmt="ogg", channels=2, loop=True, folder="ambience/ship")


@sound("amb_ship_hum", "ambience", -31.0, **SHIP_BED, **_bounds(N_HUM))
def amb_ship_hum(rng: np.random.Generator) -> np.ndarray:
    n = N_HUM
    L = n / dsp.SR
    t = dsp.time_axis(n)
    hum = np.zeros(n)
    for f0, amp in [(H(38), 0.45), (H(50), 0.5), (H(57), 0.18), (H(62), 0.12), (H(69), 0.04)]:
        a = _whole(f0, L)
        b = _whole(f0 + 0.3, L)
        hum += amp * (dsp.sine(a, n) + 0.8 * dsp.sine(b, n, start=0.25))
    breathe = 0.85 + 0.15 * np.sin(2 * np.pi * 3 * t / L)
    hum *= breathe
    rumble = _decorrelated(n, rng, dsp.brown, 0.7)
    rumble = dsp.periodic(dsp.lowpass, rumble, 140.0) * 0.5 * (0.8 + 0.2 * dsp.smooth_random(n, rng, 0.08))
    hull = _decorrelated(n, rng, dsp.pink, 0.3)
    hull = dsp.periodic(dsp.bandpass, hull, 310.0, 6.0) * 0.12 * (0.6 + 0.4 * dsp.smooth_random(n, rng, 0.05))
    x = dsp.stereo(0.6 * hum) + rumble + hull
    x = dsp.periodic(dsp.highpass, x, 30.0)
    return x - x.mean(axis=1, keepdims=True)


@sound("amb_ship_air", "ambience", -33.0, **SHIP_BED, **_bounds(N_AIR))
def amb_ship_air(rng: np.random.Generator) -> np.ndarray:
    n = N_AIR
    L = n / dsp.SR
    t = dsp.time_axis(n)
    blade = 0.85 + 0.15 * np.sin(2 * np.pi * _whole(18.0, L) * t)
    fan = _decorrelated(n, rng, dsp.pink, 0.4)
    fan = dsp.periodic(dsp.bandpass, fan, 1100.0, 0.5) * 0.4 * blade
    hiss = _decorrelated(n, rng, dsp.white, 0.1)
    hiss = dsp.periodic(dsp.lowpass, dsp.periodic(dsp.highpass, hiss, 5000.0), 9000.0) * 0.03
    pump = np.zeros((2, n))
    sighs = 5
    for k in range(sighs):
        m = dsp.samples(2.6)
        sigh = dsp.bandpass(dsp.pink(m, rng), 320.0, 1.2) * dsp.env([(0, 0), (0.9, 1.0), (2.6, 0)], m, 0.8)
        seg = np.zeros((2, n))
        dsp.place(seg, dsp.pan(0.35 * sigh, 0.55), dsp.samples(k * L / sighs + 0.7))
        pump += seg
    whine = dsp.periodic(dsp.bandpass, dsp.pink(n, rng), _whole(H(93), L), 60.0) * 0.02
    x = fan + hiss + pump + dsp.pan(whine, -0.4)
    x = dsp.periodic(dsp.highpass, x, 80.0)
    return x - x.mean(axis=1, keepdims=True)


# --------------------------------------------------------------------------- ship details

DETAIL = dict(channels=2, folder="ambience/ship")


def _indoors(x: np.ndarray, rng: np.random.Generator, side: float, room: float = 0.3,
             seconds: float = 0.9, far: float = 6000.0) -> np.ndarray:
    """Another part of the ship: a small metal room, the top rolled off, panned."""
    y = dsp.lowpass(dsp.dc_block(dsp.highpass(x, 70.0)), far)
    y = dsp.reverb(dsp.pan(y, side), rng, seconds=seconds, mix=room, predelay_ms=15.0, damp=0.6, width=0.7)
    return dsp.fade(dsp.trim_tail(y, -55.0), 0.003, 0.15)


def _relay(rng: np.random.Generator, side: float, note: int) -> np.ndarray:
    a = tick(rng, 1400.0, 0.004, 0.5)
    b = tick(rng, 2200.0, 0.003, 0.4)
    m = dsp.samples(0.12)
    beep = dsp.sine(H(note), m) * dsp.perc(m, 0.008, 0.03)
    return _indoors(_seq([(0.0, a), (0.045, 0.7 * b), (0.12, 0.25 * beep)], 0.4), rng, side, 0.25, 0.6)


for _i, (_s, _note) in enumerate([(-0.6, 93), (0.5, 100), (0.1, 98)], start=1):
    sound(f"amb_ship_relay_{_i}", "shipdetail", -33.0, max_seconds=1.2, params={"recipe": "_relay"},
          **DETAIL)(lambda rng, s=_s, note=_note: _relay(rng, s, note))


def _creak(rng: np.random.Generator, side: float, dur: float, low: float) -> np.ndarray:
    n = dsp.samples(dur)
    u = dsp.time_axis(n) / dur
    rate = 18.0 + 40.0 * np.sin(np.pi * u) ** 2 * float(rng.uniform(0.7, 1.2))
    ph = np.cumsum(rate / dsp.SR)
    hits = np.diff(np.floor(ph), prepend=0.0) > 0
    train = hits.astype(float) * (0.5 + 0.5 * rng.random(n))
    body = np.zeros(n)
    for f, q, g in [(low, 8.0, 1.0), (low * 2.37, 10.0, 0.5), (low * 5.1, 12.0, 0.2)]:
        body += g * dsp.bandpass(train, f, q)
    body *= dsp.env([(0, 0), (0.08 * dur, 1.0), (0.8 * dur, 0.7), (dur, 0)], n)
    return _indoors(body, rng, side, 0.35, 1.2, 3000.0)


for _i, (_s, _d, _f) in enumerate([(-0.4, 1.4, 170.0), (0.6, 1.9, 140.0), (0.0, 1.1, 210.0)], start=1):
    sound(f"amb_ship_creak_{_i}", "shipdetail", -34.0, max_seconds=3.0, params={"recipe": "_creak"},
          **DETAIL)(lambda rng, s=_s, d=_d, f=_f: _creak(rng, s, d, f))


def _machine(rng: np.random.Generator, side: float, up: float) -> np.ndarray:
    total = 2.4
    buf = np.zeros(dsp.samples(total))
    m = dsp.samples(0.5)
    t = dsp.time_axis(m)
    clunk = dsp.sine(85.0 * (1.0 + 0.3 * np.exp(-t / 0.02)), m) * dsp.perc(m, 0.002, 0.08)
    clunk += 0.4 * dsp.partials(370.0, m, [(1.0, 1.0, 0.12), (2.76, 0.4, 0.06)], rng)
    dsp.place(buf, clunk, 0)
    w = dsp.samples(1.4)
    u = dsp.time_axis(w) / 1.4
    f = 300.0 * up ** u
    whirr = dsp.warm_saw(f, w, 3.0) * dsp.env([(0, 0), (0.2, 0.6), (1.1, 0.5), (1.4, 0)], w)
    dsp.place(buf, 0.25 * dsp.lowpass(whirr, 1200.0), dsp.samples(0.25))
    return _indoors(buf, rng, side, 0.45, 1.6, 2500.0)


for _i, (_s, _u) in enumerate([(0.55, 1.8), (-0.5, 1.5)], start=1):
    sound(f"amb_ship_machine_{_i}", "shipdetail", -34.0, max_seconds=4.0, params={"recipe": "_machine"},
          **DETAIL)(lambda rng, s=_s, u=_u: _machine(rng, s, u))


def _ping(rng: np.random.Generator, side: float, f: float) -> np.ndarray:
    m = dsp.samples(0.9)
    x = dsp.partials(f, m, [(1.0, 1.0, 0.25), (2.31, 0.5, 0.12), (3.97, 0.25, 0.06)], rng)
    x = x * dsp.perc(m, 0.001, 1e6)
    return _indoors(x, rng, side, 0.4, 1.0, 5000.0)


for _i, (_s, _f) in enumerate([(-0.7, 1870.0), (0.65, 2490.0)], start=1):
    sound(f"amb_ship_ping_{_i}", "shipdetail", -35.0, max_seconds=2.4, params={"recipe": "_ping"},
          **DETAIL)(lambda rng, s=_s, f=_f: _ping(rng, s, f))


# --------------------------------------------------------------------------- interface


def _ui_dyads(rng: np.random.Generator, pairs: list[tuple[int, int, float, float]], total: float) -> np.ndarray:
    """Meridian dyads (lo, hi, at, dur), band-limited like the briefing panel's."""
    buf = np.zeros(dsp.samples(total))
    for lo, hi, at, dur in pairs:
        dsp.place(buf, advisor_dyad(H(lo), H(hi), dur), dsp.samples(at))
    return dsp.bandpass(dsp.highpass(buf, 350.0), 1800.0, 0.6) * 1.4 + 0.5 * dsp.highpass(buf, 350.0)


@sound("ui_title_open", "ui", UI_LUFS - 1.0, max_seconds=0.45)
def ui_title_open(rng: np.random.Generator) -> np.ndarray:
    x = _ui_dyads(rng, [(74, 81, 0.0, 0.08), (81, 88, 0.1, 0.12)], 0.45)
    glass = 0.3 * chime(H(93), 0.03, rng, brightness=0.4, decay=0.1, attack=0.006, tail=0.2)
    y = _seq([(0.0, x), (0.1, glass)], 0.45)
    return dsp.fade(dsp.trim_tail(dsp.dc_block(dsp.highpass(y, 250.0)), -55.0), 0.004, 0.05)


@sound("ui_map_open", "ui", UI_LUFS, max_seconds=0.35)
def ui_map_open(rng: np.random.Generator) -> np.ndarray:
    m = dsp.samples(0.22)
    u = dsp.time_axis(m) / 0.22
    air = dsp.sweep(dsp.white(m, rng), "bp", 1500.0 * 4.0 ** u, 1.2) * dsp.env([(0, 0), (0.15, 1), (0.22, 0)], m)
    a = chime(H(81), 0.03, rng, brightness=0.5, decay=0.06, attack=0.004, tail=0.12)
    b = chime(H(88), 0.03, rng, brightness=0.5, decay=0.1, attack=0.004, tail=0.15)
    sonar = 0.3 * tick(rng, H(100), 0.012, 0.1)
    return _done(_seq([(0.0, 0.08 * air), (0.05, 0.8 * a), (0.12, b), (0.2, sonar)], 0.35))


for _i, _note in enumerate([100, 102, 105, 107], start=1):
    sound(f"ui_map_node_hover_{_i}", "ui", UI_LUFS - 8.0, max_seconds=0.08, params={"recipe": "_hover"})(
        lambda rng, note=_note: _done(tick(rng, H(note), 0.004, 0.08, 0.8)))


@sound("ui_map_node_select", "ui", UI_LUFS, max_seconds=0.3)
def ui_map_node_select(rng: np.random.Generator) -> np.ndarray:
    wood = marimba(H(86), 0.03, rng, hardness=0.7, decay=0.05, tail=0.1)
    glass = chime(H(93), 0.03, rng, brightness=0.55, decay=0.08, attack=0.003, tail=0.14)
    m = dsp.samples(0.12)
    f = H(105) * (1.0 - 0.05 * np.clip(dsp.time_axis(m) / 0.08, 0, 1))
    ping = dsp.fm(f, 2.0, 0.6 * dsp.perc(m, 0.001, 0.02), m) * dsp.perc(m, 0.002, 0.03)
    return _done(_seq([(0.0, wood), (0.03, 0.8 * glass), (0.08, 0.25 * ping)], 0.3))


@sound("ui_map_launch", "ui", UI_LUFS + 3.0, max_seconds=1.2)
def ui_map_launch(rng: np.random.Generator) -> np.ndarray:
    total = 1.15
    pairs = [(62, 69, 0.0, 0.07), (66, 73, 0.12, 0.07), (69, 76, 0.24, 0.07), (74, 81, 0.36, 0.45)]
    x = _ui_dyads(rng, pairs, total)
    m = dsp.samples(0.7)
    u = dsp.time_axis(m) / 0.7
    air = dsp.sweep(dsp.pink(m, rng), "bp", 400.0 * 8.0 ** u, 1.0) * dsp.env([(0, 0), (0.45, 1.0), (0.7, 0)], m)
    high = 0.35 * advisor_dyad(H(86), H(93), 0.3)
    y = _seq([(0.0, x), (0.0, 0.12 * air), (0.42, high)], total)
    y = dsp.reverb(y, rng, seconds=0.7, mix=0.15, damp=0.6).mean(axis=0)
    return dsp.fade(dsp.trim_tail(dsp.dc_block(dsp.highpass(y, 150.0)), -55.0), 0.004, 0.2)[: dsp.samples(total)]


@sound("ui_tech_open", "ui", UI_LUFS, max_seconds=0.35)
def ui_tech_open(rng: np.random.Generator) -> np.ndarray:
    parts = []
    for k, note in enumerate([83, 86, 90, 93]):
        c = chime(H(note), 0.02, rng, brightness=0.45, decay=0.05 if k < 3 else 0.1, attack=0.003, tail=0.12)
        parts.append((k * 0.035, (0.6 + 0.13 * k) * c))
    return _done(_seq(parts, 0.35))


for _i, _note in enumerate([97, 100, 92], start=1):
    sound(f"ui_tech_hover_{_i}", "ui", UI_LUFS - 8.0, max_seconds=0.08, params={"recipe": "_hover"})(
        lambda rng, note=_note: _done(tick(rng, H(note), 0.005, 0.05, 0.8)))


def _seal(rng: np.random.Generator, length: float) -> np.ndarray:
    """A low bell on D3 with a quiet fifth that keeps ringing: it stays."""
    a = bell(H(50), rng, decay=0.9, brightness=0.4, strike=0.25, length=length)
    b = 0.35 * bell(H(57), rng, decay=0.7, brightness=0.3, strike=0.0, length=length)
    return dsp.lowpass(a + b, 2400.0)


@sound("ui_tech_buy", "ui", UI_LUFS + 3.0, max_seconds=1.6)
def ui_tech_buy(rng: np.random.Generator) -> np.ndarray:
    total = 1.5
    wood = marimba(H(74), 0.04, rng, hardness=0.9, decay=0.08, tail=0.15)
    g1 = chime(H(86), 0.04, rng, brightness=0.6, decay=0.25, attack=0.003, tail=0.5)
    g2 = chime(H(93), 0.04, rng, brightness=0.6, decay=0.3, attack=0.003, tail=0.5)
    seal = _seal(rng, total)
    y = _seq([(0.0, wood), (0.02, 0.7 * g1), (0.06, 0.6 * g2), (0.05, 0.9 * seal)], total)
    y = dsp.reverb(y, rng, seconds=0.9, mix=0.14, damp=0.6).mean(axis=0)
    return dsp.fade(dsp.trim_tail(dsp.dc_block(dsp.highpass(y, 90.0)), -55.0), 0.0005, 0.3)[: dsp.samples(total)]


@sound("ui_tech_unlocked", "ui", UI_LUFS + 1.0, max_seconds=1.6)
def ui_tech_unlocked(rng: np.random.Generator) -> np.ndarray:
    total = 1.5
    y = _seq([(0.0, _seal(rng, total)), (0.0, 0.4 * chime(H(86), 0.04, rng, brightness=0.4, decay=0.3, tail=0.5))],
             total)
    y = dsp.reverb(y, rng, seconds=0.9, mix=0.14, damp=0.6).mean(axis=0)
    return dsp.fade(dsp.trim_tail(dsp.dc_block(dsp.highpass(y, 90.0)), -55.0), 0.002, 0.3)[: dsp.samples(total)]


@sound("ui_tech_denied", "ui", UI_LUFS, max_seconds=0.3)
def ui_tech_denied(rng: np.random.Generator) -> np.ndarray:
    a = marimba(H(63), 0.03, rng, hardness=0.3, decay=0.05, tail=0.1)
    b = marimba(H(62), 0.03, rng, hardness=0.3, decay=0.08, tail=0.12)
    m = dsp.samples(0.1)
    stop = 0.5 * dsp.lowpass(dsp.white(m, rng), 500.0) * dsp.perc(m, 0.001, 0.012)
    y = _seq([(0.0, a), (0.08, b), (0.08, stop)], 0.3)
    return dsp.fade(dsp.trim_tail(dsp.dc_block(dsp.highpass(y, 150.0)), -55.0), 0.0005, 0.01)


@sound("ui_loadout_open", "ui", UI_LUFS, max_seconds=0.35)
def ui_loadout_open(rng: np.random.Generator) -> np.ndarray:
    latch = tick(rng, 1300.0, 0.006, 0.6)
    m = dsp.samples(0.12)
    slide = dsp.bandpass(dsp.white(m, rng), 2600.0, 1.5) * dsp.env([(0, 0), (0.03, 1), (0.12, 0)], m) * 0.12
    a = marimba(H(69), 0.03, rng, hardness=0.6, decay=0.05, tail=0.1)
    b = marimba(H(74), 0.03, rng, hardness=0.6, decay=0.09, tail=0.14)
    return _done(_seq([(0.0, latch), (0.01, slide), (0.1, a), (0.16, b)], 0.35))


@sound("ui_loadout_change", "ui", UI_LUFS - 1.0, max_seconds=0.2)
def ui_loadout_change(rng: np.random.Generator) -> np.ndarray:
    clack = dsp.mix(tick(rng, 1800.0, 0.005, 0.6), 0.5 * tick(rng, 900.0, 0.008, 0.2))
    glass = chime(H(90), 0.02, rng, brightness=0.5, decay=0.05, attack=0.003, tail=0.1)
    return _done(_seq([(0.0, clack), (0.025, 0.6 * glass)], 0.2))


@sound("ui_campaign_saved", "ui", UI_LUFS - 4.0, max_seconds=0.3)
def ui_campaign_saved(rng: np.random.Generator) -> np.ndarray:
    a = tick(rng, H(98), 0.006, 0.1)
    b = tick(rng, H(105), 0.009, 0.1)
    latch = 0.4 * tick(rng, 900.0, 0.006, 0.5, 0.3)
    return _done(_seq([(0.0, latch), (0.03, a), (0.08, 0.8 * b)], 0.3))


# --------------------------------------------------------------------------- Advisor


@sound("advisor_campaign_route_open", "advisor", ADVISOR_LUFS - 1.0, max_seconds=1.6)
def advisor_campaign_route_open(rng: np.random.Generator) -> np.ndarray:
    held = advisor_dyad(H(78), H(85), 0.45)
    n = len(held)
    u = np.clip(dsp.time_axis(n) / 0.45, 0, 1)
    held = dsp.sweep(held, "lp", 1500.0 * 5.0 ** u, 0.7)
    parts = [(0.0, 0.8, advisor_dyad(H(74), H(81), 0.08)),
             (0.12, 0.85, advisor_dyad(H(76), H(83), 0.08)),
             (0.24, 1.0, held),
             (0.55, 0.3, advisor_dyad(H(97), H(97), 0.06))]
    return _phrase(parts, rng, 1.4, room=0.16)


@sound("advisor_campaign_tech_available", "advisor", ADVISOR_LUFS - 1.0, max_seconds=1.4)
def advisor_campaign_tech_available(rng: np.random.Generator) -> np.ndarray:
    parts = [(0.0, 0.8, advisor_dyad(H(80), H(86), 0.05)),
             (0.09, 0.8, advisor_dyad(H(80), H(86), 0.05)),
             (0.18, 1.0, glide_dyad(H(80), H(86), 0.3, 1.0, 0.1)),
             (0.42, 0.45, advisor_dyad(H(88), H(93), 0.12))]
    return _phrase(parts, rng, 1.2)


@sound("advisor_campaign_intel_banked", "advisor", ADVISOR_LUFS, max_seconds=1.6)
def advisor_campaign_intel_banked(rng: np.random.Generator) -> np.ndarray:
    parts = []
    for k, (lo, hi) in enumerate([(74, 81), (76, 83), (78, 85), (81, 88)]):
        parts.append((k * 0.06, 0.6 + 0.08 * k, advisor_dyad(H(lo), H(hi), 0.035)))
    parts.append((0.26, 1.0, advisor_dyad(H(86), H(93), 0.4)))
    m = dsp.samples(0.3)
    t = dsp.time_axis(m)
    thunk = dsp.sine(H(50) * (1.0 + 0.2 * np.exp(-t / 0.02)), m) * dsp.perc(m, 0.003, 0.07)
    parts.append((0.26, 0.6, thunk))
    return _phrase(parts, rng, 1.4)


@sound("advisor_campaign_return_won", "advisor", ADVISOR_LUFS - 1.0, max_seconds=1.8)
def advisor_campaign_return_won(rng: np.random.Generator) -> np.ndarray:
    parts = [(0.0, 0.75, advisor_dyad(H(69), H(76), 0.12)),
             (0.17, 0.85, advisor_dyad(H(73), H(80), 0.12)),
             (0.34, 1.0, advisor_dyad(H(74), H(81), 0.6)),
             (0.34, 0.4, advisor_dyad(H(86), H(86), 0.6))]
    return _phrase(parts, rng, 1.7, room=0.2)


@sound("advisor_campaign_return_lost", "advisor", ADVISOR_LUFS - 2.0, max_seconds=1.8)
def advisor_campaign_return_lost(rng: np.random.Generator) -> np.ndarray:
    fall = glide_dyad(H(74), H(81), 0.55, -3.0, 0.25)
    n = len(fall)
    u = np.clip(dsp.time_axis(n) / 0.55, 0, 1)
    fall = dsp.sweep(fall, "lp", 4000.0 * 0.25 ** u, 0.7)
    m = dsp.samples(1.0)
    under = 0.3 * soft_sine(H(50), 0.6, attack=0.1, release=0.35, harmonics=(1.0, 0.1))[:m]
    parts = [(0.0, 1.0, fall), (0.35, 0.8, under)]
    return _phrase(parts, rng, 1.6, room=0.18)
