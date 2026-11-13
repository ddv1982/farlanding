# ADR 0011 — Planet rules as data, honest props, and the Phase 6 flow

- Status: accepted (Phase 6, 2026-11-13)

## Context

PLAN §2.5 gives every planet one rule; Kessel Reach's is "periodic dust storms cut
vision and ground speed for everyone". Phase 6 also asks for map cover that matters
for stealth, a settings menu with a pause menu, first-time tutorial prompts, a Survey
mission where the Combine competes, artillery that copes with its minimum range, and
a performance pass. Later planets (tides, eruptions, canopy) must add their rule
without touching the engine.

## Decision

### Planet rules (`core/defs/planet_*.gd`, `sim/systems/planet/`)

| Piece | Role |
|---|---|
| `PlanetDef` (Resource) | id, name, one `PlanetRule`. A `MissionDef` names its `planet`. |
| `PlanetRule` (Resource) | id, summary, `random_seed`, and `system`: the script that plays it. Subclasses carry the numbers (`DustStormRule`). |
| `PlanetRuleSystem` | base class run by the world: `start(world, rule)` instantiates the rule's `system`, `tick()` runs first on every sim tick, `schedule_climax(tick)`, `indicator_*` for the HUD, `to_dict/from_dict`. |
| `WorldConditions` | the weather everyone plays under: vision, ground and hover speed, sight-cone and long-range factors, storm intensity / ETA / final flag. All 1 on a calm world. |
| `DustStormSystem` | Kessel's storms. |

A rule changes the world **only through `WorldConditions`** (and `Events`). The
simulation reads them where it already had the numbers:

- `VisionSystem.range_scale` multiplies every unit's and building's vision radius
  (fog of war and targeting). The factor is kept in 0.05 steps so the grid sees few
  distinct radii.
- `Locomotion.set_speed_scale()` multiplies the top speed (ground or hover factor by
  the new `UnitDef.hovers`); the world re-applies it only when a factor changed.
- `Unit.sight_range` (what watchers notice intruders in, and the sight-cone visual)
  takes the sight factor: stealth gets easier in a storm.
- `Combat.weapon_range(def)`: weapons reaching beyond `long_range_from` (18 m) are
  shortened by the range factor but never below it (Arc 40 → 28 m, Mauler 26 → 18.2).
  `Weapon.in_range`, target search and the units' engagement distances use it.

Storm cycle: clear → warning (`Events.storm_incoming(seconds)`, Advisor
`storm_warning`) → building → full → fading → clear (Advisor `storm_passed`) → the
next one is drawn (interval ± variation, from the rule's seed; the RNG state is
saved). `Events.storm_changed(intensity)` follows the intensity at most every 3 ticks
(and on hitting 0 or 1). Defaults: first storm after 4:00 ± 1:00, then every
5:00 ± 1:00, 40 s warning, 20 s build, 50 ± 15 s full, 25 s fade; at full strength
vision ×0.5, ground speed ×0.65, hover ×0.85, sight cones ×0.55, long range ×0.7.

**Climax.** `MissionDef.climax_objective` names an objective whose deadline is the
planet's climax: Survey's `bank_intel` deadline (15:00) is the storm that does not
lift. It is announced like a storm (Advisor `storm_final` instead of
`storm_warning`), is at full strength exactly at the deadline and never fades; a
regular storm that would run into it is not scheduled, one already fading turns back.

**Everyone sees the weather.** It is public knowledge, so the AI may read it
(`AiPort.storm_intensity/storm_eta_seconds/storm_is_final`). `CommanderProfile.storm_tactic`:
*hold* (the Conquest commander) launches no wave while a storm blows or is under 25 s
away, and calls a wave home once one passes 0.5; *press* (the Survey raiders) sends
the next wave as the storm arrives, at half strength (minimum 2). A storm that never
lifts is not waited out.

HUD: `PlanetIndicator` under the top-right buttons shows any rule's
`indicator_title/text/level/alarm` ("DUST STORM · CLEAR / IN 0:35 / BUILDING / FULL /
PASSING / BURIED", a bar of the intensity). The look is the lead's `StormVfx`
(listens to `storm_changed`).

### Props (`core/defs/prop_def.gd`, `sim/entities/prop.gd`)

`PropDef` (an `EntityDef`): size (w × h × d), `blocks_movement`, `blocks_sight`,
`max_health` (0 = indestructible), armour, `model`, `sound_set`. `PropPlacement`
(def, position, quarter turns) and `PropLayout` (a list) place them: the map's
`prop_layout` (natural cover on every mission: eight boulders) and the mission's
`props` (the Infiltration outpost). `SimWorld.spawn_prop()`:

- cuts the footprint out of the navmesh like a building (ADR 0006; quarter turns keep
  it axis-aligned) and evacuates units standing there;
- registers it as a **sight blocker** when `blocks_sight` and at least 1.5 m tall:
  - the vision grid stamps a disc that reaches an occluder as the runs of cells the
    source can see. The shadow of a box from a point is `source + λ (box − source)`,
    λ ≥ 1; on one row of cells that is a single x-interval found from the λ range
    the row allows, so a shadowed disc costs a few operations per row and occluder,
    not a segment test per cell. Discs are cached per source cell and radius until
    the occluders change. A source standing at an occluder (touching it) sees over
    it; the occluder's own cells are seen (its top);
  - `StealthSystem.has_line_of_sight()` also fails when the eye-to-target segment
    crosses a sight-blocking footprint, so a guard cannot notice a Wisp behind it;
- props have no faction: never selectable, never auto-targeted, not valid attack
  targets. Destructible ones take **splash** damage (shells, the Mauler) through
  `Combat`; destroyed, they stop blocking (navmesh restored, occluders refreshed) and
  `Events.entity_died(prop)` fires (props are in group `props`; audio plays
  `death_<sound_set>`);
- the look is the def's model, or a placeholder box of the prop's size;
- saved: destroyed and damaged props (`SimWorld.to_dict()["props"]`).

Infiltration outpost: two barrier segments close the west gate from the ridge to the
gate lane, a fuel tank stands inside the gate patrol's loop (it hides the west lane
while the patrol walks the east leg), crates shadow the sentry's cone on the approach,
and the east corridor has pockets on alternating sides of the corridor guard's beat
(a barrier from the east edge, crates on the west side, a tank). Every patrol leg,
the routes from the drop to the uplink, the corridor and every site were checked on
the real navmesh with and without the props (paths still exist, no new edge errors,
no prop overlaps a node, building or site).

