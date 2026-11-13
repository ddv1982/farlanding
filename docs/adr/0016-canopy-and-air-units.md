# ADR 0016 — Canopy on Verdance, and air units

- Status: accepted (Phase 8c, 2026-11-13)

## Context

Verdance is the fourth planet. Its rule (PLAN §2.5): "Canopy hides ground units from
air and from long-range sight". PLAN §2.3 also promised air units after the vertical
slice, and the rule only means something when there is something in the air. Both
have to work through the systems we already have: one vision grid per faction
(ADR 0007), stealth on that grid (ADR 0010), planet rules as data acting through
`WorldConditions`/`Events` (ADR 0011), maps as data (ADR 0014), saves (ADR 0013). The
lead made the terrain (`verdance_basin_ground.glb`: ground, trunk and ridge colliders,
crowns, undergrowth), the visuals scene, the Talon and Hornet models and icons, the
planet emblem and the contract signal `Events.canopy_cover_changed(unit, covered)`.

## Decision

### The canopy (`CanopyRule`, `CanopySystem`)

- **Crowns are map data**: `MapDef.canopy_zones`, one `Vector4` per grove (centre x, z,
  radii x, z) copied from the terrain recipe's `GROVES`. `LandingMap` hands them to
  `SimWorld.canopy_zones`; `CanopySystem` stamps them into a 1 m cover map once.
- **Who is covered**: every living ground unit (not flyers) standing in a crown, and,
  because `CanopyRule.hides_buildings` is on, every building whose centre is in one.
  Recomputed each sim tick; a unit going under or coming out emits
  `Events.canopy_cover_changed` (for every faction; quiet on a load).
- **Who sees it**: a covered entity is hidden from a faction unless that faction has a
  *ground* observer (unit or building, not dormant) within `close_sight` (9 m, edge
  to edge) of it, or it fired in the last `fire_reveal_seconds` (4 s; any
  `Events.weapon_fired` by a covered shooter, which covers buildings that fire too).
  Flyers never count as observers. The perk stat `canopy_sight` (`FactionPerks`)
  scales close sight per faction or per observer type.
- **One answer everywhere**: `PlanetRuleSystem` gained two hooks, `hides(faction,
  entity)` and `hides_from_air(entity)`, false by default. The running rule is the
  world's sight *cover*: `VisionSystem.cover` (so `can_see()`, `refresh_unit()`,
  `refresh_building()`) and `StealthSystem.cover` (watchers notice nothing the cover
  hides from them, and a flying watcher nothing under a crown). Because targeting
  (`Combat.can_target`), the AI's port (`seen_enemies_near`), the player's view
  (`is_visible_to_player` / `visible`, which the minimap draws) and the selection
  rules all go through `VisionSystem`, hidden means the same thing everywhere; no
  parallel path. The grid itself is unchanged: a covered unit sees out as far as
  ever (the ambush is the point), and the fog shows the ground under a crown as
  visible while what stands there stays hidden.
- **Air cannot target what is under a crown** (`Combat.can_engage`, below) unless it
  gave itself away by firing. A ground observer spotting a covered unit lets its
  faction's ground guns fire, not its flyers.
- **Buildings**: hidden the same way, chosen so a base tucked under a grove is a real
  option (and the Combine cannot see one from a Hornet). A building that fires is
  revealed like a unit; once the player has seen an enemy building it is remembered as
  before.
- **HUD**: the planet indicator shows `CANOPY · n UNDER COVER / IN THE OPEN` and the
  share of the player's ground units under cover. A selected unit under a crown shows a
  small green COVER mark (`UnitVisual.set_covered`, fed by `MissionPresentation` from
  the event).
- **Saved**: the fire reveals (ticks left, by entity id) and who is covered (restored
  quietly, so loading does not announce cover again).

### Air units

- `UnitDef.flies` and `flight_altitude` (13 m, above the 10.5–13 m crowns). A flyer's
  `Locomotion` keeps its altitude above the terrain (the sim position carries it, so
  aim points, picking and projectiles follow) and moves on `SimWorld.air_paths`, a
  plain straight-line `PathService`: no navmesh, no blocked areas, no RVO agent. So it
  never blocks or is blocked by ground units, is never evacuated for a building, and
  the sea, lava or a storm's ground factor do not apply (`rides_above_ground()`: storms
  slow it like a hover unit).
- `FlightSystem` (owned by `SimWorld`, after the units each tick) pushes flyers apart
  (bodies + 1.5 m, half the overlap per tick, at most 0.8 m) — cheap, deterministic,
  free without flyers. Formations take their slot layout from a ground unit of the
  group when there is one.
