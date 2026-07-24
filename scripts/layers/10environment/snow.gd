# ==============================================================================
# LAYER 10 SUBMODULE: SNOW PARTICLES (scripts/layers/10environment/snow.gd)
# ==============================================================================
# Winter snow particle simulation helper.
# ==============================================================================
class_name SnowEffect
extends RefCounted

static func configure_snow(particles: GPUParticles3D) -> void:
	if not particles:
		return
	particles.amount = 2200
	var mat := StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_PER_PIXEL
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(0.94, 0.97, 1.0, 0.90)

	var quad_mesh := QuadMesh.new()
	quad_mesh.size = Vector2(0.22, 0.22)
	particles.draw_pass_1 = quad_mesh
	particles.material_override = mat

	if particles.process_material is ParticleProcessMaterial:
		var proc := particles.process_material as ParticleProcessMaterial
		proc.initial_velocity_min = 3.5
		proc.initial_velocity_max = 7.0
	particles.emitting = true
