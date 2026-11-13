# ADR 0015 — Eruptions on Emberfall, and the Holdout

- Status: accepted (Phase 8b, 2026-11-13)

## Context

Emberfall is the third planet. Its rule (PLAN §2.5): "Flux vents are rich but erupt;
buildings near them take damage". Phase 8 also asks for the Holdout mission type
(PLAN §2.6: "keep a site alive until extraction"). The rule has to be a decision for
the player, not a random tax; it must act through `WorldConditions`/`Events` and the
existing systems like the storm and the tide (ADR 0011, ADR 0014), be public
knowledge for the AI, and survive a save (ADR 0013). The lead made the terrain, the
visuals scene (with `EruptionVfx`) and the two contract signals
`Events.eruption_warning(vent, seconds, radius)` and `Events.eruption(vent, radius)`.

## Decision

### The rule (`EruptionRule`, `EruptionSystem`)

Every vent whose `ResourceNodeDef.erupts` is set plays its own cycle:

    calm (pressure builds) -> warning (eruption_warning) -> burst (eruption) -> quiet -> calm

- **Pressure (0..1)** builds at `tapped_rate` while a working Flux Tap draws on the vent
  and at `idle_rate` otherwise (a knocked-out, unfinished or sabotaged Tap counts
  as idle). Each cycle the vent bursts at a threshold drawn between `threshold_min` and
  1 from the rule's seed; every vent starts the landing with a random pressure up to
  `start_pressure_max`. The RNG state is saved.
- **The warning**: at the threshold the burst is announced `warning_seconds` ahead
  (`Events.eruption_warning`; the Advisor's `eruption_warning`, throttled to one per
  `alert_seconds`, and only for a vent the player has explored or has something within
  `alert_distance` of).
