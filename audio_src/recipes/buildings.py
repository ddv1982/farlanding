"""Buildings and the economy: building identities, lifecycle, production and
harvesting.

Buildings are machines, not musicians. Where a unit answers with an
instrument phrase, a building answers with a short *machine identity*: the
sound its machinery makes, tuned into D Lydian so it never clashes. Each one
is low-key (−22 LUFS, below the unit replies) and built from a different
mechanism, so a player can tell them apart with their eyes closed:

  lander      the command ship: a broad reed fifth on D swells under a D-F#-A chime
  reactor     hums up: a D drone glides from half pitch to D2 with a whine, then throbs
  refinery    clanks: two heavy metal clanks (A, E) and a puff of steam
  flux_tap    bubbles: glassy rising bubbles on G#-B-C#-D, over a faint shimmer
  muster_bay  musters: a wooden drum triplet and a reed bugle fourth (A up to D)
  foundry     presses: a deep press thud, an anvil ring on B and a hydraulic sigh

Lifecycle and economy one-shots (group `base`) are positional and play at the
building or hauler. Loops (group `baseloop`) are seamless and positional.
"""

from __future__ import annotations

import numpy as np

from synth import dsp
from synth.instruments import chime, marimba, reed, soft_sine

from . import sound
from .movement import lfo, qf

BUILDING_LUFS = -22.0
BASE_LUFS = -23.0
ROOM = dict(seconds=0.9, mix=0.15, predelay_ms=10.0, damp=0.65)


def _finish(x: np.ndarray, rng: np.random.Generator, hp: float = 45.0, room: dict = ROOM) -> np.ndarray:
    wet = dsp.reverb(dsp.highpass(x, hp), rng, **room).mean(axis=0)
    return dsp.fade(dsp.trim_tail(dsp.dc_block(wet), -58.0), 0.001, 0.05)


def clank(rng: np.random.Generator, f: float, decay: float = 0.06, weight: float = 1.0) -> np.ndarray:
    """A struck steel plate: inharmonic partials plus a noise strike."""
    n = dsp.samples(decay * 7 + 0.05)
    x = dsp.partials(f, n, [(1.0, 1.0, decay), (2.76, 0.55, decay * 0.6), (5.4, 0.3, decay * 0.3),
                            (8.9, 0.12, decay * 0.15)], rng)
    hit = 0.5 * dsp.bandpass(dsp.white(n, rng), f * 3.0, 0.8) * dsp.perc(n, 0.0003, 0.006)
    thud = 0.6 * weight * dsp.sine(f * 0.25, n) * dsp.perc(n, 0.001, 0.03)
    return x + hit + thud


def hiss(rng: np.random.Generator, dur: float, f0: float, f1: float, q: float = 0.8) -> np.ndarray:
    """Pneumatic / steam hiss whose band sweeps from f0 to f1."""
    n = dsp.samples(dur)
    fc = f0 * (f1 / f0) ** (dsp.time_axis(n) / dur)
    return dsp.sweep(dsp.white(n, rng), "bp", fc, q) * dsp.ar(n, 0.01, dur * 0.6, dur * 0.3)


def thud(f: float, dur: float, drop: float = 0.5) -> np.ndarray:
    n = dsp.samples(dur)
    t = dsp.time_axis(n)
    return dsp.sine(f * (1.0 + drop * np.exp(-t / 0.02)), n) * dsp.perc(n, 0.002, dur * 0.3)


def _seq(parts: list[tuple[float, np.ndarray]], total: float) -> np.ndarray:
    buf = np.zeros(dsp.samples(total))
    for at, x in parts:
        dsp.place(buf, x, dsp.samples(at))
    return buf


# --------------------------------------------------------------------------- building identities


