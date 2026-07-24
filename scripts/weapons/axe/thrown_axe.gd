# ==============================================================================
# THROWN AXE / HATCHET PROJECTILE (Slot 6 Attack)
# ==============================================================================
# Poly 3D Hatchet prop model thrown along a 3D ballistic trajectory:
# - Emits reddish/amber light in flight.
# - On collision with enemy or terrain, spawns sharp impact spark particles (non-explosive).
# ==============================================================================
extends Node3D

@export var throw_speed: float = 75.0   # Fast straight throw velocity (m/s)
@export var drop_gravity: float = 16.0  # Realistic gravity drop over distance
@export var spin_speed: float = 24.0    # Rotation speed of axe in flight
@export var max_lifetime: float = 4.0   # Maximum seconds before cleanup

var velocity: Vector3 = Vector3.ZERO
var hit_mobs: Array[Node] = []
var time_alive: float = 0.0

@onready var axe_model: Node3D = $AxeModel
@onready var area: Area3D = $Area3D


func _ready() -> void:
	if area:
		area.body_entered.connect(_on_body_entered)


func setup_direction(throw_dir: Vector3) -> void:
	var aim_dir: Vector3 = throw_dir.normalized()
	velocity = aim_dir * throw_speed
	if aim_dir.length() > 0.1:
		look_at(global_position + aim_dir, Vector3.UP)


func _physics_process(delta: float) -> void:
	time_alive += delta
	if time_alive >= max_lifetime:
		queue_free()
		return

	var from_pos: Vector3 = global_position

	# Apply gravity drop
	velocity.y -= drop_gravity * delta

	var to_pos: Vector3 = from_pos + (velocity * delta)

	# --- 100% CCD RAYCAST SWEEP FOR CONTACT DETECTION ---
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if space_state:
		var ray_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from_pos, to_pos)
		ray_query.collision_mask = 3 # Terrain & Enemies
		ray_query.exclude = [self]
		
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

	global_position = to_pos
	
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

	_spawn_impact_particles(global_position)

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
			print("[Hatchet] Struck enemy with hatchet:", hit_enemy.name)
			hit_enemy.call("take_damage", 1)
			queue_free()
	elif time_alive > 0.05:
		queue_free()


func _spawn_impact_particles(hit_pos: Vector3) -> void:
	var cpu_part: CPUParticles3D = CPUParticles3D.new()
	cpu_part.amount = 30
	cpu_part.lifetime = 0.3
	cpu_part.one_shot = true
	cpu_part.explosiveness = 1.0
	cpu_part.direction = Vector3(0.0, 1.0, 0.0)
	cpu_part.spread = 60.0
	cpu_part.initial_velocity_min = 8.0
	cpu_part.initial_velocity_max = 18.0
	cpu_part.gravity = Vector3(0.0, -24.0, 0.0)
	cpu_part.scale_amount_min = 0.1
	cpu_part.scale_amount_max = 0.3
	
	# Shrink scale curve to dissolve particles in mid-air
	var scale_curve: Curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.0))
	cpu_part.scale_amount_curve = scale_curve

	var box_m: BoxMesh = BoxMesh.new()
	box_m.size = Vector3(0.2, 0.2, 0.2)
	
	var part_mat: StandardMaterial3D = StandardMaterial3D.new()
	part_mat.albedo_color = Color(1.0, 0.65, 0.15) # Bright orange/gold spark
	part_mat.emission_enabled = true
	part_mat.emission = Color(1.0, 0.5, 0.1)
	part_mat.emission_energy_multiplier = 3.0
	
	cpu_part.mesh = box_m
	cpu_part.material_override = part_mat
	
	cpu_part.position = hit_pos
	var parent_node: Node = get_parent()
	if parent_node:
		parent_node.add_child(cpu_part)
		cpu_part.global_position = hit_pos
		cpu_part.emitting = true
		
		var timer: SceneTreeTimer = get_tree().create_timer(0.35)
		timer.timeout.connect(cpu_part.queue_free)