- **The burst** (`Events.eruption`): buildings whose footprint comes within `radius`
  take `building_damage` (scaled by the owner's `eruption_damage` perk), units within
  `radius` + their body take `unit_damage`; damage is plain `Health.take` with no
  attacker (no armour, no "under attack" alert). The Tap on the vent is **knocked out**
  for `knockout_seconds` (`FluxExtractor.stall`, it yields nothing; `knocked_out_changed`).
  Chosen over destroying it: the Tap already takes the building damage, so three
  unvented eruptions destroy it anyway, and a knock-out keeps the vent worth holding.
  The pressure empties and stays put for `quiet_seconds`. If a player's unit or
  building died or was left at 30 % health or less, the Advisor says `eruption_damage`.
- **Controlled venting** (`VentCommand`, the command panel's VENT button on a Flux Tap):
  from `vent_min_pressure` on, the Tap's owner releases the pressure on purpose. It
  calls off an announced eruption, costs the Tap `vent_damage` and a `vent_stall_seconds`
  pause, and the vent cannot be vented again for `vent_cooldown_seconds` (scaled by the
  `vent_cooldown` perk). Refusals: `pressure_low`, `cooling_down`, `surging`, `not_a_tap`.
  The player hears `ui_feedback` `vent_release` or `vent_denied`.
- **Rich vents**: `ResourceNodeDef.flux_rate_scale` (Emberfall's are 2.5) shortens the
  Tap's interval (`FluxExtractor.set_rate_scale`, saved). The vents never run out, so
  "much more Flux" is a faster yield, paid for in pressure.
- **The surge** (`schedule_surge(tick)`, also the rule's `schedule_climax`): every vent
  inside `surge_area` (the caldera plateau) erupts in turn, one each
  `surge_step_seconds` from the surge's tick, ordered round the caldera; announced
  `surge_warning_seconds` ahead (Advisor `surge_incoming`), each vent with its own
  `eruption_warning`. Once a vent's surge warning runs it cannot be vented.
- **Forecast**: a new discovery payoff `forecast` (`DiscoveryDef.PAYOFF_FORECAST`) calls
  `PlanetRuleSystem.forecast(faction, seconds)`. Emberfall's seismic fissure names the
  vent that will burst next (from the hidden thresholds and the current rates) for
  seven minutes: `ResourceNode.is_next_to_erupt` / `forecast_changed`, and the gauge's
  "NEXT ~0:40".
- **HUD**: `PlanetIndicator` shows `VENTS · STABLE / PRESSURE 70% / NEXT ~0:40 /
  ERUPTING IN 0:08 / SURGE IN 0:40` for the most pressing vent (the soonest announced,
  else the fullest the player has explored), and a bar of its pressure.
- **Lava** is never walkable: `bake_emberfall_navmesh.gd` cuts the ground below
  -0.5 m (the lava sheet is at -0.9 m, the river beds at -2.0 m) from the source
  geometry. A map without a sea gives hovering units the same navmesh, so they do not
  cross lava either.

Emberfall's numbers (`data/planets/emberfall.tres`, the rule's defaults): tapped
0.011/s (an empty vent fills in about 91 s of tapping), idle 0.002/s, threshold
0.85–1, start pressure 0–0.35, warning 12 s, radius 12 m, buildings 260 damage, units
45, knock-out 40 s, quiet 30 s; venting from 25 %, 40 damage, 6 s pause, 90 s cooldown;
surge step 3 s, announced 45 s ahead. A Flux Tap (600 health) on a rich vent yields
5 Flux every 1.6 s (3.1/s, against 1.25/s on an ordinary vent), about 280 Flux per
cycle. A cycle of tapping (77–91 s to the threshold, plus the warning) is shorter than
the venting cooldown, so venting every time is not possible without Pressure Valves:
the player chooses which bursts to take.

### The enemy and the vents (`VentKeeper`)

Public knowledge goes through `AiPort.vent_dangers()` (x, z, radius, seconds to the
burst; vents announced or at 80 % and more). The commander runs a `VentKeeper` on each
decision (`CommanderProfile` group "Vents"):

- its Taps vent on purpose from `vent_at_pressure` (0.7) or when announced, when the
  EruptionSystem allows it;
- its units inside a vent's radius that bursts within `vent_flee_seconds` (20 s) walk
  5 m beyond the radius (no army is left parked on a vent about to burst);
- it keeps `extractors_wanted` of its `extractor` (the Combine **Siphon**,
  `data/buildings/combine_flux_siphon.tres`) on explored free vents within 1.5×
  `deposit_radius` of home that are under 60 % pressure, with an idle builder.

The Combine spends only Alloy, so the Siphon banks vent Flux as Alloy
(`BuildingDef.flux_banked_as`). The Rigger can build it. Caldera Conquest's commander
(`data/ai/combine_caldera.tres`) starts with Siphons on its home vent and on the caldera.

### Holdout (`WaveScript`, `WaveRules`)

No new objective type was needed: `survive` (its countdown is the extraction) and
`keep_alive` (the Lander) are the objectives. The new reusable `WaveScript` (a
`MissionScript`, data in `WaveRules` as the mission's `script_rules`) sends waves of the
hostile faction at set mission times and sizes, the roster taken in turn (later, larger
waves get more of the heavier types listed last), from entry points in turn, each
announced `warning_seconds` ahead (Advisor `wave_incoming`). A wave is the enemy AI's own
`AttackGroup` in last-stand mode aimed at the site (the player's HQ): it advances,
fights what it meets and never retreats. At `climax_seconds` it schedules the planet's
climax (the surge). `inbound_seconds` before the extraction the Advisor says
`extraction_inbound`; when the survive objective completes, `extraction_arrived` (the
win). Saved: waves sent and warned, the alerts given, the climax scheduled, and the
groups (members by id, their state).

### Content

- `maps/emberfall_caldera/`: the lead's visuals, one navmesh, and
  `data/maps/emberfall_caldera_map.tres`: 12 Alloy deposits on the plains, 4 rich ones on
  the shelves, 2 ordinary vents by the bases, 5 rich erupting vents (three on the
  caldera plateau, two by the western and south-eastern bridges; `MapDef.rich_vent`),
  6 sites (the Antecedent furnace continuing the trail, charted ahead by a carryover
  from the Thalassa vault; the seismic fissure's forecast; ash lichen; a Combine vent
  survey; a slag cache; an obsidian flow that opens a quiet vent), two dormant Wardens on
  the eastern shelf, ten basalt boulders.
- Missions: **Caldera Conquest** (`emberfall_conquest`) and **Caldera Holdout**
  (`emberfall_holdout`, `MissionDef.TYPE_HOLDOUT`: the Lander on the caldera, 12:00,
  eight waves 1:00–11:20 of 3 to 12 units, the surge at 10:30). Route: Low-Water
  Recovery → Caldera Conquest → Caldera Holdout; both in the single-mission catalog. A
  campaign save from before opens new `leads_to` of nodes it already won on load
  (`CampaignState._open_new_leads`).
- Tech: `heat_shielding` (buildings take half eruption damage), `pressure_valves` (Flux
  Taps vent again in half the time), `braced_taps` (Flux Taps +30 % health; needs the
  seismic fissure). Existing ids unchanged.
- Hints: `eruption` (first `eruption_warning`), `holdout` (Holdout start).

## Consequences

- A vent's pressure is the clock, so tapping is the decision: more Flux, more often
  knocked out, more damage near the vent, unless the player spends Tap health and
  cooldowns on venting.
- The vent gauges, the knocked-out Tap and the extraction ship have placeholder looks
  (a `VentGauge` Label3D over each erupting vent; nothing for the others). Signals to
  hook: `ResourceNode.pressure_changed(pressure, seconds_to_burst)`,
  `ResourceNode.forecast_changed`, `FluxExtractor.knocked_out_changed`, the Advisor
  kinds `extraction_inbound` / `extraction_arrived`.
- A ramp must top out at the plateau's edge. The first terrain ended its ramps inside
  the plateau, which left a lip of about 0.8 m on the east ramp (more than the 0.5 m
  the bake climbs). The recipe now ends each ramp at the edge, and the map test checks
  all three ramps (south-west, south, east from (42, 3)).
