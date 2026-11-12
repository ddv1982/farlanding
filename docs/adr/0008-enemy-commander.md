# ADR 0008 — The enemy commander: goal scoring over its own knowledge, groups as state machines

- Status: accepted (Phase 3b, 2026-11-12)

## Context

PLAN §3.5 asks for a Combine opponent in two layers — a **commander** that scores
goals (economy, defence, scouting, attack) with openings from data, and per-unit
**behaviours** as small typed state machines — that plays by the player's rules
(§2.1, §3.3 rule 3): same definitions, same costs and build times, same command path,
and it knows only what its own vision grid has seen (§3.4). Difficulty changes decision
speed and mistakes, never resources.

## Decision

Code lives in `game/ai/`; data in `game/data/ai/`.

### Layers

| Piece | File | Role |
|---|---|---|
| `Commander` (Node) | `ai/commander.gd` | Wiring: ticks on the SimClock, perceives, builds a view, runs the brain, turns actions into Commands, owns the behaviours |
| `AiKnowledge`, `AiSighting` | `ai/ai_knowledge.gd`, `ai/ai_sighting.gd` | Memory of what the faction has seen: enemy units (forgotten after `memory_seconds`), enemy buildings (until their ground is seen empty), and per-sector "last seen" for scouting |
| `CommanderView` | `ai/commander_view.gd` | Snapshot for one decision: own stockpile, buildings, units (in full) and the enemy only as known |
| `GoalScorer` | `ai/goal_scorer.gd` | Pure scoring of economy / defence / scout / attack |
| `CommanderBrain` | `ai/commander_brain.gd` | Pure `decide(view) -> Array[AiAction]`: opening first, then goals best-first, keeping its own budget |
| `AttackGroup`, `ScoutBehaviour` | `ai/behaviours/` | `StateMachine` (core) behaviours that issue Commands through an `AiPort` |
| `AiPort` / `WorldAiPort` | `ai/ai_port.gd`, `ai/world_ai_port.gd` | The only way behaviours act (push a Command) and sense (enemies the faction sees now) |
| `CommanderProfile`, `CommanderDifficulty` | `ai/commander_*.gd`, `data/ai/*.tres` | Roster, opening, every tunable, three difficulty levels |

### Playing by the rules

- **One command path.** Every action is a `ProduceCommand`, `PlaceBuildingCommand`,
  `BuildCommand`, `HarvestCommand`, `MoveCommand`, `AttackCommand` or `RallyCommand`
  pushed onto the mission's `CommandQueue` with `issuer_faction` = its faction
  (`WorldAiPort.push` asserts this). Costs are paid and checked by the commands, as for
  the player. The brain also keeps its own budget within a decision, so it never asks
  for more than the stockpile holds (tested over 300 random views).
- **Only what it sees.** Perception is `Combat.seen_enemies_near(faction, centre,
  radius)` around each of its own units and buildings (sight sources merged per 8 m
  cell): a spatial-grid query filtered by the faction's own vision grid. The AI never
  iterates the world's unit or building lists for enemies. Attack targets are the
  remembered building nearest home, else the most recently seen armed unit; with
  nothing seen there is no attack, and scouting scores high instead. Deposits it may
  harvest are those on cells its grid has explored. The building-site search is
  judged on the same knowledge (see the decision loop): it never reads the live
  footprints of buildings it has not seen.
- **Own forces in full.** It reads its own units, buildings, queues and stockpile, as
  the player does through the HUD.
- **No rebuilding of the HQ.** The Hub is not placeable and Riggers only come from a
  Hub, so a dead Hub plus dead Riggers ends construction for good (a Rigger→Hub→Rigger
  data cycle would also be a resource cycle). With no production left the commander
  sends every armed unit in a **last stand** (searching sectors if no target is known),
  so remnants do not hide and victory stays reachable.

### Decision loop

On tick `(t + phase) % decision_interval == 0` (phase staggered per faction):

1. Update home (the Hub, else any building) and staging (24 m from home towards the
   map centre; factories rally there).
2. Perceive; forget what the grid now shows gone; stamp visible sectors.
3. Build the view; `brain.decide(view)`:
   - housekeeping (free): idle Scrappers back to the nearest known deposit, idle Riggers
     onto unfinished sites;
   - no production and no sites: last stand, then stop;
   - threat near home (enemy strength seen within `base_radius` in the last 3 s): the
     home guard defends (unless a *mistake* roll skips it), an outweighed wave is
     recalled;
   - the **opening** from data, step by step in order; a step waits for money, queue
     room or an idle builder, and is skipped only if nothing can make it;
   - after the opening, goals best-first:
     - economy = missing Scrappers / Rigger / Forge (+0.3 when poor);
     - defence = threat vs home guard, and missing Spires (one plus one per attack
       suffered);
     - scout = 0.85 with no target known, 0.3 otherwise, less as the map gets explored;
     - attack = free army / next wave size, once the first-attack time and the wave
       interval have passed and a target has been seen;
   - leftover money keeps each Forge queue at two units of the weighted mix (Stingers
     weigh more the more heavy armour it has seen), keeping an economy reserve, and
     pausing at the **army cap** (home guard + 1.25 × next wave) unless the base is
     under attack. Banked Alloy goes into extra Spires (one per 700 banked, up to 4).
   - a wave takes the free army beyond the home guard (cheapest units stay home), at
     most 1.5 × the wave's planned size.
