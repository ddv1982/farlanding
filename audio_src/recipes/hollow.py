"""Hollow Meridian (Phase 8d): the planet's ambience, the old engines, the
Sentinel and the Advisor lines of the campaign's last landing.

Kessel is dry and dusty, Thalassa wet and wide, Emberfall low and hot,
Verdance wooden and breathy. Hollow Meridian is built: the plated deck of an
Antecedent megastructure in the dark, bottomless chasms, glowing seams,
dormant guardians everywhere. Nothing here is alive and nothing is weather:
it is structure (a hum felt more than heard), air moving in a space too big to
have walls, and far machinery that has been turning over, slowly, for ever.

Planet beds (group `ambience`, the AmbienceDirector's own players):

  amb_hollow_hum        the structure: a sub hum on G#1 with its octave and a
                        faint D, twins beating slowly, a pressure that surges
                        once or twice a loop (47 s)
  amb_hollow_air        air moving in a vast space: dark wide noise in slow
                        swells, a hollow resonance wandering, a far whistle
                        across a chasm (41 s)
  amb_hollow_machinery  distant machinery turning over: a slow five-beat
                        cycle of rumble, grind and a far heavy clank (34 s)

Details (group `ambdetail`, positional one-shots around the listener):

  amb_metal_groan_<n>   a far metallic groan: stick-slip through plate
                        resonances, deep, in a long hall
  amb_relay_click_<n>   a relay clicking, a short electrical buzz, its echo
                        coming back across the deck
  amb_pebble_fall_<n>   a pebble dropping into a chasm: it ticks off the wall,
                        fainter, duller and further apart, and never lands
  amb_seam_tick_<n>     a glowing seam's electrical tick: a crackle, a glass
                        ping on G# or D, a blip of hum

The engines (group `machine`, MachineSound, positional on the Buildings bus):

  machine_spinup        the player's faction wakes an engine: stone grinding
                        loose, a tone rising two octaves that lands on D with
                        A above (the Meridian's dyad: it runs for us), a bell
                        strike on the landing, the hum settling in
  machine_winddown      an engine lost: the hum's D and A sag an octave as it
                        slows, the grind drags to a stop, a last clunk, a sigh
  machine_seized        the enemy wakes one: the same rise, colder, landing
                        off the chord on the Combine's bent Bb and F with
                        ring-modulated grit, no bell
  loop_engine_run       a running engine (6 s loop): D2 and A2 turning over,
                        a slow rotation, faint bell partials

The Sentinel (Custodian heavy, sound set `sentinel`): a larger Warden, its
drone on G# with D above (the tritone frame), slower and heavier.

  move_sentinel, loop_hum_sentinel, unit_sentinel_wake,
  weapon_sentinel_fire_<n> (a charged stone-and-light bolt), death_sentinel

Advisor (Meridian dyads): engine_online, engine_lost, custodians_awake,
core_charging, core_contested.
"""

from __future__ import annotations

import numpy as np

from synth import dsp
from synth.instruments import bell

from . import sound
from .advisor import ADVISOR_LUFS, _phrase, glide_dyad
from .antecedent import bell_drone
from .impacts import _finish as impact_finish, debris
from .movement import MOVE_LUFS, _finish as move_finish, lfo, qf
from .weather import loop_bounds, loop_samples
from .world import advisor_dyad

H = dsp.midi_hz


def _wide(n: int, rng: np.random.Generator, maker, shared: float) -> np.ndarray:
    common = maker(n, rng)
    return np.stack([shared * common + (1 - shared) * maker(n, rng) for _ in range(2)])


def _finish(x: np.ndarray, hp: float = 30.0) -> np.ndarray:
    x = dsp.periodic(dsp.highpass, x, hp)
    return x - x.mean(axis=-1, keepdims=True)


def _far(x: np.ndarray, rng: np.random.Generator, room: float = 0.45, seconds: float = 4.0,
         lp: float = 6500.0, hp: float = 45.0) -> np.ndarray:
    """Far away in a vast hall: a long reverb, rolled-off top, mono."""
    y = dsp.reverb(x, rng, seconds=seconds, mix=room, predelay_ms=60.0, damp=0.55).mean(axis=0)
    y = dsp.lowpass(y, lp)
    return dsp.fade(dsp.trim_tail(dsp.dc_block(dsp.highpass(y, hp)), -55.0), 0.005, 0.4)


# --------------------------------------------------------------------------- planet beds


AMB = dict(fmt="ogg", channels=2, loop=True, folder="ambience/hollow")
N_HUM = loop_samples(47.0)
N_AIR = loop_samples(41.0)
N_MACH = loop_samples(34.0)


