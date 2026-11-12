# 0006 — Buildings on the navmesh: runtime cuts, not re-bakes

- Status: accepted
- Date: 2026-11-12

## Context

Phase 2 adds buildings and Alloy deposits that units must walk around (PLAN §6). The
map's navmesh is baked offline from the terrain (ADR 0004) and committed. A building
can appear at any time (the player places it), so the navigation data has to change
at runtime, and so does the `WalkGrid` used for O(1) walkability, formation slots
and the avoidance fallback.

Options considered:

1. **`NavigationObstacle3D` avoidance only.** RVO obstacles push agents away, but
   paths still run straight through the building and units pile up against it.
   Not enough on its own.
2. **Re-bake with the building as a projected obstruction**
   (`NavigationMeshSourceGeometryData3D.add_projected_obstruction`, async bake).
   Correct, but it re-bakes the whole 240 m map at 0.25 m cells, and the result then
   needs the island and non-manifold clean-up from ADR 0004 (GDScript, slow). Units
   would path through a fresh site for the seconds the bake takes.
3. **Chunked regions re-baked locally.** Needs the map split into regions with
   edge connections and a new bake pipeline. More moving parts than the problem needs.
4. **Cut the footprint out of the baked mesh.** Remove the rectangle from the
   existing polygons directly: fast, deterministic, no bake at runtime.

## Decision

Option 4, plus option 1 for avoidance.

- `PathService.block_area(footprint) -> id` / `unblock_area(id)` is the interface.
  Callers pass the physical footprint (`BuildingDef.footprint`, or a deposit's
  square of 0.8 × radius). The base `PathService` only records the areas
  (`is_walkable` is false inside), which is what tests use.
- `NavmeshPathService` grows the area by `CUT_MARGIN` = agent radius 1.75 m + 0.5 m
  (unit centres keep clear of walls as they do of cliffs; the extra 0.5 m leaves the
  Bulwark's 2.0 m avoidance radius room along the edge), then:
  - cuts it out of the navmesh with `NavmeshCutter` and assigns the result to the
    `NavigationRegion3D` (cuts are batched to the end of the frame);
  - clears the same cells in the `WalkGrid` (a copy of the terrain-only cells is kept
    for placement checks and for restoring);
  - adds a static RVO obstacle over the footprint itself.
- Removing a blocker (a depleted deposit, later a destroyed building) re-cuts the
  remaining areas from the baked mesh.
- Vents are not blocked; a Flux Tap built on one blocks its own footprint.

### How the cutter works (`sim/systems/navigation/navmesh_cutter.gd`)

- A convex polygon that overlaps the rectangle is replaced by up to four convex
  pieces: left of, right of, below and above it (Sutherland–Hodgman clips with
  axis-aligned half-planes). No piece can have a hole.
- New points are keyed by the edge of the original mesh they lie on, so the two
  polygons sharing that edge get the same vertex, and each new point is inserted into
  every other polygon edge with the same root edge (T-junction repair). Without this
  the server would not join the pieces to their neighbours.
- Points within 0.3 m of a cut line count as on it, so no slivers are made.
- The navigation server joins polygons by rasterising edge ends to its 0.25 m cell
  and rejects an edge more than two polygons claim (a WARNING, which fails
  `tools/check.sh`). The baked mesh has slightly overlapping polygons on rough
  ground, so a cut could create such an edge. Each cut is checked around the
  rectangle with the same rasterisation and retried with the rectangle grown by a few
  centimetres (eight offsets, 0 to 0.43 m) until it adds none.

## Results

Kessel Proving, Apple M4, headless:

| Measurement | Value |
|---|---|
| Map load: 9 deposits + the Lander cut, mesh rebuilt once | 33–66 ms |
| One cut incl. rebuilding the 12–14k-polygon `NavigationMesh`, mean of 60 | 9.1 ms |
| Server edge-merge warnings after 60 random accumulated building cuts | 0 |
| Same, for every real deposit and the Lander | 0 |

Two mistakes found on the way (kept so nobody repeats them):

- Welding nearby new points into one vertex (to avoid tiny edges) merged points of
  *different* overlapping polygons and produced three-polygon edges. New points are
  now only ever shared by exact root edge.
- Repairing T-junctions by geometry alone inserted points from overlapping polygons
  into unrelated edges. The repair now also requires the same root edge.

In play the Ranger sent from (-54.5, 72.4) to (-93, 95), whose straight line crosses
the Lander, got a path with corners at x = -58.75 and z = 92.05 / 94.5, i.e. exactly
along the cut edges of the Muster Bay and the Lander, and walked round both.

## Consequences

- Buildings are not rotated (footprints are axis-aligned rectangles). Rotated
  footprints would need the cutter to clip with arbitrary half-planes; the code is
  written per axis today.
- Gameplay never touches the baked mesh; re-bake (ADR 0004) only when the terrain
  changes.
- The cut mesh is rebuilt from scratch when a blocker is removed (not measured;
  expected to scale with the number of remaining blockers, a few ms each); fine for
  depletion and, later, destruction.
- Navigation map changes take effect on the next physics frame; a path requested in
  the same frame as a placement can still cross the new site. Units standing inside a
  new footprint are sent out of it when it is placed.
