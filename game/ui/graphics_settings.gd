class_name GraphicsSettings
extends RefCounted
## Applies the render quality preset (Settings.quality) to a loaded map: shadows on
## its directional lights (and their atlas size and softness) and glow on its
## environments. A map's own choice is remembered on the node the first time, so
## "high" never turns on something the map left off.

const SHADOW_META: StringName = &"fl_shadow_enabled"
const GLOW_META: StringName = &"fl_glow_enabled"
const SSAO_META: StringName = &"fl_ssao_enabled"
const LIGHTING_META: StringName = &"fl_compatibility_lighting"
## Matched against the fixed-camera Forward+ references, not a quality reduction.
const COMPATIBILITY_LIGHT_ENERGY: float = 0.35
const COMPATIBILITY_AMBIENT_ENERGY: float = 0.55


## Call before adding the map to the tree: weather caches these authored baselines.
static func prepare(root: Node) -> void:
	if RenderingServer.get_current_rendering_method() != "gl_compatibility":
		return
	if root.has_meta(LIGHTING_META):
		return
	root.set_meta(LIGHTING_META, true)
	for node: Node in root.find_children("*", "DirectionalLight3D", true, false):
		(node as DirectionalLight3D).light_energy *= COMPATIBILITY_LIGHT_ENERGY
	for node: Node in root.find_children("*", "WorldEnvironment", true, false):
		var environment: Environment = (node as WorldEnvironment).environment
		if environment != null:
			environment.ambient_light_energy *= COMPATIBILITY_AMBIENT_ENERGY
			# LDR highlights cannot cross the native HDR threshold (> 1).
			environment.glow_hdr_threshold = minf(environment.glow_hdr_threshold, 0.9)
			environment.glow_hdr_scale = 0.2


## Applies `preset` to every light and environment under `root`.
static func apply(root: Node, preset: StringName) -> void:
	if root == null:
		return
	var profile: GraphicsProfile = GraphicsProfile.for_quality(preset)
	var size: int = profile.shadow_size
	if size > 0:
		RenderingServer.directional_shadow_atlas_set_size(size, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(
		(
			RenderingServer.SHADOW_QUALITY_SOFT_HIGH
			if profile.soft_shadows
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
		if not world_environment.has_meta(SSAO_META):
			world_environment.set_meta(SSAO_META, environment.ssao_enabled)
		var ssao: bool = world_environment.get_meta(SSAO_META)
		environment.glow_enabled = glow and profile.glow_enabled
		environment.ssao_enabled = ssao and profile.ssao_enabled
