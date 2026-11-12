"""Core DSP building blocks: oscillators, noise, envelopes, filters, effects.

Every function works on float64 numpy arrays at SR. Mono signals are 1-D arrays;
stereo signals are arrays of shape (2, n). Randomness always comes from a
numpy Generator passed in by the caller, so a recipe with a fixed seed renders
the same samples on every run.
"""

from __future__ import annotations

import numpy as np
from scipy import signal as sps

SR = 44100
NYQUIST = SR / 2


# --------------------------------------------------------------------------- time


def samples(seconds: float) -> int:
    return int(round(seconds * SR))


def time_axis(n: int) -> np.ndarray:
    return np.arange(n) / SR


def db(value_db: float) -> float:
    """Decibels to linear gain."""
    return float(10.0 ** (value_db / 20.0))


def to_db(gain: float) -> float:
    return float(20.0 * np.log10(max(gain, 1e-12)))


def midi_hz(note: float) -> float:
    return float(440.0 * 2.0 ** ((note - 69.0) / 12.0))


def cents(c: float) -> float:
    return float(2.0 ** (c / 1200.0))


# --------------------------------------------------------------------------- oscillators


def phase(freq: np.ndarray | float, n: int, start: float = 0.0) -> np.ndarray:
    """Running phase in cycles for a (possibly time-varying) frequency."""
    f = np.broadcast_to(np.asarray(freq, dtype=np.float64), (n,))
    ph = np.cumsum(f) / SR
    return ph - ph[0] + start


def sine(freq: np.ndarray | float, n: int, start: float = 0.0) -> np.ndarray:
    return np.sin(2.0 * np.pi * phase(freq, n, start))


_TABLE_SIZE = 4096


def harmonic_table(amps: list[float] | np.ndarray, phases: np.ndarray | None = None) -> np.ndarray:
    """One cycle of a waveform with the given harmonic amplitudes (1-based)."""
    x = np.arange(_TABLE_SIZE) / _TABLE_SIZE
    table = np.zeros(_TABLE_SIZE)
    for k, a in enumerate(amps, start=1):
        if a != 0.0:
            p = 0.0 if phases is None else phases[k - 1]
            table += a * np.sin(2.0 * np.pi * (k * x + p))
    return table


def wavetable(freq: np.ndarray | float, n: int, amps_fn, start: float = 0.0) -> np.ndarray:
    """Band-limited harmonic oscillator.

    `amps_fn(k)` gives the amplitude of harmonic k (k = 1, 2, ...). Harmonics above
    Nyquist for the highest frequency used are dropped, so nothing aliases.
    """
    f = np.broadcast_to(np.asarray(freq, dtype=np.float64), (n,))
    top = max(int(NYQUIST * 0.92 / max(float(f.max()), 1.0)), 1)
    amps = [float(amps_fn(k)) for k in range(1, top + 1)]
    table = harmonic_table(amps)
    ph = phase(f, n, start) % 1.0
    idx = ph * _TABLE_SIZE
    i0 = idx.astype(np.int64)
    frac = idx - i0
    return table[i0] * (1.0 - frac) + table[(i0 + 1) % _TABLE_SIZE] * frac


def warm_saw(freq: np.ndarray | float, n: int, brightness: float = 8.0, start: float = 0.0) -> np.ndarray:
    """Saw with an exponential harmonic roll-off: warm, never buzzy."""
    return wavetable(freq, n, lambda k: (1.0 / k) * np.exp(-(k - 1) / brightness), start)


def soft_square(freq: np.ndarray | float, n: int, brightness: float = 6.0, start: float = 0.0) -> np.ndarray:
    return wavetable(
        freq, n, lambda k: (1.0 / k if k % 2 else 0.0) * np.exp(-(k - 1) / brightness), start
    )


def fm(carrier: np.ndarray | float, ratio: float, index: np.ndarray | float, n: int,
       feedback_ratio: float | None = None) -> np.ndarray:
    """Two-operator FM (phase modulation). `index` may be an envelope array."""
    c = np.broadcast_to(np.asarray(carrier, dtype=np.float64), (n,))
    mod = sine(c * ratio, n)
    return np.sin(2.0 * np.pi * phase(c, n) + np.asarray(index) * mod)


