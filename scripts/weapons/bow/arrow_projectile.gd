# ==============================================================================
# BOW ARROW PROJECTILE (SLOT 2)
# ==============================================================================
# Long-range projectile affected by gravity:
# - High launch speed (38.0 m/s) that travels far over distance
# - Realistic gravity trajectory drop curve
# - 1-hit kills any mob on collision
# ==============================================================================
extends Area3D

@export var launch_speed: float = 38.0        # Fast long-range launch speed (m/s)
@export var arrow_drop_gravity: float = 14.0  # Gravity drop acceleration
@export var max_lifetime: float = 5.0         # Despawn safety timer

var velocity: Vector3 = Vector3.ZERO
var lifetime: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 3 # Hit enemies and terrain
	body_entered.connect(_on_body_entered)


func setup_direction(dir: Vector3) -> void:
	velocity = dir.normalized() * launch_speed
	# Align arrow model rotation with flight direction
	if velocity.length() > 0.1:
		look_at(global_position + velocity, Vector3.UP)


func _physics_process(delta: float) -> void:
	lifetime += delta
	if lifetime >= max_lifetime:
		queue_free()
		return

	# Apply gravity drop over flight distance
	velocity.y -= arrow_drop_gravity * delta
	global_position += velocity * delta

	# Point arrow head along velocity direction
	if velocity.length() > 0.1:
		look_at(global_position + velocity, Vector3.UP)


func _on_body_entered(body: Node3D) -> void:
	if body is EnemyBase:
		print("[BowArrow] Arrow hit enemy mob:", body.name)
		(body as EnemyBase).take_damage(1)
		queue_free()
	elif body != null:
		# Hit terrain or object -> destroy arrow
		queue_free()
