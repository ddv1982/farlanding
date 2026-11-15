extends GutTest
## The shared removal notification must not turn a sale into a combat casualty.


class VfxSpy:
	extends CombatVfx
	var explosions: int = 0

	func explosion(_at: Vector3, _radius: float) -> void:
		explosions += 1


func test_sold_buildings_do_not_change_mission_casualties_or_objectives() -> void:
	var mission := Mission.new()
	autofree(mission)
	var building := Building.new()
	autofree(building)
	building.is_sold = true
	building.faction = 0
	mission._on_entity_died(building)
	building.faction = 1
	mission._on_entity_died(building)
	assert_eq(mission.buildings_lost, 0)
	assert_eq(mission.enemies_destroyed, 0)


func test_sold_buildings_do_not_explode_or_enter_combat_audio() -> void:
	var building := Building.new()
	autofree(building)
	building.is_sold = true
	var vfx := VfxSpy.new()
	autofree(vfx)
	vfx._on_entity_died(building)
	assert_eq(vfx.explosions, 0)
	# The router has no callbacks configured: any combat handling would fail.
	var router := CombatSoundRouter.new()
	autofree(router)
	router.handle_entity_died(building, 0.0)
	assert_eq(router.mood.state, MusicMood.EXPLORE)