@sound("amb_hollow_hum", "ambience", -32.0, **AMB, **loop_bounds(N_HUM))
def amb_hollow_hum(rng: np.random.Generator) -> np.ndarray:
    n = N_HUM
    L = n / dsp.SR
    surge = 0.5 + 0.5 * dsp.smooth_random(n, rng, 0.04)
    out = np.zeros((2, n))
    for m, amp, beat in [(32, 1.0, 0.11), (44, 0.55, 0.17), (50, 0.18, 0.23), (56, 0.12, 0.3), (68, 0.03, 0.4)]:
        for c, side in enumerate((-1.0, 1.0)):
            f1 = qf(H(m), L)
            f2 = qf(H(m) + beat * side, L)
            out[c] += amp * 0.5 * (dsp.sine(f1, n, float(rng.random())) + dsp.sine(f2, n, float(rng.random())))
    out *= 0.25 * (0.75 + 0.25 * surge)
    pressure = dsp.periodic(dsp.lowpass, _wide(n, rng, dsp.brown, 0.7), 140.0) * 0.5 * (0.5 + 0.5 * surge)
    resonance = dsp.periodic(dsp.bandpass, _wide(n, rng, dsp.pink, 0.4), 210.0, 3.0) * 0.12
    return _finish(out + pressure + resonance, 32.0)


@sound("amb_hollow_air", "ambience", -31.0, **AMB, **loop_bounds(N_AIR))
def amb_hollow_air(rng: np.random.Generator) -> np.ndarray:
    n = N_AIR
    L = n / dsp.SR
    swell = (0.5 + 0.5 * dsp.smooth_random(n, rng, 0.05)) ** 1.4
    drift = dsp.smooth_random(n, rng, 0.02)
    body = _wide(n, rng, dsp.pink, 0.2)
    body = dsp.periodic(dsp.sweep, body, "lp", 500.0 + 900.0 * swell, 0.6, block=256) * (0.35 + 0.45 * swell)
    body = np.stack([body[0] * (1.0 - 0.35 * drift), body[1] * (1.0 + 0.35 * drift)])
    hollow = dsp.periodic(dsp.sweep, _wide(n, rng, dsp.pink, 0.5), "bp", 380.0 + 120.0 * drift, 5.0, block=256)
    hollow *= 0.2 * (0.4 + 0.6 * swell)
    # A far whistle across a chasm: a narrow band near G#5, twice a loop.
    whistle_gate = np.clip(lfo(n, L, 2, 0.15), 0.0, 1.0) ** 3
    whistle = dsp.periodic(dsp.bandpass, _wide(n, rng, dsp.white, 0.7), 830.0, 22.0) * 0.08 * whistle_gate
    low = dsp.periodic(dsp.lowpass, _wide(n, rng, dsp.brown, 0.6), 160.0) * 0.25
    high = dsp.periodic(dsp.bandpass, _wide(n, rng, dsp.pink, 0.2), 2800.0, 0.8) * 0.035 * (0.5 + 0.5 * swell)
    return _finish(body + hollow + whistle + low + high, 40.0)


@sound("amb_hollow_machinery", "ambience", -33.0, **AMB, **loop_bounds(N_MACH))
def amb_hollow_machinery(rng: np.random.Generator) -> np.ndarray:
    n = N_MACH
    L = n / dsp.SR
    t = dsp.time_axis(n)
    cycles = 5  # a slow turning-over, five times a loop
    phase = (t * cycles / L) % 1.0
    turn = np.sin(np.pi * phase) ** 2
    rumble = dsp.periodic(dsp.highpass, _wide(n, rng, dsp.brown, 0.8), 45.0)
    rumble = dsp.periodic(dsp.lowpass, rumble, 140.0) * (0.3 + 0.7 * turn)
    grind = dsp.periodic(dsp.sweep, _wide(n, rng, dsp.white, 0.5), "bp", 300.0 + 500.0 * turn, 4.0, block=256)
    grind *= 0.05 * turn ** 2
    buf = np.zeros((2, n + dsp.samples(8.0)))
    for k in range(cycles):  # a far heavy clank at the top of each turn
        at = int((k + 0.5) / cycles * n) + int(rng.integers(-2000, 2000))
        m = dsp.samples(2.0)
        tt = dsp.time_axis(m)
        clank = dsp.partials(float(rng.uniform(95.0, 130.0)), m, [(1.0, 1.0, 0.35), (2.76, 0.5, 0.2),
                                                                  (5.4, 0.25, 0.08)], rng)
        clank = clank + 0.4 * dsp.lowpass(dsp.white(m, rng), 900.0) * dsp.perc(m, 0.002, 0.03)
        clank = dsp.lowpass(clank * (1.0 - np.exp(-tt / 0.004)), 1800.0)
        dsp.place(buf, dsp.pan(0.25 * clank, float(rng.uniform(-0.7, 0.7))), at)
    clanks = dsp.wrap(buf, n)
    clanks = dsp.wrap(dsp.reverb(clanks, rng, seconds=5.0, mix=0.6, predelay_ms=80.0, damp=0.6), n)
    whine = dsp.sine(qf(H(62), L), n) * 0.01 * turn
    return _finish(rumble + grind + clanks + dsp.stereo(whine), 32.0)


