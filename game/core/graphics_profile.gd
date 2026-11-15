class_name GraphicsProfile
extends Resource
## Authored graphics budgets. Profiles never change simulation or audio settings.

const PATHS: Dictionary[StringName, String] = {
	&"low": "res://data/graphics/performance.tres",
	&"medium": "res://data/graphics/balanced.tres",
	&"high": "res://data/graphics/high.tres",
}

@export var render_scale: float = 1.0
@export var msaa_3d: Viewport.MSAA = Viewport.MSAA_DISABLED
@export var shadow_size: int = 4096
@export var soft_shadows: bool = true
@export var ssao_enabled: bool = true
@export var glow_enabled: bool = true


static func for_quality(quality: StringName) -> GraphicsProfile:
	var path: String = PATHS.get(quality, PATHS[&"high"])
	return load(path) as GraphicsProfile
