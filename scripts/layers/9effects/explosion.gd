# ==============================================================================
# LAYER 9 SUBMODULE: EXPLOSION EFFECT (scripts/layers/9effects/explosion.gd)
# ==============================================================================
# Visual explosion effect & 3D Block Debris particle bursts.
# ==============================================================================
class_name ExplosionEffect
extends Node3D

static func create_explosion(parent: Node3D, pos: Vector3) -> void:
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = pos

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.4, 0.1)
	light.light_energy = 8.0
	light.omni_range = 10.0
	root.add_child(light)

	var particles := CPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.amount = 32
	particles.lifetime = 0.6
	particles.direction = Vector3.UP
	particles.spread = 180.0
	particles.initial_velocity_min = 6.0
	particles.initial_velocity_max = 14.0
	particles.scale_amount_min = 0.1
	particles.scale_amount_max = 0.3
	particles.color = Color(1.0, 0.5, 0.1)
	root.add_child(particles)

	var timer := parent.get_tree().create_timer(0.7)
	timer.timeout.connect(root.queue_free)


## 3D Block Debris Particle Burst Effect (Key B Action)
static func create_block_debris_explosion(parent: Node3D, pos: Vector3) -> void:
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = pos

	# Flash OmniLight3D
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.2)
	light.light_energy = 6.0
	light.omni_range = 8.0
	root.add_child(light)

	# 3D Box Mesh Debris Particles
	var particles := CPUParticles3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(0.18, 0.18, 0.18)
	particles.mesh = box_mesh

	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.98
	particles.amount = 24
	particles.lifetime = 1.1
	particles.direction = Vector3.UP
	particles.spread = 180.0
	particles.initial_velocity_min = 8.0
	particles.initial_velocity_max = 18.0
	particles.gravity = Vector3(0.0, -12.0, 0.0)
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.4
	particles.color = Color(1.0, 0.5, 0.15)
	root.add_child(particles)

	var timer := parent.get_tree().create_timer(1.2)
	timer.timeout.connect(root.queue_free)