# --------------------------------------------------------------------------- details


DETAIL = dict(folder="ambience/details")


def _groan(rng: np.random.Generator, length: float, rate: float, pitch: float) -> np.ndarray:
    """Metal under load: stick-slip pulses whose rate wanders and sags, through
    plate resonances (inharmonic), deep."""
    n = dsp.samples(length + 1.0)
    t = dsp.time_axis(n)
    shape = dsp.env([(0, 0), (length * 0.3, 1.0), (length * 0.75, 0.7), (length, 0)], n, 1.2)
    wander = rate * (1.0 + 0.3 * dsp.smooth_random(n, rng, 1.5, periodic=False) - 0.3 * np.clip(t / length, 0, 1))
    ph = np.cumsum(wander) / dsp.SR
    pulses = (np.diff(np.floor(ph), prepend=0.0) > 0).astype(float) * rng.uniform(0.6, 1.0, n)
    body = np.zeros(n)
    for ratio, q, amp in ((1.0, 12.0, 1.0), (2.76, 10.0, 0.5), (5.4, 8.0, 0.25), (8.93, 6.0, 0.1)):
        body += amp * dsp.bandpass(pulses, pitch * ratio, q)
    return body * shape * 40.0


for _i, (_len, _rate, _pitch) in enumerate([(2.2, 18.0, 95.0), (3.0, 12.0, 70.0), (1.6, 26.0, 130.0)], start=1):
    def _make_groan(rng: np.random.Generator, length=_len, rate=_rate, pitch=_pitch) -> np.ndarray:
        return _far(_groan(rng, length, rate, pitch), rng, 0.5, 4.5, 4000.0)

    sound(f"amb_metal_groan_{_i}", "ambdetail", -26.0, max_seconds=7.5, params={"recipe": "_groan"},
          **DETAIL)(_make_groan)


def _relay(rng: np.random.Generator, clicks: int, buzz_hz: float) -> np.ndarray:
    buf = np.zeros(dsp.samples(1.6))
    at = 0.02
    for k in range(clicks):
        m = dsp.samples(0.03)
        click = dsp.bandpass(dsp.white(m, rng), float(rng.uniform(2200, 3600)), 3.0) * dsp.perc(m, 0.0004, 0.004)
        thunk = dsp.sine(float(rng.uniform(380, 520)), m) * dsp.perc(m, 0.001, 0.008) * 0.4
        dsp.place(buf, click + thunk, dsp.samples(at))
        at += float(rng.uniform(0.07, 0.2))
    m = dsp.samples(0.12)
    buzz = dsp.soft_square(buzz_hz, m, 8.0) * dsp.env([(0, 0), (0.008, 1.0), (0.1, 0.6), (0.12, 0)], m) * 0.12
    dsp.place(buf, buzz, dsp.samples(at))
    echo = dsp.delay(buf, 0.38, 0.35, 0.45, 2500.0).mean(axis=0)
    return echo


for _i, (_clicks, _buzz) in enumerate([(2, 207.65), (3, 146.83), (1, 164.81)], start=1):
    def _make_relay(rng: np.random.Generator, c=_clicks, b=_buzz) -> np.ndarray:
        return _far(_relay(rng, c, b), rng, 0.35, 3.0, 7000.0, 120.0)

    sound(f"amb_relay_click_{_i}", "ambdetail", -28.0, max_seconds=5.0, params={"recipe": "_relay"},
          **DETAIL)(_make_relay)


def _pebble(rng: np.random.Generator, bounces: int) -> np.ndarray:
    """A pebble into a chasm: a first click on the edge, then ticks off the
    wall, each fainter, duller and further apart as it falls away; it never
    lands. A faint whistle of air follows it down."""
    buf = np.zeros(dsp.samples(5.0))
    at = 0.02
    gap = 0.18
    for k in range(bounces):
        m = dsp.samples(0.04)
        fall = 0.72 ** k
        tick = dsp.bandpass(dsp.white(m, rng), 2600.0 * fall + 500.0, 4.0) * dsp.perc(m, 0.0004, 0.004)
        knock = dsp.sine(float(rng.uniform(900, 1400)) * (0.85 ** k), m) * dsp.perc(m, 0.001, 0.01) * 0.5
        dsp.place(buf, (tick + knock) * fall, dsp.samples(at))
        at += gap
        gap *= 1.35
    m = dsp.samples(at)
    u = dsp.time_axis(m) / max(at, 1e-3)
    air = dsp.sweep(dsp.pink(m, rng), "bp", 1600.0 * (1.0 - 0.7 * u), 6.0) * np.sin(np.pi * u) * 0.04
    dsp.place(buf, air, dsp.samples(0.05))
    return buf


