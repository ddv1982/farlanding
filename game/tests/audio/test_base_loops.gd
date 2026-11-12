extends GutTest
## BaseLoops: which loop an entity carries, and which loops are audible.


class Bare:
	extends Node3D
	var def: EntityDef
	var faction: int = 0


class Site:
	extends Bare
	var is_under_construction: bool = true
	var is_producing: bool = false
	var is_powered: bool = true


class Hauler:
	extends Bare
	var is_harvesting: bool = true


var _loops: BaseLoops
var _events: Dictionary[StringName, SoundEvent] = {}


func before_each() -> void:
	_events.clear()
	for id: StringName in [BaseLoops.CONSTRUCT, BaseLoops.PRODUCE, BaseLoops.MINE, BaseLoops.HUM]:
		var event: SoundEvent = SoundEvent.new()
		event.id = id
		event.streams = [load("res://assets/audio/base/loops/%s.wav" % id) as AudioStream]
		event.max_instances = 2
		event.max_distance = 60.0
		_events[id] = event
	_loops = BaseLoops.new()
	_loops.resolve_event = func(id: StringName) -> SoundEvent: return _events.get(id, null)
	add_child_autofree(_loops)


func _add(node: Bare, group: StringName, at: Vector3, faction: int = 0) -> Bare:
	node.def = EntityDef.new()
	node.faction = faction
	node.position = at
	node.add_to_group(group)
	add_child_autofree(node)
	return node


func test_loop_for_reads_properties() -> void:
	var site: Site = Site.new()
	assert_eq(BaseLoops.loop_for(site, true, false, false), BaseLoops.CONSTRUCT)
	site.is_under_construction = false
	site.is_producing = true
	assert_eq(BaseLoops.loop_for(site, true, false, false), BaseLoops.PRODUCE)
	site.is_producing = false
	assert_eq(BaseLoops.loop_for(site, true, true, true), BaseLoops.HUM, "properties beat events")
	site.is_powered = false
	assert_eq(BaseLoops.loop_for(site, true, false, false), &"")
	site.free()


func test_loop_for_degrades_to_event_state_without_properties() -> void:
	var bare: Bare = Bare.new()
	assert_eq(BaseLoops.loop_for(bare, true, false, false), BaseLoops.HUM)
	assert_eq(BaseLoops.loop_for(bare, true, true, false), BaseLoops.CONSTRUCT)
	assert_eq(BaseLoops.loop_for(bare, true, false, true), BaseLoops.PRODUCE)
	assert_eq(BaseLoops.loop_for(bare, false, false, false), &"", "no is_harvesting, no loop")
	var hauler: Hauler = Hauler.new()
	assert_eq(BaseLoops.loop_for(hauler, false, false, false), BaseLoops.MINE)
	bare.free()
	hauler.free()


func test_nearest_first_with_caps_and_hums_ranked_last() -> void:
	for i: int in 4:
		_add(Bare.new(), &"buildings", Vector3(2 + i, 0, 0))  # hums, very close
	for i: int in 3:
		_add(Site.new(), &"buildings", Vector3(10 + i, 0, 0))  # sites, further away
	var mining: Bare = _add(Hauler.new(), &"units", Vector3(0, 0, 15))
	_add(Hauler.new(), &"units", Vector3(0, 0, 16))
	_loops.rescan()
	var ids: Array[StringName] = []
	for pair: Array in _loops.chosen():
		ids.append(pair[1])
	assert_eq(ids.size(), BaseLoops.MAX_LOOPS)
	assert_eq(ids.count(BaseLoops.CONSTRUCT), 2, "capped per loop type")
	assert_eq(ids.count(BaseLoops.MINE), 2)
	assert_eq(ids.count(BaseLoops.HUM), 2)
	assert_eq(ids[0], BaseLoops.CONSTRUCT, "a site outranks a closer hum")
	assert_true(_loops.chosen().any(func(p: Array) -> bool: return p[0] == mining))


func test_events_mark_sites_and_enemies_are_ignored() -> void:
	var building: Bare = _add(Bare.new(), &"buildings", Vector3(1, 0, 0))
	_add(Site.new(), &"buildings", Vector3(0, 0, 1), 1)
	Events.building_placed.emit(building)
	_loops.rescan()
	assert_eq(_loops.chosen().size(), 1)
	assert_eq(_loops.chosen()[0], [building, BaseLoops.CONSTRUCT])
	Events.construction_completed.emit(building)
	_loops.rescan()
	assert_eq(_loops.chosen()[0], [building, BaseLoops.HUM])


func test_out_of_range_is_silent_and_low_power_is_tracked() -> void:
	_add(Bare.new(), &"buildings", Vector3(500, 0, 0))
	_loops.rescan()
	assert_eq(_loops.chosen().size(), 0)
	Events.power_changed.emit(0, 10, 20)
	assert_true(_loops.is_low_power())
	Events.power_changed.emit(1, 10, 5)
	assert_true(_loops.is_low_power(), "other factions do not count")
	Events.power_changed.emit(0, 30, 20)
	assert_false(_loops.is_low_power())
