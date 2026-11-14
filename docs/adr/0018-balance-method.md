# ADR 0018 — Balance by automated play

- Status: accepted (Phase 9, 2026-11-14)

## Context

Nobody had played Farlanding by hand. All eleven missions passed a smoke test, but
every number was a first guess. Phase 9 asks for a campaign that is fair and winnable
on Normal, with Easy gentler and Hard harsher (no resource cheats, PLAN §3.5), a
sensible tech economy, and good performance. Balance has to come from evidence that
can be re-run, not from impressions.

## Decision

### The harness

`tools/balance.sh` plays missions headless (`--fixed-fps 60`, as fast as the machine
allows) with a scripted player in the player's seat, several seeds per mission and
difficulty, in parallel, and prints one table row per mission × difficulty
(`tools/balance_table.py`). Every run keeps its report and a `BALANCE {json}` line
(`out/balance/<run>/runs.jsonl`).

```
tools/balance.sh                                   # all drivable missions, seeds 1-3, Normal
tools/balance.sh -m "survey verdance_conquest" -s "1 2 3 4" -d "easy normal hard" -j 8
tools/balance.sh -p idle -m verdance_conquest       # nobody plays: how fast does the enemy kill?
tools/balance.sh -t all                             # route landings with every tech owned
godot --headless --fixed-fps 60 --path game res://tests/balance/balance_run.tscn \
    -- --mission=hollow_power --seed=1 --log        # one run with both commanders' logs
```