for _i, _b in enumerate([6, 8, 5], start=1):
    def _make_pebble(rng: np.random.Generator, b=_b) -> np.ndarray:
        return _far(_pebble(rng, b), rng, 0.4, 4.0, 8000.0, 150.0)

    sound(f"amb_pebble_fall_{_i}", "ambdetail", -28.0, max_seconds=8.0, params={"recipe": "_pebble"},
          **DETAIL)(_make_pebble)


def _seam(rng: np.random.Generator, note: int, sparks: int) -> np.ndarray:
    buf = np.zeros(dsp.samples(1.8))
    for _ in range(sparks):
        m = dsp.samples(0.01)
        spark = dsp.highpass(dsp.white(m, rng), 3000.0) * dsp.perc(m, 0.0002, 0.0015)
        dsp.place(buf, spark * float(rng.uniform(0.3, 1.0)), dsp.samples(float(rng.uniform(0.0, 0.08))))
    m = dsp.samples(1.2)
    t = dsp.time_axis(m)
    f = H(note)
    p = (dsp.sine(f, m) + 0.7 * dsp.sine(f + 1.3, m) + 0.1 * dsp.sine(3 * f, m)) * dsp.perc(m, 0.002, 0.35) * 0.3
    dsp.place(buf, p, dsp.samples(0.03))
    k = dsp.samples(0.18)
    blip = dsp.soft_square(H(note - 36), k, 6.0) * dsp.env([(0, 0), (0.01, 1.0), (0.18, 0)], k) * 0.08
    dsp.place(buf, blip, dsp.samples(0.02))
    return buf


for _i, (_note, _sparks) in enumerate([(92, 9), (86, 14), (80, 6)], start=1):
    def _make_seam(rng: np.random.Generator, note=_note, s=_sparks) -> np.ndarray:
        return _far(_seam(rng, note, s), rng, 0.3, 2.5, 9000.0, 120.0)

    sound(f"amb_seam_tick_{_i}", "ambdetail", -28.0, max_seconds=4.5, params={"recipe": "_seam"},
          **DETAIL)(_make_seam)


# --------------------------------------------------------------------------- the engines


MACHINE = dict(folder="machines")
ENGINE_LOOP = 6.0


def _grind(rng: np.random.Generator, seconds: float, rising: bool) -> np.ndarray:
    """Stone grinding: stick-slip pulses through stone resonances, speeding up
    as it frees itself (or dragging to a stop), over a low scrape."""
    n = dsp.samples(seconds)
    u = dsp.time_axis(n) / seconds
    rate = (6.0 + 40.0 * u ** 1.5) if rising else (40.0 * (1.0 - u) ** 1.2 + 3.0)
    ph = np.cumsum(rate) / dsp.SR
    pulses = (np.diff(np.floor(ph), prepend=0.0) > 0).astype(float) * rng.uniform(0.4, 1.0, n)
    body = sum(a * dsp.bandpass(pulses, fc, 5.0) for fc, a in ((180.0, 1.0), (420.0, 0.6), (1100.0, 0.25)))
    scrape = dsp.sweep(dsp.brown(n, rng), "bp", (90.0 + 260.0 * u) if rising else (350.0 - 260.0 * u), 1.4)
    shape = dsp.env([(0, 0), (0.15, 1.0), (seconds * 0.8, 0.9), (seconds, 0)], n, 1.0)
    return (2.5 * body + 0.6 * scrape) * shape


def _engine_tone(n: int, f: np.ndarray, rng: np.random.Generator, bright: float = 1.0) -> np.ndarray:
    """The engine's voice: a fundamental, its fifth and octave, a hint of bell."""
    tone = dsp.sine(f, n) + 0.6 * dsp.sine(f * 1.5, n) + 0.35 * dsp.sine(f * 2.0, n) + 0.08 * bright * dsp.sine(f * 2.76, n)
    return tone