@sound("building_lander_select", "building", BUILDING_LUFS, folder="buildings", max_seconds=2.0)
def building_lander_select(rng: np.random.Generator) -> np.ndarray:
    """The Lander (HQ): home. A broad reed fifth on D swells under a slow
    D-F#-A chime, with a soft sub on D2."""
    body = reed(dsp.midi_hz(50), 0.55, rng, brightness=6.0, attack=0.12, release=0.3, breath=0.03,
                vibrato_hz=3.0, vibrato_cents=3.0)
    body = dsp.mix(body, 0.7 * reed(dsp.midi_hz(57), 0.55, rng, brightness=5.0, attack=0.14, release=0.3,
                                     breath=0.0, vibrato_hz=3.3, vibrato_cents=3.0))
    sub = 0.35 * soft_sine(dsp.midi_hz(38), 0.55, attack=0.1, release=0.3)
    bells = [(0.06 + 0.09 * i, 0.4 * chime(dsp.midi_hz(m), 0.05, rng, brightness=0.5, decay=0.3, tail=0.8))
             for i, m in enumerate([74, 78, 81])]
    return _finish(_seq([(0.0, body), (0.0, sub)] + bells, 1.8), rng, 40.0)


@sound("building_reactor_select", "building", BUILDING_LUFS, folder="buildings", max_seconds=1.8)
def building_reactor_select(rng: np.random.Generator) -> np.ndarray:
    """The Reactor hums up: a drone glides from D1 to D2 with a rising whine,
    then settles into a slow electrical throb."""
    dur = 0.9
    n = dsp.samples(dur)
    t = dsp.time_axis(n)
    rise = np.clip(t / 0.32, 0.0, 1.0) ** 0.6
    f = dsp.midi_hz(38) * (0.5 + 0.5 * rise)
    drone = dsp.wavetable(f, n, lambda k: [1.0, 0.6, 0.5, 0.25, 0.2, 0.1, 0.08][k - 1] if k <= 7 else 0.0)
    throb = 1.0 - 0.25 * (0.5 + 0.5 * np.sin(2 * np.pi * 6.0 * t)) * np.clip((t - 0.3) / 0.1, 0, 1)
    drone = dsp.lowpass(drone, 1200.0) * throb * dsp.ar(n, 0.05, 0.35, dur - 0.4)
    whine = 0.12 * dsp.sine(dsp.midi_hz(74) * (0.5 + 0.5 * rise), n) * dsp.ar(n, 0.08, 0.3, dur - 0.38)
    whine += 0.05 * dsp.sine(dsp.midi_hz(81) * (0.5 + 0.5 * rise), n) * dsp.ar(n, 0.1, 0.3, dur - 0.4)
    buzz = 0.04 * dsp.bandpass(dsp.saturate(drone * 3.0, 3.0), 2200.0, 1.2)
    return _finish(drone + whine + buzz, rng, 38.0)


@sound("building_refinery_select", "building", BUILDING_LUFS, folder="buildings", max_seconds=1.8)
def building_refinery_select(rng: np.random.Generator) -> np.ndarray:
    """The Refinery clanks: two heavy metal clanks (A then E) and a puff of steam."""
    a = clank(rng, dsp.midi_hz(57), 0.07, 1.0)
    b = clank(rng, dsp.midi_hz(52), 0.09, 1.2)
    steam = 0.16 * hiss(rng, 0.35, 5000.0, 2200.0, 0.9)
    knock = 0.5 * marimba(dsp.midi_hz(45), 0.05, rng, hardness=1.0, decay=0.12, tail=0.3)
    return _finish(_seq([(0.0, a), (0.17, b), (0.17, knock), (0.28, steam)], 1.4), rng, 50.0)


