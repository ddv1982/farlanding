"""Planet ambience beds. Stereo, long, seamless loops (Ogg)."""

from __future__ import annotations

import numpy as np

from synth import dsp

from . import sound


def _decorrelated(n: int, rng: np.random.Generator, maker, shared: float) -> np.ndarray:
    """Stereo noise: `shared` of the signal is common to both channels."""
    common = maker(n, rng)
    return np.stack([shared * common + (1 - shared) * maker(n, rng) for _ in range(2)])


@sound("amb_kessel_wind", "ambience", -30.0, fmt="ogg", channels=2, loop=True,
       min_seconds=47.9, max_seconds=48.1)
def amb_kessel_wind(rng: np.random.Generator) -> np.ndarray:
    """Kessel Reach: a dry dust basin. A low steady wind, gusts that move
    across the stereo field, fine sand hiss that rises with each gust, and a
    faint whistle where the wind catches rock edges."""
    L = 48.0
    n = dsp.samples(L)
    gust = 0.5 + 0.5 * dsp.smooth_random(n, rng, 0.09)  # 0..1, slow
    gust = gust ** 1.4
    drift = dsp.smooth_random(n, rng, 0.04)  # -1..1, slower: where the gust sits

    low = _decorrelated(n, rng, dsp.brown, 0.6)
    low = dsp.periodic(dsp.lowpass, low, 220.0, 0.6) * (0.55 + 0.25 * gust)

    mid = _decorrelated(n, rng, dsp.pink, 0.3)
    centre = 380.0 + 650.0 * gust
    mid = dsp.periodic(dsp.sweep, mid, "bp", centre, 0.9, block=256) * (0.15 + 0.6 * gust)
    mid = np.stack([mid[0] * (1.0 - 0.35 * drift), mid[1] * (1.0 + 0.35 * drift)])

    dust = _decorrelated(n, rng, dsp.white, 0.2)
    dust = dsp.periodic(dsp.highpass, dust, 4500.0)
    dust = dsp.periodic(dsp.lowpass, dust, 11000.0) * 0.05 * gust ** 2

    grains = np.zeros((2, n + dsp.samples(0.05)))
    count = int(L * 24)
    weights = gust / gust.sum()
    for at in rng.choice(n, size=count, p=weights):
        m = dsp.samples(0.006)
        g = dsp.bandpass(dsp.white(m, rng), float(rng.uniform(3000, 7000)), 3.0) * dsp.perc(m, 0.0002, 0.0012)
        dsp.place(grains, dsp.pan(g * float(rng.uniform(0.02, 0.07)), float(rng.uniform(-0.9, 0.9))), int(at))
    grains = dsp.wrap(grains, n)

    whistle = np.zeros((2, n))
    for base, side, cyc in [(1250.0, -0.5, 3), (1870.0, 0.45, 2)]:
        src = dsp.pink(n, rng)
        f = base * (1.0 + 0.04 * np.sin(2 * np.pi * cyc * dsp.time_axis(n) / L))
        tone = dsp.periodic(dsp.sweep, src, "bp", f, 28.0, block=256)
        level = np.clip((gust - 0.45) / 0.55, 0.0, 1.0) ** 2 * 0.12
        whistle += dsp.pan(tone * level, side)

    x = low + mid + dust + grains + whistle
    x = dsp.periodic(dsp.highpass, x, 28.0)
    return x - x.mean(axis=1, keepdims=True)