@sound("machine_spinup", "machine", -20.0, max_seconds=5.2, min_seconds=3.5, **MACHINE)
def machine_spinup(rng: np.random.Generator) -> np.ndarray:
    total = 4.8
    buf = np.zeros(dsp.samples(total + 2.0))
    dsp.place(buf, 0.6 * _grind(rng, 1.8, True), 0)
    # The rise: from D1 two octaves up, easing in to land on D3 (with A).
    land = 2.5
    m = dsp.samples(land - 0.4)
    u = dsp.time_axis(m) / (land - 0.4)
    f = H(26) * 2.0 ** (24.0 * (1.0 - (1.0 - u) ** 2.2) / 12.0)
    rise = _engine_tone(m, f, rng) * dsp.env([(0, 0), (0.6, 0.5), (land - 0.4, 1.0)], m, 1.0) * 0.25
    dsp.place(buf, rise, dsp.samples(0.4))
    # Landing: a bell strike on D and A, a thump; the hum settles in.
    dsp.place(buf, 0.9 * bell(H(50), rng, decay=1.2, brightness=0.6, strike=0.5), dsp.samples(land))
    dsp.place(buf, 0.5 * bell(H(57), rng, decay=1.0, brightness=0.5, strike=0.3), dsp.samples(land + 0.03))
    k = dsp.samples(0.6)
    tt = dsp.time_axis(k)
    dsp.place(buf, 0.7 * dsp.sine(55.0 * (1.0 + 0.4 * np.exp(-tt / 0.03)), k) * dsp.perc(k, 0.003, 0.18),
              dsp.samples(land))
    k = dsp.samples(total - land)
    tt = dsp.time_axis(k)
    hum = _engine_tone(k, np.full(k, H(38)), rng) * dsp.env([(0, 1.0), (0.4, 0.6), (total - land, 0.45)], k)
    hum *= 1.0 - 0.3 * (0.5 + 0.5 * np.sin(2 * np.pi * 1.5 * tt))  # it turns
    dsp.place(buf, 0.22 * hum, dsp.samples(land))
    y = impact_finish(buf, rng, 35.0, dict(seconds=2.2, mix=0.25, predelay_ms=20.0, damp=0.55), -58.0, 0.5)
    return y[: dsp.samples(total)]


@sound("machine_winddown", "machine", -22.0, max_seconds=4.4, min_seconds=2.5, **MACHINE)
def machine_winddown(rng: np.random.Generator) -> np.ndarray:
    total = 3.8
    buf = np.zeros(dsp.samples(total + 2.0))
    m = dsp.samples(2.8)
    u = dsp.time_axis(m) / 2.8
    f = H(38) * 2.0 ** (-12.0 * u ** 1.6 / 12.0)
    hum = _engine_tone(m, f, rng, 0.6) * (1.0 - u) ** 1.3
    hum *= 1.0 - 0.35 * (0.5 + 0.5 * np.sin(2 * np.pi * np.cumsum(1.5 * (1.0 - 0.8 * u)) / dsp.SR))
    dsp.place(buf, 0.3 * hum, 0)
    dsp.place(buf, 0.45 * _grind(rng, 2.6, False), dsp.samples(0.2))
    k = dsp.samples(0.5)
    tt = dsp.time_axis(k)
    clunk = dsp.sine(70.0 * (1.0 + 0.3 * np.exp(-tt / 0.02)), k) * dsp.perc(k, 0.002, 0.12)
    clunk += 0.4 * dsp.bandpass(dsp.white(k, rng), 700.0, 2.0) * dsp.perc(k, 0.001, 0.02)
    dsp.place(buf, 0.7 * clunk, dsp.samples(2.75))
    k = dsp.samples(1.0)
    sigh = dsp.sweep(dsp.pink(k, rng), "bp", 1500.0 * 0.3 ** (dsp.time_axis(k)), 1.2)
    sigh *= dsp.env([(0, 0), (0.1, 1.0), (1.0, 0)], k, 1.5) * 0.12
    dsp.place(buf, sigh, dsp.samples(2.8))
    y = impact_finish(buf, rng, 35.0, dict(seconds=2.0, mix=0.25, predelay_ms=20.0, damp=0.6), -58.0, 0.4)
    return y[: dsp.samples(total)]


@sound("machine_seized", "machine", -22.0, max_seconds=4.4, min_seconds=2.5, **MACHINE)
def machine_seized(rng: np.random.Generator) -> np.ndarray:
    """The enemy wakes an engine: the rise, colder, landing off the chord on
    the Combine's bent Bb and F, ring-modulated grit, no bell."""
    total = 3.8
    buf = np.zeros(dsp.samples(total + 1.5))
    dsp.place(buf, 0.5 * _grind(rng, 1.4, True), 0)
    land = 2.0
    m = dsp.samples(land - 0.3)
    u = dsp.time_axis(m) / (land - 0.3)
    f = H(22) * 2.0 ** (24.0 * (1.0 - (1.0 - u) ** 2.0) / 12.0)  # Bb0 -> Bb2
    rise = _engine_tone(m, f, rng, 1.6) * u ** 0.7 * 0.22
    rise *= 1.0 + 0.5 * dsp.sine(f * 0.5 * 1.07, m)  # ring-modulated: cold
    dsp.place(buf, rise, dsp.samples(0.3))
    k = dsp.samples(total - land)
    tt = dsp.time_axis(k)
    held = (dsp.sine(H(46), k) + 0.7 * dsp.sine(H(53) * dsp.cents(14.0), k)) * (1.0 + 0.6 * dsp.sine(H(46) * 1.414, k))
    held *= dsp.env([(0, 1.0), (0.3, 0.6), (total - land, 0.0)], k, 1.0) * 0.25
    grit = dsp.bandpass(dsp.white(k, rng), 2400.0, 1.5) * dsp.perc(k, 0.002, 0.25) * 0.15
    dsp.place(buf, dsp.saturate(held, 1.8) + grit, dsp.samples(land))
    clank = dsp.partials(310.0, dsp.samples(0.8), [(1.0, 1.0, 0.12), (1.73, 0.7, 0.08), (2.91, 0.4, 0.04)], rng)
    dsp.place(buf, 0.5 * clank, dsp.samples(land))
    y = impact_finish(buf, rng, 40.0, dict(seconds=1.4, mix=0.2, predelay_ms=12.0, damp=0.65), -58.0, 0.4)
    return y[: dsp.samples(total)]