def partials(freq: float, n: int, spec: list[tuple[float, float, float]], rng: np.random.Generator | None = None) -> np.ndarray:
    """Inharmonic additive voice. spec = [(ratio, amplitude, decay_seconds), ...]."""
    t = time_axis(n)
    out = np.zeros(n)
    for ratio, amp, decay in spec:
        f = freq * ratio
        if f >= NYQUIST * 0.95:
            continue
        p0 = 0.0 if rng is None else float(rng.random())
        out += amp * np.exp(-t / decay) * np.sin(2.0 * np.pi * (f * t + p0))
    return out


# --------------------------------------------------------------------------- noise


def white(n: int, rng: np.random.Generator) -> np.ndarray:
    return rng.standard_normal(n)


def colored(n: int, rng: np.random.Generator, slope_db_per_oct: float) -> np.ndarray:
    """Noise with a spectral slope (0 white, -3 pink, -6 brown). Inherently
    circular: the result loops seamlessly at length n."""
    spec = np.fft.rfft(rng.standard_normal(n))
    f = np.fft.rfftfreq(n, 1.0 / SR)
    f[0] = f[1]
    spec *= (f / 1000.0) ** (slope_db_per_oct / (20.0 * np.log10(2.0)))
    spec[0] = 0.0
    x = np.fft.irfft(spec, n)
    return x / (np.std(x) + 1e-12)


def pink(n: int, rng: np.random.Generator) -> np.ndarray:
    return colored(n, rng, -3.0)


def brown(n: int, rng: np.random.Generator) -> np.ndarray:
    return colored(n, rng, -6.0)


def smooth_random(n: int, rng: np.random.Generator, rate_hz: float, periodic: bool = True) -> np.ndarray:
    """Slowly wandering control signal in [-1, 1] (band-limited noise)."""
    spec = np.fft.rfft(rng.standard_normal(n))
    f = np.fft.rfftfreq(n, 1.0 / SR)
    spec *= np.exp(-((f / rate_hz) ** 2))
    spec[0] = 0.0
    x = np.fft.irfft(spec, n)
    return x / (np.max(np.abs(x)) + 1e-12)


# --------------------------------------------------------------------------- envelopes


def env(points: list[tuple[float, float]], n: int, curve: float = 0.0) -> np.ndarray:
    """Breakpoint envelope. points = [(time_s, level), ...]. `curve` > 0 bends
    segments exponentially (fast start, slow end), < 0 the other way."""
    t = time_axis(n)
    ts = np.array([p[0] for p in points])
    vs = np.array([p[1] for p in points])
    if curve == 0.0:
        return np.interp(t, ts, vs)
    out = np.empty(n)
    out[t <= ts[0]] = vs[0]
    out[t >= ts[-1]] = vs[-1]
    for i in range(len(ts) - 1):
        m = (t >= ts[i]) & (t < ts[i + 1])
        u = (t[m] - ts[i]) / max(ts[i + 1] - ts[i], 1e-9)
        shaped = (1.0 - np.exp(-curve * u)) / (1.0 - np.exp(-curve))
        out[m] = vs[i] + (vs[i + 1] - vs[i]) * shaped
    return out


def perc(n: int, attack: float, decay: float, hold: float = 0.0) -> np.ndarray:
    """Percussive envelope: linear-ish attack, exponential decay (time constant)."""
    t = time_axis(n)
    a = np.clip(t / max(attack, 1e-5), 0.0, 1.0)
    a = np.sin(a * np.pi / 2.0) ** 2
    d = np.exp(-np.maximum(t - attack - hold, 0.0) / decay)
    return a * d


def ar(n: int, attack: float, release: float, sustain: float) -> np.ndarray:
    """Attack / sustain / release with raised-cosine edges, for pads and loops."""
    t = time_axis(n)
    up = np.clip(t / max(attack, 1e-5), 0.0, 1.0)
    down = np.clip((attack + sustain + release - t) / max(release, 1e-5), 0.0, 1.0)
    return (0.5 - 0.5 * np.cos(np.pi * up)) * (0.5 - 0.5 * np.cos(np.pi * down))


