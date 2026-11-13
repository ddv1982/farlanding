class_name DiscoverySoundRouter
extends Node
## Exploration events -> sounds (the signal pulses and scan loops are the
## SignalPulses'). Listens to `Events`; gameplay never calls this.
##
## - discovery_made (player faction): the resolve phrase of its type
##   (`discovery_resolve_<type>`, flat on the Discovery bus) and a brief duck of
##   music, ambience and effects for the phrase's length; an antecedent find
##   also plays the `mus_swell_antecedent` swell. Any faction's discovery
##   updates the music's trail layer from the share of resolved sites.
## - intel_changed (player faction): `ui_intel_tick` when Intel rises. The
##   first report only sets the baseline (the mission's starting Intel).
## - intel_changed (any other faction, Phase 6): `discovery_enemy_intel` when
##   its Intel rises (the Survey race: the Combine banking Intel should worry
##   the player; the event's cooldown keeps it from chattering). The time of
##   the last enemy gain is kept, so the ending can tell an out-surveyed
##   defeat (`enemy_gained_within`).
## - field_option_used (player faction): the option's effect `field_<id>`.
## - codex_entry_added: `ui_codex_entry`.
## Codex open/close and the option button are interface feedback
## (`Events.ui_feedback(&"codex_open")` -> `ui_codex_open`, by the naming rule).

## Resolve phrases shorter than this still duck for this long.
const MIN_DUCK_SECONDS: float = 1.5
## The duck lets go this long before the phrase ends (its tail is reverb).
const DUCK_TAIL_SECONDS: float = 0.6

@export var player_faction: int = 0

## Plays the first existing event: `func(ids: Array[StringName], at: Vector3) -> StringName`.
var play_first: Callable = func(_ids: Array[StringName], _at: Vector3) -> StringName: return &""
## Length of an event in seconds: `func(id: StringName) -> float`.
var event_seconds: Callable = func(_id: StringName) -> float: return 0.0
## Ducks other buses: `func(hold_seconds: float) -> void`.
var duck: Callable = func(_hold: float) -> void: pass
## Sets the trail music layer: `func(gain_db: float) -> void`.
var set_trail_gain: Callable = func(_db: float) -> void: pass

var _intel: int = -1
var _enemy_intel: Dictionary[int, int] = {}
var _enemy_gain_at: float = -INF


func _ready() -> void:
	Events.discovery_made.connect(handle_discovery_made)
	Events.intel_changed.connect(handle_intel_changed)
	Events.field_option_used.connect(handle_field_option_used)
	Events.codex_entry_added.connect(handle_codex_entry_added)
	Events.mission_started.connect(_on_mission_started)
	refresh_trail()


func handle_discovery_made(site: Node3D, discovery: Resource, faction: int) -> void:
	if faction == player_faction:
		var kind: StringName = DiscoveryCues.type_of(discovery, site)
		var played: StringName = play_first.call(DiscoveryCues.resolve_events(kind), Vector3.INF)
		if played != &"":
			var seconds: float = event_seconds.call(played)
			duck.call(maxf(seconds - DUCK_TAIL_SECONDS, MIN_DUCK_SECONDS))
		if kind == DiscoveryCues.ANTECEDENT:
			_play([DiscoveryCues.ANTECEDENT_SWELL])
	refresh_trail(site)


func handle_intel_changed(faction: int, intel: int, now: float = -1.0) -> void:
	if faction != player_faction:
		_handle_enemy_intel(faction, intel, _now() if now < 0.0 else now)
		return
	var before: int = _intel
	_intel = intel
	if before >= 0 and intel > before:
		_play([DiscoveryCues.INTEL_TICK])


func handle_field_option_used(option: Resource, faction: int, _at: Vector3 = Vector3.ZERO) -> void:
	if faction == player_faction:
		_play(DiscoveryCues.field_option_events(option))


func handle_codex_entry_added(_entry: Resource) -> void:
	_play([DiscoveryCues.CODEX_ENTRY])


## Recomputes the trail layer from the sites in the tree. `just_resolved`
## counts as resolved even if its flag is not set yet.
func refresh_trail(just_resolved: Node = null) -> void:
	if not is_inside_tree():
		return
	var total: int = 0
	var resolved: int = 0
	for site: Node in get_tree().get_nodes_in_group(DiscoveryCues.SITES_GROUP):
		total += 1
		if site == just_resolved or DiscoveryCues.flag(site, &"is_resolved", false):
			resolved += 1
	set_trail_gain.call(DiscoveryCues.trail_gain_db(resolved, total))


## True when another faction's Intel rose within `seconds` before `now`.
func enemy_gained_within(seconds: float, now: float = -1.0) -> bool:
	var at: float = _now() if now < 0.0 else now
	return at - _enemy_gain_at <= seconds


func _handle_enemy_intel(faction: int, intel: int, now: float) -> void:
	if faction < 0:
		return
	var before: int = _enemy_intel.get(faction, -1)
	_enemy_intel[faction] = intel
	if before >= 0 and intel > before:
		_enemy_gain_at = now
		_play([DiscoveryCues.ENEMY_INTEL])


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _on_mission_started() -> void:
	_intel = -1
	_enemy_intel.clear()
	_enemy_gain_at = -INF
	refresh_trail()


func _play(candidates: Array[StringName]) -> void:
	if not candidates.is_empty():
		play_first.call(candidates, Vector3.INF)