@sound("loop_engine_run", "machine", -30.0, loop=True, min_seconds=ENGINE_LOOP - 0.1,
       max_seconds=ENGINE_LOOP + 0.1, **MACHINE)
def loop_engine_run(rng: np.random.Generator) -> np.ndarray:
    """A running engine: D2 and A2 (the Meridian's dyad, low), turning over
    nine times a loop, a soft whoosh in the turn, faint bell partials on D."""
    L = ENGINE_LOOP
    n = dsp.samples(L)
    turn = 0.5 + 0.5 * lfo(n, L, 9)
    tone = (dsp.sine(qf(H(38), L), n) + 0.6 * dsp.sine(qf(H(45), L), n) + 0.3 * dsp.sine(qf(H(50), L), n)
            + 0.1 * dsp.sine(qf(H(38) * 2.76, L), n))
    tone *= 0.7 + 0.3 * turn
    whoosh = dsp.periodic(dsp.bandpass, dsp.pink(n, rng), 520.0, 1.0) * 0.18 * turn ** 2
    shimmer = bell_drone(n, L, H(62), rng, beat_hz=0.5, bright=0.4) * 0.03
    return move_finish(0.25 * tone + whoosh + shimmer)


# --------------------------------------------------------------------------- the Sentinel


@sound("move_sentinel", "movement", MOVE_LUFS + 1.0, loop=True, folder="movement", min_seconds=4.9,
       max_seconds=5.1)
def move_sentinel(rng: np.random.Generator) -> np.ndarray:
    """A larger Warden: a deep bell drone on G# with D above (the tritone),
    slower beating, a sub under it, heavier stone grinding, brass ticks."""
    L = 5.0
    n = dsp.samples(L)
    drone = bell_drone(n, L, H(44), rng, beat_hz=0.4) * 0.17 + bell_drone(n, L, H(50), rng, beat_hz=0.6) * 0.07
    drone *= 0.85 + 0.15 * lfo(n, L, 2)
    subhum = dsp.sine(qf(H(32), L), n) * 0.12 * (0.8 + 0.2 * lfo(n, L, 1))
    air = dsp.periodic(dsp.bandpass, dsp.pink(n, rng), 500.0, 0.6) * 0.18 * (0.7 + 0.3 * lfo(n, L, 3, 0.3))
    grind = dsp.periodic(dsp.lowpass, dsp.brown(n, rng), 140.0) * 0.18
    ticks = np.zeros(n + dsp.samples(2.0))
    for i in range(4):
        at = dsp.samples(i * L / 4 + float(rng.uniform(0, 0.4)))
        m = float(rng.choice([80.0, 86.0, 74.0]))
        dsp.place(ticks, 0.08 * bell(H(m), rng, decay=0.3, brightness=0.7, strike=0.6, length=1.6), at)
    return move_finish(drone + subhum + air + grind + dsp.wrap(ticks, n))


@sound("loop_hum_sentinel", "baseloop", -31.0, loop=True, folder="base/loops", min_seconds=5.9, max_seconds=6.1)
def loop_hum_sentinel(rng: np.random.Generator) -> np.ndarray:
    """Dormant: the Sentinel's drone alone, G# with a faint D, very slow."""
    L = 6.0
    n = dsp.samples(L)
    drone = bell_drone(n, L, H(44), rng, beat_hz=0.25, bright=0.5) * 0.2
    drone *= 0.8 + 0.2 * lfo(n, L, 1)
    tri = dsp.sine(qf(H(62), L), n) * 0.03 * (0.5 + 0.5 * lfo(n, L, 2, 0.2))
    air = dsp.periodic(dsp.bandpass, dsp.pink(n, rng), 900.0, 0.8) * 0.04 * (0.5 + 0.5 * lfo(n, L, 1, 0.5))
    return move_finish(drone + tri + air)


