# ==============================================================================
# CROSSBOW BOLT PROJECTILE (Slot 7 Attack)
# ==============================================================================
# High-velocity linear bolt projectile fired from Crossbow weapon slot.
# ==============================================================================
extends Node3D

@export var launch_speed: float = 120.0
@export var drop_gravity: float = 14.0
@export var max_lifetime: float = 3.0

var velocity: Vector3 = Vector3.ZERO
var time_alive: float = 0.0
var hit_mobs: Array[Node] = []

@onready var area: Area3D = $Area3D


func _ready() -> void:
	if area:
		area.body_entered.connect(_on_body_entered)


func setup_direction(dir: Vector3) -> void:
	var aim_dir: Vector3 = dir.normalized()
	velocity = aim_dir * launch_speed
	if aim_dir.length() > 0.1:
		look_at(global_position + aim_dir, Vector3.UP)


func _physics_process(delta: float) -> void:
	time_alive += delta
	if time_alive >= max_lifetime:
		queue_free()
		return

	var from_pos: Vector3 = global_position
	
	velocity.y -= drop_gravity * delta

	var to_pos: Vector3 = from_pos + (velocity * delta)

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if space_state:
		var ray_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from_pos, to_pos)
		ray_query.collision_mask = 3
		ray_query.exclude = [self]
		var player: Node3D = GameManager.get_player()
		if player and is_instance_valid(player):
			ray_query.exclude.append(player.get_rid())

		var hit_res: Dictionary = space_state.intersect_ray(ray_query)
		if not hit_res.is_empty():
			var collider: Object = hit_res.get("collider")
			global_position = hit_res.get("position", to_pos)
			_on_body_entered(collider as Node)
			return

	global_position = to_pos


func _on_body_entered(body: Node) -> void:
	if body == null or body == GameManager.get_player() or hit_mobs.has(body):
		return
	if body.has_method("take_damage"):
		hit_mobs.append(body)
		print("[CrossbowBolt] Struck enemy:", body.name)
		body.take_damage(1)
		queue_free()
	elif time_alive > 0.05:
		queue_free()