- **Combat**: armour class `air` in the damage table (light ×1, heavy ×0.75,
  pierce ×0.6). `WeaponDef.hits_air` / `hits_ground` say what a gun reaches
  (`reaches(airborne)`). `Combat.can_engage(shooter, weapon, target)` = `can_target`
  for its faction + the gun reaches it + a flying shooter is not aiming under a crown;
  `find_target` takes the weapon and whether the shooter flies. Weapons, unit orders,
  return fire and `AttackCommand` (receivers whose gun cannot reach the target keep
  their orders) all use it. Ground splash skips flyers. Shoot up: Ranger, Sentry,
  Skitter, Spire, Talon. Not: Lancer, Bulwark, Arc, Kite, Stinger, Mauler, Warden,
  Hornet.
- **Talon** (`concord_talon`, Foundry, 220 Alloy + 80 Flux): 320 health, 10 m/s, twin
  autocannon (11 light, 14 m) that hits ground and air. **Hornet** (`combine_hornet`,
  Forge, 95 Alloy): 150 health, 11 m/s, dart gun (8 light, 12 m) for the ground only;
  a watcher (sensor 1, 140° cone). Neither carries. Presentation: the model sits at
  the unit root (at altitude), fans (`fan`, `fan_*`) spin about their up axis, a slow
  bob, no dust, the selection ring on the ground below.

### The enemy

- `AiSighting.airborne`, `AiKnowledge.air_share()`, `CommanderView.enemy_air_share`.
  `CommanderProfile.anti_air` (the Skitter in every Combine profile): its weight in
  the army mix grows ×(1 + 4·share) once flyers are seen (it is added to the mix even
  when not in it), and one more defence tower (the Spire shoots up) is wanted.
- AI groups focus on enemies some member can hit (`AttackGroup.pick_focus` with the
  members) and only order members whose gun reaches the target
  (`AiGroup.order_attack`).
- **Hornets on Verdance**: `combine_understory` (scout = Hornet, Hornets in the army
  mix and opening) and Hornet patrols in both missions. A commander now leaves units
  its faction's `GuardCommander` patrols with alone (`Commander.guards`).
- Honesty: the AI only perceives through `WorldAiPort.seen_enemies`, which goes
  through `VisionSystem.can_see`, so it never knows of a covered unit its own ground
  observers are not close to (tested).

### Content

- `maps/verdance_understory/`: the lead's visuals, `bake_verdance_navmesh.gd` (ground
  below −1.0 m cut, well below the stream bed at −0.3 m, so the stream stays wadeable;
  islands on trunks and ridges dropped; 10 908 polygons), `verdance_understory.tscn`,
  and `data/maps/verdance_understory_map.tres`: 13 crowns, 12 deposits on the open
  floor and in two groves, 4 rich deposits and 4 of 6 vents under crowns, 6 sites all
  in groves, two dormant Wardens under the south-east grove, 8 boulders at grove
  mouths (`verdance_mossrocks.tres`). Moss greens on the minimap.
- Discoveries: `verdance_trail_root` (the trail; charted by a carryover from the
  Emberfall furnace, or led to by the moths), `verdance_glowcap_ring` (heal field),
  `verdance_root_vein` (a rich deposit), `verdance_combine_listening_post` (reveals
  the enemy), `verdance_lantern_moths`, `verdance_seed_vault` (a rich deposit, guarded).
- Missions: **Canopy Conquest** (`verdance_conquest`: Conquest, three Hornets on two
  patrols over the approaches, the understory commander) and **Under the Crowns**
  (`verdance_infiltration`: no base, two Surveyors and three Rangers, Hornet patrols
  over the lanes and the outpost, a Skitter under the outpost's grove, an alert meter;
  scan the moths and the listening post, then get home; `InfiltrationScript` with a
  `scan_sites` target). Route: Caldera Holdout → Canopy Conquest → Under the Crowns;
  both in the catalog.
- Techs: `understory_optics` (canopy sight ×1.5; needs the lantern moths),
  `root_listeners` (Sentries and the Lander ×2.5; needs the root vein and the optics),
  `talon_plating` (Talons +30 % health).
- Hints: `canopy` (new trigger `canopy_cover`: a player's unit goes under a crown) and
  `air_units` (selecting a Talon).

## Consequences

- Another sight rule (fog banks, a cloaking field) is a `PlanetRuleSystem` that answers
  `hides()`; the rest of the game follows.
- Covered units cost one cover-map lookup per unit per tick and one spatial-grid query
  per covered entity; nothing without a canopy.
- Flyers ignore terrain for sight as everything does (no line of sight in the grid).
  The fog does not darken the ground under crowns: hidden units are simply not drawn.
- Air-to-air: only the Talon among flyers fights flyers; the Combine answers Talons from
  the ground.
- Placeholders: tech icons (`tech_understory_optics`, `tech_root_listeners`,
  `tech_talon_plating`) fall back to the letter swatch; the COVER mark and the
  Hornets' sight cones at altitude are plain.
