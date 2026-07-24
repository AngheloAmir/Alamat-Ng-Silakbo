# ==============================================================================
# RANDOM WANDER ENEMY DUMMY
# ==============================================================================
# Randomly selects wander destinations in a radius, walks towards them,
# and pauses briefly before choosing a new waypoint.
# ==============================================================================
extends EnemyBase

var target_position: Vector3 = Vector3.ZERO
var wander_radius: float = 18.0
var idle_timer: float = 0.0
var start_origin: Vector3 = Vector3.ZERO


func _setup_ai() -> void:
	enemy_name = "Wander Dummy"
	move_speed = 3.5
	start_origin = global_position
	_pick_new_wander_target()


func _process_ai(delta: float) -> void:
	if idle_timer > 0.0:
		idle_timer -= delta
		velocity.x = move_toward(velocity.x, 0, move_speed)
		velocity.z = move_toward(velocity.z, 0, move_speed)
		if idle_timer <= 0.0:
			_pick_new_wander_target()
		return

	# Calculate direction to target
	var to_target: Vector3 = (target_position - global_position)
	to_target.y = 0.0 # Keep movement horizontal
	
	if to_target.length() < 1.0:
		# Target reached -> enter idle pause
		idle_timer = randf_range(1.5, 3.5)
		velocity.x = 0.0
		velocity.z = 0.0
	else:
		var dir: Vector3 = to_target.normalized()
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
		
		# Smoothly rotate mesh towards movement direction
		var target_angle: float = atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle, 8.0 * delta)


func _pick_new_wander_target() -> void:
	var rand_offset: Vector3 = Vector3(
		randf_range(-wander_radius, wander_radius),
		0.0,
		randf_range(-wander_radius, wander_radius)
	)
	target_position = start_origin + rand_offset
