# ADR 0010 — Missions as data, stealth on the vision grid

- Status: accepted (Phase 5, 2026-11-13)

## Context

PLAN §2.6 and §3.6 ask for one objective framework that Conquest, Survey and
Infiltration are assembled from, with triggers and a briefing/debrief flow; §3.4 says
vision, fog and stealth share one system; Phase 5 adds signatures, sight cones, an
alert meter and patrols. Before this phase the Kessel map hard-coded a conquest
skirmish (forces, commander, `ConquestOutcome`).

## Decision

### Missions (`game/missions/`, data in `game/data/missions/`)

| Piece | Role |
|---|---|
| `MissionDef` (Resource) | id, title, type, summary, briefing, map scene, player HQ/start/roster/stockpile, enemy base/roster, commander profile and difficulty, patrol routes, `enemy_alert_meter`, objectives, optional `mission_script` + `script_rules` |
| `ObjectiveDef` (Resource) | one objective: `type`, `kind` (primary/secondary/hidden), `passive`, `deadline_seconds`, `at_start`, and generic parameters (side, defs, amount, require_all, seconds, site ids, area) |
| `Objective` + `objectives/*` | run-time classes: `DestroyAll`, `DestroyCount`, `KeepAlive`, `ReachArea`, `GatherIntel`, `Survive`, `StayUndetected`, `ScanSites`, `Sabotage`; `ObjectiveFactory` maps type → class |
| `Trigger` + `triggers/*` | `AreaTrigger`, `TimerTrigger`, `EventTrigger` (any signal + filter), once or repeating |
| `Mission` (Node) | spawns the def's forces, starts the commander / `GuardCommander`, evaluates objectives and triggers each sim tick after the world, emits the objective events, decides the outcome, keeps debrief numbers |
| `MissionScript` | hooks for rules data cannot express (`InfiltrationScript`) |

- **Outcome.** Won when every non-passive primary objective is done (and there is at
  least one); lost when any primary fails. Losing is checked first, so a Lander and
  the last enemy dying on one tick is a loss. On a win, passive objectives still
  holding (keep the Lander, stay undetected) become done. The old `ConquestOutcome`
  is now `DestroyAll` + `KeepAlive` objectives (the class is left in `sim/` with its
  tests, unused by the game).
- **Hidden objectives** start unknown: no event, not listed. Achieved, they are
  announced (`objective_added` then `objective_completed`); a failed hidden objective
  stays silent.
- **Map vs mission.** `KesselProving` builds terrain data, services, resources, sites
  and Custodians; the `Mission` it creates places bases, units and patrols. The map
  reads its mission from `mission` (set by `Main`) or plays `default_mission_path`
  (a path, because the mission refers back to the map scene). `with_mission = false`
  gives a bare map (benchmarks).
- **Flow.** `main.tscn` (`Main`) shows the mission select (`ui/mission_select.gd`),
  the briefing, the mission map, and after `Mission.finished` (1.5 s later, then the
  sim clock is paused) the debrief with Retry / Back to missions. A map is removed
  from the tree before the next loads.
- **Presentation glue** lives in `maps/mission_presentation.gd`: an `ObjectiveMarker`
  per known objective with an area, a `SightConeVisual` on every watcher of a faction
  with an alert meter, and `UnitVisual.set_cloaked` for the player's cloaked units.
  The HUD shows the objectives (and alert meter) top left; the minimap draws active
  objective areas.

### Stealth (`sim/systems/vision/stealth_system.gd`, components `Watcher`, `Cloak`)

- `UnitDef` gained `signature` (1 = seen like anything else), `sensor`,
  `sight_angle` (cone width; range = `vision_range`), cloak fields and sabotage fields.
- A unit below signature 1 is **concealed**: `VisionSystem.can_see()` (and so
  targeting, `Combat.seen_enemies_near`, the AI port and the player's view) treats it
  as unseen even on visible cells until a watcher of that faction has spotted it.
  A spotted unit stays revealed for 5 s after the last time a watcher was sure; a unit
  that hits a faction is revealed to it for 3 s and its cloak opens.
- Every tick each watcher looks for intruders through the combat spatial grid: inside
  its cone (or within 2.5 m all round), within `sight_range × signature × sensor`, on
  a cell its faction's grid sees, with terrain line of sight (height field samples
  every 2 m). Suspicion rises at `sensor × signature × lerp(0.4, 2.4, closeness)` per
  second, holds 1.5 s, then decays at 0.12/s. Crossing 0.15 emits `suspicion_raised`
  (re-armed only at 0); reaching 1 emits `intruder_spotted`.
