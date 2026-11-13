class_name DiscoveryCues
extends RefCounted
## Pure rules for the sounds of exploration (PLAN §5.1, "discovery has a voice").
##
## Discovery sites are Node3D in group &"discovery_sites". Everything is read
## duck-typed with `get()`, so stub nodes and half-written gameplay classes work:
##
##   is_resolved: bool               true -> silent for good (absent: false)
##   is_being_scanned: bool          true -> scan loop instead of the pulse
##   is_signal_known_to_player: bool true -> the player knows of it
##   is_visible_to_player: bool      used only when the property above is absent
##   discovery_type: StringName      picks the resolve phrase
##
## A site pulses only when the player knows of it, it is unresolved and nobody
## is scanning it. A site that says nothing about what the player knows stays
## silent: fog must never leak through the speakers.

const SITES_GROUP: StringName = &"discovery_sites"
const PULSE: StringName = &"signal_pulse"
const SCAN_LOOP: StringName = &"scan_loop"
const SCAN_CUT: StringName = &"scan_interrupted"
const CODEX_ENTRY: StringName = &"ui_codex_entry"
const INTEL_TICK: StringName = &"ui_intel_tick"
const ENEMY_INTEL: StringName = &"discovery_enemy_intel"
const ANTECEDENT_SWELL: StringName = &"mus_swell_antecedent"
const ANTECEDENT: StringName = &"antecedent"
## Every discovery type has its phrase `discovery_resolve_<type>`; an unknown
## type falls back to this one.
const FALLBACK_TYPE: StringName = &"geological"
## Field option ids whose name contains the key fall back to that effect.
const FIELD_FALLBACKS: Dictionary[String, StringName] = {
	"antecedent": &"field_antecedent_power",
	"scan": &"field_orbital_scan",
	"supply": &"field_supply_drop",
	"drop": &"field_supply_drop",
}


## True when `site` should carry the signal pulse.
static func wants_pulse(site: Node) -> bool:
	if site == null or not is_instance_valid(site):
		return false
	if flag(site, &"is_resolved", false) or flag(site, &"is_being_scanned", false):
		return false
	return flag(site, &"is_signal_known_to_player", flag(site, &"is_visible_to_player", false))


## Resolve phrase candidates for a discovery type, best first.
static func resolve_events(discovery_type: StringName) -> Array[StringName]:
	var events: Array[StringName] = []
	if discovery_type != &"":
		events.append(StringName("discovery_resolve_%s" % discovery_type))
	if discovery_type != FALLBACK_TYPE:
		events.append(StringName("discovery_resolve_%s" % FALLBACK_TYPE))
	return events


## The discovery type, from the discovery resource first, then the site.
static func type_of(discovery: Object, site: Object) -> StringName:
	var from_discovery: StringName = CombatCues.string_name_of(discovery, &"discovery_type")
	if from_discovery != &"":
		return from_discovery
	return CombatCues.string_name_of(site, &"discovery_type")


## Effect candidates for a field option (a Resource with `id`), best first.
static func field_option_events(option: Object) -> Array[StringName]:
	var events: Array[StringName] = []
	var id: StringName = CombatCues.string_name_of(option, &"id")
	if id == &"":
		return events
	events.append(StringName("field_%s" % id))
	var text: String = String(id)
	for key: String in FIELD_FALLBACKS:
		if text.contains(key) and not events.has(FIELD_FALLBACKS[key]):
			events.append(FIELD_FALLBACKS[key])
	return events


## Level of the Kessel "trail" music layer for a share of resolved sites:
## silent before the first discovery, -9 dB after it, full when all are found.
static func trail_gain_db(resolved: int, total: int) -> float:
	if resolved <= 0 or total <= 0:
		return AudioMix.SILENT_DB
	return lerpf(-9.0, 0.0, clampf(float(resolved) / float(total), 0.0, 1.0))


## A bool property of `node`, or `fallback` if it has none.
static func flag(node: Object, property: StringName, fallback: bool) -> bool:
	if node == null:
		return fallback
	var value: Variant = node.get(property)
	if value is bool:
		var result: bool = value
		return result
	return fallback
