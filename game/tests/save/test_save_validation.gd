extends GutTest
## Preflight reads untrusted slot data before Main replaces the current landing.

const MISSION: String = "res://data/missions/conquest.tres"
const UNIT: String = "res://data/units/concord_hauler.tres"


func _save() -> Dictionary:
	return {
		"format": 2,
		"kind": "mission",
		"mission": MISSION,
		"landing": {"world": {"version": SimWorld.SAVE_VERSION}}
	}


func test_format_two_keeps_every_supported_legacy_world_version() -> void:
	for version: int in range(1, SimWorld.SAVE_VERSION + 1):
		var data: Dictionary = _save()
		data.landing.world.version = version
		assert_eq(SaveGame.check(data), "", "world version %d" % version)
		assert_not_null(SaveGame.from_dict(data))


func test_nested_containers_are_refused_without_typed_assignment_errors() -> void:
	for key: String in ["landing", "plan", "campaign"]:
		var data: Dictionary = _save()
		data[key] = []
		assert_ne(SaveGame.check(data), "", key)
		assert_null(SaveGame.from_dict(data), key)
	for key: String in ["world", "clock", "mission", "groups"]:
		var data: Dictionary = _save()
		data.landing[key] = []
		assert_ne(SaveGame.check(data), "", key)
	for key: String in ["units", "buildings", "resource_nodes", "sites"]:
		var data: Dictionary = _save()
		data.landing.world[key] = [null]
		assert_ne(SaveGame.check(data), "", key)


func test_existing_resources_must_have_the_consumed_definition_class() -> void:
	var data: Dictionary = _save()
	data.mission = UNIT
	assert_ne(SaveGame.check(data), "", "a unit is not a mission")
	for key: String in ["units", "buildings", "resource_nodes", "sites"]:
		data = _save()
		data.landing.world[key] = [{"version": 1, "def": MISSION, "position": "Vector3(0, 0, 0)"}]
		assert_ne(SaveGame.check(data), "", key)
	data = _save()
	data.landing.world.props = {"version": 1, "props": [{"version": 1, "def": MISSION}]}
	assert_ne(SaveGame.check(data), "", "a mission is not a prop")
	data = _save()
	data.kind = "campaign"
	data.campaign_def = MISSION
	assert_ne(SaveGame.check(data), "", "a mission is not a campaign")


func test_positions_must_parse_to_the_vector_the_restore_reader_consumes() -> void:
	for position: Variant in [42, "42", "Vector2(1, 2)", "Vector3(inf, 0, 0)", "Vector3(broken"]:
		var invalid_data: Dictionary = _save()
		invalid_data.landing.world.units = [
			{
				"version": Unit.SAVE_VERSION,
				"def": UNIT,
				"locomotion":
				{
					"version": Locomotion.SAVE_VERSION,
					"mover": {"version": Mover.SAVE_VERSION, "position": position}
				}
			}
		]
		assert_ne(SaveGame.check(invalid_data), "", str(position))
	var data: Dictionary = _save()
	data.landing.world.units = [
		{
			"version": Unit.SAVE_VERSION,
			"def": UNIT,
			"locomotion":
			{
				"version": Locomotion.SAVE_VERSION,
				"mover": {"version": Mover.SAVE_VERSION},
				"post": var_to_str(Vector3.INF),
				"wanted": var_to_str(Vector3.INF)
			}
		}
	]
	assert_eq(SaveGame.check(data), "", "idle locomotion uses INF as an unset destination")


func test_campaign_plan_arrays_and_result_records_are_checked_before_parsing() -> void:
	var data: Dictionary = _save()
	data.kind = "campaign"
	data.campaign_def = SaveFixture.CAMPAIGN
	data.plan = {"version": 1, "node": "kessel_proving", "techs": {}}
	assert_ne(SaveGame.check(data), "")
	data.plan.techs = []
	data.campaign = {"results": {"kessel_proving": []}}
	assert_ne(SaveGame.check(data), "")


func test_consumed_component_versions_are_refused_without_changing_the_format() -> void:
	for version: Variant in [0, Health.SAVE_VERSION + 1, "1"]:
		var invalid_data: Dictionary = _save()
		invalid_data.landing.world.units = [
			{"version": Unit.SAVE_VERSION, "def": UNIT, "health": {"version": version}}
		]
		assert_ne(SaveGame.check(invalid_data), "", str(version))
	var data: Dictionary = _save()
	data.landing.world.economy = {
		"version": Economy.SAVE_VERSION,
		"stockpiles": {"0": {"version": Stockpile.SAVE_VERSION + 1}}
	}
	assert_ne(SaveGame.check(data), "", "nested stockpile version")


func test_malformed_movement_paths_are_refused_without_parser_errors() -> void:
	for path: Variant in [[], "42", "PackedVector3Array(broken", "PackedVector3Array(1, 2)"]:
		var data: Dictionary = _save()
		data.landing.world.units = [
			{
				"version": Unit.SAVE_VERSION,
				"def": UNIT,
				"locomotion":
				{
					"version": Locomotion.SAVE_VERSION,
					"mover": {"version": Mover.SAVE_VERSION, "path": path}
				}
			}
		]
		assert_ne(SaveGame.check(data), "", str(path))


func test_watcher_and_commander_vectors_are_checked_before_restore() -> void:
	var data: Dictionary = _save()
	data.landing.world.units = [
		{
			"version": Unit.SAVE_VERSION,
			"def": UNIT,
			"watcher": {"version": Watcher.SAVE_VERSION, "last_noticed": "42"}
		}
	]
	assert_ne(SaveGame.check(data), "", "watcher last-noticed point")
	for key: String in ["home", "staging"]:
		data = _save()
		data.landing.mission = {"commander": {key: "42"}}
		assert_ne(SaveGame.check(data), "", key)
