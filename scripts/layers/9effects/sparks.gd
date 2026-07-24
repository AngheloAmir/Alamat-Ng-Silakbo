# ==============================================================================
# LAYER 9 SUBMODULE: SPARKS EFFECT (scripts/layers/9effects/sparks.gd)
# ==============================================================================
# Visual spark particle impact burst effect on projectile collision.
# ==============================================================================
class_name SparksEffect
extends Node3D

static func create_spark_burst(parent: Node3D, pos: Vector3) -> void:
	var particles := CPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 16
	particles.lifetime = 0.4
	particles.direction = Vector3.UP
	particles.spread = 180.0
	particles.initial_velocity_min = 4.0
	particles.initial_velocity_max = 8.0
	particles.scale_amount_min = 0.05
	particles.scale_amount_max = 0.15
	particles.color = Color(1.0, 0.7, 0.2)

	parent.add_child(particles)
	particles.global_position = pos

	var timer := parent.get_tree().create_timer(0.5)
	timer.timeout.connect(particles.queue_free)
