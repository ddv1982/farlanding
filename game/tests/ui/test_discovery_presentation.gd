extends GutTest
## Exploration reveals physical sites; map records belong to completed player surveys.

var _f: DiscoveryFixture
var _minimap: Minimap


func before_each() -> void:
	_f = DiscoveryFixture.new(self, true)
	_minimap = Minimap.new()
	_minimap.world = _f.world
	_minimap.faction = 0
	autofree(_minimap)


func after_each() -> void:
	_f.dispose()


func _reveal(at: Vector3) -> void:
	var grid: VisionGrid = _f.world.vision.grid
	grid.begin_update(0)
	grid.reveal(0, at, 10.0)
	grid.end_update(0)
	_f.world.discovery.tick(1, SimClock.TICK_DELTA)


func test_unknown_sites_are_hidden_until_their_ground_is_explored() -> void:
	var site: DiscoverySite = _f.site(_f.discovery(&"unknown"), Vector3(50, 0, 50))
	assert_false(site.visible, "charted is not a free reveal")
	assert_false(site.is_signal_known_to_player)
	_reveal(site.position)
	assert_true(site.visible)
	assert_true(site.is_visible_to_player)
	assert_true(site.is_signal_known_to_player)
	assert_true(_minimap.recorded_sites().is_empty(), "unscanned sites have no map marker")
	_reveal(Vector3(-50, 0, -50))
	assert_true(site.visible, "physical site remains in explored ground")
	assert_false(site.is_visible_to_player, "audio still respects current sight")


func test_only_completed_player_surveys_become_map_records() -> void:
	var site: DiscoverySite = _f.site(_f.discovery(&"player_site"), Vector3.ZERO)
	var enemy: DiscoverySite = _f.site(_f.discovery(&"enemy_site"), Vector3(2, 0, 0))
	_reveal(Vector3.ZERO)
	enemy.resolve(1)
	assert_true(_minimap.recorded_sites().is_empty(), "enemy discoveries do not reveal locations")
	site.resolve(0)
	assert_eq(_minimap.recorded_sites(), [site] as Array[DiscoverySite])
	var saved: Dictionary = _f.world.vision.to_dict()
	_f.world.vision.from_dict(saved)
	_f.world.discovery.tick(2, SimClock.TICK_DELTA)
	assert_eq(
		_minimap.recorded_sites(), [site] as Array[DiscoverySite], "exploration survives saves"
	)


func test_sites_use_their_model_and_scan_feedback_without_floating_labels() -> void:
	var visual: SiteVisual = SiteVisual.new()
	add_child_autofree(visual)
	assert_eq(visual.find_children("*", "Label3D", true, false).size(), 0)
	assert_false(visual._ring.visible)
	visual.set_scan_progress(0.5)
	assert_true(visual._ring.visible)
	assert_true(visual._column.visible)
	visual.set_resolved(true)
	assert_false(visual._ring.visible)
	assert_gt(visual._glow.light_energy, 0.0)


func test_restoration_applies_exploration_before_any_tick_or_render() -> void:
	var def: DiscoveryDef = load("res://data/discoveries/kessel_trail_beacon.tres")
	_f.site(def, Vector3(50, 0, 50))
	var restored: EconomyFixture = EconomyFixture.new(self)
	restored.world.enable_vision(DiscoveryFixture.AREA, 2.0)
	restored.world.from_dict(_f.world.to_dict())
	assert_true(restored.context.sim_clock.paused, "no tick has run")
	var site: DiscoverySite = restored.world.discovery.site_of(def.id)
	assert_not_null(site)
	assert_false(site.visible, "restoring charted state cannot reveal unexplored ground")
	assert_false(site.is_signal_known_to_player)
	restored.dispose()


func test_survey_objectives_do_not_reveal_site_locations_even_in_older_saves() -> void:
	var def: ObjectiveDef = ObjectiveDef.new()
	def.area_center = Vector3(70, 0, 70)
	def.area_radius = 8.0
	var objective: ScanSitesObjective = ScanSitesObjective.new()
	objective.configure(def)
	assert_false(objective.has_area)
	var saved: Dictionary = objective.to_dict()
	saved["has_area"] = true
	objective.from_dict(saved)
	assert_false(objective.has_area, "legacy objective rings must not reveal the site")
