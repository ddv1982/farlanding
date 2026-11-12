# 0005 — Synthesised audio pipeline and runtime

- Status: accepted
- Date: 2026-11-12

## Context

PLAN §9.2: nothing paid, no external services, no recordings — every sound and all music is
synthesised by our own code. PLAN §5 asks for a reproducible pipeline, loudness targets, a
data-driven runtime with a voice budget, an RTS listener and adaptive music. The only audio
tools on the machine are Python (through `uv`) and ffmpeg.

## Decision

**Pipeline.** `audio_src/` is a small numpy/scipy synthesis library (`synth/`) plus one recipe
per sound (`recipes/`). `audio_src/build.py` renders everything, normalises to BS.1770 loudness
targets, writes `game/assets/audio/`, writes each file's Godot import settings (looping, BPM and
beat count for bar-synced music) into its `.import` while keeping Godot's uid, scaffolds missing
SoundEvent `.tres` files, writes `audio_src/manifest.json`, and fails on clipping, missed
loudness, DC, bad durations or loop seams. Output is deterministic (seeded; Ogg written
bit-exact), so a rebuild produces identical files. Run with
`uv run --python 3.12 --with numpy --with scipy audio_src/build.py`.

Loops are seamless by construction rather than by crossfading: whole-cycle oscillator
frequencies, circular noise, filters run over three repeats, and tails folded back over the
loop point.

**Formats.** Short sounds: 16-bit mono WAV (imported as QOA). Music, ambience: stereo Ogg Vorbis.
The installed ffmpeg has no libvorbis, only its native experimental Vorbis encoder, which
ignores bitrate/quality settings (~330 kbit/s for noise, much less for tonal material) and has
no block switching, so sharp attacks can pre-echo. Music layers therefore use soft attacks
(≥ 8 ms), and the build reports codec fidelity (median segmental SNR of the decoded file against
the source; 20–38 dB today). If libvorbis becomes available, switch `synth/io.py` to it.

**Runtime** (`game/audio/`):

- `SoundEvent` resources, auto-registered from `res://data/sounds/`.
- Two pools behind `VoiceBudget`s: 16 flat players (interface, replies, Advisor) and 32
  positional ones. Per-event instance caps and cooldowns, then priority stealing (lowest
  priority first, oldest among equals; never a higher priority). Voices also expire by their
  stream length because the headless dummy driver may not deliver `finished`.
- Event mapping in `AudioEventRouter` + pure `AudioCueSelector`: one reply per selection or
  order, from the most common sound set; repeats throttled.
- The listener is an `AudioListener3D` above the camera's ground focus, yawed with the camera;
  zoom raises it and shifts bus offsets (`AudioMix`).
- Movement loops are found by scanning group `units` every 0.2 s; speed is the unit's `speed`
  property if present, otherwise measured from position change. Six loops at most, three per
  loop type, nearest first.
- `MusicDirector` builds an `AudioStreamInteractive` from a `MusicScore` resource; each clip is an
  `AudioStreamSynchronized` stack whose layer volumes are changed live (verified in an engine
  test). Calmer states wait out a hold time.
- On quit, a guard node stops every player while still in the tree and waits 100 ms. Without
  it, Godot reports the streams as leaked: a player leaving the tree only pauses its stream,
  and the server shuts down before the mixer frees it.

## Consequences

- Every sound can be changed by editing numbers and rebuilding; nothing needs licensing.
- Spoken lines cannot exist. The Advisor's words go to on-screen text with its tone family.
- Python 3.12 + numpy + scipy are build-time dependencies, fetched by `uv` on demand.
- Generated audio is committed (ADR 0003). It is about 8 MB today, mostly the Ogg beds, because
  the native encoder spends many bits on noise.
