# ==============================================================================
# STATIC ENEMY DUMMY
# ==============================================================================
# Stands completely still in place. Ideal target practice for melee & thrown axe.
# ==============================================================================
extends EnemyBase

func _setup_ai() -> void:
	enemy_name = "Static Dummy"

func _process_ai(delta: float) -> void:
	# Zero movement velocity
	velocity.x = move_toward(velocity.x, 0, move_speed)
	velocity.z = move_toward(velocity.z, 0, move_speed)
