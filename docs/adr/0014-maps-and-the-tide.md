# ADR 0014 — A general landing map, the tide, and carrying the artefact

- Status: accepted (Phase 8a, 2026-11-13)

## Context

Phase 8 adds the other planets. Thalassa Low is the first: its own map, its rule
("the tide floods lowlands on a timer, opening and closing routes", PLAN §2.5) and a
new mission type, Recovery ("reach an artefact, then get it back to the Lander",
PLAN §2.6). Until now the only map was Kessel Proving Ground, whose script
(`KesselProving`) held the map's layout as exports next to the code that wires a
landing. A second map should be data, the tide must act through `WorldConditions`
and `Events` like the storm (ADR 0011), and both must survive a save (ADR 0013).

## Decision

### A landing map is a base scene and a MapDef

`maps/landing_map.tscn` + `landing_map.gd` (`LandingMap`) is what `KesselProving` was:
mission context, `SimWorld`, navigation region, camera, selection, HUD, and the code
that builds the terrain data, places a fresh landing or restores a saved one, and
makes the snapshot. Everything that differs per map is in a `MapDef` resource
(`core/defs/map_def.gd`): terrain area, height spacing, vision cell, landing zone,
build bounds, default mission, the navmesh (and on a tidal map its flood stages, their
sea levels and clip heights), dry crossings for the AI, resource nodes, discovery
sites, dormant Custodians and natural cover.

A map scene inherits `landing_map.tscn`, adds its visuals scene (terrain with a
collider, light, environment, VFX) and sets `map_def`. **A new map needs:** a visuals
scene, a navmesh baked from it (a bake script like `bake_kessel_navmesh.gd` or
`bake_thalassa_navmesh.gd`), a `MapDef` in `data/maps/`, and the two-node scene. No
code. Kessel became `kessel_proving.tscn` (two nodes) + `data/maps/kessel_proving_map.tres`
with the same numbers; its saves, tests, benchmarks and the mission smoke test run as
before (`tests/maps/test_landing_maps.gd` checks it lands with the same contents).

### The tide (`TideRule`, `TideSystem`, `FloodSystem`)

