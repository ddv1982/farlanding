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
  | `talon` (Phase 8c, aircraft) | high, A5–E6 | a quick pair of strokes, a breath gliding behind them | fifths and fourths, airy marimba + glass, a breathy reed glide that lifts (select) or sinks (move) |

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

- **Aboard the Meridian** (Phase 7, the campaign layer). Between landings the player is on a
  quiet survey ship, and everything there is the *Meridian's own voice* (the Advisor's sine dyads)
  rather than the Concord's outdoor instruments:

  - **The ship theme** (`res://data/sounds/music/meridian.tres`, one 70 BPM loop of 16 bars,
    54.86 s, six synchronised layers in `music/meridian/`). Still D Lydian, but its own harmony:
    F#m9 → Bm(add9) → Dmaj9/A → E6/9, four bars each, ending on the bright Lydian II so it never
    quite comes home. `pad` (the Meridian dyad as a glass pad: near-unison sine pairs, slow
    tremolo, soft bass), `pulse` (sonar chimes on dotted quarters, drifting three against four),
    `melody` (the theme on the Meridian lead, a pure sine with a chime touch: four questions, the
    last hanging on G#), `title` (the theme broad and low on a warm reed with bells), `web`
    (muted high marimba sixteenths and data ticks: thinking), `loadout` (a soft heartbeat on two
    and four, brushed eighths, a reed drone: getting ready). One state per screen; moving between
    screens fades layers on the beat and never restarts the piece:

    | Screen / state | pad | pulse | melody | title | web | loadout | fade |
    |---|---|---|---|---|---|---|---|
    | `title` | 0 | – | – | 0 | – | – | 4 s |
    | `star_map` | 0 | 0 | 0 | – | – | – | 3 s |
    | `meridian` | 0 | −4 | −6 | – | – | – | 3 s |
    | `tech_web` | −2 | −8 | −10 | – | 0 | – | 2.5 s |
    | `loadout` | −2 | −5 | −12 | – | – | 0 | 2.5 s |

  - **Ship ambience.** Two beds of different lengths on the AmbienceDirector's own players,
    wandering in level like the planet's: `amb_ship_hum` (the hull: a hum on D2 with its octave
    and fifth, two generators a hair apart so it beats slowly, a low rumble, a faint hull
    resonance; 41 s, −31, wanders −3..0 dB) and `amb_ship_air` (air handling: a fan band breathing
    at its blade rate, vent hiss, a far pump sighing five times a loop, a faint whine on A6; 29 s,
    −33, −7..−1 dB). Every 5–12 s (twice that on the title, where the beds also sit 6 dB lower) a
    flat ship detail, never the same twice running (group `shipdetail`, stereo, the pan in the
    file): `amb_ship_relay` (two relay clicks and a tiny telemetry beep, −33), `amb_ship_creak`
    (the hull settling: stick-slip friction through hull resonances, −34), `amb_ship_machine` (a
    deck away: a clunk and a servo whirring up, −34), `amb_ship_ping` (a coolant line ticking as
    it cools, −35).
  - **Interface** (Concord glass and wood with a sonar colour on the map):

    | `ui_feedback` kind | Event | Sound |
    |---|---|---|
    | `title_open` | `ui_title_open` | a Meridian dyad swelling D+A → A+E with a glass touch (−28) |
    | `map_open` | `ui_map_open` | an air sweep, chimes A5 → E6, a sonar tick |
    | `map_node_hover` | `ui_map_node_hover` (4 variations) | tiny glass ticks on E7 F#7 A7 B7 (−35), rate-limited (below) |
    | `map_node_select` | `ui_map_node_select` | locking on: a wooden D6, a glass A6, a short sonar ping |
    | `map_launch` | `ui_map_launch` | Meridian dyads climbing D+A, F#+C#, A+E to a high D+A over rising air (1.1 s, −24); the ship theme starts handing over at once |
    | `tech_open` | `ui_tech_open` | the web lights up: glass B5 D6 F#6 A6 |
    | `tech_hover` | `ui_tech_hover` (3 variations) | softer, lower glass ticks (C#7, E7, G#6; −35), rate-limited |
    | `tech_buy` | `ui_tech_buy` | a wooden D5, glass D6 + A6, sealed by a low bell on D3 (with its fifth) that rings on: permanent (1.5 s, −24) |
    | `tech_denied` | `ui_tech_denied` (fallback `ui_invalid`) | two muted wooden notes falling a semitone, a dull stop |
    | `loadout_open` | `ui_loadout_open` | a latch, a slide, marimba A4 → D5 |
    | `loadout_change` | `ui_loadout_change` | a clack and a glass F#6 (−28) |
    | (`tech_unlocked` signal) | `ui_tech_unlocked` | the seal alone, only for a tech granted without a `tech_buy` click (−26) |
    | (`campaign_saved` signal) | `ui_campaign_saved` | two tiny glass ticks and a soft latch (−31) |

  - **Advisor campaign lines** (Meridian dyads through the ship channel, through the Advisor
    queue like every Advisor phrase):

    | Kind | Phrase | Priority / throttle |
    |---|---|---|
    | `campaign_return_won` | home: A+E, C#+G#, then D+A held with its octave, warm (−21) | 92 / 5 s |
    | `campaign_return_lost` | home, quietly: D+A sinking three semitones as its filter closes, a low D under it (−22) | 92 / 5 s (shares the won throttle) |
    | `campaign_intel_banked` | four counting dyads climbing, a held D+A, a low "bank" thunk (−20) | 70 / 8 s |
    | `campaign_route_open` | D+A, E+B, then F#+C# held and opening up, a high ping: new ways (−21) | 60 / 10 s |
    | `campaign_tech_available` | G#+D twice, lifting into A+E, a bright answer (−21) | 55 / 20 s |

- **Thalassa Low is wet, wide and cold** (Phase 8a). Kessel is dry and warm; Thalassa should be
  recognisable within seconds: broadband soft wind over water instead of rock whistles, far surf
  always under it, a low tidal drone, and a score that sways rather than walks.

  - **Key and grid.** F# Aeolian (F# G# A B C# D E): the *same seven pitches* as the Concord's
    D Lydian, so unit replies, the Advisor and the Trail motif never clash with it, but centred
    on F# minor. 63 BPM in **3/4**, 24 bars, 72 beats, 68.57 s (3 024 000 samples, a multiple
    of 64). Chords, six bars each: F#m(add9), Dmaj9(#11) (the Concord's Lydian chord heard as the
    flat sixth), Bm9, C#m7(add11), which leans back and never quite resolves.
  - **Timbres.** No marimba and no taiko: cold *glass* (a sine and its slowly beating twin, a
    faint struck edge), a hollow *flute* (soft sine, breath, slow vibrato), *water plucks* (a
    dark soft FM chime with a long ping-pong echo), a *bowed* low reed, *hull drums* (long low
    thuds with a splash of noise) and *splash* backbeats. Longer, darker rooms (5–6 s).
  - **The tide motif**: F# up a minor sixth to D, a step down to C#, falling to A; long, long,
    short, very long, over two bars: a wave that rises, breaks and draws back. The Trail motif
    (D A B G#) still means discovery: on Thalassa it rings on the Antecedent bell in the `trail`
    layer, and its last quote lands on C# (Thalassa never comes home).
  - **The score** (`res://data/sounds/music/thalassa_low.tres`, layers in `music/thalassa/`):
    the same states, intensities and layer roles as Kessel (the state table is Kessel's with the
    storm column replaced by `tide`), its own material: `pad` (glass and pad chords, a swell every
    two bars), `pulse` (plucks on 1, 2+ and 3), `melody` (the tide motif and answers), `drive`
    (a slow low heartbeat, a muffled tick), `drums` (hull drums in three, splash backbeat,
    triplet shaker), `brass` (bowed-reed stabs, the motif as a call), `trail`, `hush`, `watch`
    (the flat sixth D as its shadow), variants `melody_b` (flute, ending on B), `melody_c` (the
    motif augmented on a low bowed reed), `pulse_b` (a two-against-three hemiola), `drums_b`
    (half time, rolling toms), `urgency` (fast muted F# against the D–G# tritone, a reed siren
    C# → F#), `heavy`, and **`tide`**: rolling low triplet arpeggios that swell like a wave every
    two bars, with surf noise in the same breath. The `tide` layer is driven by gain like the
    storm and urgency layers: silent below level 0.15, then −14 → −2 dB at 0.9 (in 0.5 dB steps).
    Measured offline, each state sums to the same loudness as Kessel's within 0.2 LU.
  - **Re-voiced hits and stings.** The AudioService plays `<id>_<score id>` before the shared
    `<id>` (`ScoreTransitions.voiced`): `mus_hit_combat_thalassa_low` (a wave drawn in, two
    hull drums, a low reed F#; −24), `mus_hit_aftermath_thalassa_low` (the bowed reed falls
    C# A F#, a glass bell; −25), `mus_sting_victory_thalassa_low` (the tide motif answered up to
    the high F# over D → F# with the ninth; −22), `mus_sting_defeat_thalassa_low` (the motif
    sinking to the low F# as the filter closes; −22). Kessel has no variants and keeps its own.
  - **Ambience** (the `thalassa_low` AmbienceSet). Beds: `amb_thalassa_wind` (44 s, −30,
    wanders −5..0 dB, −1.5 dB at high water), `amb_thalassa_surf` (39 s, −33: five long swells a
    loop, each a roll that breaks into a wash; −8..−1 dB, −3 dB at low water → +1 at high),
    `amb_thalassa_drone` (31 s, −34: F# and C# low, slowly beating, a pressure of filtered noise;
    −6..−2 dB, −1 → +2 with the water) and the Antecedent hush (`amb_kessel_hush`, the same
    stillness on every planet). Details (group `ambdetail`, one every 6–14 s):

    | Detail | Sound | Weight |
    |---|---|---|
    | `amb_water_lap` (4) | two to four small laps and a glug (−26) | 0.45 + 1.1 × water level |
    | `amb_shell_click` (3) | shells and pebbles clicking (−26) | 0.15 + 0.85 × (1 − level) |
    | `amb_drip` (3) | drips from wet rock and metal (−28, heard to 90 m) | 0.2 + 0.45 × (1 − level) |
    | `amb_shore_call` (3) | a far, abstract shore call: a sine glide through a soft formant, E6/F#6 → C#6/B5; never a real bird, never twice in 4 s (−27) | 0.3, none in a storm |
    | `amb_buoy_bell` (2) | a far bell buoy on C#4 or F#4, struck twice by the swell (−27, heard to 200 m, never twice in 6 s) | 0.25 + 0.15 × level |
    | `amb_flux_vent` | as on Kessel, only near Flux | 1.6 × near |
    | `amb_combine_industry` | as on Kessel, at a seen base | 2.6 × near |

  - **The tide** (`TideSound` / `TideCues`, on the **Weather** bus, the planet rule like the
    storm). `tide_changed(level)` moves four loops on the TideSound's own players: `amb_tide_low`
    (36 s, −28: dark distant water, slow washes) and `amb_tide_high` (27 s, −27: bright close
    lapping, bubbles, trickles) crossfade with equal power by level, the whole bed rising from
    −9 dB at low water to 0 dB at high (that is its level *and* its brightness);
    `amb_tide_rush` (22 s, −29: a band of water noise that climbs for ever, a Shepard figure, and
    a rushing flow) comes in while the level climbs and `amb_tide_pull` (25 s, −29: the same
    figure falling, a pebbly backwash rattle and a sucking gurgle) while it falls, by the
    smoothed rate (from 0.002 per second, full at 0.012, −2 dB at most). The heard level follows
    reports at 0.25 per second at most. `tide_turning(seconds, rising)` plays the warning:
    `tide_turn_rising` (bell tones F#4 B4 F#5 going up, short-short-long, over a swelling wash)
    or `tide_turn_falling` (F#5 C#5 F#4 going down, long-short-long, over a draining hiss); both
    −24, flat, never twice in 5 s. The TideSound also tells the AmbienceDirector the level (beds
    and details above) and the score its `tide` layer gain.
    No report, no tide (Kessel never hears it). The first report after `mission_started` is
    where the sea already is: taken at once, no motion, and everything fades in over 3 s, so a
    restored landing (which re-emits `tide_changed`) picks up mid-level without a jump cut or a
    false rush. `mission_started` and going aboard reset it.
  - **Advisor** (Meridian dyads, through the Advisor queue):

    | Kind | Phrase | Priority / throttle |
    |---|---|---|
    | `tide_rising` | F#+C#, A+E, then B+F# gliding up a step: a climb that keeps going (−19) | 108 / 20 s |
    | `tide_falling` | B+F#, A+E, then F#+C# sliding down a step: the fords open (−20) | 86 / 20 s |
    | `units_in_water` | the D+G# warning tritone twice, wobbling as if under water (−19) | 104 / 25 s |
    | `artefact_taken` | the Trail motif's D+A bent down at once to the Combine's Bb+F, twice, the second sagging (−19) | 113 / 10 s |
    | `artefact_secured` | D+A, B+F#, answered home: a held D+A with its octave (−20) | 95 / 8 s |

    An unheard `tide_rising` and a following `tide_falling` (or the other way round) cancel,
    like low power and power restored.
  - **Recovery mission** (Phase 8a): `ui_feedback` `artefact_pickup` → `ui_artefact_pickup` (a
    small Antecedent bell lifting D6 → A6, a soft latch; −27, 0.39 s), `artefact_drop` →
    `ui_artefact_drop` (A6 → D6 and a soft low thud; −28, 0.40 s). The carried artefact hums
    `loop_hum_artefact` (6 s loop, −31: an Antecedent drone on D and G# beating slowly, a glassy
    shimmer swelling twice a loop; positional, one at a time, heard within 50 m): BaseLoops hums
    any Node3D in group `artefacts` with `loop_hum_<def.sound_set or sound_set, else artefact>`,
    carried or lying down, while `is_visible_to_player` is true or absent.

- **Emberfall is hot, heavy and close** (Phase 8b). Kessel is dry and warm, Thalassa wet, wide and
  cold; Emberfall should be recognisable within seconds by its weight: a low rumble always under
  everything, lava moving, a hot narrow wind, rock ticking as it cools, and a slow score in four
  with a sub on the root (a low end neither other planet has).

  - **Key and grid.** C# Phrygian (C# D E F# G# A B): the *same seven pitches* as the Concord's
    D Lydian, so replies, the Advisor and the Trail motif never clash, but centred on C# with the
    flat second D leaning on it. 56 BPM in **4/4**, 16 bars, 64 beats, 68.57 s (3 024 000
    samples). Chords, four bars each: C#m(add11), Amaj9, Bsus4(add9), Dmaj7(#11); the D block
    sinks back onto C# at the loop (the Phrygian cadence: the Concord's own chord falling into
    the planet's). A sub sine on the root (C#1, A1, B1, D1) sits under the pad.
  - **Timbres.** No glass, no marimba, no taiko: a low saturated *forge horn* (two bright reeds
    a few cents apart), *anvils* (short inharmonic metal), *basalt drums* (deep thuds with a
    pitch fall, a sub never below 40 Hz, stone grit), *bowed metal* (inharmonic partials
    swelling slowly: heat haze) and dark metal *tines*. Short, close rooms (1.5–3 s).
  - **The pressure motif**: C# up a semitone to D and back, then down a fourth to G#; short,
    short, long, very long: a vent drawing breath and letting it go. The Trail motif rings on the
    Antecedent bell in the `trail` layer and hangs on G# (the planet's fifth).
  - **The score** (`res://data/sounds/music/emberfall.tres`, layers in `music/emberfall/`): the
    same states, intensities and layer roles as Kessel and Thalassa (17 layers: Thalassa's with
    `tide` replaced by `pressure`, plus `holdout`). `pad` (dark chords, bowed metal, the sub,
    a heat shimmer), `pulse` (tines in 3+3+2 eighths over a root thud), `melody` (the motif on
    horn and bowed metal), `drive` (muted horn eighths, the flat second on the last eighth),
    `drums` (basalt drums, anvil backbeat, grit shaker), `brass` (horn stabs, the motif as a
    call), `trail`, `hush`, `watch` (D as its shadow), variants `melody_b` (bowed metal and
    anvil, ending on G#), `melody_c` (the motif augmented on the low horn), `pulse_b` (an anvil
    simmer in sixteenths), `drums_b` (half time, one huge drum, rolling toms), `urgency` (C#
    sixteenths against the D–G# tritone, a horn siren G# → C#), `heavy`, and two gain-driven
    layers:
    - **`pressure`**: a throbbing sub in eighths, magma bubbles, a hiss band climbing and
      breaking every two bars, a beating whine on G#. Its gain follows the most pressing warned
      vent within its radius + 25 m of one of the player's buildings (`EruptionCues.music_gain_db`
      of that vent's progress: silent below 0.1, then −14 → −2 dB at 0.9, in 0.5 dB steps). It
      sits at the state's level like `tide` did (−5/−6 under combat, −6 in defeat).
    - **`holdout`**: a steady march, tines in eighths, frame hits on 2 and 4, a horn calling
      root → fifth at each block (the Concord's D → A in the D block). Silent until a Holdout's
      survival timer has two minutes left (−6 dB), full from one minute. State levels: explore,
      tension, aftermath 0; calm −3; combat −3; heavy −5; stealth −6/−4/−3; endings silent.
  - **Re-voiced hits and stings** (`<id>_emberfall`): `mus_hit_combat_emberfall` (a vent drawing
    in, a basalt drum, an anvil, a low horn C#; −24), `mus_hit_aftermath_emberfall` (the horn
    sighs D → C#, a cooling hiss, an anvil ring; −25), `mus_sting_victory_emberfall` (the motif
    answered upward into the Concord's Dmaj7: the planet's C# lifts a semitone home; −22),
    `mus_sting_defeat_emberfall` (the motif sinking to the low C# as a rumble rises and the
    filter closes; −22).
  - **Ambience** (the `emberfall` AmbienceSet). Beds: `amb_emberfall_rumble` (41 s, −31: deep
    rumble with slow surges and a C#1/C#2 throb; wanders −4..0 dB), `amb_emberfall_lava`
    (35 s, −33: a thick slow churn, crust crackle, slow bubbles and plops; −7..−1),
    `amb_emberfall_wind` (46 s, −31: hot, dry, narrower than Thalassa's, gritty, a fast heat
    flutter in the gusts; −6..0) and the Antecedent hush. Details (one every 6–14 s):

    | Detail | Sound | Weight |
    |---|---|---|
    | `amb_rock_crack` (3) | rock splitting as it cools, flakes falling (−25) | 0.6 |
    | `amb_ember_tick` (3) | tiny hot ticks and a fizz (−28, heard to 70 m) | 0.45 |
    | `amb_gas_hiss` (3) | a hiss of gas from a crack, a soft pop (−26), at the nearest Flux vent | 0.1 + 1.4 × near vent |
    | `amb_distant_collapse` (2) | far off, a slab gives way: a low give, rumble, tumbling debris (−26, to 220 m, never twice in 8 s) | 0.15 |
    | `amb_flux_vent` | as on Kessel, only near Flux | 1.0 × near vent |
    | `amb_combine_industry` | as on Kessel, at a seen base | 2.6 × near base |

  - **Eruptions** (`EruptionSound` / `EruptionCues`, the planet rule, on the **Weather** bus,
    on the node's own positional players). `eruption_warning(vent, seconds, radius)` starts a
    build-up at the vent that is a **clock**: everything is a function of the seconds left, never
    of the warning's length, so the same moment always sounds the same:
    - two loops, `eruption_build_low` (4 s, −24: a deep beating growl, slow gloops, grinding rock)
      and `eruption_build_high` (3 s, −24: a pressurised hiss, rattling stones, a whistle on G#),
      crossfade with equal power over the last 30 s, and their pitch rises from 0.65 to 1.7 in
      equal steps per second (1.4 octaves);
    - the level rises from −18 dB (60 s or more left) to −12 (30 s) to 0 (the eruption);
    - `eruption_knock` (4 variations, −24: a rock knock with a burp of gas) comes every
      0.15 × seconds left (0.12–2.5 s): **one every 1.5 s means ten seconds left**, a rattle means
      one or two.

    The clock is the simulation's (`sim_ticked`): it runs at most one tick past the last tick
    heard, so a paused game holds the build-up and a faster game speed hurries it.
    A new warning fades in over 1.5 s; a repeated one for the same vent only moves its deadline;
    a restored mission that re-emits the seconds left picks up at the same pitch, fading in. A
    warning with negative or infinite seconds calls it off; so does `ui_feedback`
    `vent_release` (for the warned vent nearest the camera within 80 m: that signal does not
    name the vent); a warning 2 s past its deadline with no eruption is dropped.
    `eruption(vent, radius)` stops the vent's build-up and plays `eruption_blast` (3 variations,
    6.5 s, −18: a crack, a deep saturated boom, a roar of gas, a long low tail with rocks coming
    down) at the vent, −3 dB at a 6 m radius to +2 dB at 26 m; a blast the player can see ducks
    the mix (BusDucker: Music −8, Ambience −6, SFX −5 dB, held 0.9 s; not twice within 1.5 s).
    The Weather bus itself is not ducked. **Voice limit**: at most two build-ups and two blasts at
    once, ranked by radius ÷ distance (nearest and largest win); a warning that loses its slot is
    still followed and returns when a slot frees, a new blast replaces the weakest ringing one only
    if it weighs more. A vent whose `is_visible_to_player` is false is −8 dB and dull (its players'
    distance filter at 900 Hz instead of 5 kHz), never silent. `mission_started` and going aboard
    reset everything.
  - **Holdout** (`HoldoutSound` / `HoldoutCues`): a survival timer is a known, active objective
    with `countdown_tick` ≥ 0 and `countdown_fails` false (SurviveObjective). The
    MissionSoundRouter's deadline mechanism ignores such timers on purpose (`is_deadline` is
    false for them), so no storm minute or countdown of doom plays; instead:

    | Seconds left | Heard |
    |---|---|
    | ≤ 120 | the score's `holdout` layer at −6 dB |
    | ≤ 60 | `mus_holdout_minute` (−24, 5.8 s: a far engine swelling in and passing, a horn C# → G# → high C#, two tines); the layer at full |
    | ≤ 10 | `mus_holdout_engine` (4 s loop, −26: the dropship hovering on C# and G#, rotor beats, a turbine whine) on the HoldoutSound's own player (Music bus), its level −14 → 0 dB and pitch 0.94 → 1.0 as the seconds run out |
    | `advisor_alert` `extraction_arrived`, or the objective completing (first of the two, once) | `mus_holdout_arrived` (−22, 5 s: the engine's C# and G# glide up a semitone into the Concord's D and A, a chime chord D F# A D, a horn D → A); the engine fades over 0.8 s; the layer goes |
    | the objective failing | the engine stops, the layer goes, no resolution |

    A restored Holdout enters the right stage at once (with ten seconds or fewer left: straight to
    the engine, no minute cue). `extraction_arrived` without a Holdout running (an Infiltration's
    extraction) plays nothing here.
  - **Advisor** (Meridian dyads, through the Advisor queue):

    | Kind | Phrase | Priority / throttle |
    |---|---|---|
    | `extraction_arrived` | D+A, F#+C#, A+E quick, landing on a high D+A with its octave: go (−19) | 117 / 10 s |
    | `surge_incoming` | the caldera's surge: four dyads climbing by step over a swelling D–G# pedal (−19) | 111 / 20 s |
    | `eruption_warning` | C#+G# pressing up to D+A, twice, faster, the last bending up a step over a low growl (−19) | 109 / 12 s |
    | `eruption_damage` | the D+G# tritone struck, then sagging a tone (−19) | 106 / 20 s |
    | `wave_incoming` | F#+C# short, then G#+D long: a step into the warning tritone (−20) | 98 / 15 s |
    | `extraction_inbound` | A+E, then D+A held, leaning upward: hold on (−20) | 94 / 20 s |

    Some news makes an older unheard alert moot without being moot itself (`REPLACES`):
    `extraction_arrived` drops a waiting `extraction_inbound`, `eruption_damage` a waiting
    `eruption_warning`.
  - **Interface**: `ui_feedback` `vent_release` → `ui_vent_release` (a valve clack, a short sharp
    hiss falling away, a thud under it; −26, 0.36 s: satisfying), `vent_denied` →
    `ui_vent_denied` (a stuck valve: two dull clunks and a choked buzz on D+G#; −28, 0.27 s;
    `ui_invalid` as fallback).

- **Verdance is hushed, alive and watchful** (Phase 8c). Kessel is dry and dusty, Thalassa wet and
  wide, Emberfall low and hot; Verdance should be recognisable within seconds by what is overhead:
  leaves always moving in the crowns, a chorus of small invented creatures, a shallow stream
  somewhere, and a score of wood and breath that sways in six.

  - **Key and grid.** B Dorian (B C# D E F# G# A): the *same seven pitches* as the Concord's D
    Lydian, so replies, the Advisor and the Trail motif never clash, but centred on B minor with
    the bright Dorian sixth G#. 70 BPM (dotted quarters) in **6/8**, 40 bars, 80 beats, 68.57 s
    (3 024 000 samples); the score's `bpm` is 70 and its beat the dotted quarter, `loop_beats` 80.
    Chords, eight bars each: Bm(add9), E(add9) (the Dorian IV: G# in a major chord), Dmaj7(#11),
    A(add9)/C#, F#m7(add11), which leans back into Bm at the loop.
  - **Timbres.** Wood and breath; no glass, no taiko, no forge. A soft-malleted *marimba* (the
    Concord's own wood), *log drums* (slit drums: two tongues a little over an octave apart, a dull
    knock), a breathy wooden *flute* (near-sine, a vibrato that grows in, a tuned breath and a
    chiff), a low *reed*, *hand percussion* (palm drums, seed shakers, finger taps). Medium, soft
    rooms (2.5–3.5 s): a space under leaves.
  - **The canopy call**: F# up a fourth to B (a call), then A, G#, F# falling (an answer from
    somewhere else); short-long, short-short-long: two voices in the trees, not quite sure of each
    other. The Trail motif rings on the Antecedent bell in the `trail` layer and hangs on G#.
  - **The score** (`res://data/sounds/music/verdance.tres`, layers in `music/verdance/`): the
    same states, intensities and layer roles as the other planets (15 layers: Kessel's without
    the storm; no planet-rule layer, since the canopy is heard in the ambience and the rustles):
    `pad` (reed-and-breath chords, flute air on the top notes), `pulse` (marimba in the 6/8 sway
    on eighths 1, 3, 4, 6 over a log drum), `melody` (the call and its answers on the flute,
    marimba marking each onset), `drive` (muted log-drum eighths on the bass, G# on the last
    eighth), `drums` (log drums and palm drums in six, seed shaker), `brass` (reed stabs, the call
    as a horn signal), `trail`, `hush` (breath on chord tones, a far marimba drop), `watch` (a low
    log-drum lub-dub, finger taps, a G# shadow), variants `melody_b` (high flute, ending on G#),
    `melody_c` (the call augmented on the low reed), `pulse_b` (plucked wood in quarters, three
    against the bar's two), `drums_b` (half time, one deep log drum, rolling palm drums),
    `urgency` (marimba sixteenths of B against the D–G# tritone, a reed siren F# → B) and
    `heavy` (low reeds in dotted halves, doubled drums, a growl). State levels are Emberfall's
    without its two planet layers.
  - **Re-voiced hits and stings** (`<id>_verdance`): `mus_hit_combat_verdance` (leaves rushing in,
    two log drums, a low reed B; −24), `mus_hit_aftermath_verdance` (the flute sighs C# → B,
    leaves settling, a marimba ring; −25), `mus_sting_victory_verdance` (the call answered upward
    to the high D over D major: B minor opening into its relative major, the Concord's key; −22),
    `mus_sting_defeat_verdance` (the call falling to the low B as a breath thins and the filter
    closes; −22).
  - **Ambience** (the `verdance` AmbienceSet). Beds: `amb_verdance_leaves` (43 s, −31: a soft
    broadband hush in the crowns, leaf flutter that thickens in slow gusts high up; wanders
    −5..0 dB), `amb_verdance_chorus` (37 s, −33: three kinds of invented insects as pulsed high
    sines in overlapping trill groups, a slow far piping in key, little runs of wooden "tok"s;
    −8..−1), `amb_verdance_stream` (29 s, −32: a shallow stream, a running wash and many small
    bubbling chirps over stones; −9..−3) and the Antecedent hush. No creature is an imitation of a
    real recording: every voice is a pulsed or gliding sine through a formant. Details:

    | Detail | Sound | Weight |
    |---|---|---|
    | `amb_branch_creak` (3) | a big branch flexing: stick-slip friction through wood resonances, a few leaves after (−26, to 120 m) | 0.5 |
    | `amb_canopy_call` (3) | a call and an answer: one invented creature trills a two- or three-note phrase, another, further off and duller, answers lower (−27, to 180 m, one at a time, never twice in 5 s) | 0.45 |
    | `amb_leaf_drip` (3) | water running off leaves: plips and leaf ticks (−28, to 60 m) | 0.4 |
    | `amb_wing_flurry` (2) | something takes off: a burst of wingbeats moving away, a shaken branch (−26, to 120 m, never twice in 3 s) | 0.25 |
    | `amb_flux_vent` | as on Kessel, only near Flux | 1.4 × near vent |
    | `amb_combine_industry` | as on Kessel, at a seen base | 2.6 × near base |

  - **The canopy** (`CanopySound` / `CanopyCues`, the planet rule). The sim emits
    `canopy_cover_changed(unit, covered)` for every faction's ground units. Only the player's own
    units within 55 m of the camera's focus are heard (another faction's rustle would give away an
    ambush the player cannot see): `canopy_rustle_in` going under a crown (3 variations, −27,
    0.6–0.75 s: a soft swell of leaves closing over the unit, a twig, darker at the end) and
    `canopy_rustle_out` coming out (3 variations, −30, 0.4–0.5 s: lighter, brighter, opening),
    positional at the unit on the Units bus. **One gesture per group**: further reports in the
    same direction fold into the rustle while they keep coming less than 0.5 s apart, for at most
    2.5 s (a squad of twenty filing under a crown is one rustle); in and out never start within
    0.2 s of each other. **Shade**: while the camera's focus is under a crown, the Ambience bus's
    low-pass (the storm's `StormMuffle`, shared) closes from 20 kHz to 6 kHz, gliding at 0.8 per
    second (about 1.3 s): the leaves overhead. It never touches the SFX bus; with a storm too, the
    lower cutoff wins. Under a crown is asked of the first node in group `canopy` with
    `is_under_canopy(point) -> bool` (the sim's CanopySystem has that method; it only needs
    `add_to_group(&"canopy")`); without one, the focus counts as shaded when a covered unit the
    player may know about (its own, or one not `is_visible_to_player == false`) is within 8 m.
    `mission_started` and going aboard reset it.
  - **The first air units.** Sound sets `talon` (`concord_talon`, a twin ducted-fan gunship) and
    `hornet` (`combine_hornet`, a crude single-rotor gunship): the unit defs' `sound_set` must be
    these. Their engines are movement loops that never stop: a SoundEvent with
    **`loops_at_rest`** keeps its `move_<set>` loop on the unit at any speed (MovementLoops), from
    70 % level and pitch 0.94 hovering up to full level and 1.08 at top speed; ground chassis are
    unchanged.

    | Event | Talon (Concord: clean, in key) | Hornet (Combine: crude, off key) |
    |---|---|---|
    | `move_<set>` | `move_ducted`: two turbine whines a few hertz apart on D6 and A5, the fans' blade-pass hum, a smooth air rush, D2 under it (4 s loop, −24, to 75 m) | `move_rotor`: a slapping blade beat 9 times a second, an angry saturated two-stroke, loose panels rattling, a whine never in tune (3 s loop, −24, to 75 m) |
    | `weapon_<set>_fire` | the chin autocannon: two quick FM bolts a fifth apart (D6/A5, E6/B5, F#6/C#6), a clean puff (−25, 0.22 s) | the dart gun (every half second): a ragged pneumatic crack, a ring-modulated metal twang as the dart leaves, the loader rattling, decimated (−26, 0.27 s) |
    | `unit_<set>_select/move/attack` | airy marimba strokes (A5–E6) with a breathy reed glide lifting a fourth or fifth behind them (falling for move, level for attack) | a buzzy ring-modulated two-tone over a rotor chop (311/466 Hz and kin: between the Concord's notes) |
    | `death_<set>` | a crack, the fans spinning down and wobbling as it falls (1.1 s, a whistle of air rising), then the ground: a thump, a blast, debris (−21, 2.6 s) | the rotor slap staggering and slowing, an engine scream falling, then a hard crash, a fireball and debris (−21, 3 s) |

    The weapons' data names (`talon_autocannon`, `hornet_dartgun`) have no alias: they fall back
    to `weapon_talon_fire` / `weapon_hornet_fire` by the owner rule (CombatCues), as any name
    beginning with `talon_` / `hornet_` would. Shots land as ordinary impacts (`impact_size` 0).
  - **Advisor** (Meridian dyads, through the Advisor queue):

    | Kind | Phrase | Priority / throttle |
    |---|---|---|
    | `air_contact` | enemy aircraft: three dyads sweeping up fast, then a high G#+D hovering with a 13 Hz rotor beat (−19) | 103 / 25 s |
    | `canopy_contact` | contact under the canopy: a muffled B+F# (heard through leaves), then the D+G# tritone uncovered, twice, the second leaning up (−19) | 101 / 20 s |
    | `air_lost` | one of ours down: a high D+A falling a fifth as it fades, a dull F#+C# where it lands (−20) | 90 / 12 s |

- **Hollow Meridian is vast, cold, reverent and built** (Phase 8d, the last planet and the
  campaign's finale). Kessel is dust and wind, Thalassa water and glass, Emberfall low, hot and
  percussive, Verdance wood and breath; Hollow Meridian should be recognisable within seconds by
  its *size* and its *stillness*: a hum felt more than heard, air moving in a space too big to
  have walls, far machinery that has been turning over for ever, and a score of bowed metal,
  struck stone and glass in a hall six to nine seconds long. Nothing on the deck is alive.

  - **Key and grid.** G# Locrian (G# A B C# D E F#): the *same seven pitches* as the Concord's D
    Lydian, centred on G#, the raised fourth the Trail motif has hung on all campaign: here the
    question is the ground. 52.5 BPM in **5/4** (3 + 2: a mechanism, not a dance), 12 bars, 60
    beats, 68.57 s (3 024 000 samples); `bar_beats` 5. Chords, three bars each: G#m7(b5) (the
    tritone G#–D inside the chord), E6/9, C#m7(add11), Dmaj7(#11)/G# (the Concord's own chord over
    the planet's note, never resolved).
  - **Timbres.** No reed, marimba, taiko, forge or flute. *Bowed metal* (plate partials
    1 : 2 : 2.76 : 5.4, each with a twin a few cents off, a slow swell, bow noise), *struck stone*
    (short inharmonic knocks, a dull crack), *glass* (beating sine pairs, a struck edge), *deep
    sub drones* (G#1 under everything), the *Antecedent bell*, and a very large room.
  - **The Hollow motif** is the Trail motif read backwards: G# B A D (long, short, short, very
    long): the place has the answer, but from the other end. The Trail motif itself rings on the
    bell in the `trail` layer and hangs on G#, which here is home.
  - **The score** (`res://data/sounds/music/hollow_meridian.tres`, layers in `music/hollow/`): the
    same states, intensities and layer roles as the other planets (18 layers: Verdance's 15 plus
    three **Core layers**). `pad` (bowed-metal chords, the sub, a glass halo), `pulse` (the
    mechanism: glass ticks every three eighths across the 5/4 bar, a cycle of three bars, stone
    knocks on 1 and 4), `melody` (the Hollow motif on bowed metal, glass on each onset), `drive`
    (muted sub eighths 3+3+2+2, metal clanks on the accents, D as a shadow), `drums` (stone drums,
    plates, glass grains), `brass` (bowed-metal sforzandi, the motif called low), `trail`, `hush`
    (far glass, a stone drop), `watch` (a stone lub-dub, relay ticks, the D shadow), variants
    `melody_b` (high glass, ending on G#), `melody_c` (the motif augmented low, bells above),
    `pulse_b` (the bar the other way round, 2 + 3), `drums_b` (half time, one huge stone drum,
    rolling plates), `urgency` (glass sixteenths of G# against the D–G# tritone, a bowed siren
    G# → C#), `heavy` (low bowed metal, doubled stone drums, a grinding sub), and the Core layers,
    silent until the Beacon Core charges:
    - **`core_1`** (charge ≥ 0.25): the Core's heartbeat (a sub throb on D, lub-dub and a beat on 4)
      and the Meridian's own dyad D6+A6 shimmering high above the planet's harmony;
    - **`core_2`** (≥ 0.5): the Trail motif arpeggiated on bells in quarters, climbing an octave
      in each block's last bar, bowed swells on the top note;
    - **`core_3`** (≥ 0.75): the motif spinning as a mechanism (bell and glass eighths D A B G#)
      and a band of light rising for ever (a Shepard figure, one cycle per block).

    State levels are Verdance's plus the Core layers at explore, tension, aftermath 0; calm −2;
    combat −3; heavy −5; victory −6; defeat silent; stealth −6/−5/−4.
  - **Re-voiced hits and stings** (`<id>_hollow_meridian`): `mus_hit_combat_hollow_meridian` (air
    drawn into the hall, two stone drums, a bowed G# and D; −24), `mus_hit_aftermath_hollow_meridian`
    (the metal sighs A → G#, a bell, a far stone; −25), `mus_sting_victory_hollow_meridian` (G# B A
    C# lifting to the high D over Dmaj7(#11): the planet's G# becomes the #11 of the Concord's D;
    −22), `mus_sting_defeat_hollow_meridian` (the motif falling to the low G#, the hall swallowing
    it as the filter closes; −22).
  - **The finale.** `Events.core_charge_changed(fraction)` brings the Core layers in by threshold
    (CoreSound / CoreCues): a layer comes in at 0.25, 0.5, 0.75 and leaves only 0.08 below its
    threshold, so a contested Core wobbling around one half never flaps a layer; changes land on the
    beat and fade like any layer gain. `Events.core_awakened(core)` (once per mission) silences the
    Core layers and plays **`mus_core_awakened`** (34 s, −21, the campaign's peak) on the CoreSound's
    own Music-bus player, the score dipped −24 dB under it until its calm tail (the last 8 s):

    | Time | Heard |
    |---|---|
    | 0–4 s | the hall draws breath: rising air, a sub climbing, bells swelled backwards into… |
    | 4 s | a great strike on the planet's tritone, G# and D (bells and stone) |
    | 4.5–15 s | the Trail motif stated in full, broad, on bell, bowed metal and glass: D, A, B, and G# held over G#m7(b5): the question, as it has been all campaign |
    | 15–19 s | the answer: G# rises to A, C#, the high D; the bass moves G# → A → D |
    | 17.6–26 s | home: Dmaj9(#11) (the planet's G# is now the Lydian #11, consonant at last), the bells on D A D A, the **Meridian dyad** D+A and its octave as pure sines, glass falling like light (the peak, ≈ −23 dB RMS) |
    | 26–34 s | the calm tail: one high bell, the dyad D+A alone, the hall |

    While it rings (`CoreSound.is_peaking()`), a `mission_ended(true)` settles the score into
    victory without the victory sting: the awakening *is* the victory. A new mission stops it.
  - **The ending theme** (`res://data/sounds/music/ending.tres`, id `ending`, three layers in
    `music/ending/`: `mus_ending_pad` −27, `mus_ending_melody` −28, `mus_ending_bells` −31; 60 BPM,
    16 bars, 64 s, one state `ending`). Quiet and resolved, in D at last: Dmaj9 → Bm(add9) → E(add9)/D
    → A(add9)/C#, and the A lands on D at every loop. The Meridian's glass pad, the Trail motif and
    its answer on the Meridian lead (D A B G#, A C# D), Antecedent bells far off with the G#
    consonant inside D. It is selected like the ship's screens: on
    `Events.campaign_screen_changed(&"ending")` the AudioService looks for a **ScreenMusic** in
    `res://data/sounds/screens/` whose `screen` is that id (`screens/ending.tres`: `screen = &"ending"`,
    `score` = the ending score, `state = &"ending"`) and switches to its score (one player, fade
    out and in) instead of the ship theme; the ship's ambience plays under it, as on any ship
    screen. If the ending screen's id turns out different, that `screen = ...` line is the only
    change. Any other screen without a file keeps the ship theme.
  - **Ambience** (the `hollow_meridian` AmbienceSet). Beds: `amb_hollow_hum` (47 s, −32: a sub hum
    on G#1 with its octave, a faint D, twins beating slowly, a pressure that surges; wanders
    −3..0 dB), `amb_hollow_air` (41 s, −31: dark wide air in slow swells, a hollow resonance
    wandering, a far whistle across a chasm twice a loop; −6..0), `amb_hollow_machinery` (34 s,
    −33: something enormous turning over five times a loop: rumble, a grinding band, a far heavy
    clank in a long hall; −9..−2) and the Antecedent hush. Details (one every 6–14 s):

    | Detail | Sound | Weight |
    |---|---|---|
    | `amb_metal_groan` (3) | a far metallic groan: stick-slip through plate resonances, deep, in a 4.5 s hall (−26, to 220 m, one at a time, never twice in 4 s) | 0.45 |
    | `amb_relay_click` (3) | a relay clicking, a short electrical buzz, its echo coming back across the deck (−28, to 90 m) | 0.5 |
    | `amb_pebble_fall` (3) | a pebble into a chasm: it ticks off the wall, fainter, duller and further apart, a whistle of air after it, and never lands (−28, to 140 m, never twice in 3 s) | 0.3 |
    | `amb_seam_tick` (3) | a glowing seam's electrical tick: a crackle, a glass ping on G#6, D6 or G#5, a blip of hum (−28, to 60 m) | 0.55 |
    | `amb_flux_vent` | as on Kessel, only near Flux | 1.2 × near vent |
    | `amb_combine_industry` | as on Kessel, at a seen base | 2.6 × near base |

  - **The old engines** (`MachineSound` / `MachineCues`, positional on the Buildings bus, group
    `machine`):

    | Signal | Heard at the machine |
    |---|---|
    | `machine_reactivated(machine, player faction)` | `machine_spinup` (4.8 s, −20: stone grinding loose, a tone rising two octaves from D1 that lands on D3 with A above, the Meridian's dyad, a bell strike and a thump on the landing, the hum settling in), then `loop_engine_run` |
    | `machine_reactivated(machine, other faction)` | `machine_seized` (3.8 s, −22: the same rise, colder, landing off the chord on the Combine's bent Bb and F with ring-modulated grit and a mistuned clank, no bell), only if the machine is not hidden (`is_visible_to_player`) and within 90 m of the camera's focus |
    | `machine_lost(machine, player faction)` | `machine_winddown` (3.8 s, −22: the hum's D and A sag an octave as it slows, the grind drags to a stop, a last clunk, a sigh); its run loop fades |
    | `machine_lost(machine, other faction)` | nothing (the new owner's reactivation speaks) |

    `loop_engine_run` (6 s loop, −30: D2 and A2 turning over nine times a loop, a soft whoosh in
    the turn, faint bell partials) hums on the MachineSound's own players at the player's running
    engines, at most three, nearest the focus within 55 m, starting 2.5 s after the spin-up (whose
    end already carries the hum) and fading over 1.2 s. A takeover of one of ours (lost, then the
    enemy's reactivation) is one gesture: a seizure within 1 s of our loss of the same machine is
    not played over the wind-down. Every machine the MachineSound has heard of is left alone by
    BaseLoops, so an engine that is also a building is not hummed twice.
  - **The Sentinel** (`custodian_sentinel`, a heavy ranged Custodian; its `def.sound_set` must be
    **`sentinel`**, its weapon's `sound_set` **`sentinel`** or any name starting with `sentinel_`,
    e.g. `sentinel_stone_bolt`, which falls back to the family by the first-word rule). A larger
    Warden, its drone on G# with D above (the tritone frame) where the Warden's is on D:

    | Event | Sound |
    |---|---|
    | `move_sentinel` | a deep bell drone on G#2 with D3 above, slower beating, a sub on G#1, heavier stone grinding, brass ticks (5 s loop, −23, to 60 m; the Warden's is −24, to 45 m) |
    | `loop_hum_sentinel` | dormant: the drone alone, G# with a faint D, very slow (6 s, −31, to 55 m; BaseLoops, while `is_dormant`) |
    | `unit_sentinel_wake` | stone grinding loose, two bell strikes G# then D, a lift rising a fifth, a sub thump (3.8 s, −20, to 140 m; when `is_dormant` turns false in view) |
    | `weapon_sentinel_fire` (3) | a charged stone-and-light bolt: a quarter second of charge (a whine rising, crackle), then a stone crack, a beam of light dropping onto G#3 / D4 / A3, a bell clang, a sub thump (1.5 s, −22, priority 60, to 110 m) |
    | `death_sentinel` | two cracked bells (G# and D) splitting and falling in pitch, a heavy stone collapse, rubble (4.6 s, −20) |

  - **Advisor** (Meridian dyads, through the Advisor queue):

    | Kind | Phrase | Priority / throttle |
    |---|---|---|
    | `core_contested` | D+A and the Combine's bent Bb+F pulling against each other, fast, twice, left hanging on the bent dyad (−19) | 110 / 15 s |
    | `custodians_awake` | a struck G#+D bell in the ship channel, then three quick dyads climbing into the tritone (−19) | 107 / 25 s |
    | `engine_lost` | D+A sagging into the planet's G#+D as a low hum winds down under it (−19) | 102 / 10 s |
    | `core_charging` | three slow D+A pulses, each a step brighter, the last rising into the motif's B (−20) | 89 / 30 s |
    | `engine_online` | a low hum swelling under dyads climbing to a held, bright D+A with its octave (−19) | 84 / 6 s |

    An `engine_online` and an `engine_lost` that both wait unheard cancel (the state flapped), like
    low power and power restored.

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
| `music` Meridian layers (Phase 7) | Ogg stereo, loop | pad −26, pulse −30, melody −28, title −27, web −31, loadout −29 | 70 BPM, 54.86 s (2 419 200 samples) |
| `ambience` ship beds | Ogg stereo, loop | hum −31, air −33 | 41 / 29 s, AmbienceDirector's ship players |
| `shipdetail` | WAV stereo | relay −33, creak −34, machine −34, ping −35 | flat, Ambience bus, priority 10 |
| `ui` Phase 7 | WAV mono | −27 (hovers −35, title −28, loadout change −28, saved −31, launch and tech buy −24, unlocked −26) | launch 1.1 s and tech buy 1.5 s: the two deliberate exceptions to ≤ 0.3 s |
| `advisor` Phase 7 | WAV mono | intel banked −20, route, tech, return won −21, return lost −22 | flat, Advisor bus |
| `music` Thalassa layers (Phase 8a) | Ogg stereo, loop | as Kessel: pad −25, pulse/pulse_b −29, melodies −27, drive −28, drums −26, brass −27, trail −29, hush −31, watch −29, urgency −29, heavy −27, tide −29 | 63 BPM in 3/4, 68.57 s (3 024 000 samples) |
| `sting` Thalassa (Phase 8a) | Ogg stereo | hits −24 / −25, victory and defeat −22 | `<id>_thalassa_low` |
| `ambience` Thalassa beds | Ogg stereo, loop | wind −30, surf −33, drone −34 | 44 / 39 / 31 s |
| `ambdetail` Thalassa | WAV mono | laps −26, shells −26, drips −28, shore call −27, buoy −27 | positional, priority 10 |
| `weather` tide (Phase 8a) | Ogg stereo | low −28, high −27, rush −29, pull −29 (loops 36 / 27 / 22 / 25 s); turning −24 | TideSound's players / flat, Weather bus |
| `advisor` Phase 8a | WAV mono | tide rising −19, falling −20, units in water −19, artefact taken −19, secured −20 | flat, Advisor bus |
| `ui` Phase 8a | WAV mono | artefact pickup −27, drop −28 | 0.39 / 0.40 s |
| `baseloop` artefact | WAV mono, loop | −31 | 6 s, positional |
| `music` Emberfall layers (Phase 8b) | Ogg stereo, loop | as Kessel: pad −25, pulse/pulse_b −29, melodies −27, drive −28, drums −26, brass −27, trail −29, hush −31, watch −29, urgency −29, heavy −27, pressure −29, holdout −28 | 56 BPM in 4/4, 68.57 s (3 024 000 samples) |
| `sting` Emberfall (Phase 8b) | Ogg stereo | hits −24 / −25, victory and defeat −22 | `<id>_emberfall` |
| `sting` Holdout | Ogg stereo | minute −24, engine −26 (4 s loop), arrived −22 | flat / HoldoutSound's player, Music bus |
| `ambience` Emberfall beds | Ogg stereo, loop | rumble −31, lava −33, wind −31 | 41 / 35 / 46 s |
| `ambdetail` Emberfall | WAV mono | rock cracks −25, gas hiss −26, collapse −26, ember ticks −28 | positional, priority 10 |
| `weather` eruptions (Phase 8b) | WAV mono | build low / high −24 (loops 4 / 3 s), knocks −24, blast −18 | EruptionSound's positional players, Weather bus |
| `advisor` Phase 8b | WAV mono | extraction arrived, surge, eruption warning, damage −19; wave, extraction inbound −20 | flat, Advisor bus |
| `ui` Phase 8b | WAV mono | vent release −26, vent denied −28 | 0.36 / 0.27 s |
| `music` Verdance layers (Phase 8c) | Ogg stereo, loop | as Kessel: pad −25, pulse/pulse_b −29, melodies −27, drive −28, drums −26, brass −27, trail −29, hush −31, watch −29, urgency −29, heavy −27 | 70 BPM in 6/8, 68.57 s (3 024 000 samples) |
| `sting` Verdance (Phase 8c) | Ogg stereo | hits −24 / −25, victory and defeat −22 | `<id>_verdance` |
| `ambience` Verdance beds | Ogg stereo, loop | leaves −31, chorus −33, stream −32 | 43 / 37 / 29 s |
| `ambdetail` Verdance | WAV mono | creak −26, call −27, drip −28, wing flurry −26 | positional, priority 10 |
| `canopy` (Phase 8c) | WAV mono | rustle in −27, out −30 | CanopySound, positional, Units bus, priority 42 |
| `movement` aircraft | WAV mono, loop | −24 (`move_ducted` 4 s, `move_rotor` 3 s) | `loops_at_rest`, to 75 m |
| `weapon` aircraft | WAV mono | talon −25, hornet −26 | positional, Weapons bus |
| `unit` aircraft | WAV mono | −21 | flat, Barks bus |
| `explosion` aircraft deaths | WAV mono | −21 | positional, Explosions bus |
| `advisor` Phase 8c | WAV mono | air contact, canopy contact −19; air lost −20 | flat, Advisor bus |
| `music` Hollow Meridian layers (Phase 8d) | Ogg stereo, loop | as Kessel: pad −25, pulse/pulse_b −29, melodies −27, drive −28, drums −26, brass −27, trail −29, hush −31, watch −29, urgency −29, heavy −27; core_1 −30, core_2/core_3 −29 | 52.5 BPM in 5/4, 68.57 s (3 024 000 samples) |
| `sting` Hollow Meridian (Phase 8d) | Ogg stereo | hits −24 / −25, victory and defeat −22 | `<id>_hollow_meridian` |
| `sting` finale | Ogg stereo | `mus_core_awakened` −21 (34 s) | CoreSound's own player, Music bus |
| `music` ending theme | Ogg stereo, loop | pad −27, melody −28, bells −31 | 60 BPM, 64 s (2 822 400 samples) |
| `ambience` Hollow Meridian beds | Ogg stereo, loop | hum −32, air −31, machinery −33 | 47 / 41 / 34 s |
| `ambdetail` Hollow Meridian | WAV mono | groan −26, relay, pebble, seam −28 | positional, priority 10 |
| `machine` (Phase 8d) | WAV mono | spin-up −20, wind-down −22, seized −22; run loop −30 (6 s) | positional, Buildings bus; the loop on the MachineSound's players |
| `movement` / `baseloop` Sentinel | WAV mono, loop | move −23 (5 s), dormant hum −31 (6 s) | positional |
| `antecedent` / `weapon` / `explosion` Sentinel | WAV mono | wake −20, fire −22, death −20 | positional |
| `advisor` Phase 8d | WAV mono | core contested, custodians awake, engine online, engine lost −19; core charging −20 | flat, Advisor bus |

Also checked on every build: DC offset ≤ 0.002, energy below 25 Hz ≤ 3 %, duration within the
recipe's bounds, and for loops the seam (no step, kink or level jump bigger than the loop's own
most abrupt moment). Ogg files are decoded again and compared with the source (codec fidelity).

## Final mix (Phase 6)

**Buses.** `Master` ← `Music`, `Ambience`, `Weather`, `SFX` (`Weapons`, `Explosions`, `Units`,
`Buildings`), `Voice` (`Barks`, `Advisor`), `UI`, `Discovery`, `Stealth`. Player settings:
Master → `master_volume`, Music → `music_volume`, UI → `ui_volume`, Advisor →
`voice_volume` (Phase 9), Ambience → `ambience_volume` (Phase 9), everything else (Weather, SFX,
Barks, Discovery, Stealth) → `sfx_volume`. The Voice bus itself has no setting, so the Advisor is
not scaled by the effects slider too; unit replies (Barks) stay with the effects, and so does the
Weather bus, because it carries warnings. At default settings the mix is unchanged: both new
settings default to 1.0, as the effects volume did, and an older settings file carries its
effects volume over to both.

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
| Aboard the ship (any campaign screen) | SFX, Weather, Stealth, Discovery silent; zoom offsets as fully zoomed out (Music, Ambience 0 dB) | nothing of a planet is heard aboard |
| Landing hand-over (launch or leaving the ship) | the planet's score at −14 dB | held until the briefing bed takes it, or the mission starts |
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
| ship (Phase 7): the star map's theme and the ship ambience, a map hover every 50 ms, clicks, a tech purchase, a campaign Advisor phrase every 1.5 s | −23.3 LUFS | −11.0 dBFS |
| worst case: `combat_heavy` + urgency + storm layers, a full storm (beds, gusts, debris, muffle), 6 weapon and 6 impact starts per 50 ms frame within 35 m plus blasts, an Advisor or stealth alarm every 1.5 s, interface clicks | −19.4 LUFS | −5.7 dBFS (limiter never engaged) |
| Thalassa calm (Phase 8a): the Thalassa score in `calm`, its ambience, the tide at low water, slack | −26.9 LUFS | −16.5 dBFS |
| Thalassa fight (Phase 8a): `combat_heavy` + urgency + tide layers at high water with the sea still rising (water bed and rush), the worst-case battle, an Advisor or stealth alarm every 1.5 s plus `advisor_tide_rising` every 1.5 s, a tide warning, clicks | −17.3 LUFS | −3.9 dBFS (limiter never engaged) |
| Emberfall calm (Phase 8b): the Emberfall score in `calm`, its ambience | −29.0 LUFS | −15.5 dBFS |
| Verdance calm (Phase 8c): the Verdance score in `calm`, its ambience, the camera under a crown (the Ambience high band shaded) | −29.9 LUFS | −19.7 dBFS |
| Verdance air war (Phase 8c): `combat_heavy` + urgency layers, four aircraft engines overhead (two Talons, two Hornets), a Talon autocannon shot every 50 ms and a Hornet dart every 100 ms on top of the worst-case battle, an aircraft coming down every second, canopy rustles, an Advisor or stealth alarm every 1.5 s plus `advisor_air_contact` every 1.5 s, clicks | −17.1 LUFS | −4.4 dBFS (limiter never engaged) |
| Hollow Meridian calm (Phase 8d): the Hollow score in `calm` with `core_1` (a quarter charged), its ambience, two of the player's engines running nearby | −27.0 LUFS | −14.9 dBFS |
| Hollow Meridian finale (Phase 8d): the Core's awakening at its peak (19.5–25 s into the cue) over `combat_heavy` + urgency + all three Core layers (dipped −24 dB under it), the worst-case battle plus a Sentinel bolt every 150 ms, a Sentinel falling every 2 s and an engine spinning up every second, an Advisor or stealth alarm every 1.5 s plus `advisor_core_contested` every 1.5 s, clicks | −17.3 LUFS | −4.2 dBFS (limiter never engaged) |
| Emberfall Holdout fight (Phase 8b): `combat_heavy` + urgency + pressure + holdout layers, the extraction engine in its last seconds, a vent 23 m away building up then erupting (blast and duck) by a player building, the worst-case battle, an Advisor or stealth alarm every 1.5 s plus `advisor_eruption_warning` every 1.5 s, clicks | −18.1 LUFS | −3.9 dBFS (limiter never engaged) |

Worst-case loudness per category (each bus before its fader, LUFS): Music −25.3, Weather −25.8,
Weapons −24.7, Explosions −25.7, Advisor −21.4, Stealth −22.8, UI −36.4, Ambience −64.7
(covered by the storm; −37 to −38 in clear air under the explore score at −24). While the
Advisor speaks the Music bus sits at −30.4 against the Advisor's −20.9 (9.5 LU clear).
The test asserts: Master below −0.9 dBFS, the mix below 0 dBFS before the limiter, the worst
case within −24..−13 LUFS and explore within −36..−22 LUFS, the voice budget, and the Advisor
at least 3 LU over the music while it speaks.

Aboard (per bus before its fader): Music −31.2, Ambience −40.1, Advisor −25.1, UI −27.4 LUFS; while
the Advisor speaks the ship theme sits at −31.3 against its −25.3. The ship test asserts no
clipping, headroom before the limiter, −36..−22 LUFS, the Advisor 3 LU over the music and the
interface under the Advisor. (The scene is deliberately busy; a player idling on the map hears the
theme and the hull, around the explore level.)

Thalassa fight (per bus before its fader): Music −32.6, Weather −27.7 (the tide), Weapons −24.8,
Explosions −25.7, Advisor −20.5, Stealth −22.9, UI −36.3, Ambience −43.8 LUFS; while the Advisor
speaks the score sits at −36.2 against its −20.6. The music is lower than Kessel's worst case
because the scene has the Advisor speaking twice as often (the sidechain holds it down); the
Thalassa states themselves sum to Kessel's loudness within 0.2 LU. Both Thalassa scenes assert
what the Kessel ones do (no clipping, headroom, the same loudness windows, the voice budget, the
Advisor 3 LU over the music).

Emberfall fight (per bus before its fader): Music −27.1 (the score plus the extraction engine),
Weather −30.0 (build-up and blast), Weapons −25.2, Explosions −25.7, Advisor −21.0, Stealth −22.9,
UI −36.4, Ambience −39.4 LUFS; while the Advisor speaks the score sits at −32.7 against its −20.5
(12.2 LU clear). The low end checked on its own (unweighted, below 150 Hz, only while the Advisor
speaks): the score's low band at −34.7 dB RMS against the Advisor's −23.0 dB RMS. Both Emberfall
scenes assert what the others do, and the fight also asserts that low band under the Advisor.

Verdance air war (per bus before its fader): Music −32.7, Weapons −24.9, Explosions −23.1 (an
aircraft falling every second), Advisor −21.2, Stealth −22.9, UI −36.4, Ambience −39.7 LUFS, 35
voices at most; while the Advisor speaks the score sits at −34.6 against its −21.1 (13.5 LU clear).
Both Verdance scenes assert what the others do (no clipping, headroom, the loudness windows, the
voice budget, the Advisor 3 LU over the music); calm also asserts the camera is shaded.

Hollow Meridian finale (per bus before its fader): Music −31.7 (the awakening over the dipped score,
held down by the Voice sidechain while the Advisor speaks every 0.75 s), Weapons −24.7, Explosions
−25.3, Advisor −20.5, Stealth −22.9, UI −36.4, Ambience −40.4 LUFS, 35 voices at most; while the
Advisor speaks the music sits at −33.8 against its −20.3 (13.5 LU clear). The campaign's peak never
reaches the limiter: −4.2 dBFS before it, the same headroom as the other fights. Both Hollow scenes
assert what the others do (no clipping, headroom, the loudness windows, the voice budget, the
Advisor 3 LU over the music); calm also asserts the Core's first layer and the engines' hum, the
finale that the recording is inside the awakening.

Phase 9 changes the finale: the awakening is now the one moment the Advisor does **not** duck the
music. `CoreSound` switches the Music bus's `DuckUnderVoice` compressor off when the awakening
starts and back on when it ends or a new mission starts. The Advisor still speaks over it,
level with the cue rather than above it, and the cue sits 2 dB lower (`mus_core_awakened`
`volume_db = -2`) so that the unducked peak stays with the other fights (table below). The test now
asserts that the duck is off and that the music while the Advisor speaks is within 1.5 LU of its
level over the whole recording.

The first measurement found one problem, fixed: heavy combat with the storm and urgency layers
stacked integrated to −21.7 LUFS of music, louder than the weapons (−25) and level with the
Advisor. `combat_heavy` was pulled back 2–4 dB per layer, the storm layer capped at −3 dB
(the Weather beds carry the storm), and urgency set to −4..−6 under fighting states.

## Across the campaign (Phase 9)

Each planet has a calm scene (its score in `calm` and its ambience; Hollow Meridian also has
the Core's first layer and two engines humming) and a busy one (its worst fight).
`test_final_mix.gd` records all ten through the real buses, with the same settings as the
Phase 6 table above. Its last test, `test_zz_planets_sit_together`, asserts that the calm scenes
sit within 2.5 LU of each other and the busy scenes within 3.0 LU. Measured in Phase 9 on the
full `tests/audio` run:

| Planet | Calm: integrated | Calm: peak before the limiter | Busy scene | Busy: integrated | Busy: peak before the limiter |
|---|---|---|---|---|---|
| Kessel Reach | −29.0 LUFS | −19.4 dBFS | worst case (storm fight) | −19.6 LUFS | −6.9 dBFS |
| Thalassa Low | −28.0 LUFS | −17.6 dBFS | fight at high tide | −17.6 LUFS | −4.0 dBFS |
| Emberfall | −27.9 LUFS | −15.5 dBFS | Holdout fight with an eruption | −18.0 LUFS | −5.0 dBFS |
| Verdance | −30.0 LUFS | −19.6 dBFS | air war | −17.1 LUFS | −4.5 dBFS |
| Hollow Meridian | −28.3 LUFS | −16.9 dBFS | finale (awakening) | −16.7 LUFS | −1.9 dBFS |
| **Spread** | **2.1 LU** | | | **2.9 LU** | |

The same six-second scene moves by up to about 1.5 LU from run to run, because the beds wander
and the details are random. Across four runs the calm scenes spanned 1.5–2.6 LU and the busy ones
2.4–2.9 LU, and every peak stayed under the −1 dBFS limiter ceiling, so the limiter never acted.
The finale's peak varied most (−1.9 to −5.0 dBFS): it is the campaign's one unducked climax, with
explosions landing on top of the cue.

Fixed in Phase 9:

- **Hollow Meridian calm was 2.5–4 LU hot** (−25.5 against about −28.5). Its `calm` state played
  pad, trail, melodies and the Core layers 2 dB above the other planets' (Music −24.1 LUFS before
  its fader, against −25.4 to −26.9). The state is now 2 dB lower on every sounding layer except
  urgency. Result: −27.7 to −28.3.
- **Hollow Meridian finale**: the awakening is no longer ducked (see the finale above), so the cue
  plays 2 dB lower (Music −23.1 before its fader, from −21.1). The finale stays the loudest scene in
  the campaign and the only one near the limiter.
- Left as it is: **Verdance calm** (−29.7 to −30.0) is the quietest, because the camera sits
  under a crown and the canopy shades the Ambience high band; raising its score's calm layers by
  1.5 dB changed nothing measurable, so the change was reverted. **Kessel's worst case** is the
  quietest busy scene: its score is actually the loudest of the five fights (−25.3 before its
  fader), but the storm covers its ambience, and it has none of the extras the other planets'
  fights add (tide, eruption, air war, awakening).

Phase 9 also rechecked three assets (the build's own analysis):

| Asset | Check | Before | Now |
|---|---|---|---|
| `amb_verdance_leaves.ogg` | codec fidelity (median segmental SNR, floor 18 dB) | 18 dB (on the floor) | 20 dB: the hush layer is now 55 % shared between the channels, so the encoder's channel coupling has less to code |
| `amb_kessel_air.ogg` | codec fidelity | 18 dB (on the floor) | 21 dB, by the same change (60 % shared) |
| `mus_hollow_explore_trail.ogg` | loop seam curvature (limit 1.5) | 1.43 | 1.31: the bell-air swell now peaks at the loop point, so the join falls in a steady tone instead of near-silence |

**Subtitles.** Every Advisor event (`game/data/sounds/advisor/*.tres`) has a `subtitle`: one
short line saying in words what the tones mean ("Eruption warning.", "Engine online."). When a
line actually starts playing, the AudioEventRouter emits `Events.subtitle(&"advisor", text,
seconds)`, where `seconds` is the stream's real length. A line that is throttled, dropped,
superseded, cancelled or refused a voice is never subtitled. `test_phase9_audio.gd` fails if any
Advisor event has no subtitle, so add one with every new Advisor line.

**Phase 9 sounds** (`audio_src/recipes/polish.py`): `ui_tab_changed`, `ui_rebind_listen`,
`ui_rebind_done`, `ui_rebind_conflict` (the settings pages emit these names as `ui_feedback`
kinds), `ui_credits_open`, `advisor_extraction_moved`, and `loop_engine_claim`: a ratchet over a
faint D+A drone that `MachineClaimSound` plays at an old engine while the player's workers bring
it back. Its pitch rises from 0.8 to 1.3 with the work done, and it fades when the work stops,
finishes, or is the enemy's.

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
- Phase 7: `amb_ship_<bed>` (ambience), `amb_ship_<detail>_<n>` (group `shipdetail`),
  `mus_meridian_<layer>` (the ship score `meridian.tres`), `ui_<campaign kind>`,
  `advisor_campaign_<kind>`
- Phase 8a: `mus_thalassa_<layer>`, `amb_thalassa_<bed>`, `amb_tide_<layer>`,
  `tide_turn_<rising|falling>`, score variants `<hit or sting>_<score id>`; planets as data in
  `game/data/sounds/planets/<planet id>.tres` (PlanetAudio: score + AmbienceSet) and
  `game/data/sounds/ambience/sets/<planet id>.tres` (AmbienceSet: beds and details)
- Phase 8b: `mus_emberfall_<layer>`, `amb_emberfall_<bed>`, details `amb_<what>_<n>`,
  `eruption_<build_low|build_high|knock|blast>[_<n>]` (group `weather`), `mus_holdout_<cue>`
  (group `sting`), `ui_vent_<release|denied>`, `advisor_<kind>`
- Phase 8c: `mus_verdance_<layer>`, `amb_verdance_<bed>`, details `amb_<what>_<n>`,
  `canopy_rustle_<in|out>_<n>` (group `canopy`), aircraft by sound set like any unit
  (`move_<chassis>` files `move_ducted` / `move_rotor` serving `move_talon` / `move_hornet`,
  `weapon_<set>_fire_<n>`, `unit_<set>_<kind>_<n>`, `death_<set>`), `advisor_<kind>`
- Phase 8d: `mus_hollow_<layer>` (score `hollow_meridian.tres`), `mus_core_awakened` (the finale),
  `mus_ending_<layer>` (score `ending.tres`), `amb_hollow_<bed>`, details `amb_<what>_<n>`,
  `machine_<spinup|winddown|seized>`, `loop_engine_run` (group `machine`), the Sentinel by sound set
  (`move_sentinel`, `loop_hum_sentinel`, `unit_sentinel_wake`, `weapon_sentinel_fire_<n>`,
  `death_sentinel`), `advisor_<kind>`; screen music as data in `game/data/sounds/screens/<screen>.tres`
  (ScreenMusic: screen id, score, state)

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

Campaign (`CampaignSoundRouter`, pure rules in `CampaignCues`, Phase 7).
`campaign_screen_changed(screen)`: any screen but `&""` is aboard. Coming aboard: the world's
positional voices and loops stop, a storm left on the planet is reset, the MissionSoundRouter
forgets an open briefing or a pending launch, the bed stops (the debrief's, or a hand-over dip;
not the mission-select theme), the MusicDirector `switch_score`s to the ship theme in the
screen's state, the AmbienceDirector `start_ship`s, the ship mix applies. Between ship screens:
only the state changes (`CampaignCues.music_state`; an unknown screen plays `star_map`). `&""`
(a landing takes over): the planet's score (the one `Audio.play_planet` or `Audio.play_score`
set last; Kessel by default) switches back in held at −14 dB, the planet ambience returns. `map_launch` starts that
music hand-over at once, under the launch gesture; the ambience waits for the screen.
`mission_started` always leaves the ship (without the hold: the mission router has set the
level). A **score switch** fades the playing score out (1.5 s) and the new one in (2 s) on the
one player, so two scores can never sound together; a score younger than 1 s is cut; switching
back before the fade ends calls the switch off; states asked for meanwhile are the incoming
score's. Launch to mission: `ui_map_launch` → ship theme fades, planet score waits at −14 →
`briefing_open` (briefing bed, −14) → `briefing_close` (bed out, `mus_sting_launch`, score up).
Debrief to ship: debrief bed (score −18) → `star_map` (bed out, score switch to the ship theme).

`ui_feedback`: `map_node_hover` and `tech_hover` are the CampaignSoundRouter's (the
AudioEventRouter skips them): two hovers never start within 70 ms; after four within 0.6 s the
gap is 160 ms and they play 5 dB quieter (a sweep across 75 nodes in 1.5 s plays about ten
ticks). The SoundEvents add `cooldown` 0.05 and one instance. Every other campaign kind plays
`ui_<kind>` by the naming rule. `tech_unlocked` plays `ui_tech_unlocked` only when no
`tech_buy` came within 0.5 s either side (the click already carries the seal).
`campaign_saved(slot)`: `ui_campaign_saved`, at most once a minute for a slot whose name
contains "auto", once per 2 s otherwise.

Landing results: the debrief's victory or defeat sting is the verdict; the ship's
`campaign_return_won` / `_lost` phrase is the welcome home. They never stack: the return phrase
waits for the first ship screen after `landing_resolved` (never during the debrief), and is
skipped if a mission-ending sting played less than 10 s before (the player skipped the debrief
and has just heard the verdict). Resolved while already aboard: at once. It goes through the
Advisor queue at priority 92, so a `campaign_intel_banked` (70) or `campaign_route_open` (60)
raised at the same moment follows it rather than talking over it (all three fit within the
queue's 4 s wait). `mission_started` and `campaign_loaded` drop anything pending. Gameplay
raises `campaign_route_open`, `campaign_tech_available` and `campaign_intel_banked` as ordinary
`advisor_alert`s.

**Planets** (Phase 8a, `PlanetAudio`). Which score and ambience play is data, by planet id:
`res://data/sounds/planets/<planet id>.tres` names a MusicScore and an AmbienceSet (the score's
`id` is the planet id). `Audio.play_planet(id)` makes that planet's score fade over (one player,
`switch_score`) and its ambience replace the old one (another set's beds stop first; the same
set is left alone); an id without a file changes nothing; aboard the ship it is remembered for
the landing. Gameplay does not have to call it: on `mission_started` the AudioService reads the
planet itself (deferred one frame) from the running map, the first of the current scene and its
children with a `mission` property whose `planet.id` is set (duck-typed, like the rest of
`audio/`). A new planet is two `.tres` files, no code. `Audio.play_score(score)` still cuts to a
score at once, with the ambience of the planet whose id the score carries.

Thalassa routing (Phase 8a):

| Signal | Sound |
|---|---|
| `tide_turning(seconds, rising)` | `tide_turn_rising` / `tide_turn_falling` (flat, Weather) |
| `tide_changed(level)` | the TideSound's four loops (Weather), the score's `tide` layer gain, the ambience's water level |
| `advisor_alert(&"tide_rising" / &"tide_falling" / &"units_in_water")` | `advisor_<kind>` through the Advisor queue (table above) |
| `advisor_alert(&"artefact_taken" / &"artefact_secured")` | `advisor_<kind>` through the Advisor queue |
| `ui_feedback(&"artefact_pickup" / &"artefact_drop")` | `ui_<kind>` (naming rule) |
| a Node3D in group `artefacts` | `loop_hum_artefact` on it (BaseLoops) |
| `mission_started` | the planet is read from the map (`play_planet`); the tide resets |

Emberfall and Holdout routing (Phase 8b):

| Signal | Sound |
|---|---|
| `eruption_warning(vent, seconds, radius)` | the vent's build-up (two loops and knocks, EruptionSound, Weather); the score's `pressure` layer if the vent is near one of the player's buildings |
| `eruption_warning(vent, < 0 or INF, _)` | calls that vent's eruption off (build-up stops) |
| `eruption(vent, radius)` | build-up stops, `eruption_blast` at the vent; a seen blast ducks the mix |
| `ui_feedback(&"vent_release")` | `ui_vent_release`; the warned vent nearest the camera (80 m) is called off |
| `ui_feedback(&"vent_denied")` | `ui_vent_denied` (fallback `ui_invalid`) |
| `advisor_alert(&"eruption_warning" / &"eruption_damage" / &"surge_incoming" / &"wave_incoming" / &"extraction_inbound" / &"extraction_arrived")` | `advisor_<kind>` through the Advisor queue (table above) |
| `objective_added` / `_updated` with a survival countdown, then `sim_ticked` | the `holdout` layer (≤ 120 s), `mus_holdout_minute` (≤ 60 s), `mus_holdout_engine` (≤ 10 s) |
| `advisor_alert(&"extraction_arrived")` or that objective's `objective_completed` | `mus_holdout_arrived` once; engine out, layer out |
| `objective_failed` for it | engine and layer stop |
| `mission_started` | eruptions and the holdout reset |

Verdance and air routing (Phase 8c):

| Signal or data | Sound |
|---|---|
| `canopy_cover_changed(unit, covered)` for a player unit within 55 m of the focus | `canopy_rustle_in` / `canopy_rustle_out` at the unit, one per gesture (CanopySound) |
| any `canopy_cover_changed` | remembered for the shade fallback (no sound for other factions) |
| the focus under a crown (group `canopy` → `is_under_canopy(focus)`, else a covered, known unit within 8 m) | the Ambience bus's high band closes to 6 kHz |
| a unit whose `def.sound_set` is `talon` / `hornet` | `move_talon` / `move_hornet` on it while it exists and is not hidden (`loops_at_rest`) |
| `weapon_fired` with a weapon `sound_set` of `talon*` / `hornet*` | `weapon_talon_fire` / `weapon_hornet_fire` |
| `entity_died` for such a unit | `death_talon` / `death_hornet` |
| selection or orders of such units | `unit_<set>_<select|move|attack>` (naming rule) |
| `advisor_alert(&"air_contact" / &"canopy_contact" / &"air_lost")` | `advisor_<kind>` through the Advisor queue (table above) |
| `mission_started` | the planet is read from the map (`play_planet(&"verdance")`); the canopy resets |

What gameplay needs to provide for all of this (as of this phase): the planet id `verdance` on
Verdance's PlanetDef, `sound_set` `talon` on `concord_talon` and `hornet` on `combine_hornet`,
weapon sound sets starting with `talon_`/`hornet_` (they do: `talon_autocannon`,
`hornet_dartgun`), the three `advisor_alert` kinds above, and the CanopySystem in group `canopy`
for the shade (optional: the fallback works without it, less exactly).

Hollow Meridian routing (Phase 8d):

| Signal or data | Sound |
|---|---|
| `core_charge_changed(fraction)` | the score's `core_1..3` layers by threshold with hysteresis (CoreSound) |
| `core_awakened(core)` | once: `mus_core_awakened` on the CoreSound's player, Core layers out, the score dipped −24 dB until the calm tail; no victory sting while it rings |
| `machine_reactivated(machine, faction)` / `machine_lost(machine, faction)` | spin-up, seizure, wind-down and the run loop (MachineSound, table above) |
| `campaign_screen_changed(&"ending")` | the ending score (`screens/ending.tres` → `music/ending.tres`, state `ending`) over the ship ambience |
| a unit whose `def.sound_set` is `sentinel` | `move_sentinel`, `loop_hum_sentinel` while `is_dormant`, `unit_sentinel_wake` when it wakes in view, `death_sentinel` |
| `weapon_fired` with a weapon `sound_set` of `sentinel` / `sentinel_*` | `weapon_sentinel_fire` |
| `advisor_alert(&"core_contested" / &"custodians_awake" / &"engine_lost" / &"core_charging" / &"engine_online")` | `advisor_<kind>` through the Advisor queue (table above) |
| `mission_started` | the planet is read from the map (`play_planet(&"hollow_meridian")`); the Core and the engines reset |

What gameplay needs to provide (as of this phase): the planet id `hollow_meridian` on Hollow
Meridian's PlanetDef (the score and ambience are found by it), the four machine and Core signals
(already in `Events`), `sound_set` `sentinel` on `custodian_sentinel` and a weapon `sound_set`
starting with `sentinel`, an `is_dormant` bool on the Sentinel for the dormant hum and the wake
(as the Warden), the five `advisor_alert` kinds above, and the ending screen emitting
`campaign_screen_changed(&"ending")` (if it uses another id, change `screen` in
`game/data/sounds/screens/ending.tres`). Optional: `is_visible_to_player` on the engines (without
it, an enemy seizure within 90 m of the camera is always heard).

## Adding a sound

1. Write a recipe: a function `(rng) -> np.ndarray` in `audio_src/recipes/<module>.py`,
   decorated with `@sound("<id>", "<group>", <target_lufs>, ...)`. Tune it by editing numbers.
2. Render: `uv run --python 3.12 --with numpy==2.5.4 --with scipy==1.18.1 audio_src/build.py` (or `--only <id>`).
   The report must say `0 failed`.
3. The build scaffolds `game/data/sounds/<group>/<event>.tres` with group defaults if the event
   is new. Tune bus, priority, caps, cooldown and volume there (it is never overwritten).
   No code change: the AudioService registers every SoundEvent under `res://data/sounds/`.
4. If a gameplay event should trigger it and no naming rule covers it, add the mapping in
   `game/audio/audio_cue_selector.gd`.
