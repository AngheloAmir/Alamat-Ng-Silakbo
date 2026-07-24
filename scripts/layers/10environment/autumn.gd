# ==============================================================================
# LAYER 10 SUBMODULE: AUTUMN LEAF DRIFT (scripts/layers/10environment/autumn.gd)
# ==============================================================================
# Autumn falling leaf particle simulation helper.
# ==============================================================================
class_name AutumnEffect
extends RefCounted

static func configure_autumn(particles: GPUParticles3D) -> void:
	if not particles:
		return
	particles.amount = 650
	var mat := StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_PER_PIXEL
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(0.92, 0.48, 0.18, 0.90)

	var quad_mesh := QuadMesh.new()
	quad_mesh.size = Vector2(0.28, 0.20)
	particles.draw_pass_1 = quad_mesh
	particles.material_override = mat

	if particles.process_material is ParticleProcessMaterial:
		var proc := particles.process_material as ParticleProcessMaterial
		proc.initial_velocity_min = 2.0
		proc.initial_velocity_max = 4.0
	particles.emitting = true
