# ADR 0017 — Machinery on Hollow Meridian, the Beacon Core, and the end of the campaign

> **Superseded numbers (Phase 9 balance pass, ADR 0018).** Power Up is now: run three
> engines for four minutes before the Combine holds three for eight. The deck has 22
> guardians (the Sentinel at each base's second engine is gone), the vents by the bases
> moved inside the build area, and the deck's Alloy deposits are deeper. The numbers
> below are as first designed; `docs/adr/0018-balance-method.md` has the current ones
> and why.

- Status: accepted (Phase 8d, 2026-11-13)

## Context

Hollow Meridian is the fifth and last planet. Its rule (PLAN §2.5): "Custodians
everywhere; power comes from reactivating old machinery". It closes the Antecedent
trail opened on Kessel, so its second landing is the campaign's finale, and after it
the campaign must end. As before, the rule must be data played by a
`PlanetRuleSystem` (ADR 0011), be public knowledge for a fair AI (ADR 0008), survive a
save (ADR 0013), and the map must be data (ADR 0014). The lead made the terrain, the
visuals scene, the engine, Beacon Core and Sentinel models and icons, the planet
emblem and the contract signals `machine_reactivated`, `machine_lost`,
`core_charge_changed` and `core_awakened`.

## Decision

### Engines are Buildings with a Machine component

An Antecedent engine is a `Building` whose `BuildingDef.machine` is set
(`data/buildings/antecedent_engine.tres`: 1600 health, 15 power, not placeable). The
map places them (`MapDef.machine` + `machine_positions`) as finished buildings of the
Custodians: dormant engines belong to nobody. A `Machine` component holds the state
(dormant / running / shut down), the work done on it and by whom, and the shutdown
timer, and saves with the building (Building v5).

Chosen over a new entity type because a Building already has everything an engine
needs: health and a health bar, a footprint cut from the navmesh, selection, power
through `Economy.update_power`, vision for its owner, team colour on the model and the
minimap, and being an attack target that the AI's knowledge already tracks. What it
must not do is handled in few places: `Building.is_operational()` is false unless the
machine runs; `Building.is_inert` (dormant or shut down) makes `Combat.can_target`,
`find_target` and `damage` leave it alone; `Health.undying` lets its health run out
without dying; `ConquestOutcome` and objectives (unless they name it) ignore machines;
Custodians never pick a machine as a target (they guard them).

### The rule (`MachineryRule`, `MachinerySystem`)

- **Reactivating** is an order (`ReactivateCommand`, a `Reactivator` order handler on
  every unit that can build or scan: Fabricator, Surveyor, the Combine's Rigger). The
  unit walks to the footprint's edge and reports its work each tick; the system adds it
  up (several workers add, perks scale it) and at 1 hands the engine over:
  `machine_reactivated(engine, faction)`. Anything that ends the order stops the work;
  unworked progress fades (`progress_decay`).
- **Taking over** a running engine is the same order, slower (`takeover_seconds` 24 s
  against `reactivate_seconds` 12 s): the old owner gets `machine_lost`. Work by one
  faction first drains another's unfinished progress; two factions at once cancel out.
- **Shutting down**: an engine whose health runs out stops for `shutdown_seconds`
  (45 s): `machine_lost`, no power, nothing can shoot it, and anybody but its owner may
  claim it at the reactivation pace. Unclaimed, it restarts for its owner at full
  health (`machine_reactivated` again). It is never destroyed.
- **Custodians**: a worker who starts on an engine wakes the dormant Custodians within
  `disturb_radius` (32 m); they see the worker for a while and go for it
  (`UnitOrders.engage`, leashed at `chase_distance`).
- **Power**: Reactors are locked for every faction while the rule plays (the rule adds
  the lock to the world's perks; `Mission.setup` now applies the campaign's perks
  before it starts the planet rule so the lock is not overwritten), and non-machine
  buildings give `headquarters_power_scale` (0.5) of their output (`Economy.power_scale`):
  Lander 5, Combine Hub 15. We chose "cannot be built" over "gives nothing": a building
  that does nothing is a trap in the build menu.
- **HUD**: the planet indicator shows `ENGINES · n / 8 HELD` (· ONE CONTESTED while an
  enemy works on one of ours or one is shut down) and a bar of the share held. The
  command card has REACTIVATE for Fabricators and Surveyors (nearest claimable explored
  engine); a click on an engine with them selected reactivates it (with armed units in
  the selection, a running enemy engine is attacked instead); a selected engine shows
  its owner, health and the work on it. Presentation shows the `active` part only while
  an engine runs, turns the `dish` only then, and tints it in its owner's colour.
- Advisor kinds (for the audio worker): `machine_online`, `machine_lost`,
  `custodians_awake`, `core_charging`, `core_guardians`, `enemy_linking`, `core_awakened`.

### The enemy and the engines (`MachineKeeper`)

Run on each commander decision when `CommanderProfile.machines_wanted` > 0
(`combine_meridian`: 5). It keeps one claim at a time: an idle builder goes to the
nearest claimable engine it has explored, with an escort of at least `machine_escort`
idle armed units, more when it has seen Custodians by that engine (until the escort's
strength reaches half the guards' over 2; Custodians count at half their nominal
price); engines guarded beyond twice the strength of all its free armed units are
passed over. It remembers the Custodians it has
seen by each engine (only what its faction sees), takes over the player's engines
(`machine_takeover`), and sends `machine_defenders` to an engine of its own that is
hurt, shut down or being claimed. Its attack waves already target the player's engines
as known buildings. Saved with the commander.

### The Sentinel

`custodian_sentinel`: a heavier, ranged Custodian (1300 health, heavy armour, a 26 m
turreted lens, 60 heavy splash damage, hits ground and air), dormant like the Warden.

### Missions

- **Power Up** (`hollow_power`, type `power`): run four engines for three minutes in
  all (new objective `hold_machines`: the clock runs while the side holds enough and
  pauses, never resets), before the Combine holds four for four minutes (the same
  objective on the enemy side, passive: it fails the mission).
- **The Beacon Core** (`hollow_finale`, type `finale`, `CoreScript` + `CoreRules`): each
  side charges the Core while it runs at least four engines and a scanner stands within
  16 m of it; 240 s from empty, +25 % per extra engine; both linked = contested, nobody
  charges. The Core shows the leading charge (`core_charge_changed`, at most every 3
  ticks). At 20 / 45 / 70 / 90 % the Custodians within 45 / 80 / 115 m / everywhere
  wake and converge on the dais as last-stand groups. Full player charge:
  `core_awakened`, the `core_charge` objective is done (won). The Combine's full charge
  first fails its passive `core_charge` objective; losing the Lander fails too. From
  5:00, once it runs four engines, the Combine sends a Rigger with an escort to link,
  and strikes at the dais while the player charges.

### The end of the campaign

`CampaignDef.final_node` (`hollow_finale`); `CampaignState.is_complete()` is derived
(the final node is won), so the save format is unchanged. `CampaignSession.resolve`
emits `Events.campaign_completed` once. The debrief's Back reads THE END OF THE TRAIL
and opens the `EndingScreen` (four short paragraphs over the star backdrop, then
landings, Intel banked, discoveries and techs from `CampaignState.statistics()`), which
returns to the title (`campaign_screen_changed(&"ending")`). Continue on a finished
campaign opens the ending again instead of an empty star map.

### Content

- `maps/hollow_meridian_deck/`: the lead's visuals, `bake_hollow_navmesh.gd` (ground
  below −1 m cut: the chasms' floor is at −14 m, the deck at 0.5 m; 1255 polygons) and
  `data/maps/hollow_meridian_deck_map.tres`: point-symmetric, 12 deposits, 4 rich, 6
  vents, 8 engines at the recipe's spots, 24 dormant guardians (Wardens and Sentinels
  by every engine, at two bridge heads and on the dais corners), 6 sites, and the Core
  (`antecedent_site_core` prop, 12 × 12 m) on the dais. Stone greys on the minimap.
- Discoveries: `hollow_trail_terminus` → `hollow_core_annal` (the trail ends; the
  annal lists our worlds and many more), `hollow_engine_schematic`,
  `hollow_custodian_cradle` (heal field), `hollow_combine_survey_rig` (reveal),
  `hollow_plate_seam` (rich deposit). Carryovers: Verdance's spire charts the last
  beacon; the last beacon charts the annal.
- Techs (branch survey, row 8): `resonance_keys` (reactivation ×1.5; needs the
  schematic), `engine_bracing` (engines +50 % health; needs the plate seam),
  `custodian_hush` (wake and disturb radii ×0.6; needs the cradle). New perk stats
  `reactivation_rate`, `custodian_disturb`.
- Hints: `machinery` (Hollow landings start), `machine_online` (first engine of ours),
  `core` (the Core begins to charge).

## Consequences

- The terrain does not make the bridges the only connection: each chasm stops short of
  one map edge, so the bases are also joined through the middle deck. The bridges are
  the short ways across (tested: straight over a bridge, a long detour between two).
- A new kind of map machine (a gate, a turret) is a `BuildingDef` with `machine` and
  whatever rule system gives it meaning.
- Engines count as buildings for everything that does not check `machine`; new code
  that sums a faction's buildings should ask itself whether engines belong.
- Placeholders: Advisor lines and sounds for the new alert kinds and the engine/Core/
  Sentinel sound sets (`antecedent_engine`, `beacon_core`, `sentinel`), tech emblems,
  and the work-in-progress look on an engine (only the command card's bar shows it;
  hook `Machine.progress_changed`).
