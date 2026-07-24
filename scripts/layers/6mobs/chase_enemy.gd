# ==============================================================================
# PLAYER CHASING ENEMY DUMMY (scripts/layers/6mobs/chase_enemy.gd)
# ==============================================================================
# Executes chase movement based on AI decision queue from Layer 12 or target vector.
# ==============================================================================
extends EnemyBase

var chase_radius: float = 45.0


func _setup_ai() -> void:
	enemy_name = "Chase Dummy"
	move_speed = 5.2


func _process_ai(delta: float) -> void:
	var action: String = current_queued_action.get("action", "")

	if action == "chase":
		var dir: Vector3 = current_queued_action.get("direction", Vector3.ZERO)
		if dir.length() > 0.0:
			velocity.x = dir.x * move_speed
			velocity.z = dir.z * move_speed
			var target_angle: float = atan2(-dir.x, -dir.z)
			rotation.y = lerp_angle(rotation.y, target_angle, 10.0 * delta)
			return

	# Fallback target tracking if no queued decision is present
	var player: Node3D = Server.get_player()
	if not player:
		velocity.x = move_toward(velocity.x, 0, move_speed)
		velocity.z = move_toward(velocity.z, 0, move_speed)
		return

	var diff: Vector3 = (player.global_position - global_position)
	diff.y = 0.0
	var dist: float = diff.length()

	if dist <= chase_radius and dist > 1.2:
		var dir: Vector3 = diff.normalized()
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
		var target_angle: float = atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle, 10.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed)
		velocity.z = move_toward(velocity.z, 0, move_speed)
