"""Sound recipes. Each module registers its sounds with `@sound(...)`.

A recipe is a function `(rng) -> np.ndarray` that returns the finished sound
before loudness normalisation (mono 1-D or stereo (2, n)). The decorator holds
everything the build needs to know about the file.
"""

from __future__ import annotations

import zlib
from dataclasses import dataclass, field
from typing import Callable

import numpy as np


@dataclass
class Sound:
    id: str
    group: str
    fn: Callable[[np.random.Generator], np.ndarray]
    target_lufs: float
    fmt: str = "wav"
    loop: bool = False
    channels: int = 1
    max_seconds: float = 2.0
    min_seconds: float = 0.0
    folder: str = ""
    seed: int = 0
    # Music metadata written into the Godot import settings (bar-synced loops).
    bpm: float = 0.0
    beats: int = 0
    bar_beats: int = 4
    params: dict = field(default_factory=dict)

    @property
    def path(self) -> str:
        return f"{self.folder or self.group}/{self.id}.{self.fmt}"


REGISTRY: list[Sound] = []


def sound(id: str, group: str, target_lufs: float, **kwargs) -> Callable:
    """Registers a recipe. The seed defaults to a stable hash of the id, so
    renaming a sound changes its seed but editing another sound never does."""

    def wrap(fn: Callable) -> Callable:
        seed = kwargs.pop("seed", zlib.crc32(id.encode()) & 0x7FFFFFFF)
        REGISTRY.append(Sound(id=id, group=group, fn=fn, target_lufs=target_lufs, seed=seed, **kwargs))
        return fn

    return wrap


def load_all() -> list[Sound]:
    from . import (  # noqa: F401
        advisor, ambience, antecedent, buildings, campaign, combine, discovery, emberfall, impacts, interface, missions,
        movement, music_emberfall, music_kessel, music_kessel_combat, music_kessel_score, music_kessel_stealth, music_kessel_trail, music_meridian,
        music_thalassa,
        specialists,
        stealth, thalassa, units, vertical_slice, weapons, weather, world,
    )

    return REGISTRY
