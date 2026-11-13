class_name GraphicsSettings
extends RefCounted
## Applies the render quality preset (Settings.quality) to a loaded map: shadows on
## its directional lights (and their atlas size and softness) and glow on its
## environments. A map's own choice is remembered on the node the first time, so
## "high" never turns on something the map left off.

const SHADOW_META: StringName = &"fl_shadow_enabled"
const GLOW_META: StringName = &"fl_glow_enabled"
## Directional shadow atlas size per preset (0 = shadows off).
const SHADOW_SIZE: Dictionary[StringName, int] = {&"low": 0, &"medium": 2048, &"high": 4096}


## Applies `preset` to every light and environment under `root`.
static func apply(root: Node, preset: StringName) -> void:
	if root == null:
		return
	var size: int = SHADOW_SIZE.get(preset, 4096)
	if size > 0:
		RenderingServer.directional_shadow_atlas_set_size(size, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(
		(
			RenderingServer.SHADOW_QUALITY_SOFT_HIGH
			if preset == Settings.QUALITY_HIGH
			else RenderingServer.SHADOW_QUALITY_SOFT_LOW
		)
	)
	for node: Node in root.find_children("*", "DirectionalLight3D", true, false):
		var light: DirectionalLight3D = node as DirectionalLight3D
		if not light.has_meta(SHADOW_META):
			light.set_meta(SHADOW_META, light.shadow_enabled)
		var wanted: bool = light.get_meta(SHADOW_META)
		light.shadow_enabled = wanted and size > 0
	for node: Node in root.find_children("*", "WorldEnvironment", true, false):
		var world_environment: WorldEnvironment = node as WorldEnvironment
		var environment: Environment = world_environment.environment
		if environment == null:
			continue
		if not world_environment.has_meta(GLOW_META):
			world_environment.set_meta(GLOW_META, environment.glow_enabled)
		var glow: bool = world_environment.get_meta(GLOW_META)
		environment.glow_enabled = glow and preset != Settings.QUALITY_LOW