@sound("unit_sentinel_wake", "antecedent", -20.0, folder="units/sentinel", max_seconds=4.2, min_seconds=2.0)
def sentinel_wake(rng: np.random.Generator) -> np.ndarray:
    total = 3.8
    buf = np.zeros(dsp.samples(total + 3.0))
    dsp.place(buf, 0.7 * _grind(rng, 1.3, True), 0)
    for k, (m, at, g) in enumerate([(44, 1.1, 1.0), (50, 1.5, 0.8)]):  # G#, then D: the frame
        dsp.place(buf, g * bell(H(m), rng, decay=1.8, brightness=0.8, strike=0.8), dsp.samples(at))
    m = dsp.samples(1.8)
    u = dsp.time_axis(m) / 1.8
    lift = dsp.sine(H(56) * 2.0 ** (7.0 * u ** 0.7 / 12.0), m) + 0.5 * dsp.sine(H(62) * 2.0 ** (7.0 * u ** 0.7 / 12.0), m)
    lift *= dsp.env([(0, 0), (0.3, 0.2), (1.8, 0)], m) * 0.8
    dsp.place(buf, lift, dsp.samples(1.7))
    k = dsp.samples(0.7)
    tt = dsp.time_axis(k)
    dsp.place(buf, 0.6 * dsp.sine(48.0 * (1.0 + 0.4 * np.exp(-tt / 0.03)), k) * dsp.perc(k, 0.003, 0.2),
              dsp.samples(1.1))
    y = impact_finish(buf, rng, 30.0, dict(seconds=2.0, mix=0.22, predelay_ms=14.0, damp=0.55), -58.0, 0.4)
    return y[: dsp.samples(total)] if len(y) > dsp.samples(total) else y


def sentinel_fire(rng: np.random.Generator, v: int) -> np.ndarray:
    """A charged stone-and-light bolt: a quarter second of charge (a whine
    rising, crackle, a bell shimmer swelling), then the strike: a stone crack,
    a bright beam of light dropping onto its note, a bell clang, a sub thump."""
    root = [56, 62, 57][v]  # G#3, D4, A3
    charge = 0.26
    n = dsp.samples(1.5)
    buf = np.zeros(n)
    m = dsp.samples(charge)
    u = dsp.time_axis(m) / charge
    whine = dsp.sine(H(root + 24) * 2.0 ** (-7.0 * (1.0 - u) / 12.0), m) * u ** 2 * 0.2
    crackle = dsp.highpass(dsp.white(m, rng), 3000.0) * (rng.random(m) < 0.02) * u * 0.8
    dsp.place(buf, whine + crackle, 0)
    k = n - m
    t = dsp.time_axis(k)
    f = H(root) * (1.0 + 1.5 * np.exp(-t / 0.05))
    beam = (dsp.sine(f, k) + 0.5 * dsp.sine(f * 2.0, k) + 0.25 * dsp.sine(f * 1.414, k)) * dsp.perc(k, 0.002, 0.2)
    light = dsp.sweep(dsp.white(k, rng), "bp", 5000.0 * np.exp(-t / 0.2) + 1200.0, 4.0) * dsp.perc(k, 0.002, 0.15) * 0.4
    crack = dsp.lowpass(dsp.white(k, rng), 2500.0) * dsp.perc(k, 0.0005, 0.02) * 0.8
    ring = 0.55 * bell(H(root), rng, decay=0.5, brightness=1.0, strike=0.9, length=k / dsp.SR)
    thump = dsp.sine(50.0 * (1.0 + 0.6 * np.exp(-t / 0.025)), k) * dsp.perc(k, 0.002, 0.12) * 0.7
    dsp.place(buf, 0.5 * beam + light + crack + ring + thump, m)
    return impact_finish(buf, rng, 40.0, dict(seconds=1.0, mix=0.18, predelay_ms=8.0, damp=0.6), -58.0, 0.12)


for _v in range(3):
    sound(f"weapon_sentinel_fire_{_v + 1}", "weapon", -22.0, folder="weapons", max_seconds=1.6,
          params={"recipe": "sentinel_fire"})(lambda rng, v=_v: sentinel_fire(rng, v))


@sound("death_sentinel", "explosion", -20.0, folder="deaths", max_seconds=4.8, min_seconds=2.0)
def death_sentinel(rng: np.random.Generator) -> np.ndarray:
    """Two cracked bells (G# and D) falling in pitch, a heavy stone collapse."""
    total = 4.2
    n = dsp.samples(total)
    buf = np.zeros(n)
    t = dsp.time_axis(n)
    fall = 2.0 ** (-4.0 * np.clip(t / total, 0, 1) / 12.0)
    pos = np.cumsum(fall)
    pos = np.clip(pos - pos[0], 0, n - 1)
    for m, g, det in ((44, 1.0, 30.0), (50, 0.6, 38.0)):
        cracked = bell(H(m), rng, decay=1.4, brightness=1.0, strike=1.0, detune_cents=det, length=total)
        dsp.place(buf, g * np.interp(pos, np.arange(n), cracked), 0)
    m = dsp.samples(2.2)
    tt = dsp.time_axis(m)
    thud = dsp.sine(40.0 * (1.0 + 0.5 * np.exp(-tt / 0.05)), m) * dsp.perc(m, 0.003, 0.35)
    rubble = dsp.lowpass(dsp.brown(m, rng), 600.0) * dsp.env([(0, 0), (0.05, 0.7), (2.2, 0)], m, 2.0)
    dsp.place(buf, 0.9 * thud + 0.6 * rubble, dsp.samples(0.7))
    buf += debris(rng, n, 70, 0.75, 2.4, 600.0, 3000.0, 0.35)
    return impact_finish(buf, rng, 30.0, dict(seconds=1.8, mix=0.2, predelay_ms=12.0, damp=0.6), -60.0, 0.3)