- **Alert meter** per faction listed in `guard_factions` (the mission's
  `enemy_alert_meter`): Suspicious when a watcher passes 0.4 or something is
  sabotaged; Alerted when an intruder is spotted or the faction is attacked. One step
  down after 60 s (Alerted) / 25 s (Suspicious) of quiet. Guard factions' watchers
  also grow suspicious of full-signature intruders. Without a meter, watchers only
  notice low-signature units (so Conquest costs nothing until Wisps appear).
- **Cloak.** In stealth mode (default) the Wisp's top speed is capped at
  `cloak_max_speed`; after `cloak_delay` s at or below it the cloak closes (signature
  0.5 → 0.2). `CloakCommand` toggles stealth mode (command panel button). A hit opens
  it for 2 s.
- **Sabotage.** `Saboteur` handler / `SabotageCommand`: work next to a working enemy
  building for `sabotage_time`; the building then stops working for good
  (`Building.is_sabotaged`, `Events.entity_sabotaged`). Classic and modern clicks
  resolve it through `SelectionRules.command_target()`: a selection whose only
  units that can act are saboteurs (no armed unit) sabotages instead of attacking.

### Guards (`ai/behaviours/patrol_behaviour.gd`, `ai/guard_commander.gd`)

`PatrolRoute` (core def) holds waypoints, pauses, loop/ping-pong, facing and the
guard type/count. `PatrolBehaviour` (patrol → pause, look ahead then aside → patrol;
investigate where a guard's suspicion passed 0.4, or where the suspicious faction
noticed something within 40 m; hunt toward the faction's alert position when
alerted, attacking what it sees) issues only `MoveCommand`, `AttackCommand` and the
new `FaceCommand`. It reads its own guards' watchers and its faction's alert level and
position through the `AiPort`. `GuardCommander` emits `reinforcements_called` once
per alert; `InfiltrationScript` answers with one hunting wave.

### The three missions

| | Conquest "Proving Ground" | Survey "Before the Storm" | Infiltration "Quiet Uplink" |
|---|---|---|---|
| Player | Lander + 2 Fabricators, Hauler, Surveyor | Lander + Fabricator, Hauler, 2 Surveyors | 3 Wisps + Surveyor, no base, no production |
| Enemy | full base, commander (easy) | same base, *raider* profile: waves of 3–6, often | outpost (Hub, Forge, Spire), 4 patrols + 1 sentry, alert meter |
| Primary | destroy everything; keep the Lander | bank 300 Intel within 15:00; keep the Lander | sabotage the uplink (Hub), then extract the squad |
| Secondary | scan the Combine relay | follow the Antecedent trail; scan the survey cut | stay undetected; scan the relay |
| Hidden | silence a Custodian Warden | open the sealed cache | leave no one behind |
| Being seen | — | — | reinforcements hunt, the pick-up moves to the far north-west, 5:00 to get out |

## Consequences

- New mission types are a `.tres` plus, at most, a small `MissionScript`. Objective
  types need code but are ~20 lines each.
- Stealth costs nothing while no unit is below signature 1 and no faction has a meter;
  with an outpost it is a grid query per watcher per tick.
- The commander never sees a concealed Wisp (tested in
  `tests/stealth/test_stealth_fairness.gd`); a spotted one enters its memory like any
  unit.
- Not done: Survey's "before the Combine reaches its own target" (the Combine still
  does not scan; the storm clock is the pressure); the Arc does not back away from
  targets inside its minimum range; mission state is saveable per class (`to_dict`)
  but the Mission itself is not yet saved (mid-mission saves are Phase 7).
- `tests/smoke/mission_smoke.tscn` runs all three missions on the real map outside
  GUT. In headless mode a freed `UnitVisual` leaks one renderer shader RID at exit
  (reported to the presentation owner), so it is not part of `tools/check.sh` yet.
