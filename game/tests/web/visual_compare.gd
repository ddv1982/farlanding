extends Node
## Diagnostic-only, fixed-camera visual reference. Never included in release exports.

var _main: Main


func _ready() -> void:
	var mission_id: String = "conquest"
	var quality: StringName = Settings.QUALITY_HIGH
	var scale: float = 1.0
	var output: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--visual="):
			mission_id = arg.get_slice("=", 1)
		elif arg.begins_with("--visual-quality="):
			quality = StringName(arg.get_slice("=", 1))
		elif arg.begins_with("--visual-scale="):
			scale = float(arg.get_slice("=", 1))
		elif arg.begins_with("--visual-output="):
			output = arg.get_slice("=", 1)
	Settings.path = "user://visual_comparison_settings.cfg"
	Settings.launch_graphics_changed = false
	Settings.graphics_upgrade_available = false
	SaveSlots.default_dir = "user://visual_comparison_saves/"
	Settings.quality = quality
	Settings.render_scale = scale
	Settings.msaa_3d = GraphicsProfile.for_quality(quality).msaa_3d
	Settings.ui_scale = 1.0
	Settings.edge_pan = false
	Settings.fullscreen = false
	Settings.apply_display()
	seed(1729)
	var subject: Node3D
	if mission_id == "orbit":
		subject = (load(Main.STAR_BACKDROP_SCENE) as PackedScene).instantiate() as Node3D
		GraphicsSettings.prepare(subject)
		add_child(subject)
		GraphicsSettings.apply(subject, quality)
		subject.set_process(false)
		# A clean reference composition, without the campaign's UI framing.
		var orbit_camera: Camera3D = subject.get_node(^"Camera3D") as Camera3D
		orbit_camera.position.y = 80.0
		orbit_camera.fov = 30.0
	else:
		_main = (load("res://main.tscn") as PackedScene).instantiate() as Main
		add_child(_main)
		var mission: MissionDef = load("res://data/missions/%s.tres" % mission_id) as MissionDef
		_main.start_mission(mission, _main.single_modifiers(Difficulty.NORMAL))
		await get_tree().process_frame
		_main.runner.context.sim_clock.paused = true
		_main._hints.end_mission()
		var camera: RtsCamera = _main.map.get(&"camera")
		camera.set_process(false)
		subject = _main.map as Node3D
	var environment: WorldEnvironment = (
		subject.find_child("WorldEnvironment", true, false) as WorldEnvironment
	)
	# Capture the authored landing camera identically, with the full starting crew.
	for frame: int in 12:
		await get_tree().process_frame
	var lights: Array[Node] = subject.find_children("*", "DirectionalLight3D", true, false)
	var report: Dictionary = {
		"ambient_energy": environment.environment.ambient_light_energy,
		"exposure": environment.environment.tonemap_exposure,
		"sun_energy":
		(lights[0] as DirectionalLight3D).light_energy if not lights.is_empty() else 0.0,
		"physical_lights":
		ProjectSettings.get_setting("rendering/lights_and_shadows/use_physical_light_units", false),
		"mission": mission_id,
		"renderer": RenderingServer.get_current_rendering_method(),
		"quality": quality,
		"render_scale": scale,
		"viewport":
		[get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y],
		"msaa": get_viewport().msaa_3d,
		"display_scale": get_tree().root.content_scale_factor,
		"draw_calls":
		RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
		),
	}
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.farlanding.visual = " + JSON.stringify(report))
		JavaScriptBridge.eval("window.farlanding.ready = true")
	elif output != "":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output + ".png")
		var file: FileAccess = FileAccess.open(output + ".json", FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "\t"))
		get_tree().quit()
