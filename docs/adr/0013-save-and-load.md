# ADR 0013 — Mid-mission save and load

- Status: accepted (Phase 7, 2026-11-13)

## Context

PLAN §3.3 rule 7 made every component saveable from day one, and ADR 0012 kept the
campaign's start of a landing (`LandingPlan`) plain data. What was missing was a
game-level save: a file, a load path that builds the map and restores into it, the
mission runner and AI state, and the reconnection of restored references. Phase 7's
"known gap": a restored unit did not reconnect an active build, harvest or scan
order to its target.

## Decision

### What a save holds (`save/save_game.gd`)

`SaveGame` (in `game/save/`, which sits with `campaign/` between missions and the
UI: it uses `CampaignState`, `LandingPlan`, `MissionDef`, `SimWorld`):

| Field | |
|---|---|
| `format` | `FORMAT_VERSION` (1). Bumped whenever anything nested in a save changes shape, so an older build refuses a newer save instead of misreading it |
| `kind` | `campaign` or `mission` |
| `mission`, `mission_id`, `title` | the `MissionDef` path, for the load and the slot list |
| `seconds`, `saved_at` | game time played, Unix time saved |
| `campaign_def`, `plan`, `campaign` | campaign landings: the `CampaignDef`, the `LandingPlan` the landing started with, `CampaignState.to_dict()` at save time |
| `landing` | the map's `snapshot()`: `clock` (SimClock), `world` (`SimWorld.to_dict()`), `mission` (`Mission.to_dict()`, which holds the objectives, triggers, script and AI), `camera` (focus), `groups` (control groups by entity id) |

### Load: spawn nothing, then restore everything

