# ADR 0007 — One CPU vision grid per faction, drawn with native image spans

Status: accepted (Phase 3a, 2026-11-12)

## Context

PLAN §3.4 asks for one system behind fog of war, targeting and (later) stealth:
a per-faction grid of about 2 m cells, three knowledge states (charted, explored,
visible), computed on the CPU on a staggered tick and uploaded as a texture. The
simulation reads the same grid to decide what each faction knows: units may not
auto-engage or be ordered onto targets their faction cannot see.

Kessel Proving is 240 m square, so a 2 m grid is 120 × 120 = 14 400 cells. The scale
target is 150–250 units. GDScript loops over cells are the cost to avoid: stamping a
22 m vision disc cell by cell is ~380 writes, ~38 000 per update for 100 units.

## Decision

- `VisionGrid` (`game/sim/systems/vision/vision_grid.gd`) keeps two `Image`s per
  faction in `FORMAT_L8`: a **visible** layer cleared every update and an **explored**
  layer that only ever gains cells. Charted = neither.
- A sight source is stamped as a disc of horizontal spans with `Image.fill_rect`
  (native). Spans are cached per radius (in quarter cells) and rows of equal width are
  merged, so a 22 m disc is ~13 calls instead of ~380 cell writes.
- Sources that share a cell and radius in one update are stamped once (a clumped army
  costs about as much as one unit). The explored layer remembers which discs it already
  holds and skips them, so standing units cost nothing there.
- After an update the layers are copied once to `PackedByteArray`s (`get_data()`,
  native) and every query (`state_at`, `is_visible`, `can_see`) is one array index.
- `VisionSystem` staggers updates: each 10 Hz sim tick recomputes **one** faction,
  round robin (two factions: each sees anew five times a second). After the player's
  update it applies the player's view: enemy units are hidden off visible cells, enemy
  buildings are shown from the first time they were seen (and stay, as last seen),
  resource nodes from the first time they were explored. Every unit, building, node
  and projectile exposes `is_visible_to_player`.
- Presentation (`game/presentation/fog_of_war.gd`) uploads the player's two layers as
  small textures only when that faction updated, and a SubViewport shader blurs them
  and eases them in over a few frames into the `fog_map` global (red = visible, green
  = explored). No per-cell GDScript runs per frame.

## Measured cost

Headless, Apple M4, Godot 4.7.2 (`tests/combat/test_vision.gd`,
`test_update_cost_with_a_hundred_units_is_small`): **0.20 ms per faction update with
100 units spread 20 m apart** (no two share a cell, so nothing is deduplicated; every
explored disc after the first update is skipped). With the stagger that is ~2 ms of
vision work per second of game time for that faction. The first update of a fresh
grid (explored stamps too) is about twice that. In the live map (editor play-test,
player faction with Lander, 2 Fabricators, Hauler and buildings, including applying
the view to every entity) one update measured **0.32 ms**. The HUD's F3 overlay shows
the last update's cost ("Vision update").

- A unit or building that damages another faction is **exposed** to that faction for
  2 s (a 3 m disc on their grid at its position). Without this, a Mauler shelling a
  base from beyond the base's sight could never be seen, so nothing could answer it.

## Consequences

- Vision is circular and ignores terrain (no line of sight over ridges yet). A height
  test per span would be the place to add it; stealth (`signature` vs `sensor`) can
  be a second threshold layer on the same grid.
- Knowledge lags by up to two ticks (0.2 s) per faction. Targets that step out of sight
  are dropped at the next update; a commanded attack then walks to where the target
  was last seen.
- Remembered enemy buildings are the live nodes, shown from first sight: a building
  destroyed out of sight disappears, and a remembered one shows its current
  construction state. Ghost copies can replace this later without touching the grid.
- Explored layers save as base64 bytes per faction (`VisionGrid.to_dict()`).
