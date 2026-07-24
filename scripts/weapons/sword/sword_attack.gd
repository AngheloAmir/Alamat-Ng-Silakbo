# ==============================================================================
# SWORD ATTACK (SLOT 1)
# ==============================================================================
# Horizontal melee slash attack:
# - Spawns rectangular blade mesh in front of player
# - Rotates in a fast 180-degree horizontal arc (0.2s duration)
# - Destroys any mob hit on contact (1-hit kill)
# ==============================================================================
extends Area3D

@export var swing_speed: float = 12.0 # Arc rotation speed (rad/s)
var lifetime: float = 0.2              # Total attack duration


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # Detect enemy layer
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	# Rotate slash arc around Y-axis
	rotation.y += swing_speed * delta


func _on_body_entered(body: Node3D) -> void:
	if body is EnemyBase:
		print("[SwordAttack] Hit enemy:", body.name)
		(body as EnemyBase).take_damage(1)
