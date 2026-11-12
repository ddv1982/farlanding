# Audio style guide

Every sound and all music in Farlanding is synthesised by code in `audio_src/`. No recordings,
samples, text-to-speech or external services (PLAN §9). This page fixes the identity, the
loudness targets and the naming, and says how to add a sound.

## Identity

- **The Concord Survey sounds like instruments, not machines.** Three voices carry the faction:
  a warm FM *chime* (glass and wood, vibraphone-like), a *marimba* with wooden partials, and a
  soft *reed* (rolled-off saw with breath). Interface sounds, unit replies and the music are all
  built from them, so the whole faction reads as one family.
- **One key.** Concord sounds sit in D with a Lydian colour (D E F# G# A B C#), the mode of the
  Kessel Reach music, so replies never clash with the score.
- **Units speak in tonal signatures, never words.** Each unit type owns a register, a rhythm
  and an interval; the reply *grammar* is shared: **select rises** (a question), **move falls
  and resolves** (an answer), **attack repeats a note with an accent** (insistence).

  | Sound set | Register | Rhythm | Interval and timbre |
  |---|---|---|---|
  | `surveyor` | high, D6–C#7 | quick triplets (45–60 ms) | thirds and sixths, glassy chime, scan shimmer |
  | `ranger` | middle, A4–A5 | two or three even strokes (~110 ms) | fourths and fifths, marimba + chime |
  | `bulwark` | low, A1–A3 (+ octave chimes) | slow, ~0.27 s per note | octaves and fifths, brassy reed + sub |
  | `kite` | upper middle, E5–B5 | one or two swoops | glides of a fifth or sixth, airy reed |

- **The Advisor (the ship *Meridian*) is a different family**: pure sine dyads with a slow
  tremolo, band-limited to a "ship channel" with a faint carrier hiss. It never uses the unit
  instruments.
- **The Trail motif** — D A B G# (scale degrees 1, 5, 6, #4), short-long-short-long — means
  *discovery*. It ends on the raised fourth so it hangs like a question. Music quotes it
  transposed through the scale; the stinger `mus_trail_motif` plays it alone.
- **Restraint.** Interface sounds are short (≤ 0.3 s) and dry; replies carry a small room;
  only music and ambience are wide and wet.

## Loudness targets

Integrated loudness per ITU-R BS.1770 (gated; files shorter than 400 ms are one block). Every
file is normalised to its target; the build fails if a file misses it by more than 0.5 LU (WAV)
or 1 LU (Ogg, measured after decoding), or if true peak exceeds −0.5 dBTP (normalisation
ceiling −1 dBTP, a look-ahead limiter catches transients).

| Group | Format | Target LUFS | Notes |
|---|---|---|---|
| `ui` | WAV mono | −27 (hover −34, deselect −29) | dry, ≤ 0.3 s |
| `unit` | WAV mono | −21 (surveyor −20) | flat, Barks bus |
| `advisor` | WAV mono | −20 | flat, Advisor bus; ducks music |
| `world` | WAV mono | −25 | positional (order ping) |
| `movement` | WAV mono, loop | −24 | positional, seamless |
| `ambience` | Ogg stereo, loop | −30 | ≥ 30 s, seamless |
| `music` layers | Ogg stereo, loop | pad −25, pulse −29, melody −27 | one tempo, same length |
| `music` stinger | Ogg stereo | −22 | |

Also checked on every build: DC offset ≤ 0.002, energy below 25 Hz ≤ 3 %, duration within the
recipe's bounds, and for loops the seam (no step, kink or level jump bigger than the loop's own
most abrupt moment). Ogg files are decoded again and compared with the source (codec fidelity).

## Naming

`<group>_<subject>_<action>[_<variation>]`, lowercase. Files live in
`game/assets/audio/<folder>/`, events in `game/data/sounds/<group>/<event>.tres`.

- `ui_click`, `ui_group_assign`
- `unit_<sound_set>_<select|move|attack>_<1..n>` → event `unit_<sound_set>_<kind>`
- `move_<chassis>` (file) → event `move_<sound_set>` (one chassis can serve many sound sets)
- `world_order_ping`, `advisor_alert`, `amb_<planet>_<bed>`, `mus_<planet>_<state>_<layer>`

The event router looks events up by these names: a unit's `def.sound_set` picks
`unit_<set>_select`; `Events.ui_feedback(kind)` plays `ui_<kind>` (kinds starting with
`invalid`/`not_enough` fall back to `ui_invalid`).

## Adding a sound

1. Write a recipe: a function `(rng) -> np.ndarray` in `audio_src/recipes/<module>.py`,
   decorated with `@sound("<id>", "<group>", <target_lufs>, ...)`. Tune it by editing numbers.
2. Render: `uv run --python 3.12 --with numpy --with scipy audio_src/build.py` (or `--only <id>`).
   The report must say `0 failed`.
3. The build scaffolds `game/data/sounds/<group>/<event>.tres` with group defaults if the event
   is new. Tune bus, priority, caps, cooldown and volume there (it is never overwritten).
   No code change: the AudioService registers every SoundEvent under `res://data/sounds/`.
4. If a gameplay event should trigger it and no naming rule covers it, add the mapping in
   `game/audio/audio_cue_selector.gd`.