@sound("building_flux_tap_select", "building", BUILDING_LUFS, folder="buildings", max_seconds=1.8)
def building_flux_tap_select(rng: np.random.Generator) -> np.ndarray:
    """The Flux Tap bubbles: glassy rising bubbles (G#, B, C#, D) over a faint
    high shimmer, like energy welling out of a vent."""
    parts = []
    for i, (m, at) in enumerate([(80, 0.0), (83, 0.07), (85, 0.12), (86, 0.2), (92, 0.27)]):
        dur = 0.07
        n = dsp.samples(dur + 0.08)
        t = dsp.time_axis(n)
        f = dsp.midi_hz(m) * (0.8 + 0.2 * np.clip(t / dur, 0, 1) ** 0.5)
        x = dsp.fm(f, 2.0, 1.2 * dsp.perc(n, 0.002, 0.02), n) * dsp.perc(n, 0.004, 0.05 + 0.02 * i)
        parts.append((at + float(rng.uniform(0, 0.01)), 0.6 * x))
    n = dsp.samples(0.7)
    t = dsp.time_axis(n)
    shimmer = 0.06 * dsp.sine(dsp.midi_hz(92) * (1 + 0.01 * np.sin(2 * np.pi * 9 * t)), n) * dsp.ar(n, 0.1, 0.4, 0.2)
    well = 0.2 * dsp.sweep(dsp.pink(n, rng), "bp", 600.0 + 900.0 * t / 0.7, 2.0) * dsp.ar(n, 0.05, 0.35, 0.3)
    return _finish(_seq(parts + [(0.0, shimmer), (0.0, well)], 1.4), rng, 200.0,
                   dict(seconds=0.9, mix=0.22, predelay_ms=12.0, damp=0.5))


@sound("building_muster_bay_select", "building", BUILDING_LUFS, folder="buildings", max_seconds=1.8)
def building_muster_bay_select(rng: np.random.Generator) -> np.ndarray:
    """The Muster Bay musters: a wooden drum triplet on D3 and a short reed
    bugle call, A up to D."""
    def drum(accent: float) -> np.ndarray:
        n = dsp.samples(0.25)
        snare = 0.35 * dsp.bandpass(dsp.white(n, rng), 2500.0, 0.8) * dsp.perc(n, 0.0005, 0.02)
        return accent * dsp.mix(marimba(dsp.midi_hz(50), 0.03, rng, hardness=1.6, decay=0.07, tail=0.2), snare)
    bugle_a = reed(dsp.midi_hz(69), 0.08, rng, brightness=14.0, attack=0.012, release=0.05, breath=0.03,
                   vibrato_cents=0.0)
    bugle_d = reed(dsp.midi_hz(74), 0.22, rng, brightness=14.0, attack=0.015, release=0.15, breath=0.03,
                   vibrato_hz=5.5, vibrato_cents=5.0)
    parts = [(0.0, drum(0.8)), (0.07, drum(0.7)), (0.14, drum(1.0)),
             (0.28, 0.55 * bugle_a), (0.38, 0.6 * bugle_d)]
    return _finish(_seq(parts, 1.3), rng, 90.0)


@sound("building_foundry_select", "building", BUILDING_LUFS, folder="buildings", max_seconds=1.8)
def building_foundry_select(rng: np.random.Generator) -> np.ndarray:
    """The Foundry presses: a deep press thud, an anvil ring on B and a
    hydraulic sigh as the press lifts."""
    press = 0.9 * thud(55.0, 0.35, 0.7)
    n = dsp.samples(0.9)
    anvil = dsp.partials(dsp.midi_hz(59), n, [(1.0, 0.6, 0.25), (2.4, 0.5, 0.18), (3.9, 0.35, 0.1),
                                              (6.1, 0.15, 0.05)], rng)
    anvil += 0.4 * dsp.bandpass(dsp.white(n, rng), 3000.0, 1.0) * dsp.perc(n, 0.0003, 0.005)
    sigh = 0.14 * hiss(rng, 0.4, 1800.0, 700.0, 1.2)
    return _finish(_seq([(0.0, press), (0.005, 0.7 * anvil), (0.32, sigh)], 1.5), rng, 40.0)


# --------------------------------------------------------------------------- lifecycle one-shots


@sound("base_place", "base", BASE_LUFS, max_seconds=1.2)
def base_place(rng: np.random.Generator) -> np.ndarray:
    """Placement confirmed: a foundation drops (thud, dust) and a quick chime
    fourth A-D says 'here'."""
    n = dsp.samples(0.4)
    dust = 0.25 * dsp.lowpass(dsp.pink(n, rng), 1500.0) * dsp.perc(n, 0.004, 0.08)
    a = 0.5 * chime(dsp.midi_hz(69), 0.04, rng, brightness=0.6, decay=0.08, tail=0.3)
    d = 0.55 * chime(dsp.midi_hz(74), 0.05, rng, brightness=0.6, decay=0.18, tail=0.5)
    return _finish(_seq([(0.0, thud(70.0, 0.3, 0.6)), (0.0, dust), (0.05, a), (0.12, d)], 1.0), rng, 45.0)


