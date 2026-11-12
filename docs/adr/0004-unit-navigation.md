# 0004 — Unit navigation: navmesh + group corridors + server RVO

- Status: accepted
- Date: 2026-11-12

## Context

PLAN §3.1 picked `NavigationServer3D` navmesh paths plus server-side RVO avoidance,
with plain `Node3D` units (no physics body) and a flow-field backend as the fallback,
to be confirmed by a Phase 0 spike: 200 units ordered across a map, with numbers.

## Method

- Scene `game/tests/bench/bench_navigation.tscn` (not part of `tools/check.sh`). It
  loads the real Kessel Proving map, spawns 200 Concord units (ranger / surveyor / kite
  / bulwark mix) on a 4 m grid in the north-west, and orders all 200 with one
  `MoveCommand` to (55, 0, −40), about 160 m across the basin past two mesas.
  It runs until every unit's orders are idle, and reports:
  - the cost of `MoveCommand.execute` (formation + all path requests);
  - the sim cost per 10 Hz tick (all ticked systems, wall clock), and `SimWorld`
    alone;
  - frame time (wall clock between frames);
  - the cost of 200 individual `query_path` calls, for comparison.

  Run: `godot --headless --path game res://tests/bench/bench_navigation.tscn`
  (add `-- --no-avoidance` to run without RVO agents). Windowed: play the scene
  from the editor; the report is also written to `user://bench_navigation.txt`.
- Machine: Apple M4 (10 cores), macOS, Godot 4.7.2 stable, Forward+.
  Windowed = the game embedded in the open editor at 1152 × 648, so the editor
  shared the CPU and GPU.
- Navmesh: baked offline from the terrain collider
  (`maps/kessel_proving/bake_kessel_navmesh.gd`): cell 0.25 m, agent radius 1.75 m (1.0 m when the benchmark ran),
  max slope 32°, max climb 0.5 m, islands not connected to the player start dropped,
  non-manifold edges removed. 15 267 polygons.

## Results

| Metric (200 units) | Headless, RVO on | Headless, RVO off | Windowed, RVO on |
|---|---|---|---|
| `MoveCommand.execute` (formation + paths) | 21.7 ms | 21.8 ms | 21.3 ms |
| Sim per tick, mean / p95 / max | 0.99 / 2.44 / 4.14 ms | 0.79 / 2.25 / 3.87 ms | 3.27 / 7.38 / 11.18 ms |
| Frame time, mean / p95 | n/a (unthrottled) | n/a | 10.1 / 13.2 ms |
| Navigation server time per frame, mean | 0.13 ms | 0.00 ms | 0.39 ms |
| 95 % / all units arrived | 35.2 s / 47.3 s | 34.8 s / 44.4 s | 33.8 s / 37.5 s |
| Units arrived | 200 / 200 | 200 / 200 | 200 / 200 |

Path queries are the expensive part:

- 200 individual `query_path` calls take **120–150 ms** (0.6–0.75 ms each on
  15k polygons; turning off path metadata did not help).
- With a **group corridor**, the same order costs **21.7 ms**: one query, and only
  5 of 200 units needed their own.

The "navigation server time" and process/physics monitors come from `Performance`,
which refreshes about once a second, so read them as rough averages only. The
windowed run's single ~300 ms frame is the bench's own deliberate 200-query bursts,
not gameplay.

### Mistakes caught along the way (kept so nobody repeats them)

- A first version snapped every avoidance-moved unit back onto the navmesh with
  `map_get_closest_point` each tick. That costs time proportional to the polygon
  count, and made a tick cost 16 ms on average. It was replaced by a `WalkGrid`:
  the navmesh rasterised once into a 1 m grid, giving O(1) walkability.
- An order whose formation overlapped mesas left 70 units re-pathing forever.
  Two fixes:
  - formation slots now skip unwalkable cells;
  - a unit gives up after 2 stuck re-paths.

## Decision

Keep the navmesh + RVO plan, with these specifics:

1. **One `PathService` interface** (`sim/systems/navigation/path_service.gd`):
   `find_path`, `find_group_paths`, `is_walkable`, `closest_point`,
   `get_avoidance_map`. `NavmeshPathService` is the only backend. A flow-field
   backend fits the same interface, and `find_group_paths` is where it would
   naturally plug in.
2. **Paths per order per group, never per frame.**
   - A group order makes one corridor query.
   - Each unit joins the corridor at its first visible corner and leaves it at the
     first corner that sees its formation slot (checked on the `WalkGrid`).
   - Units that can't see the corridor get their own query.
   - Queued waypoints and stuck re-paths query per unit when they start.
3. **Avoidance: server-side RVO agents** (2D, one agent per unit, created in
   `Locomotion`).
   - Velocities are pushed once per sim tick; the safe velocity arrives through the
     callback and is applied on the next tick.
   - Idle units have priority 1.0 and moving units 0.5, so movers steer around
     parked units.
   - A safe velocity that would leave the walk grid is ignored for that tick.
   - RVO costs about 0.2 ms per tick for 200 units (on vs. off, headless), which is
     affordable.
4. **Navmesh agent radius is the Bulwark's 1.75 m.** The first bake had to use 1.0 m
   because the plateau ramps eroded shut at 1.25 m or more. The ramps were then
   widened and lengthened in `art/terrain/kessel_proving.py`, and the plateau and both
   ramps stay connected at 1.75 m (checked after re-baking). Rule for future maps:
   ramps need at least 20 m of width.
5. **Not needed now:** a flow-field backend, C#/GDExtension, or per-tick path
   budgets.
   - At 200 units the sim costs about 1 ms per tick headless (about 1 % of a
     100 ms tick).
   - The worst case is an order where every unit falls back to its own query
     (a widely spread group): about 150 ms in one tick.
   - If that shows up in play, add a per-tick path budget in `find_group_paths`
     before considering a flow field.

## Consequences

- Units are plain `Node3D`s.
  - `Locomotion` follows terrain through a `HeightField` (raycast grid, about 60 ms
    at map load).
  - `SimWorld` ticks all units in one loop and interpolates their nodes every frame.
- Map load builds the `HeightField` and `WalkGrid`: 85–95 ms in total for Kessel
  Proving.
- Re-run the bake script whenever the terrain changes; the navmesh is a committed
  binary (`kessel_proving_navmesh.res`, about 130 KB).
- `navigation/3d/merge_rasterizer_cell_scale` stays at the default 1.0. Lowering it
  to 0.1 raised edge-merge errors from 25 to 301. The baker removes non-manifold
  edges instead.
