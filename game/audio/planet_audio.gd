class_name PlanetAudio
extends Resource
## What a planet sounds like: its score and its ambience. One `.tres` per planet
## in `res://data/sounds/planets/<planet id>.tres`, found by the planet's id,
## so gameplay only names the planet (`Audio.play_planet(def.planet.id)`) and a
## new planet is a new file here, not code.
##
## Without a call, the AudioService finds the planet itself when a mission
## starts (`planet_id_in`): it reads `mission.planet.id` from the running map
## (duck-typed, so audio does not depend on the mission classes).

const DIR: String = "res://data/sounds/planets"
## Used for anything that names no planet, or one without a file.
const DEFAULT_PLANET: StringName = &"kessel_reach"

@export var id: StringName = &""
@export var score: MusicScore
@export var ambience: AmbienceSet


## The planet's audio, or null if it has no file.
static func find(planet_id: StringName) -> PlanetAudio:
	if planet_id == &"":
		return null
	var path: String = "%s/%s.tres" % [DIR, planet_id]
	if not ResourceLoader.exists(path):
		return null
	return load(path) as PlanetAudio


## The planet's audio, falling back to the default planet.
static func find_or_default(planet_id: StringName) -> PlanetAudio:
	var found: PlanetAudio = find(planet_id)
	return found if found != null else find(DEFAULT_PLANET)


## The id of the planet a running mission is on: the first of `root` and its
## children with a `mission` property whose `planet` has an `id`. &"" if none.
static func planet_id_in(root: Node) -> StringName:
	if root == null:
		return &""
	var nodes: Array[Node] = [root]
	nodes.append_array(root.get_children())
	for node: Node in nodes:
		var id_found: StringName = _planet_of(node.get(&"mission"))
		if id_found != &"":
			return id_found
	return &""


static func _planet_of(mission: Variant) -> StringName:
	if not mission is Resource:
		return &""
	var def: Resource = mission
	var planet: Variant = def.get(&"planet")
	if not planet is Resource:
		return &""
	var planet_def: Resource = planet
	var planet_id: Variant = planet_def.get(&"id")
	if planet_id is StringName:
		var found: StringName = planet_id
		return found
	return &""