@sound("base_complete", "base", BASE_LUFS + 1.0, max_seconds=2.0)
def base_complete(rng: np.random.Generator) -> np.ndarray:
    """Construction complete: scaffolds retract (a falling clank pair), the
    machine powers on (a settling clunk) and a marimba-and-chime arpeggio
    D-F#-A-D rises to a held A-D shimmer."""
    parts = [(0.0, 0.4 * clank(rng, 880.0, 0.03, 0.2)), (0.06, 0.35 * clank(rng, 660.0, 0.03, 0.2)),
             (0.12, 0.8 * thud(62.0, 0.3, 0.4))]
    for i, m in enumerate([74, 78, 81, 86]):
        last = i == 3
        wood = 0.6 * marimba(dsp.midi_hz(m), 0.04, rng, hardness=0.9, decay=0.2 if last else 0.08, tail=0.4)
        bell = 0.45 * chime(dsp.midi_hz(m), 0.05, rng, brightness=0.6, decay=0.45 if last else 0.12, tail=0.9)
        parts += [(0.16 + 0.06 * i, wood), (0.16 + 0.06 * i, bell)]
    n = dsp.samples(0.8)
    held = (dsp.sine(dsp.midi_hz(81), n) + 0.7 * dsp.sine(dsp.midi_hz(86), n)) * 0.08 * dsp.ar(n, 0.08, 0.5, 0.2)
    parts.append((0.36, held))
    return _finish(_seq(parts, 1.8), rng, 50.0, dict(seconds=1.1, mix=0.18, predelay_ms=12.0, damp=0.6))


@sound("base_unit_ready", "base", BASE_LUFS, max_seconds=1.4)
def base_unit_ready(rng: np.random.Generator) -> np.ndarray:
    """A unit rolls out: the bay hatch unlocks (clunk), vents (hiss) and a
    two-note chime A-E rings the door open."""
    parts = [(0.0, 0.7 * clank(rng, 330.0, 0.04, 0.8)), (0.05, 0.22 * hiss(rng, 0.45, 3500.0, 1200.0)),
             (0.18, 0.45 * chime(dsp.midi_hz(81), 0.04, rng, brightness=0.5, decay=0.08, tail=0.3)),
             (0.27, 0.5 * chime(dsp.midi_hz(88), 0.05, rng, brightness=0.5, decay=0.2, tail=0.5))]
    return _finish(_seq(parts, 1.2), rng, 60.0)


@sound("base_unload", "base", BASE_LUFS, max_seconds=1.6)
def base_unload(rng: np.random.Generator) -> np.ndarray:
    """A Hauler unloads ore: the hopper tips (a chute clank), ore pours as a
    dense rattle that thins out, and a small marimba E 'receipt' tick."""
    dur = 0.8
    n = dsp.samples(dur + 0.1)
    pour = np.zeros(n)
    density = 160
    for _ in range(density):
        u = float(rng.random()) ** 1.6  # denser at the start
        at = int(u * dsp.samples(dur))
        m = dsp.samples(0.03)
        r = dsp.bandpass(dsp.white(m, rng), float(rng.uniform(700, 3800)), 3.0) * dsp.perc(m, 0.0004, 0.004)
        dsp.place(pour, r * float(rng.uniform(0.2, 0.6)) * (1.0 - 0.6 * u), at)
    rumble = 0.3 * dsp.lowpass(dsp.brown(n, rng), 250.0) * dsp.ar(n, 0.02, 0.4, 0.3)
    tick = 0.45 * marimba(dsp.midi_hz(76), 0.03, rng, hardness=0.8, decay=0.1, tail=0.3)
    parts = [(0.0, 0.6 * clank(rng, 196.0, 0.06, 0.8)), (0.03, pour + rumble), (0.85, tick)]
    return _finish(_seq(parts, 1.4), rng, 60.0)