# --------------------------------------------------------------------------- filters


def _sos(kind: str, fc: float, q: float = 0.707, gain_db: float = 0.0) -> np.ndarray:
    """RBJ biquad as a second-order section."""
    fc = float(np.clip(fc, 10.0, NYQUIST * 0.98))
    w0 = 2.0 * np.pi * fc / SR
    cw, sw = np.cos(w0), np.sin(w0)
    alpha = sw / (2.0 * q)
    A = 10.0 ** (gain_db / 40.0)
    if kind == "lp":
        b = [(1 - cw) / 2, 1 - cw, (1 - cw) / 2]
        a = [1 + alpha, -2 * cw, 1 - alpha]
    elif kind == "hp":
        b = [(1 + cw) / 2, -(1 + cw), (1 + cw) / 2]
        a = [1 + alpha, -2 * cw, 1 - alpha]
    elif kind == "bp":
        b = [alpha, 0.0, -alpha]
        a = [1 + alpha, -2 * cw, 1 - alpha]
    elif kind == "peak":
        b = [1 + alpha * A, -2 * cw, 1 - alpha * A]
        a = [1 + alpha / A, -2 * cw, 1 - alpha / A]
    elif kind == "lowshelf":
        sa = 2 * np.sqrt(A) * alpha
        b = [A * ((A + 1) - (A - 1) * cw + sa), 2 * A * ((A - 1) - (A + 1) * cw), A * ((A + 1) - (A - 1) * cw - sa)]
        a = [(A + 1) + (A - 1) * cw + sa, -2 * ((A - 1) + (A + 1) * cw), (A + 1) + (A - 1) * cw - sa]
    elif kind == "highshelf":
        sa = 2 * np.sqrt(A) * alpha
        b = [A * ((A + 1) + (A - 1) * cw + sa), -2 * A * ((A - 1) + (A + 1) * cw), A * ((A + 1) + (A - 1) * cw - sa)]
        a = [(A + 1) - (A - 1) * cw + sa, 2 * ((A - 1) - (A + 1) * cw), (A + 1) - (A - 1) * cw - sa]
    else:
        raise ValueError(kind)
    b = np.array(b) / a[0]
    a = np.array(a) / a[0]
    return np.concatenate([b, a])[None, :]


def biquad(x: np.ndarray, kind: str, fc: float, q: float = 0.707, gain_db: float = 0.0) -> np.ndarray:
    return sps.sosfilt(_sos(kind, fc, q, gain_db), x, axis=-1)


def lowpass(x: np.ndarray, fc: float, q: float = 0.707) -> np.ndarray:
    return biquad(x, "lp", fc, q)


def highpass(x: np.ndarray, fc: float, q: float = 0.707) -> np.ndarray:
    return biquad(x, "hp", fc, q)


def bandpass(x: np.ndarray, fc: float, q: float = 1.0) -> np.ndarray:
    return biquad(x, "bp", fc, q)


