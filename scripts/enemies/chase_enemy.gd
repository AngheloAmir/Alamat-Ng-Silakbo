# ==============================================================================
# PLAYER CHASING ENEMY DUMMY
# ==============================================================================
# Locates player via GameManager and actively pursues the player character.
# ==============================================================================
extends EnemyBase

var chase_radius: float = 45.0 # Max distance to detect player


func _setup_ai() -> void:
	enemy_name = "Chase Dummy"
	move_speed = 5.2 # Slightly faster than wander dummy


func _process_ai(delta: float) -> void:
	var player: Node3D = GameManager.get_player()
	if not player:
		velocity.x = move_toward(velocity.x, 0, move_speed)
		velocity.z = move_toward(velocity.z, 0, move_speed)
		return

	# Calculate vector to player
	var diff: Vector3 = (player.global_position - global_position)
	diff.y = 0.0 # Keep movement grounded
	
	var dist: float = diff.length()
	
	if dist <= chase_radius and dist > 1.2:
		var dir: Vector3 = diff.normalized()
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
		
		# Rotate facing towards player
		var target_angle: float = atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle, 10.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed)
		velocity.z = move_toward(velocity.z, 0, move_speed)