The map (`KesselProving`) gets `restore_state` (a snapshot) next to `mission` and
`modifiers` before it enters the tree. It builds its terrain data and services as
usual, creates the `Mission` runner and calls `setup()` (which starts the planet rule
and puts the campaign's perks into the world, so restored units get their stats), and
then **places nothing from its own lists**: `SimWorld.from_dict()` spawns every
resource node, site, building, unit and prop the save names, with their saved ids.
Then the navmesh is cut, presentation is set up, and `Mission.resume()` takes the
place of `spawn_units()` + `start()`.

The alternative, spawning the fresh landing and reconciling, was rejected: every
spawn rule (auto-harvest, formations, charted chains, modifiers' extra units) would
have to be undone, and anything the mission spawned later (reinforcements, produced
units) has no "default" to reconcile against.

Ids are stable: each restored entity takes its saved `entity_id`; afterwards the
world's next id continues from the saved one, so a save → load → save is identical.

### Rehydration: a second pass once every entity exists

`SimWorld.from_dict()` ends with `resolve_references()` on every unit and building
(no new public method on SimWorld):

- `UnitOrders.resolve_targets()` turns saved target ids into nodes (attack, harvest,
  build, scan, sabotage targets; the queue too) and then calls the current order's
  handler `OrderHandler.resume(order)`:
  - **Harvester**: deposit and dock by id (saved now: dock, attempts); the loop goes on
    in its saved state.
  - **Builder**: back on its site (the order's target); attempts saved.
  - **Scanner**: state and attempts saved; a scanner that was scanning rejoins the
    site's scanners and `Events.scan_started` is announced again. The site's scan
    progress is saved now (`DiscoverySite` v2), so a scan in progress resumes.
  - **Saboteur**: back on its target; the progress is the building's.
- `Weapon.resolve_target()`: the saved target (it was saved but never read back).
- Movement goes on along the saved mover path; attack orders re-approach.

Decided per kind of in-flight state:

| State | After a load |
|---|---|
| Move/attack/queued orders, patrol legs, rally points, production queues, construction sites, sabotage and scan progress | restored and continue |
| Projectiles in flight | restored (target by id); the shooter is not (a kill by one is credited to no-one) |
| Commands pushed but not yet executed (less than one 0.1 s tick old) | dropped |
| A unit's "who hit me last" memory, stuck timers, RVO velocities, facing | re-derived on the next ticks |
| AI group states | re-entered: the state's `enter()` re-issues its order to the same saved target, its timers start over; a scout keeps its waypoint |

### Mission runner and AI

- `Mission.to_dict()` / `resume(data)`: start tick, the debrief counters, Intel
  bookkeeping, time-low warnings given, the HQ by id, every objective (by definition
  id, found among the mission's or its script's `objective_defs()`), trigger states
  (by position: scripts re-create their triggers in `on_resumed()`), the script's state
  and the AI. `resume()` then announces what presentation needs:
  `Events.objective_added` for every known objective and the alert level
  (`alert_level_changed(faction, level, level)`; a re-announcement with
  `previous == level` is not a new alert, so the guards do not call reinforcements).
- `Objective` v2 saves the bar, the countdown kind and the area; `KeepAlive` and
  `Sabotage` objectives save their entities by id, `RivalIntel` its last count.
- `MissionScript` gained `on_resumed()`, `objective_defs()`, `to_dict()`, `from_dict()`;
  `InfiltrationScript` saves the alarm, the waves sent and the deadline.
- `Commander.to_dict()` / `from_dict()`: memory (v2: every field), the brain's RNG
  state, knowledge (sightings keyed by entity id, sector times), home, staging, wave
  sizes, the per-unit order back-off and refused sites, and its attack, defence,
  scout and survey groups (members by id). `GuardCommander` saves its patrols (route
  as an index into the mission's patrols, -1 for hunters) and its calls.
- `StateMachine.resume(state, previous)` enters a saved state as if coming from
  `previous`.

### Files (`save/save_slots.gd`)

`user://saves/` (`SaveSlots.default_dir`, pointed elsewhere by tests): `quicksave`,
`autosave_landing` (written as a campaign landing starts) and `manual_1..3`, one
`<slot>.save` each. A file is a header line `FARLANDING_SAVE <format>`, a SHA-256 line
and the payload (`var_to_str` of the dictionary, so ints stay ints). Written to
`<slot>.save.tmp`, then renamed over the slot. Reading checks the magic, the format
(newer is refused before the payload is parsed), the hash (damaged and truncated
files are refused without parsing), then `SaveGame.check()`: mission, campaign, plan
and world version, and every `res://` path the save names must exist. Any failure
gives a message (`SaveSlots.last_error`) and leaves the game in play untouched;
nothing in `from_dict()` runs on a save that did not pass.

### Flow and UI (`main.gd`, `ui/`)

- F5 quicksave, F9 quickload in a mission: raw keycodes in `Main._unhandled_input`
  (no input actions, `project.godot` is not edited while the editor is open).
- Pause menu: SAVE and LOAD open `SaveLoadPanel` (slot, mission title, time played,
  date; an unusable save shows why). `SaveNotice` shows the outcome over the map.
- Title: Continue loads the newest of the campaign autosave (`campaign.cfg`'s modified
  time) and the saved landings (`saved_at`); it shows when either exists.
- A campaign save loads into a `CampaignSession` rebuilt from the saved state with the
  landing in play, so the result is written into the campaign when it ends.
  `campaign.cfg` is not rewritten by the load itself.
- Signals: `Events.campaign_saved(slot)` / `campaign_loaded(slot)` with the slot
  names above; `Events.ui_feedback` `save_done`, `save_failed`, `load_done`, and
  `invalid` for a refused load. A finished landing cannot be saved.

### Presentation after a load

Presentation is built after the world is restored and follows the usual signals:
components emit their state as they restore (health, construction progress, scan
progress, cloak, storm intensity, resources), the mission re-announces objectives and
the alert level, and `MissionPresentation.show_restored_state()` gives sabotaged
buildings their sparks. The fog's explored layer is restored and the player's sight
is refreshed at once. Selection starts empty; control groups are restored; the
camera looks where it did.

## Consequences

- Anything new that holds gameplay state must save it **and** reconnect references by
  id in a second pass (`resume()` / `resolve_references()`), and the round-trip tests
  (`tests/save/`) will catch state that is silently dropped: they compare a save, the
  load of it, and a save of that.
- A change to any nested save shape bumps `SaveGame.FORMAT_VERSION`; per-system
  versions keep reading their older dictionaries.
- Not saved: commands younger than a tick, transient AI timers, and the shooter of a
  projectile in flight.
