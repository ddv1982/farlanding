class_name OrbitalScan
extends RefCounted
## What the Meridian's orbital scan shows of a landing before it launches (PLAN 1):
## the discovery sites its map charts from orbit (the `?` signals), read from the map
## scene's saved properties without instancing it.


## The DiscoveryDefs whose sites start charted on `mission`'s map (chain steps that
## a site leads to stay hidden, unless `also_charted` lists them).
static func charted_sites(
	mission: MissionDef, also_charted: Array[StringName] = []
) -> Array[DiscoveryDef]:
	var all: Array[DiscoveryDef] = map_sites(mission)
	var result: Array[DiscoveryDef] = []
	for def: DiscoveryDef in all:
		if not Discovery.is_led_to(all, def.id) or also_charted.has(def.id):
			result.append(def)
	return result


## Every DiscoveryDef the map scene of `mission` places (its root's `discoveries`).
static func map_sites(mission: MissionDef) -> Array[DiscoveryDef]:
	var result: Array[DiscoveryDef] = []
	if mission == null or mission.map_scene == null:
		return result
	var scene: SceneState = mission.map_scene.get_state()
	if scene.get_node_count() == 0:
		return result
	for i: int in scene.get_node_property_count(0):
		if scene.get_node_property_name(0, i) != &"discoveries":
			continue
		var value: Variant = scene.get_node_property_value(0, i)
		if value is Array:
			var list: Array = value
			for entry: Variant in list:
				if entry is DiscoveryDef:
					result.append(entry)
	return result
