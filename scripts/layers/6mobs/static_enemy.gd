# ==============================================================================
# STATIC ENEMY DUMMY (scripts/layers/6mobs/static_enemy.gd)
# ==============================================================================
# Stands still in place as target practice.
# ==============================================================================
extends EnemyBase

func _setup_ai() -> void:
	enemy_name = "Static Dummy"


func _process_ai(_delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, move_speed)
	velocity.z = move_toward(velocity.z, 0, move_speed)
