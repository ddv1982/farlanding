# ADR 0009 — Discovery, Intel and Custodians

- Status: accepted (Phase 4, 2026-11-13)

## Context

PLAN §1 and §2.4 make Intel the third resource, earned only by looking: Surveyors scan
discovery sites, each discovery type pays out something felt in play, every discovery
writes a codex entry, and Intel is spent at the Survey Lab on field options. Custodians
(§2.1) guard Antecedent sites. All of it must follow §3.3: data-driven definitions, one
command path, sim talks outward only through `Events`, saveable state, and an enemy
commander that gains nothing from what the player finds.

## Decision

### Data

| Resource | File | Holds |
|---|---|---|
| `DiscoveryDef` | `core/defs/discovery_def.gd`, `data/discoveries/*.tres` | type (`geological`, `biological`, `antecedent`, `enemy`), Intel reward, scan time, radius, `leads_to` (chain), codex title/text, one payoff kind with its numbers, glow colour |
| `FieldOptionDef` | `core/defs/field_option_def.gd`, `data/field_options/*.tres` | effect (`reveal`, `supply_drop`, `strike`), Intel cost, cooldown, `requires_unlock`, effect numbers |
| `UnitDef` additions | `scan_rate`, `scan_range`; `starts_dormant`, `wake_radius`, `guard_radius` | Surveyor scanning; Custodian dormancy |
| `BuildingDef.field_options` | `data/buildings/concord_survey_lab.tres` | Options a building offers |

Payoffs are a small closed set chosen by data: `deposit` (a resource node appears:
rich Alloy or a Flux vent), `heal_field` (own units near the site heal for a while),
`unlock_option` (a field option opens), `reveal_enemy` (the finder sees around every
enemy unit and building for a while). Adding a discovery is a `.tres`; adding a payoff
kind is a few lines in `Discovery._apply_payoff()`.

### Simulation

- `DiscoverySite` (`sim/entities/discovery_site.gd`, group `discovery_sites`) is a
  neutral entity spawned by `SimWorld.spawn_site()`. It is *charted* (the orbital scan's
  "?") or, for a later chain step, hidden and unscannable until the previous site is
  resolved. Its scene's `SiteVisual` follows three signals (progress, resolved, colour).
  Audio and UI read `is_resolved`, `is_being_scanned`, `discovery_type`,
  `is_visible_to_player`, `is_signal_known_to_player`.
- `Scanner` (`sim/components/scanner.gd`) is an `OrderHandler` for `scan` orders, added
  to any unit whose def can scan. `ScanCommand` is the command. A scan is interrupted by
  anything that ends the order (new order, stop, death, being pushed aside); with no
  scanner left the progress is lost. Several scanners add up.
- `Discovery` (`sim/systems/discovery/discovery.gd`, service `discovery`) is a SimWorld
  child ticked after units: it resolves sites (Intel, codex, `discovery_made`,
  `codex_entry_added`, payoff, chain), runs heal fields and the player's view of sites.
  `FieldOptions` (same folder) keeps unlocks and cooldowns per faction and applies
  effects; `FieldOptionCommand` (receiver: an operational lab offering the option) is the
  only way to use one. `field_option_used` fires on use, the Advisor's
  `field_option_ready` when an option is unlocked or comes off cooldown, `discovery` on
  each find.
- Intel lives in `Stockpile.intel` next to Alloy and Flux (`Economy.add_intel` /
  `spend_intel`, `Events.intel_changed`).
- `VisionSystem` gained timed reveals per faction (`reveal_area`, `reveal_entity`),
  stamped into that faction's grid only, exactly like attacker exposure.
- Custodians are `Factions.CUSTODIANS` (2). A `Dormancy` component keeps a Warden still
  and unarmed, and `Combat.find_target()` skips dormant units, so nothing shoots it on
  its own. It wakes when hit, when a unit of another faction comes within `wake_radius`,
  or when a scan starts within `guard_radius` (`SimWorld.disturb`). Awake it is an
  ordinary armed unit, hostile to everyone. `ConquestOutcome` ignores Custodians.

### Fairness

The commander plays against the player only and never profits from the player's
discoveries: Intel, unlocks and cooldowns are per faction; reveals go into the
discovering faction's grid only; a deposit a discovery uncovers is an ordinary map node
the commander must explore with its own eyes (its site search already reads only
explored nodes); `WorldAiPort.seen_enemies()` leaves Custodians out, so the commander
neither counts them as a threat nor picks them as an attack target. Its units still fight
an awake Warden that attacks them. Tests in `tests/discovery/test_commander_fairness.gd`.

### Controls

Classic (C&C) and modern mouse schemes share one rule set in `SelectionRules`
(`command_target()` for what a command on a target means, `resolve()` for which button
commands and when a click selects or deselects). The cursor is drawn in code
(`CursorIcons`). See PLAN §9 item 5.

## Consequences

- Discoveries are cheap to add; payoff kinds are deliberately few and need code.
- A scan in progress is not saved (it starts over); sites, the codex, unlocks, cooldowns
  and heal fields are. Reveals that follow an entity end on load.
- The Custodian faction joins the vision round robin, so with three factions each grid
  updates about 3.3 times a second instead of 5. Acceptable at this scale; revisit if the
  fog feels sluggish.
- Only the player scans. The commander does not explore sites (a fair opponent that also
  competes for Intel is a later choice).
