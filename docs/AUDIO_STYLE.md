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
- **The dust storm is the planet speaking** (Phase 6, Kessel Reach's rule). Nothing in it is
  tonal except its release; it lives on its own **Weather** bus:

  | Event | Sound |
  |---|---|
  | `storm_front_rumble` | the warning (`storm_incoming`): a wall of low noise rolling in from the left, far thunder inside it, the dust hiss arriving last (8.5 s, −25) |
  | `amb_storm_wind` / `_grit` / `_throb` | the bed: a surging wide wind body (40 s loop, −25); sand hissing on hulls with grain crackle and faint struck-panel rings (33 s, −29); a slow pressure throb on D2 (24 s, −31). Different lengths, so the surges never line up twice |
  | `storm_gust_1..4` | flat stereo surges sweeping across the field (−26) |
  | `storm_debris_1..5` | positional, 12–38 m around the listener: pebbles skittering, a loose panel rattling, a tumbling can, grit on armour, a scrape and thud (−26) |
  | `storm_passed` | the release: the wind falling down a closing band, then chimes D A E rising as the air opens (−24) |
  | `mus_sting_storm_final` | Survey's end: the Trail motif on the reed, each note further under a rising wall of noise; the hanging G# is swallowed, thunder, only wind left (−22) |
  | `advisor_storm_passed` | a muffled B+F# opening and lifting into D+A, a high A+E answering (−21) |

  While the storm is up the world is heard *through* it: a low-pass on the SFX and Ambience
  buses closes from 20 kHz to 900 Hz and they dip (SFX −4 dB, Ambience −10 dB). Unit replies
  (Barks), the Advisor, the interface, discovery and stealth stingers are on other buses and
  stay clear.
- **Kessel Reach's ambience is layered and never the same twice** (Phase 6). Two beds of
  different lengths loop together (`amb_kessel_wind` 48 s, `amb_kessel_air` 37 s: high thin
  air, a sand-sift, rock-edge whistles on G# and C#), each wandering to a new level every
  7–15 s (wind −5..0 dB, air −9..−1 dB). Positional details (group `ambdetail`, −23..−25,
  heard from 14–55 m) come every 6–14 s: `amb_rock_settle` (stone cooling and trickling),
  `amb_dust_devil` (a whirl passing), `amb_flux_vent` (a far hiss with bubbles on G# B C# D, at
  the nearest Flux node), `amb_combine_industry` (clanks, a drop hammer, a hydraulic sigh, a
  flat shift horn: off the Concord key, at a Combine base the player has seen). Near an
  Antecedent site `amb_kessel_hush` rises (a faint bell drone on D and G#, glass shimmer) and
  the wind and the details step back.
- **Restraint.** Interface sounds are short (≤ 0.3 s) and dry; replies carry a small room;
  only music and ambience are wide and wet.

- **The complete Kessel score** (Phase 6). Six more synchronised layers of the explore clip:
  `melody_b` (a second set of phrases on the chime-and-reed voice), `melody_c` (the motif
  augmented, low, on marimba with a chime above), `pulse_b` (the pulse in a 3+3+2 figure),
  `drums_b` (half-time taiko, tom runs, off-beat frame drum), `urgency` (base under attack: a
  muted sixteenth ostinato of D against G#, a reed siren rising a fourth every two bars) and
  `heavy` (heavy combat: low reed brass in half notes on root and fifth, doubled taiko, a
  grinding sub). Layers sharing a *variant group* (`melody`, `melody_b`, `melody_c`; `pulse`,
  `pulse_b`; `drums`, `drums_b`) take turns, one per 48 s loop, never the same twice running,
  so fifteen minutes in one state passes through 12 different combinations of material.
  States (dB per layer in `kessel_reach.tres`):

  | State | Sounding | Fade |
  |---|---|---|
  | `explore` | pad, pulse*, melody*, trail, storm†, urgency −4‡ | 3 s |
  | `calm` | pad, melody* −6, trail −3, storm†, urgency −6‡ | 3 s |
  | `tension` | pad −2, pulse* −6, drive, trail −8, storm†, urgency‡ | 3 s |
  | `combat` | pad −4, drive −3, drums*, brass, storm† −5, urgency −4‡ | 3 s |
  | `combat_heavy` | pad −7, drive −5, drums* −2, brass −3, heavy −2, storm† −6, urgency −6‡ | 1.5 s |
  | `aftermath` | pad, melody* −5, drive −14, trail −4, storm†, urgency −8‡ | 3 s |
  | `victory` / `defeat` | quiet pads (defeat keeps storm† −6: the final storm outlasts it) | at once |
  | `stealth_unaware` / `_suspicious` / `_alerted` | as in Phase 5, plus urgency‡ −6 / −5 when the base is hit | 4 / 1.5 / 0.5 s |

  \* one variant of the group. † the `storm` layer only sounds with the storm (gain from the
  weather: silent below 0.1, −14 → −3 dB up to 0.8; or 0 dB from the Survey deadline). ‡ the
  `urgency` layer only sounds for 24 s after an `under_attack` phrase. Heavy combat is heat
  ≥ 70 (a full battle; a skirmish settles at 25–50) and steps back to combat after 6 s below
  35. Every change waits for the next beat. Two changes a fade cannot hide get a hit on that
  beat (`ScoreTransitions`): into combat or heavy combat from anything not already fighting,
  `mus_hit_combat` (air sucked in, two taiko strikes, a low reed D, −24); combat or heavy into
  aftermath, `mus_hit_aftermath` (the reed falling D A F# D, a soft bell, −25). combat ↔
  combat_heavy is a swell on the same drums; stealth_alerted already has its alarm and drums;
  victory and defeat have their stings.
- **The mission-select theme** `mus_menu_theme` (48 s loop, −26): the Trail motif stated in
  full and broad on chime and reed, stepping up through the chords, finally answered by its
  victory form rising to the high D, over the four chords and a slow marimba pulse.
- **Endings.** A defeat inside a storm (intensity ≥ 0.5) plays `mus_sting_storm_final`; a defeat
  within 45 s of the enemy banking Intel plays `mus_sting_outsurveyed` (the motif on the reed,
  then the Combine's bent D A Bb on ring-modulated saws climbing over it into a tritone);
  otherwise `mus_sting_defeat`. The score dips 6 dB under any ending sting.
- **The Survey race.** Another faction's Intel rising plays `discovery_enemy_intel` (a
  ring-modulated chirp falling a tritone, data ticks, a "bank" thunk: the Combine sound world,
  −24, Discovery bus, 4 s cooldown); gameplay's `advisor_alert(&"enemy_intel")` is the Meridian
  phrase `advisor_enemy_intel` (D+A answered by a bent Bb+F, twice, the second sagging; 25 s
  throttle).
- **Phase 6 interface and props.** `ui_pause_open` / `_close` (marimba A → D with a soft thump /
  D → A), `ui_slider_tick` (a tiny wooden F#6, −34), `ui_toggle` (a latch click and a glass G#),
  `ui_hint_show` (chime B5 → E6 with air), `ui_hint_dismiss` (glass E6 → B5). Props die as
  `death_prop_<kind>` on the Explosions bus: `crates` (metal crash, buckling, lids rattling,
  −23), `tank` (gas burst, boom, long venting hiss, −21), `barrier` (wire twang, a post snapping,
  −24), `boulder` (crack, rockfall, dust, −22). Props never raise `under_attack` and never heat
  the score.

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
| `weather` beds (Phase 6) | Ogg stereo, loop | wind −25, grit −29, throb −31 | 40 / 33 / 24 s (multiples of 64 samples), own players on the **Weather** bus |
| `weather` one-shots | Ogg stereo / WAV mono | front −25, passed −24, gusts −26, debris −26 | gusts flat, debris positional |
| `ambience` (Phase 6) | Ogg stereo, loop | air −33, hush −32 | 37 / 29 s, AmbienceDirector's own players |
| `ambdetail` | WAV mono | rock, devils −24, vents −25, industry −23 | positional, priority 10 (first to lose a voice) |
| `music` Phase 6 layers | Ogg stereo, loop | melody_b/c −27, pulse_b −29, drums_b −26, urgency −29, heavy −27 | Kessel explore grid |
| `sting` Phase 6 | Ogg stereo | hits −24 / −25, storm final −22, out-surveyed −22 | flat, Music bus |
| `bed` menu theme | Ogg stereo, loop | −26 | 48 s |
| `ui` Phase 6 | WAV mono | −27 (slider tick −34, hint show −26, hint dismiss −29) | |
| `explosion` props | WAV mono | crates −23, tank −21, barrier −24, boulder −22 | positional |
| `advisor` Phase 6 | WAV mono | storm passed −21, enemy Intel −20 | flat, Advisor bus |
| `discovery` enemy Intel | WAV mono | −24 | flat, Discovery bus |

Also checked on every build: DC offset ≤ 0.002, energy below 25 Hz ≤ 3 %, duration within the
recipe's bounds, and for loops the seam (no step, kink or level jump bigger than the loop's own
most abrupt moment). Ogg files are decoded again and compared with the source (codec fidelity).

## Final mix (Phase 6)

**Buses.** `Master` ← `Music`, `Ambience`, `Weather`, `SFX` (`Weapons`, `Explosions`, `Units`,
`Buildings`), `Voice` (`Barks`, `Advisor`), `UI`, `Discovery`, `Stealth`. Player settings:
Master → `master_volume`, Music → `music_volume`, UI → `ui_volume`, everything else
(Ambience, Weather, SFX, Voice, Discovery, Stealth) → `sfx_volume`.

| Bus | Effects | Why |
|---|---|---|
| Master | HardLimiter, ceiling −1 dBFS | safety net; the measured worst case never reaches it |
| Music | Compressor, sidechain Voice: −30 dB threshold, 3:1, 8 ms / 450 ms | the Advisor and unit replies duck the score |
| Ambience | Compressor, sidechain Voice: −32 dB, 2.5:1; `StormMuffle` low-pass (off when clear) | ducks under voices; muffled in a storm |
| Weather | Compressor, sidechain Voice: −32 dB, 2.5:1 | the storm ducks under voices too |
| SFX | `StormMuffle` low-pass (off when clear) | the battle heard through dust |

No compressor sits on SFX: the measurements below leave 5–8 dB of headroom before the limiter
in the worst case, and a glue compressor would pump a battle without protecting anything.

**Ducking and overlays** (all added to the bus faders by the AudioService):

| Rule | Buses | Amount |
|---|---|---|
| Advisor / replies over music | Music, Ambience, Weather | sidechain compressors (above); measured: Music −30.4 LUFS while the Advisor speaks against −25.3 over the whole worst case |
| Discovery resolve phrase | Music −8, Ambience −6, SFX −5 dB | 80 ms attack, held for the phrase, 1 s release (`BusDucker`) |
| Stealth spotted | same as discovery, 0.5 s | |
| Briefing / debrief / menu bed | the score (Music player) | −14 / −18 / −40 dB, 10 dB/s |
| Ending sting over the score | the score | −6 dB for the sting's length |
| Storm muffle (intensity 0.55 → 0.95) | SFX −4, Ambience −10 dB, low-pass 20 kHz → 900 Hz | lifts as the storm does; resets on `mission_started` |
| Storm cover | the planet's ambience beds | down to −16.5 dB at full storm |
| Pause menu open | Music −6, Ambience −8, Weather −8, SFX −10, Discovery −6, Stealth −6 dB | UI, Advisor, replies unchanged |
| Mission-select menu | Ambience −10, Weather −10 dB | under the menu theme |
| Camera zoom | Units +1.5 → −7, Buildings 0 → −4, Weapons 0 → −2, Music −3 → 0, Ambience −4 → 0 dB | close: detail; far: score |

**Voice budget.** 16 flat and 32 positional players, priority stealing, per-event caps and
cooldowns; the combat mixer admits at most 8 fire / 5 impact / 4 blast starts per 0.5 s.
Lowest priorities, first to lose a voice under load: ambience details 10, storm debris 25,
movement and base loops 30, storm gusts 35. Measured under the worst case below: 30–31
voices busy at once (of 48).

**Measured** (`tests/audio/test_final_mix.gd`, through the real buses, headless Godot at
44.1 kHz, 5.5 s recorded after 2.5 s to settle, BS.1770 K-weighted and gated, zoom 0.5, default
settings: master 1.0, music 0.8, effects 1.0):

| Scene | Master integrated | Master peak (pre-limiter) |
|---|---|---|
| explore: the explore score and the planet ambience | −27.2 LUFS | −16.0 dBFS |
| worst case: `combat_heavy` + urgency + storm layers, a full storm (beds, gusts, debris, muffle), 6 weapon and 6 impact starts per 50 ms frame within 35 m plus blasts, an Advisor or stealth alarm every 1.5 s, interface clicks | −19.4 LUFS | −5.7 dBFS (limiter never engaged) |

Worst-case loudness per category (each bus before its fader, LUFS): Music −25.3, Weather −25.8,
Weapons −24.7, Explosions −25.7, Advisor −21.4, Stealth −22.8, UI −36.4, Ambience −64.7
(covered by the storm; −37 to −38 in clear air under the explore score at −24). While the
Advisor speaks the Music bus sits at −30.4 against the Advisor's −20.9 (9.5 LU clear).
The test asserts: Master below −0.9 dBFS, the mix below 0 dBFS before the limiter, the worst
case within −24..−13 LUFS and explore within −36..−22 LUFS, the voice budget, and the Advisor
at least 3 LU over the music while it speaks.

The first measurement found one problem, fixed: heavy combat with the storm and urgency layers
stacked integrated to −21.7 LUFS of music, louder than the weapons (−25) and level with the
Advisor. `combat_heavy` was pulled back 2–4 dB per layer, the storm layer capped at −3 dB
(the Weather beds carry the storm), and urgency set to −4..−6 under fighting states.

## Naming

`<group>_<subject>_<action>[_<variation>]`, lowercase. Files live in
`game/assets/audio/<folder>/`, events in `game/data/sounds/<group>/<event>.tres`.

- `ui_click`, `ui_group_assign`
- `unit_<sound_set>_<select|move|attack>_<1..n>` → event `unit_<sound_set>_<kind>`
- `move_<chassis>` (file) → event `move_<sound_set>` (one chassis can serve many sound sets)
- `world_order_ping`, `advisor_alert`, `amb_<planet>_<bed>`, `mus_<planet>_<state>_<layer>`

- `building_<sound_set>_select`, `base_<what>`, `loop_<what>`, `advisor_<alert kind>`
- `amb_storm_<layer>`, `storm_<what>[_<n>]` (group `weather`, Weather bus), `amb_<what>[_<n>]`
  details (group `ambdetail`), `death_prop_<kind>` (a prop's `def.sound_set` is `prop_<kind>`),
  `mus_hit_<state>` (transition hits)

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

Storm (`StormSound`, pure rules in `StormCues`, Phase 6). `storm_incoming` plays
`storm_front_rumble`. `storm_changed(intensity)` sets the target; the heard intensity follows at
0.6 per second, and each frame drives the three bed layers (equal-power ramps: wind 0.05 → 0.7,
grit 0.3 → 1, throb 0.5 → 1; each starts at a random point of its loop), the muffle, the score's
`storm` layer (the higher of this and the Survey deadline's request) and the ambience cover.
Gusts start at 0.25 (every 14 s → 3.5 s, ×0.6–1.4 random), debris at 0.45 (9 s → 1.6 s). A storm
that peaked at ≥ 0.5 and falls below 0.08 plays `storm_passed`. `mission_ended` freezes the
storm: it may still build but never lifts or passes (and picks the ending sting, above);
`mission_started` resets everything at once. Gameplay's Advisor kinds `storm_warning` (110),
`storm_passed` (88, 10 s throttle) and `enemy_intel` (66, 25 s) are ordinary `advisor_alert`s;
since Phase 6 `storm_warning` no longer starts the Survey deadline stages (only
`objective_time_low` and `storm_final` do, for missions without a deadline objective).

Ambience (`AmbienceDirector`, pure rules in `AmbienceCues`, Phase 6). Every 1.5 s it reads the
scene: the nearest node in `resource_nodes` whose `resource()` is `&"flux"` (near: 10 → 60 m),
the nearest `discovery_sites` node whose `discovery_type` is `&"antecedent"` (15 → 70 m), the
nearest building of another faction (`buildings`, `faction` ≥ 0) that has been
`is_visible_to_player` at least once this mission (40 → 140 m). Nearness glides at 0.4/s. Detail
weights: rock 1, dust devils 0.45 (none in a storm), vents 0.08 + 2.2 × near, industry
2.6 × near (only with a seen base to put it at); everything × (1 − 0.75 × hush). The gap is
6–14 s × (1 + hush) × (1 + 3 × storm). The same kind never plays twice running when another can.

Score extras (Phase 6). `MusicClip.layer_groups` names variant groups and `loop_beats` the loop
(64); the MusicDirector picks the next variant of each group at every loop boundary
(`pick_variant`, no repeats). `AudioEventRouter.on_alert_played` tells the AudioService when a
phrase starts; `under_attack` raises the `urgency` layer for 24 s. A state change that
`ScoreTransitions.hit_for(before, after)` names plays its hit via `MusicDirector.at_next_beat`.
`ui_feedback`: `menu_open` starts `mus_menu_theme` as a bed (score −40 dB) and the menu overlay,
`menu_close` (or `briefing_open`, or `mission_started`) ends it; `pause_open` / `pause_close`
apply and lift the pause overlay; `slider_tick`, `toggle`, `hint_show`, `hint_dismiss`,
`pause_open`, `pause_close` play `ui_<kind>` by the naming rule. `Audio.stop_all_voices()`
stops every one-shot and world loop (the score, ambience and storm go on).

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
