"""Loudness (ITU-R BS.1770), true peak, limiting, normalisation and the
automated checks the build runs on every rendered file."""

from __future__ import annotations

import numpy as np
from scipy import ndimage
from scipy import signal as sps

from .dsp import SR, db, to_db


# --------------------------------------------------------------------------- loudness


def _k_weighting() -> np.ndarray:
    """BS.1770 K-weighting (pre-filter shelf + RLB high-pass) for SR."""
    # Stage 1: high shelf.
    f0, g, q = 1681.974450955533, 3.999843853973347, 0.7071752369554196
    k = np.tan(np.pi * f0 / SR)
    vh, vb = 10 ** (g / 20.0), 10 ** (g / 20.0) ** 0.4996667741545416
    a0 = 1.0 + k / q + k * k
    b1 = [(vh + vb * k / q + k * k) / a0, 2.0 * (k * k - vh) / a0, (vh - vb * k / q + k * k) / a0]
    a1 = [1.0, 2.0 * (k * k - 1.0) / a0, (1.0 - k / q + k * k) / a0]
    # Stage 2: high-pass.
    f0, q = 38.13547087602444, 0.5003270373238773
    k = np.tan(np.pi * f0 / SR)
    a0 = 1.0 + k / q + k * k
    b2 = [1.0, -2.0, 1.0]
    a2 = [1.0, 2.0 * (k * k - 1.0) / a0, (1.0 - k / q + k * k) / a0]
    return np.array([b1 + a1, b2 + a2])


_K = _k_weighting()


def lufs(x: np.ndarray) -> float:
    """Integrated loudness in LUFS (gated). Sounds shorter than one 400 ms block
    are measured as a single block over their whole length."""
    x = np.atleast_2d(x)
    y = sps.sosfilt(_K, x, axis=-1)
    n = y.shape[-1]
    block = int(0.4 * SR)
    if n <= block:
        ms = np.sum(np.mean(y ** 2, axis=-1))
        return float(-0.691 + 10.0 * np.log10(ms + 1e-20))
    hop = block // 4
    starts = range(0, n - block + 1, hop)
    powers = np.array([np.sum(np.mean(y[:, s:s + block] ** 2, axis=-1)) for s in starts])
    loud = -0.691 + 10.0 * np.log10(powers + 1e-20)
    gated = powers[loud > -70.0]
    if len(gated) == 0:
        return -120.0
    rel = -0.691 + 10.0 * np.log10(np.mean(gated)) - 10.0
    gated = powers[(loud > -70.0) & (loud > rel)]
    return float(-0.691 + 10.0 * np.log10(np.mean(gated) + 1e-20))


def true_peak(x: np.ndarray) -> float:
    """Peak in dBTP, estimated with 4x oversampling."""
    up = sps.resample_poly(np.atleast_2d(x), 4, 1, axis=-1)
    return to_db(float(np.max(np.abs(up))))


def sample_peak(x: np.ndarray) -> float:
    return to_db(float(np.max(np.abs(x))))


# --------------------------------------------------------------------------- dynamics


def limit(x: np.ndarray, ceiling_db: float = -1.5, window_ms: float = 4.0, circular: bool = False) -> np.ndarray:
    """Transparent look-ahead peak limiter (offline). The gain curve is the
    minimum required gain held over a window, then smoothed, so it never lets a
    peak through and never pumps faster than the window."""
    ceiling = db(ceiling_db)
    mono = np.abs(np.atleast_2d(x)).max(axis=0)
    need = np.minimum(1.0, ceiling / np.maximum(mono, 1e-12))
    w = max(int(window_ms * SR / 1000.0), 3)
    mode = "wrap" if circular else "nearest"
    g = ndimage.minimum_filter1d(need, size=2 * w + 1, mode=mode)
    g = ndimage.uniform_filter1d(g, size=w, mode=mode)
    g = np.minimum(g, need)
    return x * g


def normalize(x: np.ndarray, target_lufs: float, ceiling_dbtp: float = -1.0, circular: bool = False) -> np.ndarray:
    """Gain to the loudness target; limits peaks if the target would push them
    past the ceiling, then re-applies the gain (a few passes converge)."""
    y = x
    for _ in range(4):
        y = y * db(target_lufs - lufs(y))
        if true_peak(y) <= ceiling_dbtp:
            return y
        y = limit(y, ceiling_dbtp - 0.6, circular=circular)
    return y * db(target_lufs - lufs(y))


# --------------------------------------------------------------------------- checks


def dc_offset(x: np.ndarray) -> float:
    return float(np.max(np.abs(np.atleast_2d(x).mean(axis=-1))))


CLICK_FLOOR = 0.002


def seam(x: np.ndarray) -> dict:
    """How well a loop joins its end to its start, judged against the signal
    itself so that busy and quiet material are held to the same standard.

    jump: the step from the last sample to the first, divided by the largest
      step in the 20 ms either side of the seam. <= 1 means no click. Steps below
      CLICK_FLOOR (-54 dBFS) count as the floor: in near-silence the codec's own
      noise would otherwise dominate the ratio.
    curve: the same for the second difference (a kink in the waveform).
    level_db: loudness change across the seam (50 ms windows) minus the largest
      change between any two other neighbouring windows. <= 0 means the seam is
      no more abrupt than the most abrupt moment inside the loop (a downbeat
      after a rest is fine; a jump in a steady bed is not).
    """
    x = np.atleast_2d(x)
    w = int(0.02 * SR)
    joined = np.concatenate([x[:, -w:], x[:, :w]], axis=-1)
    d1 = np.abs(np.diff(joined, axis=-1))
    d2 = np.abs(np.diff(joined, 2, axis=-1))
    seam1 = d1[:, w - 1]
    seam2 = np.maximum(d2[:, w - 2], d2[:, w - 1])
    rest1 = np.maximum(np.delete(d1, w - 1, axis=-1).max(axis=-1), CLICK_FLOOR)
    rest2 = np.maximum(np.delete(d2, [w - 2, w - 1], axis=-1).max(axis=-1), CLICK_FLOOR)
    win = int(0.05 * SR)
    usable = (x.shape[-1] // win) * win
    rms = np.sqrt(np.mean(x[:, :usable].reshape(x.shape[0], -1, win) ** 2, axis=(0, 2))) + 1e-12
    steps = np.abs(np.diff(20.0 * np.log10(rms)))
    head = np.sqrt(np.mean(x[:, :win] ** 2)) + 1e-12
    tail = np.sqrt(np.mean(x[:, -win:] ** 2)) + 1e-12
    across = abs(to_db(float(head / tail)))
    return {
        "jump": float(np.max(seam1 / rest1)),
        "curve": float(np.max(seam2 / rest2)),
        "level_db": float(across - np.max(steps)),
    }


def spectrum(x: np.ndarray) -> dict:
    """Spectral centroid and the share of energy below 25 Hz / above 16 kHz."""
    mono = np.atleast_2d(x).mean(axis=0)
    p = np.abs(np.fft.rfft(mono * np.hanning(len(mono)))) ** 2
    f = np.fft.rfftfreq(len(mono), 1.0 / SR)
    total = float(np.sum(p)) + 1e-20
    return {
        "centroid_hz": float(np.sum(f * p) / total),
        "sub_ratio": float(np.sum(p[f < 25.0]) / total),
        "air_ratio": float(np.sum(p[f > 16000.0]) / total),
    }