- `tests/balance/balance_run.gd` lands the mission on its real map (route landings get
  a fresh campaign's modifiers) and stops at the result or the time cap.
- `tests/balance/reference_player.gd` is the **reference player**: the enemy
  `Commander` playing the Concord through the same command queue a human uses, with a
  Concord profile built per mission type and a "competent casual" difficulty (decides
  every 3 s, first wave at 7:00, 10% mistakes). Objective drivers: it scans sites on
  every mission (3 Surveyors on Survey), sends an 8-unit squad for the Recovery artefact
  after 3 min, vents its Taps on Emberfall, turtles with Sentries on Holdout, reactivates
  engines on Hollow Meridian and, on the finale, walks a Surveyor to the Core with the
  free army as escort once it runs enough engines.
- **Infiltration is not driven**: a squad that must stay unseen is not a commander's
  game. Its numbers (five single-unit patrols, a 5-min alerted extraction, one
  reinforcement wave) were reviewed by analysis and left alone.
- Route landings assume the techs a not-too-thorough player owns by then
  (`TECH_ORDER`/`TECHS_OWNED` in `balance_run.gd`, from the economy model below).
  Without this the Holdout was played without Sentries, which start locked.
- `tests/balance/balance_recorder.gd` measures, from the world and `Events` only: first
  enemy hit and first enemy unit near a player building, army strength of both sides
  per minute (the AI's own Alloy-equivalent), Alloy and Flux income, mean Alloy floated,
  objective timings, damage taken by source (enemy / Custodians / the world), losses by
  unit type, eruptions, waves launched, and on a timeout what the enemy still has.
- **Determinism**: the commanders' dice are seeded per run, but the simulation is not
  bit-reproducible (avoidance and physics-frame timing), so the same seed can end
  differently. Results are read over several seeds, never from one run.

Supporting tools: `tools/balance_units.py` (damage per second per 100 Alloy-equivalent
against each armour type, health per cost: finds dominated units),
`tools/balance_campaign.py` (Intel along the route against the tech web).

### Targets (Normal)

The reference player wins most seeds, is not crushed in the first five minutes, does
not win unopposed; the first enemy attack comes after the player can have a few
defenders; missions last about 12–25 min (the finale may run longer). Easy clearly
gentler, Hard clearly harsher, by commander behaviour and wave sizes only.

### Results on Normal (reference player, before → after)

Before: seeds 1-3, the data as found (fresh campaign, no techs). After: seeds 1-4, all
changes below (route landings with the typical techs). Won/lost/timeout; median time.

| Mission | Before | Before time | After | After time | Notes |
|---|---|---|---|---|---|
| Kessel Proving | 2/0/1 | 18:47 | 3/1/0 | 17:02 | first enemy hit 2:20 |
| Kessel Storm (Survey) | 0/3/0 | 15:00 | 2/2/0 | 11:32 (4-15 min) | a knife-edge race, see open questions |
| Thalassa Shallows | 2/1/0 | 18:11 | 4/0/0 | 14:00 | |
| Thalassa Recovery | 3/0/0 | 1:55, unopposed | 4/0/0 | 4:26 | short by nature, see open questions |
| Emberfall Conquest | 1/2/0 | 14:29 | 4/0/0 | 23:46 | |
| Emberfall Holdout | 0/3/0 | 5:34 | 2/2/0 (4/1 in an earlier 5-seed run) | 11:30 | losses come at the 10:30 surge |
| Verdance Conquest | 0/3/0 | 10:12 | 3/1/0 | 22:10 | first wave no longer wipes the player |
| Hollow Power | 0/2/1 | 24:53 | 0/2/2 | 36:42 | unresolved, see open questions |
| Hollow Finale | 0/2/1 | 13:20 | 2/0/2 | 31:38 | |

Easy and Hard (seeds 1-3; Verdance and Hollow re-run after the last AI changes):

| Mission | Easy | Hard |
|---|---|---|
| Kessel Proving | 3/0/0, 19:47 | 1/2/0, 16:09 |
| Kessel Storm | 3/0/0, 4:55 | 2/1/0, 4:38 |
| Thalassa Shallows | 3/0/0, 14:55 | 3/0/0, 12:30 |
| Thalassa Recovery | 2/1/0, 4:52 | 1/2/0, 5:38 |
| Emberfall Conquest | 3/0/0, 19:47 | 3/0/0, 18:50 |
| Emberfall Holdout | 3/0/0, 12:00 (5/5 in an earlier run) | 1/2/0, 11:08 (scale 1.15) |
| Verdance Conquest | 1/2/0, 16:43 | 3/0/0, 23:35 |
| Hollow Power | 1/1/1, 19:10 | 1/2/0, 24:27 |
| Hollow Finale | 1/0/2, 40:00 | 1/0/2, 40:00 |

With three seeds and a non-deterministic sim, single cells (Verdance Easy below Hard)
are noise; over Proving, Storm, Recovery and Holdout the order is Easy > Normal > Hard.

### What changed and why

Bugs and AI (each with a test):

- `SurveyBehaviour` kept freed surveyors as keys of typed dictionaries: an error every
  tick, and the dead unit's site stayed "taken", so the survey stalled
  (`tests/discovery/test_combine_survey.gd`).
- `VentKeeper` re-placed an extractor on a refused vent every decision, holding both
  builders for good (the Holdout's build order never passed the Muster Bay). A vent now
  waits 2 min after an attempt (`tests/ai/test_commander_vents.gd`).
- `DestroyAllObjective` stayed open for unarmed stragglers ("0 known structures
  standing", mission never ends). A side with no building, armed unit or builder counts
  as destroyed (`tests/missions/test_objectives.gd`).
- Carriers were only slowed by a factor: a Kite carried the artefact at 7.8 m/s.
  Capped at 3.6 m/s (`Carrier.MAX_SPEED`, `tests/props/test_carry.gd`); Kites may no
  longer carry.
- Retrieval squads of the same size were fed one after another into guards: each lost
  squad makes the next bigger and 60 s later (`Commander.retrievals_lost`, saved;
  `tests/ai/test_commander.gd`).
- The vent/engine keepers took the last builder while the base had lost its factory
  (Hollow: the only Fabricator walked from engine to engine while 5,000 Alloy piled
  up). `Commander.spare_builders`; with engines to claim, a second builder comes from
  one factory on (`tests/ai/test_commander_brain.gd`).
- `MachineKeeper` sent builders, often alone, back to engines whose guards had just
  killed the last one (one finale: 26 Fabricators and 54 Riggers lost). An engine where a
  worker died is left alone for 3 min, and no worker goes without an escort
  (`tests/ai/test_commander_machines.gd`; the older tests there now pass an escort).
- Won wars timed out with a big army idling at home and the last Riggers unseen. With no
  target known and a free army 1.5× the next wave, the commander hunts sector by sector
  (`CommanderBrain._hunt`, `tests/ai/test_commander_brain.gd`).
- For the reference player: `CommanderProfile.power_plant` (build one when free power
  runs low), producers other than the factory build army units, and the view knows the
  faction's locked types.

Data:

- **Holdout** (Emberfall): waves at 90/180/270/350/430/510/590/670 s, sizes
  2,3,4,4,5,6,7,8 (were 60..680 s, 3..12); start Alloy 1200 (was 650); authored at
  Normal (it defaulted to Easy). Wave sizes now follow the commander level
  (`WaveRules.easy_scale` 0.7, `hard_scale` 1.15); before they ignored difficulty.
- **Verdance**: the Combine starts with one Spire (was two) and without the extra
  Skitter and Hornet; its opening has one Hornet (was two); the player starts with 550
  Alloy (450).
- **Kessel Storm**: with the survey fix the Combine's Riggers really race. The targets
  could not both be met before (player 300 of the map's 525, Combine 250). Now both bank
  250; the player lands one Surveyor (was two), the Combine has three Riggers and
  surveys from 0:45, Kessel scans take 1.5× as long.
- **Thalassa Recovery**: the artefact lies by the Combine (50, -42); the salvagers go for
  it at 4:00 (was 1:00).
- **Kessel Proving**: its own profile `combine_proving` (Easy `proving_easy`, Normal =
  the old Easy numbers, Hard = the old Normal numbers), authored Normal, so the player's
  Easy is gentler than Normal on the first landing too.
- **Hollow Meridian**: HQ power scale 0.7 (Lander 7, was 5: not even a Muster Bay and a
  Sentry); Custodians stir within 26 m of a waking engine (was 32); Sentinel lens 50
  damage (60).
- **Units** (`tools/balance_units.py`): Sentry repeater 12 dmg / 0.7 s (10 / 0.8: weaker
  and dearer than the Combine Spire); Mauler range 20 m (26: it out-ranged every Concord
  unit but the Arc, and Sentries); Lancer rail 52 dmg (42: at twice a Ranger's cost it
  was barely better against armour); Bulwark 230/50 (250/60); Arc 220/70, 80 dmg
  (240/90, 70); Talon 200/60 (220/80). The Combine's cheap units stay more efficient
  per Alloy (PLAN §2.1: cheap and numerous); the Concord's edge is health per unit and
  the Sentry line.

Tests that pinned old numbers were updated on purpose: tech count and costs
(`test_campaign_state`, `test_campaign_flow`), Holdout wave sizes and times
(`test_holdout`, `test_emberfall_landing_round_trip`), the artefact spot
(`test_tidal_landing_round_trip`) and the Hollow Lander's power
(`test_hollow_landing_round_trip`).

### Campaign economy

Discovery sites pay on every landing on their map (the campaign keeps no per-site
memory), so a reasonable explorer banks about 2,300 Intel before the finale against a
web that cost 1,855: about 90% of it. Tech costs were scaled: the roster unlocks (Survey
Lab, Lancer, Sentry, Arc, Talon) ×1.5 so they stay reachable early, everything else
×2.2. The web now costs 4,005. `tools/balance_campaign.py` (cheapest affordable tech
first at every Meridian stop): a reasonable explorer owns 55% of the web at the finale,
a lazier one (70% of the exploring) 40%.

**The Talon** is locked at the campaign start and unlocked by a new tech, *Talon
Frames* (Arms, 150 Intel, no prerequisite); *Talon Plating* requires it. The model
has it bought before Thalassa Recovery. The Verdance briefing says so.

### Performance

Headless sim cost, ~220-unit battles (budget 100 ms per tick at 10 ticks/s):

| Bench | Sim tick mean / p95 / max, before → after | Commander decision |
|---|---|---|
| `bench_battle` (Kessel, 233 units) | 5.3 / 7.8 / 12.8 → 4.8 / 7.8 / 11.6 ms | 4.7 → 4.1 ms |
| `bench_finale` (new: Meridian deck, 24 Custodians awake, flyers, 223 units) | 4.6 / 5.4 / 7.5 → 4.0 / 4.8 / 6.9 ms | 5.1 → 4.7 ms |

Rendered at 1920×1080 on the development Mac, the tick cost 15.7 ms against 5.3 ms
headless: 6 ms of it was `CombatVfx` building a new capsule mesh (a vertex loop in
GDScript) and a new material for every projectile. Meshes, materials and trail looks
are now shared. Rendered `bench_battle`: tick 15.7 → 9.3 ms, frame mean 11.1 → 10.1 ms
(about 100 fps), frame p95 27.2 → 20.1 ms. The frames that carry a sim tick still dip
to about 50 fps (one frame in six); spreading the tick over frames would be the next
step if that shows as stutter.

### Test suite

`tools/check.sh` runs GUT twice: every test outside `tests/audio` with `--fixed-fps 60`
(frames run as fast as the machine allows; those tests only wait on frames), and the
audio tests in real time (they record the live mixer). Local suite 224 s → 198 s
(59 s for 657 tests, 139 s for 415 audio tests). `tests/audio/test_final_mix.gd` alone
takes about 126 s; shortening it belongs to the audio lane.

## What only a human play-test can settle

- **Hollow Power** is a 35-minute grind decided by Custodians; the reference lost or
  timed out in every Normal seed after the last changes (2/3 won in an intermediate
  pass). Engines needed, hold time and guard counts need a human's eye: is fighting the
  guardians the fun part or the chore?
- **Recovery and Survey are short by nature** on these maps: a carry across Thalassa
  takes under a minute, and ten Kessel sites go in a few minutes. Recovery lasts about
  5 min, Survey 4-15 min. A longer Recovery needs a mechanic (for instance a seal that
  opens at the first low tide): a design call.
- Whether the reference's habits match players': it never micro-manages, retreats only
  by rule, and scans almost every site (its Intel per landing is the model's upper end).
- Infiltration (both missions): patrol timing, sight cones and the alert meter.
- The Holdout surge: the reference mostly loses at the 10:30 surge, with its army by the
  vents. Whether the warning reads clearly enough is a UI question.
- Feel: unit speeds, how hard Hornets are to see under the canopy, and whether the
  50 fps tick frames in big fights are noticeable.
- Kessel Proving on Hard (the old Normal numbers) lost two of three: it is the first
  landing; whether Hard should stay that sharp there is a judgement call.
- Not from this lane: the `check_scripts` step of `tools/check.sh` reports leaked
  objects at exit on a clean HEAD as well (since the settings/UI commit), so the gate
  stops there until that is fixed.
