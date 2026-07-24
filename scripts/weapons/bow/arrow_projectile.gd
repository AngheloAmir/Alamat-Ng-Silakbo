# ==============================================================================
# BOW ARROW PROJECTILE (SLOT 2 & SLOT 7)
# ==============================================================================
# Long-range projectile with 100% Continuous Collision Detection (CCD Raycasting):
# - Raycast sweep between frames eliminates high-speed tunneling through mobs
# - Realistic gravity trajectory drop curve
# - 1-hit kills any mob on collision
# ==============================================================================
extends Area3D

@export var launch_speed: float = 95.0        # High-velocity arrow flight (m/s)
@export var arrow_drop_gravity: float = 15.0  # Realistic gravity drop trajectory
@export var max_lifetime: float = 5.0         # Despawn safety timer

var velocity: Vector3 = Vector3.ZERO
var lifetime: float = 0.0
var has_hit: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 3 # Layer 1: Terrain, Layer 2: Mobs
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func setup_direction(dir: Vector3) -> void:
	velocity = dir.normalized() * launch_speed
	if velocity.length() > 0.1:
		look_at(global_position + velocity, Vector3.UP)


func _physics_process(delta: float) -> void:
	if has_hit:
		return

	lifetime += delta
	if lifetime >= max_lifetime:
		queue_free()
		return

	# Start position for CCD raycast sweep
	var from_pos: Vector3 = global_position

	# Update velocity for gravity drop
	velocity.y -= arrow_drop_gravity * delta

	# End position for this physics frame
	var to_pos: Vector3 = from_pos + (velocity * delta)

	# --- 100% CONTINUOUS COLLISION DETECTION (CCD RAYCAST SWEEP) ---
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if space_state:
		var ray_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from_pos, to_pos)
		ray_query.collision_mask = 3 # Check Terrain (1) and Enemies (2)
		ray_query.exclude = [self]
		
		# Exclude player and all player child collision objects from self-hit
		var player: Node3D = GameManager.get_player()
		if player and is_instance_valid(player):
			ray_query.exclude.append(player.get_rid())
			for child in player.get_children():
				if child is CollisionObject3D:
					ray_query.exclude.append((child as CollisionObject3D).get_rid())

		var hit_result: Dictionary = space_state.intersect_ray(ray_query)
		if not hit_result.is_empty():
			var collider: Object = hit_result.get("collider")
			var hit_pos: Vector3 = hit_result.get("position", to_pos)
			global_position = hit_pos
			_handle_hit_target(collider)
			return

	# No raycast hit: advance position normally
	global_position = to_pos

	# Align arrow direction along flight path
	if velocity.length() > 0.1:
		look_at(global_position + velocity, Vector3.UP)


func _on_body_entered(body: Node3D) -> void:
	_handle_hit_target(body)


func _on_area_entered(area: Area3D) -> void:
	_handle_hit_target(area)


func _handle_hit_target(target: Object) -> void:
	if has_hit or target == null:
		return
		
	# Ignore player self-collisions
	var player: Node3D = GameManager.get_player()
	if target == player or (target is Node and player and player.is_ancestor_of(target as Node)):
		return

	has_hit = true

	# Search up node tree to find EnemyBase or take_damage handler
	var curr: Object = target
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
		print("[Arrow CCD] Arrow hit enemy mob:", hit_enemy.name)
		hit_enemy.call("take_damage", 1)
	else:
		print("[Arrow CCD] Arrow hit terrain or object:", target)

	queue_free()
