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
  | `wisp` | middle-high, D5–E6 | a breath: grace into a swelled note, a ghost echo an octave up | the raised fourth (D–G#) and fourths, breathy reed + faint glass |
  | `lancer` | middle, A3–E5 | short-short-LONG spear strokes, each scooping up into pitch | fifths and octaves, bright reed + chime tine + marimba knock |
  | `arc` | low-middle, A2–D4 (+ two-octave chime) | lobbed glides that arch a third over the target note, then land | fifths, reed + sine, wooden knock and thump on landing |

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
  | `under_attack` | alarm: two fast bursts of four staccato tritone dyads a semitone apart, the second a step higher (−19) |

  Alert discipline (`AdvisorQueue`): one phrase at a time (others wait up to 4 s, most
  important first), each kind throttled (insufficient resources and low power 15 s,
  under attack 20 s), and an unheard low-power warning cancels out against a following
  power-restored. `under_attack` outranks every other alert and is skipped (without starting
  its throttle) while the listener focus is within 40 m of the damaged entity: the player is
  already looking at the fight.
- **Combat tells the factions apart by ear.** Concord weapons are clean, tonal and tight: sine
  and FM bolts landing on D Lydian notes, controlled noise, no distortion (spectral flatness
  ≤ 0.05). Combine weapons are harsher, lower and dirtier: detuned saws, ring modulation at
  inharmonic ratios, saturated and decimated noise, crackle (flatness 0.10–0.18). Rapid weapons
  are ≤ 0.2 s with nothing below ~500 Hz; heavy ones carry a sub thump and a tail.

  | Sound set | Weapon | Sound |
  |---|---|---|
  | `repeater` | Ranger | FM bolt chirping down an octave onto A5/B5/C#6, 0.15 s |
  | `light_gun` | Kite | double-tap of tight tonal "tak"s on E6/F#6 |
  | `sentry` | Sentry turret | twin bolts a fifth/fourth apart over a soft body |
  | `cannon` | Bulwark | deep thump, tight crack, barrel ringing on D/A/E, breech clack |
  | `skitter_gun` | Combine drone | buzzy ring-modulated snap with decimated grit |
  | `lance` | Combine Stinger | 0.3 s beam: beating saw cluster, rising whine, crackle, sizzle cut-off |
  | `siege` | Combine Mauler | two saturated booms, a mistuned clang, loose rattle |
  | `wisp` | Wisp | a suppressed glass "pff": a short FM bolt onto D6/E6/C#6 under a breath of air (−27) |
  | `lancer` | Lancer | a 0.1 s charge whine rising into a long FM spear onto D5/E5/A4, crack and sub knock (−23) |
  | `arc` | Arc | the tube's deep "thoonk" ringing on D3/A2/E3, a propellant puff, the shell's whistle climbing away |

  Impacts say what was hit (`impact_spark` light target, `impact_armour` heavy armour or
  structure, `impact_ground` a miss; lances always spark); an `impact_size` of 1 m or more plays
  an explosion instead (small < 2.5 m ≤ medium < 5 m ≤ large). Deaths: `death_light`, `death_heavy`
  (by `def.armour_type`), `death_building` (a 3.8 s collapse).
- **Combat music** is more synchronised layers of the Kessel explore clip (same 48 s grid and
  chords): `drive` (tension: low ostinato, off-beat tick, phrase swells), `drums` and `brass`
  (combat: taiko and toms; reed stabs and the Trail motif augmented as a call to arms). States
  are layer mixes: explore, calm, tension, combat, aftermath (pad, soft melody, a trace of drive),
  victory and defeat (quiet pads under the sting). The stings (`mus_sting_victory`: the motif
  answered, rising to the high D; `mus_sting_defeat`: the motif darkened, D A Bb falling to the
  low D) play flat on the Music bus.
- **The Trail motif** — D A B G# (scale degrees 1, 5, 6, #4), short-long-short-long — means
  *discovery*. It ends on the raised fourth so it hangs like a question. Music quotes it
  transposed through the scale; the stinger `mus_trail_motif` plays it alone.
- **Discovery has a voice** (Phase 4), and every part of it is built on the Trail motif:

  | Event | Sound |
  |---|---|
  | `signal_pulse` | an unresolved site: only the motif's first interval, D5 short, A5 long, then 2.5 s of air (3.2 s loop, −30, positional) |
  | `scan_loop` | scanning: the same D–A pulsed eight times a second, a band of noise sweeping up, data ticks, the next note (B) barely there (2 s loop, −27) |
  | `scan_interrupted` | the dyad sags a tritone while its filter closes, a dull tick |
  | `discovery_resolve_geological` | stone bars D A B, then down onto the low D with an anvil ring and a rumble: it lands |
  | `discovery_resolve_biological` | breathy reeds gliding D A B G#, the G# turning up to A in a trill, chirps around it: alive |
  | `discovery_resolve_antecedent` | the whole motif on bells, chime and reed over a Lydian swell, then its answer A C# rising to the high D (−20, 6.2 s) |
  | `discovery_resolve_enemy` | the motif bent: D A Bb on ring-modulated Combine saws, the last note sagging G# → G with a growl |
  | `ui_codex_open` / `_close` / `_entry` | two marimba notes up / down; the motif's last step B → G# on glass with a paper flick |
  | `ui_intel_tick`, `ui_option_button` | a tiny glass tick on A6; a click with a glass G# above it (spending Intel) |
  | `field_orbital_scan`, `field_supply_drop`, `field_antecedent_power` | a sonar sweep from orbit with data rain; a falling pod, a landing thump and a D–A chime; reversed bells swelling into a strike on D and G# |
  | `advisor_discovery`, `advisor_field_option_ready` | Meridian dyads D+A → A+D (the ship heard it too); G#+D twice, lifting into A+D |

  Resolve phrases are stereo, −21 LUFS, flat on the **Discovery** bus, and briefly duck the
  other buses (`BusDucker`: Music −8 dB, Ambience −6, SFX −5, 80 ms attack, held for the
  phrase minus its 0.6 s tail, 1 s release). An antecedent find also plays
  `mus_swell_antecedent` (a low Lydian chord that blooms under the phrase's last note) on the
  Discovery bus, so the duck does not swallow it.
- **The Custodians (Antecedent machines) are a third sound world**, neither Concord instrument
  nor Combine machine: everything comes from the *Antecedent bell* (`instruments.bell`), a tuned
  bell spectrum whose partials include a faint raised fourth, so D and G#, the frame of the
  Trail motif, are literally in the metal. Warden: `loop_hum_warden` (dormant drone on D,
  −32), `move_warden` (the drone with air, stone grind and brass ticks), `unit_warden_wake`
  (stone grinding up into a great strike on D and G# and a lift), `weapon_warden_fire` (a
  bell-bolt dropping onto G#/D/A, a clang and a short beam), `death_warden` (the bell cracks,
  its partials split and fall, stone crumbles).
- **Machines heard as identities.** `loop_hum_survey_lab` (Concord hum on D, the dish pinging
  D then A once per loop, −33; select: a servo and three pings climbing D-A-B); Combine
  `loop_hum_hub` (47 Hz transformer, mains buzz, pressure cycle), `loop_hum_forge` (furnace,
  drop hammer, quench), `loop_hum_spire` (beating whine cluster, arcing, guy-wire drone),
  all −30 and off the Concord key; `move_scrapper` (rough two-stroke, grinding treads, loose
  scrap) and `move_rigger` (four hydraulic legs, detuned servo whines, a weld spit).
- **Missions have the Advisor's voice** (Phase 5). Objectives are Meridian phrases
  (`advisor_<kind>`, through the Advisor queue, so the Advisor bus ducks the music):

  | Kind | Phrase |
  |---|---|
  | `objective_new` | a three-dyad pickup climbing into a held D+A, a high ping |
  | `objective_hidden` | a muffled tritone G#+D that opens up and settles on A+E, a faint G# above: a secret |
  | `objective_done` | primary: A+E, B+F#, then D+A held with its octave, answered by a high D+A (−19) |
  | `objective_done_secondary` | the same idea, smaller: two dyads up a fourth, short-long (−22) |
  | `objective_failed` | D+A bending down three semitones as its filter closes, over a beating low D |
  | `objective_time_low` | a clock: tick-tock dyads (A+E, G#+D), the last falling a tone |
  | `storm_warning` | three dyads stepping down a whole tone each (out of key) over a rising gust (−19) |
  | `detected` | six staccato dyads climbing in semitones into a held, trembling tritone (−19) |

  `ui_objective_tick` (A6 → D7 glass ticks) marks progress. There are no spoken words: the
  *briefing voice* is `mus_briefing_bed` (the Meridian's sine dyads slowed into a pad, a low D,
  telemetry pings every 3.2 s, the ship channel's carrier; 32 s loop) under the panel with
  `ui_briefing_tick` (E7/F#7/A7, −34) on each text reveal, `ui_briefing_open`/`_close` (two soft
  dyads up/down). `mus_sting_launch` starts the mission (a Meridian dyad lifting off, the
  Concord answering with a rising D F# A D, a drum on the downbeat, the motif's opening leap
  D → A over Dmaj9). `mus_debrief_bed` (Dmaj9 → Bm pad, the Trail motif slowed and far away,
  32 s loop) sits under the debrief; the victory and defeat stings say who won.
  Survey's storm: `mus_storm_minute` (thunder rolls in, a low reed D → A sagging to G#) with
  one minute left, then the score's `storm` layer; `mus_storm_countdown` (ten ticks a second
  apart, each a semitone higher, the wind rising, the storm breaking on the tenth second).
- **Stealth is the Combine listening.** Watching and alarms are in the Combine sound world;
  the Wisp's cloak is Concord glass:

  | Event | Sound |
  |---|---|
  | `stealth_suspicion` | a beating detuned-saw cluster throbbing 4×/s with a radar tick (2 s loop, −26, positional); its level (−14 → 0 dB) and pitch (0.85 → 1.3) follow the watcher's suspicion, so the beat speeds up: it tightens |
  | `stealth_spotted` | two ring-modulated chirps snapping up into a hard tritone stab with a crack (−19, flat) |
  | `stealth_alert_suspicious` | a radio squelch, a buzzy two-tone query rising a fourth ("hm?"), squelch off (−23) |
  | `stealth_alert_alarm` | a saturated, decimated klaxon wailing up a fourth and back, twice, a thump under each (−21) |
  | `stealth_all_clear` | squelch, the query falling (stand down), squelch off, then a soft Concord chime D+A (−24) |
  | `stealth_cloak_engage` / `_disengage` | chimes D A E swelled backwards, air rising through a closing comb, folding to nothing / an air pop sweeping down, chimes A → D ringing out (−24, positional) |

  Stealth music: three more synchronised layers of the Kessel explore clip, `hush` (sparse:
  high air on chord tones, a muted marimba drop every other bar), `watch` (a low lub-dub on
  beats 1 and 3, off-beat ticks, a G# shadow) and `storm` (rumble, gusts, a half-time throb on
  D, distant thunder). States: `stealth_unaware` (pad −9, hush), `stealth_suspicious` (the
  watch pulse joins, a trace of drive), `stealth_alerted` (watch, drive, drums, a little brass:
  full drive). Layer changes wait for the next beat (score `bpm` 80, `quantize_beats` 1) and
  fade at the state's own speed (4 s, 1.5 s, 0.5 s), so a joining layer lands in time.
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
| `movement` | WAV mono, loop | −24 | positional, seamless (Combine: skitter, stinger, mauler) |
| `weapon` | WAV mono | rapid −26, sentry −25, lance −24, heavy −22 | positional, Weapons bus |
| `impact` | WAV mono | spark −27, armour/ground −26 | positional, Weapons bus |
| `explosion` | WAV mono | small −23, medium −21, large −19; deaths −23/−21, building −20 | positional, Explosions bus |
| `sting` | Ogg stereo | −22 | flat, Music bus, 3–6 s |
| `ambience` | Ogg stereo, loop | −30 | ≥ 30 s, seamless |
| `music` layers | Ogg stereo, loop | pad −25, pulse −29, melody −27 | one tempo, same length |
| `music` stinger | Ogg stereo | −22 | |
| `music` trail layer | Ogg stereo, loop | −29 | Kessel explore grid, Antecedent bell |
| `signal` | WAV mono, loop / one-shot | pulse −30, scan −27, cut −26 | positional, Discovery bus |
| `discovery` | WAV stereo | −21 (antecedent −20) | flat, Discovery bus, ducks other buses |
| `field` | WAV stereo | −22 (antecedent −21) | flat, SFX bus |
| `antecedent` | WAV mono | −21 | positional, Units bus (Warden wake) |
| `stealth` | WAV mono | spotted −19, alarm −21, suspicious −23, all-clear −24, cloak −24, suspicion loop −26 | flat on the **Stealth** bus (not ducked); suspicion loop and cloak positional |
| `advisor` (Phase 5) | WAV mono | objectives −20 (done −19, secondary −22), storm −19, detected −19 | flat, Advisor bus |
| `bed` | Ogg stereo, loop | −28 | 32 s (a multiple of 64 samples: the native encoder pads), own player on the Music bus |
| `sting` (Phase 5) | Ogg stereo | launch −22, storm minute −22, countdown −21 (11.8 s) | flat, Music bus |
| `music` stealth layers | Ogg stereo, loop | hush −31, watch −29, storm −29 | Kessel explore grid |
| `movement` (Wisp) | WAV mono, loop | −28 | `move_phantom`, quieter than any chassis by design; −9 dB more while cloaked |

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

Combat (`CombatSoundRouter`): `weapon_fired` plays `weapon_<weapon.sound_set>_fire` at the
muzzle, or the sound family a data name is aliased to in `CombatCues.FIRE_ALIASES`
(`ranger_repeater` → `repeater`, `mauler_twin_cannon` → `siege`, ...); `projectile_impacted` the impact or explosion (above); `entity_died` the death sound;
nothing plays for an entity whose `is_visible_to_player` is false, and ground impacts ask the
fog (`fog_of_war` group: `is_point_visible_to_player(position)`). A Sentry that fires after
3 s of silence also plays `base_turret_traverse`. Mass-combat discipline (`CombatMixer`):
offers are arbitrated once per frame, out-of-range ones dropped, the rest ranked by
`priority − distance in metres` (priority is the weight: rapid 38–40, sentry 46, lance 50,
heavy 58, impacts 34–40, explosions 62–70, deaths 66–78), and each category may start at most
fire 8 / impact 5 / blast 4 sounds per 0.5 s; per-event caps and cooldowns apply on top.
Blasts play first and duck light fire (priority < 50) by 4 dB for 0.45 s.
The combat music (`MusicMood`) runs on *heat* from player-involved fire, damage and deaths
(near = within 45 m of the focus counts more; halves every 6 s): tension at 2.5, combat at 12;
stepping down needs 6 s below 1 (tension) or 4 (combat); combat always passes through 20 s of
aftermath. `mission_ended` forces victory/defeat and plays the sting.

Exploration (`SignalPulses`, `DiscoverySoundRouter`, pure rules in `DiscoveryCues`). Sites
are Node3D in group `discovery_sites`, read duck-typed: a site pulses while
`is_signal_known_to_player` (fallback `is_visible_to_player`, else silent) and neither
`is_resolved` nor `is_being_scanned`; at most three pulses (and the event's `max_instances`),
nearest first, within 80 m; they fade over 1.2 s and drop up to 6 dB as the camera zooms out.
`scan_started` starts one `scan_loop` per site (heard when the scanner is the player's or the
site is visible), `scan_interrupted` from the last scanner stops it and plays
`scan_interrupted`, `discovery_made` stops it silently. For the player's discoveries
`discovery_resolve_<discovery_type>` plays (fallback geological) with the duck; any faction's
discovery sets the Kessel **trail** layer from the share of resolved sites (silent before the
first, −9 dB after it, 0 dB when all are found), via `MusicDirector.set_layer_gain`; states
keep it at 0 (explore), −3 (calm), −8 (tension), −4 (aftermath), −6 (victory), silent in
combat and defeat. `intel_changed` for the player plays `ui_intel_tick` when Intel rises (the
first report is the baseline); `field_option_used` plays `field_<id>` (ids containing
`antecedent`/`scan`/`supply`/`drop` fall back to the three effects); `codex_entry_added` plays
`ui_codex_entry`. Codex open/close and the option button are `Events.ui_feedback(&"codex_open")`,
`&"codex_close"`, `&"option_button"`. Advisor kinds `discovery` (priority 70, throttle 4 s) and
`field_option_ready` (45, 20 s) are raised by gameplay as ordinary `advisor_alert`s.

Base loops (`BaseLoops`) sit on the player's entities, at most six, nearest first, hums ranked
last: `loop_construct` (`is_under_construction`, else building_placed → construction_completed),
`loop_produce` (`is_producing`, else production_started/completed), `loop_mine`
(`is_harvesting` on a unit), `loop_hum` (any other building unless `is_powered` is false).
All four properties are optional bools; low power dims the player's hums and production by 6 dB.
Hums have identities: a sound set with an event `loop_hum_<set>` uses it (survey lab, hub,
forge, spire, warden). Other factions' buildings hum only while `is_visible_to_player` is true.
A unit with `loop_hum_<set>` hums while idle (`is_dormant`, else `speed` below 0.3), and when
its `is_dormant` turns false where the player can see it, `unit_<set>_wake` plays once.
Movement loops skip units whose `is_visible_to_player` is false. Deaths try `death_<set>` first
(the Warden); weapon sets without an alias fall back to their first word
(`warden_bell_bolt` → `weapon_warden_fire`).

Missions (`MissionSoundRouter`, Phase 5). `objective_added` offers `objective_hidden` for a
hidden objective, else `objective_new`; `objective_completed` offers `objective_done` for a
primary objective, else `objective_done_secondary`; `objective_failed` offers
`objective_failed`; several in one frame make one phrase, the most important. Gameplay's own
`advisor_alert(objective_new | objective_done | objective_failed)` joins that frame's choice
(the AudioEventRouter leaves those kinds alone), and the AdvisorQueue's families
(`objective_hidden` → `objective_new`, `objective_done_secondary` → `objective_done`) share a
throttle, so a signal and an alert for the same moment speak once. `objective_updated` plays
`ui_objective_tick` (not for a hidden objective before it is revealed). Priorities: detected
115, storm 110–112, objective failed 105, time low 100, done 90, hidden 85, secondary done 75,
new 72. `ui_feedback`: `briefing_open` starts the briefing bed (score dips −14 dB),
`briefing_close` stops it, `debrief_open` starts the debrief bed (−18 dB); the launch phrase
plays when the briefing closes, or 0.3 s after `mission_started` if none is open. Storm: the
soonest known, active objective with `countdown_tick` ≥ 0 and `countdown_fails` is the
deadline, checked on `sim_ticked`; 60 s left plays `mus_storm_minute` and brings the `storm`
layer in, 10 s left `mus_storm_countdown`; completing it takes the layer out. Without such an
objective, `advisor_alert(storm_warning | objective_time_low)` starts the minute stage and a
second one (≥ 20 s later) or `storm_final` the countdown.

Stealth (`StealthSoundRouter`, `SuspicionTones`, pure rules in `StealthCues`, `StealthMood`).
The most alarmed watching faction (`alert_level_changed`; the player's own faction ignored)
decides: rising to Suspicious plays `stealth_alert_suspicious`, to Alerted
`stealth_alert_alarm`, back to Unaware `stealth_all_clear`; Alerted decaying to Suspicious is
left to the music. `intruder_spotted` plays `stealth_spotted` once per target per 4 s (silent
when the target belongs to another faction than the player's) and ducks the other buses for
0.5 s. Units in group `units` with `is_cloaked` play the cloak sounds when it changes (their
first reading is the baseline), if the unit is the player's or visible. Suspicion tones:
watchers learnt from `suspicion_raised`/`intruder_spotted` (or group `watchers`) that are
visible to the player, not `is_alerted` and above 0.02 suspicion, ranked by suspicion − 0.5 ×
distance / 70 m, at most two. Stealth music starts once an alert level is reported (an initial
`alert_level_changed(faction, &"unaware", &"unaware")` starts the Unaware score silently) or a
node is in group `watchers`; a watcher's suspicion alone does not (a Wisp in Conquest keeps the
combat score). It rises at once and falls after the lower level has held 6 s (from Alerted) or
4 s (from Suspicious). `MusicArbiter`: with stealth active its state plays, except that combat
always wins and tension or aftermath win over Unaware. `mission_started` resets all of it.

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
