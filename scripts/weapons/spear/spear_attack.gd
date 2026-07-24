# ==============================================================================
# STAFF EXPLOSIVE FIERY BOX PROJECTILE (Slot 3 Attack)
# ==============================================================================
# Glowing fiery box projectile fired towards 3D crosshair in FPS / 3rd person mode.
# - Emits dynamic OmniLight3D firelight in flight.
# - On contact with terrain or enemy, explodes into a massive 8.5m AOE blast!
# - Emits shrinking mid-air ember particles & ejected rock chunks that disappear before landing.
# ==============================================================================
extends Node3D

@export var launch_speed: float = 85.0   # Fast flight speed (m/s)
@export var drop_gravity: float = 25.0   # Heavy ballistic gravity drop curve (drops fast)
@export var max_lifetime: float = 4.0    # Lifetime before auto-cleanup
@export var explosion_radius: float = 8.5 # Bigger 8.5m Explosion AOE damage radius

var velocity: Vector3 = Vector3.ZERO
var time_alive: float = 0.0
var has_exploded: bool = false

@onready var area: Area3D = $Area3D
@onready var light: OmniLight3D = $OmniLight3D
@onready var mesh: MeshInstance3D = $FireballMesh


func _ready() -> void:
	if area:
		area.body_entered.connect(_on_body_entered)


func setup_direction(shoot_dir: Vector3) -> void:
	var aim_dir: Vector3 = shoot_dir.normalized()
	velocity = aim_dir * launch_speed
	if aim_dir.length() > 0.1:
		look_at(global_position + aim_dir, Vector3.UP)


func _physics_process(delta: float) -> void:
	if has_exploded:
		return

	time_alive += delta
	if time_alive >= max_lifetime:
		queue_free()
		return

	var from_pos: Vector3 = global_position
	
	# Apply heavy ballistic gravity drop
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
			var hit_pos: Vector3 = hit_result.get("position", to_pos)
			global_position = hit_pos
			_explode()
			return

	global_position = to_pos
	
	# Rotate box mesh in flight for dynamic magic effect
	if mesh:
		mesh.rotate_z(12.0 * delta)
		mesh.rotate_x(9.0 * delta)

	if light:
		light.light_energy = 4.5 + (sin(time_alive * 30.0) * 1.2)


func _on_body_entered(body: Node) -> void:
	if has_exploded:
		return
	var player: Node3D = GameManager.get_player()
	if body == player or (body is Node and player and player.is_ancestor_of(body)):
		return
	_explode()


func _explode() -> void:
	if has_exploded:
		return
	has_exploded = true
	
	print("[StaffExplosion] Massive 8.5m Fiery Box Explosion at:", global_position)
	
	# 1. Intense Light Flash (24.0 energy, 20m range)
	if light:
		light.light_energy = 24.0
		light.omni_range = 20.0
	
	# 2. AOE Damage Sweep within 8.5m explosion_radius
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if space_state:
		var shape_query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		var sphere_shape: SphereShape3D = SphereShape3D.new()
		sphere_shape.radius = explosion_radius
		shape_query.shape = sphere_shape
		shape_query.transform = Transform3D(Basis(), global_position)
		shape_query.collision_mask = 2 # Enemies
		
		var results: Array[Dictionary] = space_state.intersect_shape(shape_query)
		var hit_mobs: Array[Node] = []
		for res in results:
			var collider: Object = res.get("collider")
			if collider and collider.has_method("take_damage"):
				var mob: Node = collider as Node
				if not hit_mobs.has(mob):
					hit_mobs.append(mob)
					print("[StaffExplosion] AOE 8.5m blast hit mob:", mob.name)
					mob.call("take_damage", 1)

	# 3. Create CPUParticles3D Ground Debris Burst (shrinks to 0 scale in mid-air)
	_spawn_ground_particles()

	# 4. Spawn 8 Ejected Ground Rock Chunks (scales to 0 and auto-frees)
	_spawn_ejected_rock_chunks()

	# 5. Visual shockwave expansion tween
	var tween: Tween = create_tween().set_parallel(true)
	if mesh:
		tween.tween_property(mesh, "scale", Vector3.ONE * 8.5, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if light:
		tween.tween_property(light, "light_energy", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	tween.chain().tween_callback(queue_free)


func _spawn_ground_particles() -> void:
	var cpu_part: CPUParticles3D = CPUParticles3D.new()
	cpu_part.amount = 45
	cpu_part.lifetime = 0.35
	cpu_part.one_shot = true
	cpu_part.explosiveness = 1.0
	cpu_part.direction = Vector3(0.0, 1.0, 0.0)
	cpu_part.spread = 80.0
	cpu_part.initial_velocity_min = 12.0
	cpu_part.initial_velocity_max = 22.0
	cpu_part.gravity = Vector3(0.0, -20.0, 0.0)
	cpu_part.scale_amount_min = 0.15
	cpu_part.scale_amount_max = 0.4
	
	# Shrink scale curve: Particles shrink from 1.0 scale to 0.0 scale in mid-air
	var scale_curve: Curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.0))
	cpu_part.scale_amount_curve = scale_curve

	var box_m: BoxMesh = BoxMesh.new()
	box_m.size = Vector3(0.25, 0.25, 0.25)
	
	var part_mat: StandardMaterial3D = StandardMaterial3D.new()
	part_mat.albedo_color = Color(0.42, 0.28, 0.14)
	part_mat.emission_enabled = true
	part_mat.emission = Color(1.0, 0.4, 0.08)
	part_mat.emission_energy_multiplier = 2.5
	
	cpu_part.mesh = box_m
	cpu_part.material_override = part_mat
	
	var impact_pos: Vector3 = global_position
	cpu_part.position = impact_pos
	
	var parent_node: Node = get_parent()
	if parent_node:
		parent_node.add_child(cpu_part)
		cpu_part.global_position = impact_pos
		cpu_part.emitting = true
		
		var timer: SceneTreeTimer = get_tree().create_timer(0.4)
		timer.timeout.connect(cpu_part.queue_free)


func _spawn_ejected_rock_chunks() -> void:
	var rock_mesh: BoxMesh = BoxMesh.new()
	rock_mesh.size = Vector3(0.35, 0.35, 0.35)
	
	var rock_mat: StandardMaterial3D = StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.35, 0.22, 0.12)
	rock_mat.emission_enabled = true
	rock_mat.emission = Color(1.0, 0.35, 0.05)
	rock_mat.emission_energy_multiplier = 2.0

	var origin: Vector3 = global_position
	var parent_node: Node = get_parent()
	if not parent_node:
		return

	for i in range(8):
		var chunk: MeshInstance3D = MeshInstance3D.new()
		chunk.mesh = rock_mesh
		chunk.material_override = rock_mat
		chunk.position = origin
		parent_node.add_child(chunk)
		chunk.global_position = origin
		
		var angle: float = (i / 8.0) * TAU + randf_range(-0.2, 0.2)
		var distance: float = randf_range(3.0, 6.0)
		var height: float = randf_range(1.5, 3.5)
		var target_offset: Vector3 = Vector3(cos(angle) * distance, height, sin(angle) * distance)
		var final_pos: Vector3 = origin + target_offset
		
		var chunk_tween: Tween = create_tween().set_parallel(true)
		chunk_tween.tween_property(chunk, "global_position", final_pos, 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		chunk_tween.tween_property(chunk, "rotation", Vector3(randf() * 10, randf() * 10, randf() * 10), 0.30)
		chunk_tween.tween_property(chunk, "scale", Vector3.ZERO, 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		chunk_tween.chain().tween_callback(chunk.queue_free)