@sound("base_depleted", "base", BASE_LUFS, max_seconds=1.6)
def base_depleted(rng: np.random.Generator) -> np.ndarray:
    """A deposit runs out: the last rock crumbles hollow and thins away, and a
    dull marimba falls B-F#-D."""
    dur = 0.6
    n = dsp.samples(dur + 0.1)
    crumble = np.zeros(n)
    for _ in range(50):
        u = float(rng.random())
        at = int(u * dsp.samples(dur))
        m = dsp.samples(0.04)
        r = dsp.lowpass(dsp.white(m, rng), float(rng.uniform(600, 1500))) * dsp.perc(m, 0.001, 0.008)
        dsp.place(crumble, r * float(rng.uniform(0.3, 0.8)) * (1.0 - u) ** 1.5, at)
    parts = [(0.0, crumble), (0.0, 0.5 * thud(90.0, 0.25, 0.3))]
    for i, m in enumerate([71, 66, 62]):
        parts.append((0.15 + 0.16 * i, 0.55 * marimba(dsp.midi_hz(m), 0.05, rng, hardness=0.4,
                                                      decay=0.25 if i == 2 else 0.1, tail=0.4)))
    return _finish(_seq(parts, 1.4), rng, 60.0)


# --------------------------------------------------------------------------- positional loops
# Seamless by construction, as in movement.py: whole-cycle oscillators,
# periodic filters, events folded back over the loop point with dsp.wrap.


def _loop_finish(x: np.ndarray) -> np.ndarray:
    x = dsp.periodic(dsp.highpass, x, 40.0)
    return x - x.mean()


@sound("loop_construct", "baseloop", -25.0, folder="base/loops", loop=True, min_seconds=3.9, max_seconds=4.1)
def loop_construct(rng: np.random.Generator) -> np.ndarray:
    """Construction site: a hammer every second, ratcheting tool taps, welding
    crackle and servo arms swinging, over a low generator."""
    L = 4.0
    n = dsp.samples(L)
    buf = np.zeros(n + dsp.samples(1.0))
    for i in range(4):  # hammer, alternating two pitches
        dsp.place(buf, 0.5 * clank(rng, 520.0 if i % 2 == 0 else 470.0, 0.035, 0.6),
                  dsp.samples(i * 1.0 + float(rng.uniform(0, 0.01))))
    for i in range(10):  # ratchet bursts: 4 quick ticks each
        at = float(rng.uniform(0, L))
        for k in range(4):
            m = dsp.samples(0.02)
            t = dsp.bandpass(dsp.white(m, rng), 4200.0, 4.0) * dsp.perc(m, 0.0002, 0.002)
            dsp.place(buf, 0.25 * t, dsp.samples(at + k * 0.028))
    for at, up in [(0.55, True), (2.3, False)]:  # servo arm
        m = dsp.samples(0.35)
        u = dsp.time_axis(m) / 0.35
        f = 420.0 * (1.4 ** (u if up else 1.0 - u))
        x = dsp.wavetable(f, m, lambda k: [1.0, 0.4, 0.25][k - 1] if k <= 3 else 0.0)
        dsp.place(buf, 0.09 * x * dsp.ar(m, 0.05, 0.1, 0.2), dsp.samples(at))
    crackle_env = np.clip(0.5 + 0.5 * dsp.smooth_random(n, rng, 2.0), 0, 1) ** 2
    crackle = dsp.periodic(dsp.highpass, dsp.white(n, rng) * (rng.random(n) < 0.02), 3000.0) * 0.6 * crackle_env
    gen = dsp.wavetable(qf(73.5, L), n, lambda k: [1.0, 0.5, 0.3, 0.2][k - 1] if k <= 4 else 0.0)
    gen = dsp.periodic(dsp.lowpass, gen, 500.0) * 0.12
    return _loop_finish(dsp.wrap(buf, n) + crackle + gen)


