# ADR 0012 — The campaign layer: route, tech web, loadout and what reaches a landing

- Status: accepted (Phase 7, 2026-11-13)

## Context

PLAN §1 and Phase 7: between landings the player is aboard the *Meridian*, picks the
next landing from a branching route, spends banked Intel on a permanent tech web and
chooses a loadout. "Done when: two planets can be played in sequence with Intel
carrying over and changing the second landing." The simulation must not learn about
the campaign (`core ← sim ← ai/missions ← campaign ← ui`), and mid-mission saves come
later, so whatever starts a landing must be plain, saveable data.

## Decision

### Data (`core/defs/`, `campaign/`, `data/campaign/`)

| Resource | Where | Holds |
|---|---|---|
| `PerkEffect` | core/defs | one effect: `kind` (`unlock`, `scale`, `units`, `resources`, `unlock_option`, `charge_option`, `chart_site`), `target`, `stat`, `factor`, `unit`, `count`, `alloy/flux/intel`, optional `note` |
| `TechDef` | core/defs | `id`, `title`, `description`, `branch`, `intel_cost`, `requires` (tech ids), `requires_discovery` (a discovery id), `grid` (column, row on the web), `effects` |
| `LoadoutSlotDef` / `LoadoutOptionDef` | core/defs | a slot's options; an option has `requires_tech` and `effects`. The first option is the default and needs no tech |
| `CarryoverDef` | core/defs | `discovery` id → `effects` on every later landing |
| `RouteNodeDef` | campaign | `id`, `title`, `planet`, `mission`, `map_position` (0..1), `leads_to`, `excludes`, `requires_tech`, `requires_nodes`, `scan_summary`, `intel_notes`, `placeholder` |
| `CampaignDef` | campaign | `nodes`, `start_node`, `techs`, `loadout_slots`, `carryovers`, `locked_at_start`, `lost_landing_share` |

`RouteNodeDef` and `CampaignDef` live in `campaign/`, not `core/defs/`, because they
name a `MissionDef` (a `missions/` class); `core` may not depend on `missions`.

`PlanetDef` gained a `summary` line for the orbital scan. Thalassa Low
(`data/planets/thalassa_low.tres`) has no rule yet.

The Kessel Trail (`data/campaign/kessel_trail.tres`): Proving Ground → Before the
Storm **or** Quiet Uplink (each `excludes` the other) → Tidewater Landing on Thalassa
Low. The last node is `placeholder = true`: its mission
(`data/missions/thalassa_shallows.tres`) reuses the Kessel map with a different setup
(normal commander, less Alloy, the Antecedent trail as the optional objective) until
Phase 8 brings Thalassa's map and tide.

### State (`campaign/campaign_state.gd`)

`CampaignState` is a pure `RefCounted` over its `CampaignDef`: banked `intel`, owned
`techs`, `opened` / `won` / `closed` nodes, per-node `results` (attempts, won, Intel
banked, seconds), `discoveries` (the campaign codex), `loadout` (slot → option) and
`current_node`. Rules:

- A node is **open** when opened (start node, or led to by a won node), not won or
  closed, and its `requires_tech` / `requires_nodes` are met; otherwise locked.
- **Banking.** A won landing banks the Intel in the player's stockpile when it ends
  (`MissionResult.intel_held`); Intel spent at the Survey Lab is gone. A lost landing
  banks `lost_landing_share` of it: **0 in the Kessel Trail**, because lost nodes stay
  open for a retry and a share could be farmed. Discoveries made on a lost landing
  are kept anyway (the data reached orbit), so an Antecedent find is never wasted.
- Winning opens `leads_to` and closes `excludes`.
- A tech is locked (requirement or discovery missing), available (too expensive),
  affordable, or owned. Buying spends banked Intel.
- A loadout option needs its `requires_tech`; a chosen option whose tech is gone falls
  back to the slot's first option.

### How tech and loadout reach a landing

1. `LandingPlan` (plain data: `node_id`, `techs`, `loadout`, `discoveries`) is
   snapshotted from the state when the briefing's START is pressed.
2. `LandingBuilder.build(def, plan)` turns it into `LandingModifiers`
   (`missions/landing_modifiers.gd`): the campaign's start locks, then every owned
   tech's effects, the loadout's, and the carryovers of discoveries already made.
