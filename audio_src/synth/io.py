"""File output: 16-bit WAV (with TPDF dither) and Ogg Vorbis through ffmpeg."""

from __future__ import annotations

import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np

from .dsp import SR


def to_int16(x: np.ndarray, rng: np.random.Generator) -> np.ndarray:
    """Float [-1, 1] to interleaved int16 with triangular dither."""
    x = np.atleast_2d(x)
    d = (rng.random(x.shape) - rng.random(x.shape)) / 32768.0
    y = np.clip(np.round((x + d) * 32767.0), -32768, 32767).astype("<i2")
    return y.T.reshape(-1)


def write_wav(path: Path, x: np.ndarray, seed: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    channels = 1 if x.ndim == 1 else x.shape[0]
    data = to_int16(x, np.random.default_rng(seed ^ 0x5EED))
    with wave.open(str(path), "wb") as w:
        w.setnchannels(channels)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def read_wav(path: Path) -> np.ndarray:
    with wave.open(str(path), "rb") as w:
        ch = w.getnchannels()
        raw = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(np.float64) / 32768.0
    x = raw.reshape(-1, ch).T
    return x[0] if ch == 1 else x


# The ffmpeg build available has only its native Vorbis encoder (experimental,
# no -q scale). A fixed bitrate keeps it well above its artefact threshold.
OGG_BITRATE = "224k"


def write_ogg(path: Path, x: np.ndarray, seed: int) -> None:
    """Encodes via a temporary 24-bit WAV so ffmpeg gets the full float detail."""
    path.parent.mkdir(parents=True, exist_ok=True)
    x2 = np.atleast_2d(x)
    with tempfile.TemporaryDirectory() as tmp:
        src = Path(tmp) / "src.f32"
        src.write_bytes(np.clip(x2, -1.0, 1.0).T.astype("<f4").tobytes())
        cmd = [
            "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
            "-f", "f32le", "-ar", str(SR), "-ac", str(x2.shape[0]), "-i", str(src),
            "-c:a", "vorbis", "-strict", "-2", "-b:a", OGG_BITRATE,
            "-map_metadata", "-1", "-fflags", "+bitexact", "-flags:a", "+bitexact",
            str(path),
        ]
        subprocess.run(cmd, check=True)


def read_any(path: Path, channels: int) -> np.ndarray:
    """Decodes any file ffmpeg reads to float at SR (used to analyse the Ogg
    output exactly as the game will receive it)."""
    out = subprocess.run(
        ["ffmpeg", "-hide_banner", "-loglevel", "error", "-i", str(path),
         "-f", "f32le", "-ac", str(channels), "-ar", str(SR), "-"],
        check=True, capture_output=True,
    ).stdout
    x = np.frombuffer(out, dtype="<f4").astype(np.float64).reshape(-1, channels).T
    return x[0] if channels == 1 else x
