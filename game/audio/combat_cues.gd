class_name CombatCues
extends RefCounted
## Pure rules that turn combat notifications into sound-event ids. Every input
## is read defensively: a missing property means "unknown", never an error.
##
## Weapons (`WeaponDef`, read with `get()`): `sound_set` names the fire sound
## `weapon_<set>_fire` (data names such as &"ranger_repeater" are aliased to
## the sound family, &"repeater"); `impact_size` (metres) of at least
## EXPLOSION_RADIUS picks an explosion size, smaller is a surface hit;
## `projectile_style` &"lance" always lands as sparks.
## Entities: `is_visible_to_player == false` hides them (fog of war); a unit's
## weight class (light/heavy) picks its death sound and whether a hit on it
## rings like armour.

## Weapon sound sets as named in the weapon data -> the fire sound family.
const FIRE_ALIASES: Dictionary[StringName, StringName] = {
	&"ranger_repeater": &"repeater",
	&"bulwark_cannon": &"cannon",
	&"kite_autogun": &"light_gun",
	&"sentry_repeater": &"sentry",
	&"skitter_needler": &"skitter_gun",
	&"stinger_lance": &"lance",
	&"mauler_twin_cannon": &"siege",
}
## Splash radius (m) from which an impact is an explosion rather than a hit.
const EXPLOSION_RADIUS: float = 1.0
## Explosion radius (m) at or above which an impact is medium, then large.
const MEDIUM_RADIUS: float = 2.5
const LARGE_RADIUS: float = 5.0
## Armour classes that ring like armour and die heavy.
const HEAVY_ARMOUR: Array[StringName] = [&"heavy", &"structure"]
## Unit sound sets that are heavy (armour hits, heavy deaths).
const HEAVY_SETS: Array[StringName] = [&"bulwark", &"mauler", &"hauler"]
## Units with at least this much health count as heavy if nothing else says.
const HEAVY_HEALTH: int = 400
const BUILDINGS_GROUP: StringName = &"buildings"


## Candidates for a weapon's fire sound, best first (empty if it has no set).
static func fire_events(weapon: Resource) -> Array[StringName]:
	var events: Array[StringName] = []
	var sound_set: StringName = string_name_of(weapon, &"sound_set")
	if sound_set == &"":
		return events
	events.append(StringName("weapon_%s_fire" % sound_set))
	if FIRE_ALIASES.has(sound_set):
		events.append(StringName("weapon_%s_fire" % FIRE_ALIASES[sound_set]))
	return events


## Candidates for a shot landing, best first. `victim` may be null (ground).
static func impact_events(weapon: Resource, victim: Node) -> Array[StringName]:
	var radius: float = float_of(weapon, &"impact_size")
	if radius >= EXPLOSION_RADIUS:
		return [explosion_event(radius)]
	if string_name_of(weapon, &"projectile_style") == &"lance":
		return [&"impact_spark"]
	if victim == null or not is_instance_valid(victim):
		return [&"impact_ground"]
	if is_building(victim) or is_heavy(victim):
		return [&"impact_armour", &"impact_spark"]
	return [&"impact_spark"]


static func explosion_event(radius: float) -> StringName:
	if radius >= LARGE_RADIUS:
		return &"explosion_large"
	if radius >= MEDIUM_RADIUS:
		return &"explosion_medium"
	return &"explosion_small"


## Death sound for an entity: building collapse, or the unit's weight class.
static func death_events(entity: Node) -> Array[StringName]:
	if is_building(entity):
		return [&"death_building", &"explosion_large"]
	if is_heavy(entity):
		return [&"death_heavy", &"explosion_medium"]
	return [&"death_light", &"explosion_small"]


static func is_building(entity: Node) -> bool:
	return entity != null and is_instance_valid(entity) and entity.is_in_group(BUILDINGS_GROUP)


## Heavy if its def's armour class says so (`armour_type`, also read as
## `weight_class`/`armor_type`: &"heavy" or &"structure"). Only for defs
## without one: a heavy chassis sound set, or a lot of health.
static func is_heavy(entity: Node) -> bool:
	if entity == null or not is_instance_valid(entity):
		return false
	var def: Variant = entity.get(&"def")
	if not def is Resource:
		return false
	var resource: Resource = def
	for key: StringName in [&"armour_type", &"weight_class", &"armor_type"]:
		var value: StringName = string_name_of(resource, key)
		if value != &"":
			return value in HEAVY_ARMOUR
	if string_name_of(resource, &"sound_set") in HEAVY_SETS:
		return true
	var health: Variant = resource.get(&"max_health")
	if health is int:
		var amount: int = health
		return amount >= HEAVY_HEALTH
	return false


## True only when the entity says it is hidden from the player.
static func is_hidden(entity: Node) -> bool:
	if entity == null or not is_instance_valid(entity):
		return false
	var value: Variant = entity.get(&"is_visible_to_player")
	if value is bool:
		var visible: bool = value
		return not visible
	return false


static func string_name_of(object: Object, key: StringName) -> StringName:
	if object == null:
		return &""
	var value: Variant = object.get(key)
	if value is StringName:
		var as_name: StringName = value
		return as_name
	if value is String:
		var text: String = value
		return StringName(text)
	return &""


static func float_of(object: Object, key: StringName) -> float:
	if object == null:
		return 0.0
	var value: Variant = object.get(key)
	if value is float:
		var number: float = value
		return number
	if value is int:
		var whole: int = value
		return float(whole)
	return 0.0
