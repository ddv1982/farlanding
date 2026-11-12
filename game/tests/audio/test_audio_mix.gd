extends GutTest
## AudioMix: settings to bus volume, zoom shaping.


func test_zoom_moves_detail_and_music_in_opposite_directions() -> void:
	assert_gt(AudioMix.zoom_offset_db(&"Units", 0.0), AudioMix.zoom_offset_db(&"Units", 1.0))
	assert_lt(AudioMix.zoom_offset_db(&"Music", 0.0), AudioMix.zoom_offset_db(&"Music", 1.0))
	assert_eq(AudioMix.zoom_offset_db(&"UI", 0.3), 0.0)


func test_settings_volume_maps_to_db_and_silence() -> void:
	assert_almost_eq(AudioMix.bus_volume_db(&"UI", 1.0, 0.5), 0.0, 0.001)
	assert_almost_eq(AudioMix.bus_volume_db(&"UI", 0.5, 0.5), linear_to_db(0.5), 0.001)
	assert_eq(AudioMix.bus_volume_db(&"Music", 0.0, 1.0), AudioMix.SILENT_DB)


func test_every_mapped_bus_exists_in_the_layout() -> void:
	for bus: StringName in AudioMix.SETTING_FOR_BUS:
		assert_ne(AudioServer.get_bus_index(bus), -1, "bus %s" % bus)
	for bus: StringName in AudioMix.ZOOM_OFFSETS_DB:
		assert_ne(AudioServer.get_bus_index(bus), -1, "bus %s" % bus)