3. `Main` sets `modifiers` on the map next to `mission`; the map hands it to its
   `Mission`, which in `setup()` puts `modifiers.perks` into `SimWorld.perks[player]`,
   adds the bonus resources and Intel, unlocks and charges field options, and in
   `spawn_units()` lands `extra_roster` with the crew. The map charts the sites in
   `charted_sites` even when a chain would hide them.
4. The sim only knows `FactionPerks` (`sim/systems/faction_perks.gd`): a set of
   locked ids and stat multipliers keyed `stat` or `<def id>/<stat>`. It reads them
   where the stat is used: `Unit` (health, `vision_range`, `carry_capacity`,
   `mine_time`, `scan_rate`, used by Harvester, Scanner and VisionSystem), `Building`
   (health; locked unit types are left out of its Producer), `PlaceBuildingCommand`
   (refuses locked types, `LOCKED`), the command panel (hides them), and `FieldOptions`
   (locked options; `intel_cost` and `cooldown` scales; free **charges** that cost
   no Intel and start no cooldown, saved in its `to_dict`, version 2). A world without
   perks plays its definitions unchanged, so single missions and the enemy are
   untouched. `FactionPerks.of(world.perks, faction)` returns a shared empty set
   for a faction without perks (SimWorld was at its public-method limit).

The discovery → landing link is twofold: techs gated by `requires_discovery`
(Antecedent Lens needs the trail ruin, Cache Alloys the sealed cache), and
carryovers (the trail beacon charts the ruin's site on later landings; the Combine
relay is worth 30 Intel; the sealed cache 100 Alloy).

### Save format

One autosave slot, `CampaignSession.PATH` = `user://campaign.cfg` (a ConfigFile, so
ints stay ints): section `campaign`, keys `version` and `state` (the
`CampaignState.to_dict()` dictionary: `version`, `campaign` id, `intel`, `techs`,
`opened`, `won`, `closed`, `results`, `discoveries`, `loadout`, `current_node`; ids as
strings). Written on New campaign, after every resolved landing, every purchase and
every loadout change. `from_dict` returns null for another version or another
campaign id; Continue then fails quietly and stays on the title.
`CampaignSession.default_path` (a static var) is pointed elsewhere by tests.
`LandingPlan.to_dict()` is what a mid-mission save will store to restart the landing
with the same modifiers.

### Flow and signals (`main.gd`, `ui/`)

Title (New campaign, Continue, Single missions, Settings, Quit) → star map
(`StarMap` + `RouteView`) ↔ Meridian (`MeridianScreen`: overview, `TechWebView`,
`LoadoutView`) → briefing (lists the modifiers' notes) → mission → debrief (Intel
banked; Back to star map; no Retry after a win). The result is written into the
campaign the moment the mission ends. Quitting from the pause menu abandons the
landing without a result. Single missions keep the old flow, with Back to the title.

`Events.campaign_screen_changed`: `title`, `star_map`, `meridian`, `tech_web`,
`loadout`, and `""` when a briefing, mission, debrief or the mission select has the
screen. `tech_unlocked`, `landing_resolved`, `campaign_saved` and `campaign_loaded`
come from `CampaignSession`, as do the advisor alerts `campaign_intel_banked`,
`campaign_route_open` and `campaign_tech_available` (after a landing resolves).

Screens use `HudStyle` (new: `campaign_state_color`, `make_icon`, `optional_icon`,
`make_menu_button`, node/tech state colours) and the `MenuScreen` base. Icons are
loaded when present: `res://assets/icons/tech_<tech id>.png`,
`res://assets/icons/planet_<planet id>.png`; otherwise a lettered placeholder. The
star backdrop `res://presentation/campaign/star_backdrop.tscn` plays behind the
campaign screens when it exists; the menu backdrop behind the title and the mission
select.

## Consequences

- New planets, landings, techs and loadout options are data. A new kind of effect
  needs a `PerkEffect` kind, a line in `LandingBuilder.apply`, and (if it is a new
  stat) a read of it in the sim.
- Stats the sim does not route through `FactionPerks` (weapon damage, speed, build
  times) cannot be teched yet; add them where needed.
- Tidewater Landing is a placeholder: same map, same discoveries as Kessel.