# --------------------------------------------------------------------------- Advisor


@sound("advisor_engine_online", "advisor", ADVISOR_LUFS + 1.0, max_seconds=1.9)
def advisor_engine_online(rng: np.random.Generator) -> np.ndarray:
    """An engine is ours: a low hum swells under D+A climbing to a held, bright
    D+A with its octave: power from something very old."""
    n = dsp.samples(1.3)
    hum = (dsp.sine(H(50), n) + 0.5 * dsp.sine(H(57), n)) * dsp.env([(0, 0), (0.3, 0.5), (1.3, 0)], n, 1.5) * 0.3
    return _phrase([(0.0, 1.0, hum), (0.05, 0.85, advisor_dyad(H(62), H(69), 0.12)),
                    (0.2, 0.9, glide_dyad(H(66), H(73), 0.12, 0.0)),
                    (0.38, 1.0, advisor_dyad(H(74), H(81), 0.55)),
                    (0.42, 0.45, advisor_dyad(H(86), H(93), 0.45))], rng, 1.6)


@sound("advisor_engine_lost", "advisor", ADVISOR_LUFS + 1.0, max_seconds=1.9)
def advisor_engine_lost(rng: np.random.Generator) -> np.ndarray:
    """An engine lost: D+A sags into the planet's G#+D tritone as a low hum
    winds down under it."""
    n = dsp.samples(1.3)
    u = dsp.time_axis(n) / 1.3
    f = H(50) * 2.0 ** (-7.0 * u / 12.0)
    hum = dsp.sine(f, n) * (1.0 - u) * 0.3
    return _phrase([(0.0, 1.0, hum), (0.0, 1.0, advisor_dyad(H(74), H(81), 0.2)),
                    (0.3, 1.0, glide_dyad(H(74), H(80), 0.6, -6.0, 0.2))], rng, 1.6)


@sound("advisor_custodians_awake", "advisor", ADVISOR_LUFS + 1.0, max_seconds=1.9)
def advisor_custodians_awake(rng: np.random.Generator) -> np.ndarray:
    """The guardians wake: a struck G#+D (the Custodians' own frame, a bell in
    the ship channel), then three quick dyads climbing into the tritone."""
    b = 0.5 * bell(H(68), rng, decay=0.5, brightness=0.6, strike=0.5, length=1.0)
    b += 0.35 * bell(H(74), rng, decay=0.45, brightness=0.5, strike=0.3, length=1.0)
    parts = [(0.0, 1.0, b)]
    for k, (lo, hi) in enumerate([(64, 71), (66, 73), (68, 74)]):
        parts.append((0.45 + 0.11 * k, 0.85 + 0.05 * k, advisor_dyad(H(lo), H(hi), 0.08)))
    parts.append((0.8, 1.0, advisor_dyad(H(68), H(74), 0.45)))
    return _phrase(parts, rng, 1.6)


@sound("advisor_core_charging", "advisor", ADVISOR_LUFS, max_seconds=1.9)
def advisor_core_charging(rng: np.random.Generator) -> np.ndarray:
    """The Core gathers: three slow pulses of D+A, each a step brighter, the
    last rising into the motif's B."""
    parts = []
    for k, (lo, hi, g) in enumerate([(62, 69, 0.75), (66, 73, 0.85), (69, 76, 0.95)]):
        parts.append((0.3 * k, g, advisor_dyad(H(lo), H(hi), 0.16)))
    parts.append((0.95, 1.0, glide_dyad(H(74), H(81), 0.45, 2.0, 0.5)))
    return _phrase(parts, rng, 1.7)


@sound("advisor_core_contested", "advisor", ADVISOR_LUFS + 1.0, max_seconds=1.9)
def advisor_core_contested(rng: np.random.Generator) -> np.ndarray:
    """Someone else is at the Core: D+A and the Combine's bent Bb+F pull
    against each other, fast, twice, the last left hanging on the bent dyad."""
    parts = []
    for k in range(2):
        parts.append((0.28 * k, 1.0, advisor_dyad(H(74), H(81), 0.11)))
        parts.append((0.28 * k + 0.13, 0.95, glide_dyad(H(70), H(77), 0.11, -0.5, 0.3)))
    parts.append((0.6, 1.0, glide_dyad(H(70), H(77), 0.5, -1.0, 0.3)))
    return _phrase(parts, rng, 1.6)
