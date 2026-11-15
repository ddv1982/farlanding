# 0022 — Traffic: how ground units pass each other

- Status: accepted (replaces decision 3 of ADR 0004, server-side RVO)
- Date: 2026-11-15

## Context

Units drove into each other and did not pass naturally. ADR 0004 used the
navigation server's RVO agents for avoidance. Reading the code and playing showed
why that was not enough:

- A standing unit had the highest priority and never moved, so a mover in a narrow
  place pressed against it until it gave up.
- Avoidance was the only thing keeping bodies apart. When it failed, units
  overlapped; nothing separated them again.
- The safe velocity came back through a server callback tied to physics frames,
  one sim tick late, with a 0.8 s look-ahead. Fast units reacted too late and
  swerved at the last moment.
- The safe velocity was a sideways slide the unit's facing knew nothing about.
- None of it ran in the tests (the test `PathService` has no navigation map), so
  passing behaviour had no test at all, and the outcome depended on frame timing.

## Decision

Avoidance moves into the simulation as one system, `Traffic`
(`game/sim/systems/navigation/traffic.gd`), and the server-side agents and
obstacles are removed.

1. **One pass per sim tick, before the units move.** `SimWorld` calls
   `Traffic.solve()`. It reads each ground unit's `TrafficBody` (position, intended
   velocity, radius, faction, whether it moves, whether it would step aside) and
   writes four answers back. `Locomotion` applies them in its own tick.
2. **Steer.** For each moving unit and each body that it would touch within
   `HORIZON` (2 s), or already within 2 m of contact, a sideways pull away from where the other body will be at the
   closest moment. The pull is stronger the sooner and the nearer the meeting.
   - Oncoming traffic adds a pull to the right, so two units meeting head-on both
     keep right.
   - The smaller unit bends more; a unit passing a standing body does all of it.
   - A unit ahead that drives the same way at 70 % or more of our top speed is
     followed, not passed.
   - Whether something is in the way is judged by the unit's *wish* (straight along
     its path), not by its bent velocity. Otherwise bending away removes the reason
     to bend and the unit oscillates.
   - The pull changes the travel direction inside `Mover.plan()`, so the body turns
     toward where it goes. `Locomotion` eases it in and out.
3. **Speed cap.** A unit brakes for a body in its lane, using half its braking
   power and stopping 0.3 m short, because the order to brake arrives a tick late.
   Moving traffic keeps additional clearance; a parked neighbour merely beside
   the lane is steered around without needlessly braking.
4. **Step aside.** A standing unit with nothing to do steps sideways out of the
   line of a friend that would hit it within 1.2 s, and walks back to its post once
   nothing has driven by for 2 s. A unit with orders, a target or a cloak holds its
   ground, and so does every enemy.
5. **Push.** Bodies predicted to overlap after the pending movement step are moved apart.
   The push is applied after integration, matching the positions it resolves. Whoever is freer to
   move makes all the room: a moving body for a standing one, a standing body with
   nothing to do for one that holds its ground. A body that holds its ground (it
   works, scans or fires where it stands) is never shifted, so two of them working
   on the same spot stay as they are.
6. **Walkable ground wins.** A give-way or return step requires its whole straight
   segment to be walkable, not only its endpoint. A push or a steered move that would leave the walk
   grid is not made; the unit then follows its path alone for half a second.
7. Flying units stay out (the `FlightSystem` keeps them apart, ADR 0016).

Formations already hand out slots so that paths do not cross (`Formation.assign`),
so that part needed no change. Groups retain each unit's own speed: faster units queue behind or pass slower
ones. Nearby path corners are skipped when the next leg is directly walkable;
a unit does not have to touch the shared funnel point after clearing an obstacle.
Traffic waiting consumes the stuck budget slowly, and a blocked unit retries its
route instead of declaring success several vehicle lengths short of its slot.

## Results

`game/tests/test_traffic.gd` (14 tests, straight-line paths, vehicle-like units of
radius 1.2 m at 6 m/s). Without Traffic two units meeting head-on end up 1.9 m
inside each other. With it, in every case no two bodies are ever more than 0.1 m
inside each other and every unit arrives:

- two units head-on (both pass on the right);
- two columns of four head-on;
- two units crossing at right angles;
- a standing friend in the way (it steps aside and walks back);
- a unit holding its ground, and an enemy, in the way (driven around, not moved);
- a fast small unit behind a slow large one;
- two units spawned on top of each other (pushed apart);
- the same inputs twice give the same positions.

Navigation checks on Kessel Proving, Apple M4, headless, 10 Hz simulation:

| Bodies | 95% near destination / all settled | Tick mean / p95 / max |
| --- | --- | --- |
| 26 | 44.9 s / 52.8 s | 0.67 / 1.07 / 1.61 ms |
| 64 | 63.1 s / 66.9 s | 1.38 / 2.13 / 2.57 ms |
| 202 | 141.1 s / 147.6 s | 4.50 / 6.24 / 8.60 ms |

Arrival means no active order, path, movement or pending return to an idle post,
within one body width plus clearance of the assigned reachable endpoint. The
202-body run finished with all 202 in that area, 201 within one body radius.
The 64-body run finished with all 64 within one radius. This distinguishes actual
arrival from giving up far away, and from briefly stopping while turning.

These are simulation seconds, so `--fixed-fps 60` can accelerate headless runs;
frame timing in that mode is not real-time FPS. Historical RVO numbers (mean
3.33 ms / p95 5.61 ms, all 'arrived' at 51.3 s) used a weaker idle-only completion
counter and allowed overlap; they are not a like-for-like throughput comparison.
Dense physical queues take longer than a ghosting group. These measurements do
not establish a frame-rate guarantee for the rendered browser game.

Reproduce with `godot --headless --fixed-fps 60 --path game
res://tests/bench/bench_navigation.tscn -- --units=200 --seconds=240 --details`.
The report records strict one-radius accuracy separately and explains its arrival
threshold. Normal traffic tests also cover slow queues making room and taking a
visible next route leg while retaining corners blocked by a wall.

## Consequences

- Passing is deterministic and runs in the tests and the balance runs the same as
  in play.
- `PathService.get_avoidance_map()` and the RVO obstacles over buildings are gone.
  Buildings were already cut out of the navmesh and the walk grid.
- Cost grows with the number of *moving* units and how many bodies are within
  their look-ahead (at most 14 m). If a much larger battle makes it show, the first
  step is to solve only every second tick for units far from any other.
- A save keeps a step aside in progress and the post to walk back to (Locomotion
  save version 3).
