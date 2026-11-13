# Performance

How fast the simulation runs at the scale the game targets (PLAN §2.7: a couple of
hundred units), and how to measure it. Numbers are wall-clock, headless, Apple M4,
Godot 4.7.2.

## How to measure

```
godot --headless --path game res://tests/bench/bench_battle.tscn [-- options]
```

`bench_battle` plays the Conquest mission as in a real game (fog of war, the Combine
commander, the dust-storm rule, the map's boulders), then drops 110 units per side
(Rangers, Lancers, Bulwarks, Kites, Arcs against Skitters, Stingers, Maulers: 233 units
with the bases' crews) in the middle of the map and sends them at each other for 25 s.
Options: `--storm` (a storm at full strength throughout), `--no-props` (no boulders),
`--seconds=N`, `--sections` (split the tick by system; the split itself costs a
little). The F3 overlay in game shows the last tick, vision and stealth costs.

Runs vary by ±0.5 ms because the fight itself differs (avoidance timing), so the
figures below are means of three runs.

## Phase 6 (2026-11-13)

Sim tick (the 10 Hz simulation step, all systems):

| Build | Scenario | Sim tick mean | p95 | Vision update mean |
|---|---|---|---|---|
| Start of Phase 6 (`e1aa60b`) | no props, no storms (did not exist) | 5.2 ms | 8.3 ms | 0.30 ms |
| First Phase 6 build (props, storms) | boulders | 11.5 ms | 26.6 ms | 4.31 ms |
| End of Phase 6 | no props | 5.3 ms | 8.0 ms | 0.30 ms |
| End of Phase 6 | boulders | 5.4 ms | 8.2 ms | 0.61 ms |
| End of Phase 6 | boulders, full storm | 5.9 ms | 9.4 ms | 0.57 ms |

Where a tick goes at the end of Phase 6 (`--sections`, boulders): units 4.1 ms
(weapons 2.2 — including the synchronous listeners of `weapon_fired` and
`projectile_launched`, i.e. audio and effects; movement 1.3; orders 0.5), vision 0.6,
projectiles 0.5, combat grid 0.2, stealth 0 in Conquest (0.3 before), the rest under
0.05 each. The commander decides every ~4 s at 6–8 ms per decision (outside the
world's tick).

### What was done

1. **Shadows per row, not per cell.** Sight-blocking props made the vision update
   14× slower (each disc near a prop ran a segment test per cell in GDScript, ~380
   cells × occluders). The shadow of a box from a point is `source + λ (box −
   source)`, λ ≥ 1, which on one row of cells is a single interval; computing it per
   row and occluder took vision from 4.3 ms to 0.6 ms (p95 21 → 1.8 ms). A test
   cross-checks the result against the exact per-cell test.
2. **A spatial grid that carries numbers.** Each entry of the combat grid now keeps
   position, body radius and faction alongside the node, so target search
   (`Combat.find_target`) and AI perception (`seen_enemies_near`) skip friends and
   out-of-reach candidates without method calls or temporary arrays (weapons 2.9 →
   2.2 ms).
3. **Tell the navigation server only what changed.** Units set their RVO position,
   velocity and priority only when they differ from the last value sent: most units
   stand still most of the time.
4. **Quieter signals.** A weapon re-announces its aim only when the aim point moved
   more than 0.2 m (the visual eases toward it anyway).
5. **Skip idle systems.** The stealth pass does nothing when no unit hides and no
   faction keeps an alert meter (a plain Conquest fight), apart from its periodic
   clean-up. Engagement distances are recomputed only when the weapon's reach changed
   (a storm).

Net: the phase added props with honest line of sight, storms and the Survey race at
about the cost the game had before them (within the run-to-run noise).

### Next candidates

- The listeners of `weapon_fired` / `projectile_launched` run inside the tick; a
  pooled projectile look and an audio-side throttle would cut the weapons share.
- The commander's decision (6–8 ms every few seconds) could be spread over ticks.
- Vision discs of moving units near occluders are recomputed per new cell; a coarser
  cache key (half-cell positions) would trade a little accuracy for fewer misses.