def sweep(x: np.ndarray, kind: str, fc: np.ndarray, q: float = 0.707, block: int = 64) -> np.ndarray:
    """Time-varying biquad: coefficients follow `fc` (an array), updated per block.
    Works on mono or stereo input."""
    x = np.asarray(x)
    out = np.empty_like(x)
    lead = x.shape[:-1]
    zi = np.zeros(lead + (1, 2)) if lead else np.zeros((1, 2))
    n = x.shape[-1]
    for s in range(0, n, block):
        e = min(s + block, n)
        sos = _sos(kind, float(fc[min(s + block // 2, n - 1)]), q)
        if lead:
            for c in range(lead[0]):
                out[c, s:e], zi[c] = sps.sosfilt(sos, x[c, s:e], zi=zi[c])
        else:
            out[s:e], zi = sps.sosfilt(sos, x[s:e], zi=zi)
    return out


def periodic(fn, x: np.ndarray, *args, **kwargs) -> np.ndarray:
    """Applies a causal process (filter, sweep) to a looping signal so that its
    output loops too: runs it over three repeats and keeps the middle one."""
    n = x.shape[-1]
    tiled = np.concatenate([x, x, x], axis=-1)
    extra = [np.concatenate([a, a, a], axis=-1) if isinstance(a, np.ndarray) and a.shape[-1] == n else a for a in args]
    return fn(tiled, *extra, **kwargs)[..., n:2 * n]


def dc_block(x: np.ndarray, fc: float = 18.0) -> np.ndarray:
    return sps.sosfilt(sps.butter(2, fc, "hp", fs=SR, output="sos"), x, axis=-1)


# --------------------------------------------------------------------------- shaping & space


def saturate(x: np.ndarray, drive: float = 1.0) -> np.ndarray:
    """Soft tanh saturation, level-compensated for small signals."""
    if drive <= 0:
        return x
    return np.tanh(x * drive) / np.tanh(drive)


def pan(x: np.ndarray, position: float | np.ndarray) -> np.ndarray:
    """Equal-power pan of a mono signal; position -1 (left) .. +1 (right)."""
    p = (np.asarray(position) + 1.0) * np.pi / 4.0
    return np.stack([x * np.cos(p), x * np.sin(p)])


def stereo(x: np.ndarray) -> np.ndarray:
    return x if x.ndim == 2 else np.stack([x, x])


def fractional_delay(x: np.ndarray, delay_samples: np.ndarray) -> np.ndarray:
    """Reads x at (n - delay) with linear interpolation; delay may vary per sample."""
    n = x.shape[-1]
    pos = np.arange(n) - delay_samples
    return np.interp(pos, np.arange(n), x, left=0.0, right=0.0)


def chorus(x: np.ndarray, rng: np.random.Generator, depth_ms: float = 3.0, rate_hz: float = 0.25,
           mix: float = 0.5, voices: int = 2) -> np.ndarray:
    """Stereo chorus from a mono or stereo source."""
    src = x if x.ndim == 1 else x.mean(axis=0)
    n = src.shape[-1]
    t = time_axis(n)
    out = np.zeros((2, n))
    for ch in range(2):
        wet = np.zeros(n)
        for v in range(voices):
            ph = float(rng.random())
            d = (8.0 + depth_ms * (1.0 + np.sin(2 * np.pi * (rate_hz * (1 + 0.13 * v) * t + ph)))) * SR / 1000.0
            wet += fractional_delay(src, d)
        out[ch] = wet / voices
    dry = stereo(x)
    return dry * (1.0 - mix) + out * mix


def delay(x: np.ndarray, time_s: float, feedback: float = 0.35, mix: float = 0.3,
          damp_hz: float = 4000.0, ping_pong: bool = False) -> np.ndarray:
    """Feedback echo with a low-pass in the loop. Output length grows by the tail."""
    x = stereo(x)
    d = samples(time_s)
    tail = int(d * np.log(1e-3) / np.log(max(feedback, 1e-3))) + d
    n = x.shape[-1]
    total = n + tail
    dry = np.zeros((2, total))
    dry[:, :n] = x
    wet = np.zeros((2, total))
    sos = sps.butter(1, damp_hz, "lp", fs=SR, output="sos")
    zi = np.zeros((2, 1, 2))
    mono = dry.mean(axis=0)
    # y[k] = x[k-d] + fb * lp(y[k-d]); computed one delay-length block at a time.
    # Ping-pong: the input enters on the left and every repeat swaps sides.
    for s in range(d, total, d):
        e = min(s + d, total)
        if ping_pong:
            src = np.stack([mono[s - d:e - d] + feedback * wet[1, s - d:e - d], feedback * wet[0, s - d:e - d]])
        else:
            src = dry[:, s - d:e - d] + feedback * wet[:, s - d:e - d]
        for c in range(2):
            filt, zi[c] = sps.sosfilt(sos, src[c], zi=zi[c])
            wet[c, s:e] = filt
    return dry + mix * wet


def reverb_ir(seconds: float, rng: np.random.Generator, predelay_ms: float = 12.0,
              damp: float = 0.5, width: float = 1.0) -> np.ndarray:
    """Synthetic stereo impulse response: decaying noise split into bands, each
    band with its own decay time (highs die first, controlled by `damp`)."""
    n = samples(seconds * 1.15)
    t = time_axis(n)
    bands = [(20, 250, 1.0), (250, 1200, 0.92), (1200, 4000, 1.0 - 0.45 * damp), (4000, 16000, 1.0 - 0.75 * damp)]
    ir = np.zeros((2, n))
    for lo, hi, scale in bands:
        sos = sps.butter(2, [lo, hi], "bandpass", fs=SR, output="sos")
        t60 = seconds * scale
        decay = np.exp(-6.9078 * t / t60)
        for c in range(2):
            ir[c] += sps.sosfilt(sos, rng.standard_normal(n)) * decay
    # Width: blend towards mono.
    mid = ir.mean(axis=0)
    ir = mid + (ir - mid) * width
    # Soft onset (diffuse build-up) and predelay.
    onset = np.clip(t / 0.02, 0.0, 1.0)
    ir *= onset
    pd = samples(predelay_ms / 1000.0)
    ir = np.concatenate([np.zeros((2, pd)), ir], axis=1)
    return ir / np.sqrt(np.sum(ir ** 2) / 2.0)


def reverb(x: np.ndarray, rng: np.random.Generator, seconds: float = 1.5, mix: float = 0.25,
           predelay_ms: float = 12.0, damp: float = 0.5, width: float = 1.0) -> np.ndarray:
    """Convolution reverb with a synthetic IR. Output length grows by the tail."""
    x = stereo(x)
    ir = reverb_ir(seconds, rng, predelay_ms, damp, width)
    n = x.shape[-1] + ir.shape[-1] - 1
    out = np.zeros((2, n))
    out[:, :x.shape[-1]] = x * (1.0 - mix)
    for c in range(2):
        out[c] += mix * sps.fftconvolve(x[c], ir[c]) * 0.35
    return out


def wrap(x: np.ndarray, n: int) -> np.ndarray:
    """Folds everything past sample n back onto the start (circular sum), turning
    tails that run past a loop point into a seamless loop of length n."""
    out = np.zeros(x.shape[:-1] + (n,))
    for s in range(0, x.shape[-1], n):
        seg = x[..., s:s + n]
        out[..., :seg.shape[-1]] += seg
    return out


def place(buffer: np.ndarray, x: np.ndarray, at: int) -> None:
    """Adds x into buffer starting at sample `at` (clipped to the buffer)."""
    if at < 0:
        x, at = x[..., -at:], 0
    end = min(at + x.shape[-1], buffer.shape[-1])
    if end > at:
        buffer[..., at:end] += x[..., : end - at]


def fade(x: np.ndarray, in_s: float = 0.002, out_s: float = 0.01) -> np.ndarray:
    x = x.copy()
    n = x.shape[-1]
    i, o = min(samples(in_s), n), min(samples(out_s), n)
    if i > 0:
        x[..., :i] *= np.sin(np.linspace(0, np.pi / 2, i)) ** 2
    if o > 0:
        x[..., n - o:] *= np.cos(np.linspace(0, np.pi / 2, o)) ** 2
    return x


def trim_tail(x: np.ndarray, threshold_db: float = -60.0, keep_s: float = 0.01) -> np.ndarray:
    """Cuts trailing near-silence (relative to the peak)."""
    mono = np.abs(x).max(axis=0) if x.ndim == 2 else np.abs(x)
    thr = mono.max() * db(threshold_db)
    loud = np.nonzero(mono > thr)[0]
    end = min(int(loud[-1]) + samples(keep_s), x.shape[-1]) if len(loud) else x.shape[-1]
    return x[..., :end]


def mix(*parts: np.ndarray) -> np.ndarray:
    """Sums signals of different lengths (shorter ones are zero-padded)."""
    n = max(p.shape[-1] for p in parts)
    lead = max((p.shape[:-1] for p in parts), key=len)
    out = np.zeros(lead + (n,))
    for p in parts:
        out[..., : p.shape[-1]] += p
    return out
