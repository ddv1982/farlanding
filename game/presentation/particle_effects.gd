class_name ParticleEffects
extends RefCounted


static func for_platform(gpu: GPUParticles3D) -> GeometryInstance3D:
	if not OS.has_feature("web"):
		return gpu
	var cpu: CPUParticles3D = CPUParticles3D.new()
	cpu.convert_from_particles(gpu)
	if gpu.name != &"":
		cpu.name = gpu.name
	cpu.transform = gpu.transform
	cpu.cast_shadow = gpu.cast_shadow
	cpu.visible = gpu.visible
	gpu.free()
	return cpu
