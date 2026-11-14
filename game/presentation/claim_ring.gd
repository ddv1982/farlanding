class_name ClaimRing
extends MeshInstance3D
## The work on an Antecedent engine (ADR 0017), drawn on the ground round it: an arc
## that fills as a faction's workers reactivate it or take it over, in that faction's
## colour, and empties again when they leave. Hidden when nobody has work in it. It
## follows the Machine's `progress_changed` signal and hides with the engine under fog.
## Reads the simulation, never changes it.

const SHADER: Shader = preload("res://presentation/shaders/scan_ring.gdshader")
## Width of the ring, in metres (outside the engine's footprint).
const SIZE: float = 11.0


static func attach(engine: Building) -> ClaimRing:
	var ring: ClaimRing = ClaimRing.new()
	ring.name = &"ClaimRing"
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = SHADER
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(SIZE, SIZE)
	quad.orientation = PlaneMesh.FACE_Y
	quad.material = material
	ring.mesh = quad
	ring.position = Vector3(0.0, 0.3, 0.0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	engine.add_child(ring)
	engine.machine.progress_changed.connect(ring.show_progress)
	ring.show_progress(engine.machine.progress, engine.machine.claimant)
	return ring


## `progress` 0..1 of the work by faction `claimant` (-1: nobody).
func show_progress(progress: float, claimant: int) -> void:
	visible = progress > 0.0 and claimant >= 0
	if not visible:
		return
	set_instance_shader_parameter(&"progress", clampf(progress, 0.0, 1.0))
	set_instance_shader_parameter(&"ring_color", TeamColors.for_faction(claimant))
