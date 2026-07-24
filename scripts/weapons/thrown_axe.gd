# ==============================================================================
# THROWN AXE PROJECTILE (Right-Click Attack - Cursor Aimed Straight Throw)
# ==============================================================================
# Composite primitive mesh (Rectangular handle + Eclipse blade head).
# Launches high above player head (2.2m elevation) and flies fast & straight
# towards the exact 3D direction aimed by the player's crosshair cursor.
# ==============================================================================
extends Node3D

# --- CURSOR-AIMED STRAIGHT THROW PARAMETERS ---
@export var throw_speed: float = 75.0   # Fast straight throw velocity (m/s)
@export var drop_gravity: float = 2.5    # Minimal gravity drop over distance
@export var spin_speed: float = 24.0     # Rotation speed of axe in flight
@export var max_lifetime: float = 4.0    # Maximum seconds before cleanup

var velocity: Vector3 = Vector3.ZERO
var hit_mobs: Array[Node] = []
var time_alive: float = 0.0

@onready var axe_model: Node3D = $AxeModel
@onready var area: Area3D = $Area3D


func _ready() -> void:
	area.body_entered.connect(_on_body_entered)


func setup_direction(throw_dir: Vector3) -> void:
	# Fires straight in the exact direction aimed by crosshair/cursor
	var aim_dir: Vector3 = throw_dir.normalized()
	velocity = aim_dir * throw_speed
	if aim_dir.length() > 0.1:
		look_at(global_position + aim_dir, Vector3.UP)


func _physics_process(delta: float) -> void:
	time_alive += delta
	if time_alive >= max_lifetime:
		queue_free()
		return

	# Start position for CCD raycast sweep
	var from_pos: Vector3 = global_position

	# 1. Apply slight gravity drop
	velocity.y -= drop_gravity * delta

	# End position for this physics frame
	var to_pos: Vector3 = from_pos + (velocity * delta)

	# --- 100% CONTINUOUS COLLISION DETECTION (CCD RAYCAST SWEEP) ---
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if space_state:
		var ray_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from_pos, to_pos)
		ray_query.collision_mask = 3 # Check Terrain (1) and Enemies (2)
		ray_query.exclude = [self]
		
		# Exclude player from self-hit
		var player: Node3D = GameManager.get_player()
		if player and is_instance_valid(player):
			ray_query.exclude.append(player.get_rid())

		var hit_result: Dictionary = space_state.intersect_ray(ray_query)
		if not hit_result.is_empty():
			var collider: Object = hit_result.get("collider")
			var hit_pos: Vector3 = hit_result.get("position", to_pos)
			global_position = hit_pos
			_handle_hit_target(collider)
			return

	# No raycast hit: advance position normally
	global_position = to_pos
	
	# 3. Spin axe visually in flight
	if axe_model:
		axe_model.rotate_x(spin_speed * delta)


func _on_body_entered(body: Node) -> void:
	_handle_hit_target(body)


func _handle_hit_target(body: Object) -> void:
	if body == null:
		return
	var player: Node3D = GameManager.get_player()
	if body == player or (body is Node and player and player.is_ancestor_of(body as Node)):
		return

	var curr: Object = body
	var hit_enemy: Node = null

	while curr != null:
		if curr is EnemyBase:
			hit_enemy = curr as Node
			break
		elif curr is Node and (curr as Node).has_method("take_damage"):
			hit_enemy = curr as Node
			break
		if curr is Node:
			curr = (curr as Node).get_parent()
		else:
			break

	if hit_enemy and hit_enemy.has_method("take_damage"):
		if not hit_mobs.has(hit_enemy):
			hit_mobs.append(hit_enemy)
			print("[ThrownAxe CCD] Axe struck enemy:", hit_enemy.name)
			hit_enemy.call("take_damage", 1)
			queue_free()
	elif time_alive > 0.05:
		queue_free()
