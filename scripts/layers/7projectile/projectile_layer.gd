# ==============================================================================
# LAYER 7: PROJECTILE PROCESSING LAYER (scripts/layers/7projectile/projectile_layer.gd)
# ==============================================================================
# Dedicated layer running on a separate processing loop for active projectiles.
# 1. Manages all active projectile entities in the world.
# 2. Uses `ProjectileMath` for frame-rate independent time-delta trajectory tracking.
# 3. Performs Continuous Collision Detection (CCD) raycasting against ground, walls, blocks, and mobs.
# 4. On impact: requests `Server.spawn_effect(...)` for Layer 9, applies damage, and removes projectile.
# ==============================================================================
extends Node3D

const LAYER_ID: int = 7

# Active projectile runtime structure array
var active_projectiles: Array[Dictionary] = []


func _ready() -> void:
	Server.register_layer_manager(LAYER_ID, self)
	print("[Layer 7] Projectile processing layer initialized.")


## Called by Server hub when a player or entity fires a projectile.
func spawn_projectile(data: Dictionary) -> void:
	var proj_type: String = data.get("type", "arrow")
	var damage: float = data.get("damage", 8.0)
	var speed: float = data.get("velocity_speed", 120.0)
	var weight: float = data.get("weight", 100.0)
	var origin: Vector3 = data.get("origin", Vector3.ZERO)
	var direction: Vector3 = data.get("direction", Vector3.FORWARD)

	# Build visual mesh representation for projectile
	var visual_node: Node3D = _create_projectile_visual(proj_type)
	add_child(visual_node)
	visual_node.global_position = origin

	var velocity: Vector3 = direction.normalized() * speed
	if velocity.length() > 0.1:
		visual_node.look_at(origin + velocity, Vector3.UP)

	# Gather player RIDs to exclude self-hits
	var exclude_rids: Array[RID] = []
	var player: Node3D = Server.get_player()
	if player and is_instance_valid(player):
		if player is CollisionObject3D:
			exclude_rids.append((player as CollisionObject3D).get_rid())
		for child in player.get_children():
			if child is CollisionObject3D:
				exclude_rids.append((child as CollisionObject3D).get_rid())

	var projectile_record := {
		"type": proj_type,
		"damage": damage,
		"weight": weight,
		"velocity": velocity,
		"position": origin,
		"elapsed_time": 0.0,
		"max_lifetime": 5.0,
		"visual_node": visual_node,
		"exclude_rids": exclude_rids,
		"has_hit": false
	}

	active_projectiles.append(projectile_record)
	print("[Layer 7] Spawned projectile:", proj_type, " Damage:", damage, " Speed:", speed, " Weight:", weight)


func _physics_process(delta: float) -> void:
	if active_projectiles.is_empty():
		return

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var collision_mask: int = CollisionUtils.get_default_projectile_mask()
	var to_remove: Array[int] = []

	for i in range(active_projectiles.size()):
		var p: Dictionary = active_projectiles[i]
		if p.get("has_hit", false):
			to_remove.append(i)
			continue

		var elapsed: float = p.get("elapsed_time", 0.0) + delta
		p["elapsed_time"] = elapsed

		if elapsed >= p.get("max_lifetime", 5.0):
			_destroy_projectile_record(p)
			to_remove.append(i)
			continue

		var current_pos: Vector3 = p.get("position", Vector3.ZERO)
		var current_vel: Vector3 = ProjectileMath.calculate_velocity(p.get("velocity", Vector3.ZERO), p.get("weight", 100.0), delta)
		p["velocity"] = current_vel

		var next_pos: Vector3 = ProjectileMath.calculate_next_position(current_pos, current_vel, delta)

		# Perform Continuous Collision Detection (CCD) raycast
		var exclude_rids: Array[RID] = p.get("exclude_rids", [])
		var hit_result: Dictionary = ProjectileMath.perform_ccd_raycast(space_state, current_pos, next_pos, collision_mask, exclude_rids)

		if not hit_result.is_empty():
			p["has_hit"] = true
			var hit_pos: Vector3 = hit_result.get("position", next_pos)
			var collider: Object = hit_result.get("collider")

			# Handle hit response & trigger Layer 9 visual effect via Server hub
			_on_projectile_hit(p, collider, hit_pos)
			_destroy_projectile_record(p)
			to_remove.append(i)
		else:
			# Advance position smoothly
			p["position"] = next_pos
			var visual_node: Node3D = p.get("visual_node")
			if visual_node and is_instance_valid(visual_node):
				visual_node.global_position = next_pos
				if current_vel.length() > 0.1:
					visual_node.look_at(next_pos + current_vel, Vector3.UP)

	# Clean up destroyed projectile records in reverse order
	for idx in range(to_remove.size() - 1, -1, -1):
		active_projectiles.remove_at(to_remove[idx])


func _on_projectile_hit(p: Dictionary, collider: Object, hit_pos: Vector3) -> void:
	var proj_type: String = p.get("type", "arrow")
	var damage: float = p.get("damage", 8.0)

	# Trigger impact particle effect on Layer 9 via Server Hub
	if proj_type == "fireball" or proj_type == "hammer":
		Server.spawn_effect("explosion", hit_pos)
	else:
		Server.spawn_effect("sparks", hit_pos)

	if collider == null:
		return

	# Search node hierarchy for hit recipient
	var curr: Object = collider
	var target_node: Node = null

	while curr != null:
		if curr is Node and (curr as Node).has_method("take_damage"):
			target_node = curr as Node
			break
		if curr is Node:
			curr = (curr as Node).get_parent()
		else:
			break

	if target_node and target_node.has_method("take_damage"):
		print("[Layer 7 Hit] Projectile", proj_type, "hit target:", target_node.name, "Damage:", damage)
		target_node.call("take_damage", damage)


func _create_projectile_visual(proj_type: String) -> Node3D:
	var root: Node3D = Node3D.new()
	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	var mat: StandardMaterial3D = StandardMaterial3D.new()

	match proj_type:
		"bolt":
			var cyl: CylinderMesh = CylinderMesh.new()
			cyl.top_radius = 0.05
			cyl.bottom_radius = 0.05
			cyl.height = 0.6
			mesh_inst.mesh = cyl
			mat.albedo_color = Color(1.0, 0.7, 0.2)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.6, 0.1)
			mat.emission_energy_multiplier = 3.0
		"axe":
			var box: BoxMesh = BoxMesh.new()
			box.size = Vector3(0.1, 0.6, 0.4)
			mesh_inst.mesh = box
			mat.albedo_color = Color(0.8, 0.3, 0.2)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.2, 0.1)
		"fireball":
			var sphere: SphereMesh = SphereMesh.new()
			sphere.radius = 0.4
			sphere.height = 0.8
			mesh_inst.mesh = sphere
			mat.albedo_color = Color(1.0, 0.4, 0.1)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.3, 0.0)
			mat.emission_energy_multiplier = 5.0
		_: # "arrow" standard
			var cyl: CylinderMesh = CylinderMesh.new()
			cyl.top_radius = 0.02
			cyl.bottom_radius = 0.04
			cyl.height = 0.8
			mesh_inst.mesh = cyl
			mat.albedo_color = Color(0.9, 0.2, 0.2)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.2, 0.2)

	mesh_inst.material_override = mat
	mesh_inst.rotation.x = deg_to_rad(90.0) # Orient forward
	root.add_child(mesh_inst)
	return root


func _destroy_projectile_record(p: Dictionary) -> void:
	var visual: Node3D = p.get("visual_node")
	if visual and is_instance_valid(visual):
		visual.queue_free()
