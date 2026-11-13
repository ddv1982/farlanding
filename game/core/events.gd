## Global, typed event bus (autoload `Events`).
##
## The simulation emits; presentation, UI and audio listen. Signals are named in the
## past tense. Mission-scoped data never lives here, only notifications.
extends Node

@warning_ignore_start("unused_signal")

## The player's selection changed. Empty array means nothing is selected.
signal selection_changed(entities: Array[Node3D])

## A command was accepted by the command queue. It executes on the next sim tick.
signal command_issued(command: Command)

## A UI-level feedback cue, e.g. &"invalid_target" or &"not_enough_resources".
signal ui_feedback(kind: StringName)

## An entity entered the simulation.
signal entity_spawned(entity: Node3D)

## An entity died. It may be freed after the frame ends.
signal entity_died(entity: Node3D)

## The mission's sim clock advanced to `tick`.
signal sim_ticked(tick: int)

## A building was placed and its construction site now exists.
signal building_placed(building: Node3D)

## A building finished construction and is operational.
signal construction_completed(building: Node3D)

## A producer started building `def` (a unit type).
signal production_started(producer: Node3D, def: EntityDef)

## A producer finished a unit, which is already in the world.
signal production_completed(producer: Node3D, unit: Node3D)

## A faction's stockpile changed.
signal resources_changed(faction: int, alloy: int, flux: int)

## A faction's power balance changed. Low power means `used` exceeds `produced`.
signal power_changed(faction: int, produced: int, used: int)

## A hauler unloaded `amount` Alloy at a refinery.
signal harvest_delivered(hauler: Node3D, amount: int)

## A resource node ran out.
signal resource_depleted(node: Node3D)

## Something the player's advisor should announce, e.g. &"low_power",
## &"insufficient_resources", &"construction_complete", &"unit_ready",
## &"deposit_depleted", &"under_attack". Player-facing only: never emitted for other factions.
signal advisor_alert(kind: StringName)

## A weapon fired. `weapon` is the WeaponDef; `muzzle` and `target` are world points.
signal weapon_fired(shooter: Node3D, weapon: WeaponDef, muzzle: Vector3, target: Vector3)

## A projectile entered the world, so presentation can give it a look. The sim moves
## it every frame, oriented along its travel (-Z forward); it leaves the tree on impact.
signal projectile_launched(projectile: Node3D, weapon: WeaponDef)

## A shot landed at `position`. `victim` is null when it hit the ground.
signal projectile_impacted(weapon: WeaponDef, position: Vector3, victim: Node3D)

## An entity lost `amount` health. `attacker` may be null.
signal entity_damaged(entity: Node3D, amount: float, attacker: Node3D)

## A mission began (also after "Play again"). Mission-scoped state held by
## autoloads, such as audio, resets on this.
signal mission_started

## The mission is over: `won` is true when the player won.
signal mission_ended(won: bool)

## A unit began scanning a discovery site.
signal scan_started(scanner: Node3D, site: Node3D)

## A scan stopped before it finished (the scanner left, died or was reassigned).
signal scan_interrupted(scanner: Node3D, site: Node3D)

## A site was resolved: the discovery is now known. `discovery` is its DiscoveryDef.
signal discovery_made(site: Node3D, discovery: Resource, faction: int)

## A faction's Intel total changed.
signal intel_changed(faction: int, intel: int)

## A field option bought at the Survey Lab took effect at `at`. `option` is its definition.
signal field_option_used(option: Resource, faction: int, at: Vector3)

## The player's codex gained an entry. `entry` is the DiscoveryDef it describes.
signal codex_entry_added(entry: Resource)

## A mission objective became known to the player. `objective` is an Objective:
## `id`, `title`, `kind` (&"primary", &"secondary", &"hidden"), `state`
## (&"active", &"done", &"failed") and `progress_text`.
signal objective_added(objective: RefCounted)

## An objective's progress text changed.
signal objective_updated(objective: RefCounted)

## An objective was achieved.
signal objective_completed(objective: RefCounted)

## An objective can no longer be achieved.
signal objective_failed(objective: RefCounted)

## A watcher began to notice `target`: its suspicion crossed the notice threshold
## (StealthSystem.NOTICE_AT). It fires again only after the watcher calmed down to zero.
signal suspicion_raised(watcher: Node3D, target: Node3D)

## A watcher is now sure of `target`: it has been spotted.
signal intruder_spotted(watcher: Node3D, target: Node3D)

## The alert state of a watching faction changed: &"unaware", &"suspicious" or
## &"alerted". Alerts decay back down when nothing is seen for a while.
signal alert_level_changed(faction: int, level: StringName, previous: StringName)

## `saboteur` disabled the enemy building `building` for good (it no longer works).
signal entity_sabotaged(building: Node3D, saboteur: Node3D)

## A unit's cloak closed (`cloaked` true) or opened. Fires for every faction's units.
signal cloak_changed(unit: Node3D, cloaked: bool)

## A planet storm is on its way: it begins in `seconds`.
signal storm_incoming(seconds: float)

## The storm's strength changed: 0 = clear sky, 1 = full storm. Emitted as it
## builds and as it dies down, a few times a second at most.
signal storm_changed(intensity: float)

## `carrier` lifted `cargo` (a carriable prop: an Antecedent artefact).
signal cargo_picked_up(carrier: Node3D, cargo: Node3D)

## `carrier` put `cargo` down (or died carrying it).
signal cargo_dropped(carrier: Node3D, cargo: Node3D)

## A Flux vent is about to erupt: in `seconds` it bursts over `radius` metres.
## Negative `seconds`: an announced eruption was called off (vented in time).
signal eruption_warning(vent: Node3D, seconds: float, radius: float)

## The vent erupts now, burning everything within `radius` metres.
signal eruption(vent: Node3D, radius: float)

## The tide is about to turn: in `seconds` it starts to rise (`rising`) or fall.
signal tide_turning(seconds: float, rising: bool)

## The sea level changed: 0 = low water, 1 = high water. Emitted as it moves, a
## few times a second at most.
signal tide_changed(level: float)

## The campaign shows another screen: &"title", &"star_map", &"meridian",
## &"tech_web", &"loadout", or &"" when a landing (briefing, mission, debrief)
## takes over.
signal campaign_screen_changed(screen: StringName)

## The player bought `tech` (a TechDef) on the tech web. Permanent for the campaign.
signal tech_unlocked(tech: Resource)

## A landing ended and its result was written into the campaign: `node` is the
## route node (a RouteNodeDef), `intel_banked` what the landing brought home.
signal landing_resolved(node: Resource, won: bool, intel_banked: int)

## The campaign was written to disk (`slot` names the save).
signal campaign_saved(slot: StringName)

## The campaign could not be written to disk (`slot` names the save): what
## changed since the last good save exists only in memory.
signal campaign_save_failed(slot: StringName)

## A campaign or a mid-mission save was loaded from `slot`.
signal campaign_loaded(slot: StringName)

@warning_ignore_restore("unused_signal")