### Settings, pause, flow

- `Settings` (autoload) adds edge-pan, pan speed (0.5–2×), fullscreen, quality preset
  (low: no shadows or glow; medium: 2048 shadow atlas; high: 4096 and soft shadows),
  3D resolution scale (0.5–1), and the hints seen. Every setter saves at once
  (`Settings.path`, which tests point elsewhere). `GraphicsSettings.apply(root,
  preset)` sets shadows and glow on a loaded map (remembering what the map chose).
- `SettingsPanel` (volumes, mouse scheme, edge-pan, pan speed, fullscreen, quality,
  resolution, Reset hints) opens from the mission select and from the pause menu.
- `PauseMenu` (Esc in a mission, or the HUD's MENU button, which replaced the
  MOUSE toggle): Resume, Settings, Restart, Quit to missions. It stops the sim clock
  and the camera, takes all clicks, and eats keys while open. The scene tree is not
  paused, so audio keeps playing under its pause mix (`ui_feedback` `pause_open` /
  `pause_close`).
- `Main` instances `res://presentation/menu_backdrop.tscn` (when it exists) behind
  the mission select and briefing, whose backgrounds then turn see-through, and frees
  it before a map loads. It emits `menu_open` / `menu_close`.

### Tutorial hints

`HintDef` (id, title, text with `{command}` / `{select}`, trigger, subject, mission
types, delay) in `data/hints/catalog.tres` (a `HintCatalog`). Triggers:
`mission_started`, `selected` (subject: a capability — builder, harvester, scanner,
saboteur, producer — or a def id), `construction_completed` (def id),
`storm_incoming`, `alert_meter`. `HintDirector` queues matching unseen hints; one card
at a time shows below the resource bar (`TutorialHints`), never taking clicks except
GOT IT, gone after 16 s. A hint is marked seen (saved) when shown. Nine hints:
select and move, build a Reactor, harvest, produce, scan a "?", the Survey Lab,
storm incoming, sight cones, sabotage.

### Survey pressure

The Combine Rigger can scan (`scan_rate` 0.4). `CommanderProfile.surveyor`,
`surveyors_wanted`, `survey_after_seconds`: the raiders keep two Riggers scanning
(making more at the Hub, always keeping one as a builder) from 1:30.
`SurveyBehaviour` sends each to the nearest open site (charted — the orbital scan is
everyone's — and unresolved) no other surveyor is on, through `ScanCommand` and the
same `Scanner` the player's Surveyors use; a surveyor that sees enemies within 16 m
runs home for 20 s. Intel goes to the Combine's stockpile only. The new objective
type `rival_intel` fails when the rival banks `amount`: Survey's primary
"Bank yours before the Combine banks 250" (passive). Objectives can show a bar
(`progress_ratio`, `progress_side`): Intel banked in the Intel colour, the Combine's
in the warning colour. The Advisor says `enemy_intel` when the Combine banks more.

### Artillery

`UnitOrders.min_engage_distance` (minimum range + 1.5 m): an attack whose target is
inside it backs straight away (re-pathing at most once a second) until the target can
be hit; an attacker up close is answered the same way. Auto-targeting already skipped
targets inside the minimum range; engagement distances now follow the storm's range.

### Engineering

- **The headless shader leak** (ADR 0010) was not the UnitVisual as such: naming a
  `GPUParticles3D` *before* giving it a `ParticleProcessMaterial`, when the node is
  made after the first frame, leaks one dummy-renderer shader RID at exit (naming it
  afterwards does not; bisected down to that one line). `UnitVisual` (dust) and
  `StormVfx` (grit) now set the name last. `tests/smoke/mission_smoke.tscn` is part of
  `tools/check.sh`, and GUT tests may load real maps (the pause-flow tests do).
- **Performance**: see `docs/PERFORMANCE.md`. The combat spatial grid stores each
  entry's position, body radius and faction as numbers so target search and AI
  perception reject most candidates without touching nodes; units tell the
  navigation server only what changed; aim is re-announced only when it moved; the
  stealth pass is skipped when nobody hides and nobody keeps a meter.
  `SimWorld.profiling` splits the tick cost by system
  (`tests/bench/bench_battle.tscn -- --sections`); the F3 overlay also shows the
  stealth cost and the storm.

## Consequences

- A new planet rule is a Resource subclass, a `PlanetRuleSystem` script and a
  `PlanetDef`; it acts through `WorldConditions` (adding a factor there when it needs
  a new kind of effect).
- Props make cover that the fog, stealth and the AI all respect. A thin prop's
  navmesh cut is wide (2.25 m margin each side), so gaps between props need about
  6 m to stay passable. One spot on the east corridor's deposit field produced a
  navigation-server edge error and was dropped; the cutter's retry (ADR 0006) does not
  catch every case for small rectangles.
- Destructible props can only be hurt by splash today; attack orders on them would
  need click picking and a target rule for factionless things.
- Storm, commander memory and props save; the Mission itself still does not (Phase 7).