@sound("loop_produce", "baseloop", -29.0, folder="base/loops", loop=True, min_seconds=3.9, max_seconds=4.1)
def loop_produce(rng: np.random.Generator) -> np.ndarray:
    """A producer at work, subtle: a low machine hum on D, a conveyor whir and
    a soft press cycle every two seconds."""
    L = 4.0
    n = dsp.samples(L)
    hum = dsp.wavetable(qf(73.5, L), n, lambda k: [1.0, 0.35, 0.3, 0.1, 0.12][k - 1] if k <= 5 else 0.0) * 0.25
    whir = dsp.periodic(dsp.bandpass, dsp.pink(n, rng), 1300.0, 2.5) * 0.25 * (0.75 + 0.25 * lfo(n, L, 8))
    buf = np.zeros(n + dsp.samples(1.0))
    for i in range(2):
        dsp.place(buf, 0.3 * thud(80.0, 0.2, 0.3), dsp.samples(i * 2.0 + 0.4))
        dsp.place(buf, 0.06 * hiss(rng, 0.4, 2500.0, 1200.0), dsp.samples(i * 2.0 + 0.6))
    return _loop_finish(hum + whir + dsp.wrap(buf, n))


@sound("loop_mine", "baseloop", -26.0, folder="base/loops", loop=True, min_seconds=2.9, max_seconds=3.1)
def loop_mine(rng: np.random.Generator) -> np.ndarray:
    """A Hauler mining at a deposit: a rotating drill grind, its motor and
    rock chips cracking off."""
    L = 3.0
    n = dsp.samples(L)
    rot = 0.6 + 0.4 * (0.5 + 0.5 * lfo(n, L, 33))  # 11 Hz drill rotation
    grind = dsp.periodic(dsp.bandpass, dsp.pink(n, rng), 1600.0, 0.9) * 0.5 * rot
    motor = dsp.wavetable(qf(110.0, L), n, lambda k: [1.0, 0.5, 0.35, 0.2, 0.15][k - 1] if k <= 5 else 0.0)
    motor = dsp.periodic(dsp.lowpass, motor, 1200.0) * 0.18 * (1.0 + 0.04 * lfo(n, L, 2))
    chips = np.zeros(n + dsp.samples(0.2))
    for _ in range(22):
        at = int(rng.integers(0, n))
        m = dsp.samples(0.05)
        c = dsp.bandpass(dsp.white(m, rng), float(rng.uniform(1200, 3500)), 2.0) * dsp.perc(m, 0.0004, 0.006)
        c += 0.4 * dsp.lowpass(dsp.white(m, rng), 400.0) * dsp.perc(m, 0.001, 0.01)
        dsp.place(chips, c * float(rng.uniform(0.2, 0.6)), at)
    return _loop_finish(grind + motor + dsp.wrap(chips, n))


@sound("loop_hum", "baseloop", -33.0, folder="base/loops", loop=True, min_seconds=5.9, max_seconds=6.1)
def loop_hum(rng: np.random.Generator) -> np.ndarray:
    """An operational building at rest: mains hum on D2 with its harmonics, a
    faint transformer buzz and ventilation air, breathing slowly."""
    L = 6.0
    n = dsp.samples(L)
    breathe = 1.0 + 0.08 * lfo(n, L, 1) + 0.04 * lfo(n, L, 3, 0.3)
    hum = dsp.wavetable(qf(73.5, L), n, lambda k: [1.0, 0.6, 0.45, 0.15, 0.2][k - 1] if k <= 5 else 0.0)
    hum = hum * 0.3 * breathe
    buzz = dsp.periodic(dsp.bandpass, dsp.saturate(dsp.sine(qf(147.0, L), n) * 4.0, 4.0), 1800.0, 1.0) * 0.03
    air = dsp.periodic(dsp.lowpass, dsp.pink(n, rng), 900.0) * 0.18 * (1.0 + 0.1 * lfo(n, L, 2, 0.6))
    return _loop_finish(hum + buzz + air)
