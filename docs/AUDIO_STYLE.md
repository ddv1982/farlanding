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
  | `hauler` | low middle, D3–B3 (+ octave knock) | dotted short-long | steps and thirds, reed "horn" dyad + marimba knock |
  | `fabricator` | upper, F#5–F#6 | grace-note flick into a landing note | seconds and fourths, busy marimba + tool tick |

- **Buildings are machines, not musicians.** Selecting a building plays its *machine identity*
  (`building_<set>_select`, −22 LUFS, quieter than a unit reply), the sound its machinery
  makes, tuned into D: `lander` a reed fifth on D under a D-F#-A chime; `reactor` a drone that
  glides up to D2 and throbs; `refinery` two metal clanks (A, E) and steam; `flux_tap` glassy
  rising bubbles on G#-B-C#-D; `muster_bay` a wooden drum triplet and a reed bugle A→D;
  `foundry` a press thud, an anvil ring on B and a hydraulic sigh.

- **The Advisor (the ship *Meridian*) is a different family**: pure sine dyads with a slow
  tremolo, band-limited to a "ship channel" with a faint carrier hiss. It never uses the unit
  instruments. Each alert kind owns a phrase (`advisor_<kind>`):

  | Kind | Phrase |
  |---|---|
  | `low_power` | warning: three tritone pulses (D+G#) that sag a semitone, the last longest, over a beating undertone |
  | `power_restored` | a dyad slides up a semitone into D+A, a high D+A answers |
  | `insufficient_resources` | two quick, quiet staccato dyads (−22) |
  | `construction_complete` | three dyads climbing D, F#, A to a held D, middle register |
  | `unit_ready` | a high leap of a fifth, short-long, crisp |
  | `deposit_depleted` | three dyads falling and fading, each darker |
  | `building_placed` | one soft high dyad with an echo (−23) |

  Alert discipline (`AdvisorQueue`): one phrase at a time (others wait up to 4 s, most
  important first), each kind throttled (insufficient resources and low power 15 s), and an
  unheard low-power warning cancels out against a following power-restored.
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
| `advisor` | WAV mono | −20 (low power −19, insufficient −22, placed −23) | flat, Advisor bus; ducks music |
| `world` | WAV mono | −25 | positional (order ping) |
| `building` | WAV mono | −22 | flat, Buildings bus (machine identities) |
| `base` | WAV mono | −23 (complete −22) | positional, Buildings bus (place, complete, unit ready, unload, depleted) |
| `baseloop` | WAV mono, loop | construct −25, mine −26, produce −29, hum −33 | positional, seamless |
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

- `building_<sound_set>_select`, `base_<what>`, `loop_<what>`, `advisor_<alert kind>`

The event router looks events up by these names: a unit's `def.sound_set` picks
`unit_<set>_select`; a selection of buildings only (group `buildings`) picks
`building_<set>_select`; `Events.advisor_alert(kind)` plays `advisor_<kind>` (fallback
`advisor_alert`); `Events.ui_feedback(kind)` plays `ui_<kind>` (kinds starting with
`invalid`/`not_enough`/`insufficient` or ending in `_invalid` fall back to `ui_invalid`;
aliases such as `placement_invalid` → `ui_invalid_placement` are in `AudioCueSelector`).

Base loops (`BaseLoops`) sit on the player's entities, at most six, nearest first, hums ranked
last: `loop_construct` (`is_under_construction`, else building_placed → construction_completed),
`loop_produce` (`is_producing`, else production_started/completed), `loop_mine`
(`is_harvesting` on a unit), `loop_hum` (any other building unless `is_powered` is false).
All four properties are optional bools; low power dims hum and production by 6 dB.

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