`TideRule` (a `PlanetRule`) holds the numbers; `TideSystem` (a `PlanetRuleSystem`)
plays them: low → (rise announced) → rising → high → (fall announced) → falling → low.
Each turn is announced `warning_seconds` ahead with `Events.tide_turning(seconds,
rising)` and the Advisor's `tide_rising` / `tide_falling`; the holds vary from the
rule's seed (the RNG state is saved). `Events.tide_changed(level)` (0 low .. 1 high)
follows the level at most every 3 ticks and on reaching 0 or 1. The rule writes only
`WorldConditions`: `sea_level`, `low_water`, `high_water`, `wading_depth`, wading speed
and damage, `tide_level`, `tide_rising`, `tide_eta_seconds`, `shallows_close_seconds`.
The HUD's `PlanetIndicator` shows `TIDE · LOW / RISING IN 0:30 / RISING / HIGH /
FALLING IN … / FALLING` and a bar of the level, through the rule's `indicator_*`.

Thalassa's numbers: low water −1.3 m, high water +0.15 m, wading depth 0.25 m; first
rise after 3:30 ± 0:20, low hold 2:30, **rise 45 s**, high hold 1:40, **fall 45 s**
(holds ± 20 s), 30 s warning; units in water deeper than the wading depth move at
0.35× and take 2 damage per second.

`FloodSystem` (owned by `SimWorld`, run every tick after the planet rule, idle and
free without a sea) turns the sea into consequences:

- **Navigation.** `PathService.set_water(level, wading_depth)`: ground lower than
  `closed_below` (sea minus wading depth) is closed to ground units. The base class
  judges it point by point against a height field (tests); `NavmeshPathService`
  switches between **flood stages**: navmeshes for a few sea levels, each with ground
  below its clip height removed. When the stage changes, every ground unit whose
  remaining route runs into closed water, and every unit waiting for the tide, asks
  for a new path: two ticks after the change and then every half second for three
  seconds (the navigation server takes an 11 000-polygon mesh a few frames later).
- **Hovering units** path on their own navigation map holding the lowest stage
  (`PathService.for_hover()`): flooded shallows stay open to them, the deep channel
  (below low water minus the wading depth) never does. Blocked areas are mirrored;
  RVO avoidance stays on the ground map.
- **Waiting for the tide.** A ground unit's path that ends more than 3 m short of
  where it was sent, when the hover paths (sea ignored) get there, marks it
  `is_waiting_for_tide()`: it stands on the shore with its order open, and goes on when
  the sea falls. Move orders place formation slots with the sea ignored, so a click on
  flooded ground means "wait, then go", not "go to the shore".
- **Units caught** by the rising sea (centre in water deeper than the wading depth)
  are slowed and take light damage; idle ones wade to the nearest dry point on their
  own; the player hears `units_in_water` at most every 30 s. Hovering units are never
  caught.
- **Deposits** under the sea are `is_flooded`: haulers deliver what they carry, move
  to a dry deposit within the search radius, or wait on ground above high water and go
  back when it is dry. `nearest_deposit()` and the AI's deposit search pass flooded
  ones over.
- **Placement** refuses ground that floods at high water (`PlacementRules.FLOODS`,
  "The tide floods this ground"), at any tide.

**Why flood stages.** Cutting the flooded area out of the navmesh at runtime like a
building (ADR 0006) does not work: the shore is a contour, not a rectangle, and the
cutter's rectangles cost a few milliseconds each. Rebaking at runtime costs seconds.
A handful of stages baked offline costs ~110 KB each. Every stage keeps its own
cutter; they are all prepared with the buildings and props while the landing loads
(`prepare_flood_stages()`), each later cut is queued for every stage, and a switch
applies the stage's queued cuts and hands its mesh to the region (3–4 ms; see
`docs/PERFORMANCE.md`). A stage is conservative: it closes ground at the
height the *top* of its sea range makes too deep, so a route closes before anyone on
it would wade. Thalassa has four stages (`bake_thalassa_navmesh.gd`): from sea −1.3
(clip −1.2: fords open), −0.95 (clip −0.7: the fords' necks close), −0.45 (clip −0.4:
the fords' bars and the pans close), −0.15 (clip −0.1, to high water). Stage 0 is baked
from the terrain with the ground below −1.2 m cut from the source geometry; stages
1–3 are stage 0 with its polygons clipped where the *terrain* (a height field sampled
from the collider) crosses their height (`NavmeshTools.clip_navmesh`; the navmesh
itself floats ~0.4 m above the terrain, so its own heights would close the ford
0.4 m too late). Their dry ground keeps stage 0's polygons, and neighbours share the
new points, so the mesh stays joined edge to edge.

**Engineering found on the way.** Two things the navigation server does that cost
time to find: (1) it stops an A* search after `path_search_max_polygons` (default
4096) and returns a path to the nearest point found; on a map of 11 000 polygons a
long detour (the causeway at high water) ended half-way. `NavmeshPathService` raises
it to 65 536. (2) It joins edges by rasterising their end points; near-duplicate
vertices from the clipped bake made it reject edges ("edge errors"), so the bake
cleans edges as the server joins them (`remove_nonmanifold_edges(…, merge_scale)`). A
navigation map made with `map_create()` behaved as if it rasterised more finely than
the world's default map although both report the same merge scale; the hover map sets
scale 1, which joins like the default map (measured).

### The enemy and the tide

The tide is public, like the weather: `AiPort.tide_level()`,
`shallows_close_seconds()`, `dry_crossing(from, to)` (the map's always-dry crossing
nearest the way, when the straight way crosses ground below low water). Any group
order (`AiGroup.order_move`) goes through the causeway first while the shallows are
unsafe (the sea is up, or the next rise is less than `tide_safe_seconds`, 70 s,
away). `CommanderProfile.tide_tactic`: `causeway` (default) or `wait`: no new wave
leaves until the shallows are safe. Haulers do not drown: they use the same harvest
rules, and the commander's deposit search skips flooded deposits.

### Carrying (`Carrier`, `CarryCommand`, two objectives)

- `PropDef.carriable` marks a prop that can be lifted (it should neither block
  movement nor sight). Carriable props join group `artefacts` (audio hums for them)
  and turn a model part named `core` slowly. `UnitDef.can_carry` (default true) gives a
  unit a `Carrier` order handler.
- `CarryCommand` sends the receiver nearest the prop that can lift it (`carry`
  order: walk, lift within reach); the others walk along as escort. Nothing happens if
  someone carries it.
- A carrier moves at 0.6× (`Locomotion.set_extra_scale(&"carrying")`, the same
  mechanism as wading), does not fire or answer fire, and drops the prop where it dies
  (`Health.died`). Any unit — of either side — may lift a prop nobody carries.
- Announcements: `Events.cargo_picked_up` / `cargo_dropped` (and `Prop.carried_changed`);
  for the player's units `ui_feedback` `artefact_pickup` / `artefact_drop`; the Advisor
  says `artefact_secured` when the player's side lifts it after nobody or the enemy
  had it, and `artefact_taken` when the enemy lifts it.
- Objectives (reusable): `carry_to` (done when the side brings a matching carriable
  prop into the area, carried or put down there; the progress line says where it is)
  and `keep_from_enemy` (passive: fails when the enemy brings it into the area — its
  base — remembering who carried it last, saved).
- The Combine's side: `CommanderProfile.retrieves_cargo` sends a squad
  (`RetrieveGroup`: fetch → bring home, attacking a visible enemy carrier) after
  `retrieve_after_seconds`.
- Saved: `Carrier` saves its cargo by id and lifts it again in `resolve_references`
  without announcing anything; `Prop` v2 saves `lifted` and `last_faction`;
  `Locomotion` v2 saves where it was sent and the wait for the tide; `TideSystem` its
  state, level, schedule and RNG. `SaveGame.FORMAT_VERSION` is 2 (format 1 still loads).

### Content

- `maps/thalassa_tidewater/`: the lead's `thalassa_visuals.tscn`, four flood-stage
  navmeshes and `data/maps/thalassa_tidewater_map.tres`: 12 deposits and 4 rich ones in
  the tidal pans, 6 vents, 8 sites (a two-step Antecedent chain, the trail echo → the
  shoal vault, charted ahead by a Kessel carryover; the drowned cache in a pan), two
  dormant Wardens on the eastern shoal, 11 reef rocks, the causeway as dry crossing.
- `thalassa_shallows` (Tidewater Landing, Conquest) now plays there; the route node
  id is unchanged so campaign saves load. `thalassa_recovery` (Low-Water Recovery)
  follows it on the route and is in the single-mission catalog.
- Tutorial hints `tide` (first `tide_turning`) and `carry` (Recovery start).
- `tests/maps/test_landing_maps.gd` checks both bases, every deposit, site and
  crossing on the real navmeshes at low and at high water, for ground and hovering
  units, and that the bake's numbers match the MapDef and the rule.

## Consequences

- A new map is data. A new tidal map also needs its stages baked; the stage levels
  are a design choice (when each crossing closes) and a test should hold them to the
  rule's numbers.
- Units right at a stage's shore stand at the edge of wading depth at the top of the
  stage's range; stages 1–3 are not eroded by the agent radius as stage 0 is.
- Rising water reaches a waiting unit's shore only as far as the next stage, where it
  re-plans to the new shore.
- Path searches may visit up to 65 536 polygons; an unreachable target on a large map
  costs more than before (still once per order).
- Placeholders waiting for art: the carried look (the artefact's model rides 1.9 m
  above its carrier), the carry cursor (the assist cursor), no closed-ford marker and
  no flooded tint on placement or deposits (signals exist: `ResourceNode.flooded_changed`,
  `Prop.carried_changed`, `Events.tide_changed`, `NavmeshPathService.flood_stage`).