4. Apply actions (Commands, or new behaviours). Building sites are searched on rings
   (up to 64 m) around the anchor and must keep producers' doors and drop-off docks
   clear (the new building's own too), stay off the staging point and away from
   deposits, and have open ground for 6 m all round (90 % of a sampled ring), so the
   base never builds into its own exit corridors. A building with no free site backs
   off for 20 s.
   The search knows only terrain (walkability, slope, map bounds), its own buildings,
   the enemy buildings it remembers seeing (`AiKnowledge` sightings), resource nodes on
   explored ground, and sites refused lately (`Commander.known_placement_rules()`).
   The real placement rules still judge the `PlaceBuildingCommand` when it runs; if
   something unseen stands there the command is refused (`refused` says why, as the
   player hears it), and the commander keeps out of that footprint for 2 minutes, so
   it picks another spot next time instead of repeating the refused one.

Behaviours tick every `behaviour_interval_ticks` (5 = twice a second):

- `AttackGroup`: gather → advance → (regroup) → fight → advance … → retreat → done.
  Fight focuses the most dangerous enemy in sight (armed units, then armed buildings,
  then the rest), re-ordering only when the focus changes or members idle (30-tick
  rate limit). It retreats when the enemy strength seen is more than
  `retreat_ratio` (1.6) times its own, or its strength fell below `retreat_losses`
  (30 %) of the start. Gather and regroup tests scale with the group's packed size, so
  a 30-unit wave is not judged by a 14 m radius. When gathering or regrouping times
  out (or everyone has stopped), members that cannot catch up are dropped and return
  to the home guard. A target is given up as unreachable only after three re-orders
  without getting 5 m closer. Defence groups never retreat; a last stand never retreats.
- `ScoutBehaviour`: travel to the next sector (never seen, far from home first; then
  the stalest), evade = move on to the next sector when armed enemies are within 20 m,
  report unreachable sectors (skipped for 2 min).

Strength is an Alloy-equivalent: armed units by cost (Flux ×2) × health share, armed
buildings twice that, unarmed things 0.

### Found in play-testing (kept so nobody repeats them)

- A fixed gather/regroup radius never fits a 60-unit blob: the first wave sat in
  gather/regroup for minutes. The tests now scale with the group's packed size.
- Without an army cap the Combine fielded 65 units by 5:00 and sent all of them.
- The commander built a Forge and two Spires inside its own exit corridor; waves then
  jammed in it. Hence the open-ground rule for sites.
- A Refinery was placed with its dock inside the Lander's footprint (the player-side
  test bot), so haulers never delivered. A new building's own door and dock must now
  be reachable.
- A deposit whose nearest navmesh point lay on the plateau above it stranded all six
  Scrappers: the Harvester gave up and re-picked the same deposit forever. The
  Harvester now moves on to another deposit when one cannot be reached, and the
  deposit was moved.
- Two map spots produced navmesh edge-merge warnings; the NavmeshCutter now tries 15
  growth offsets (was 8) and the deposit was placed where its cut is clean.

### Difficulty

Only timing, sizes and mistakes change; costs, build times, income and vision never do.

| | Easy | Normal | Hard |
|---|---|---|---|
| Decision interval | 40 ticks (4 s) | 20 ticks (2 s) | 10 ticks (1 s) |
| First attack not before | 7:00 | 5:00 | 3:30 |
| Time between waves (min) | 150 s | 110 s | 80 s |
| Wave sizes (units) | 6, 8, 10 … max 14 | 8, 11, 14 … max 24 | 10, 14, 18 … max 30 |
| Mistake chance | 30 % | 10 % | 0 % |
| A premature wave leaves with | 50 % | 60 % | — |
| First scout | 1:30 | 0:45 | 0:30 |

Mistakes (seeded RNG, so games repeat): per wave, leaving early with too few units; per
decision under attack, not sending the home guard; per decision, leaving the Forges idle
(at half the chance). The map selects the level with `KesselProving.enemy_difficulty`
(normal by default).

## Measured cost

Apple M4, Godot 4.7.2. One decision = home update, perception, view, brain, and
turning actions into commands (site search included); "behaviour step" = every
group and the scout ticking once.

| | Per decision, mean | Per decision, max | Behaviour step, max |
|---|---|---|---|
| Headless, full 22-minute game vs the player-side bot (660 decisions, 30–60 Combine units) | 0.25–0.50 ms | 3.9 ms (a Forge site search) | 0.52 ms |
| Editor play (debug build, rendering, editor sharing the CPU), 3× speed | 1.2–1.5 ms | 14.8 ms (site search) | 0.62 ms |

On normal (one decision every 2 s) that is about 0.2 ms of commander work per second
of game time headless; the sim tick around it costs 0.4–4.6 ms. The maximum is always
a building-site search (up to 13 rings × 16 directions, each candidate checked
against placement, doors, deposits and the open-ground ring); it happens at most once
per decision and backs off for 20 s when it finds nothing. If it ever shows up in
profiles, cache the open-ground test per cell.

## Consequences

- The commander is a plain node on the map; another faction or another personality is a
  new `CommanderProfile` `.tres`.
- What the AI knows of the enemy is memory, not the live nodes: a building destroyed out
  of its sight stays a target until it looks again.
- The brain, scorer and behaviours are testable without a scene (`tests/ai/`).
- Not done: no expansion Hubs (the Hub is not buildable), no line-of-sight-aware
  routing, no flanking. A wave takes one path (the group corridor).
