# ==============================================================================
# LAYER 1: GROUND & TERRAIN LAYER (scripts/layers/1ground/terrain_layer.gd)
# ==============================================================================
# Manages ground physics, terrain heightmap generation, environment props,
# and Indestructible Ground Furniture Props (Key N).
# Assigned to Collision Layer 1 (Ground).
# ==============================================================================
extends Node3D

const LAYER_ID: int = 1

@export var terrain_size: Vector2 = Vector2(1400.0, 1400.0)
@export var grid_subdivisions: int = 220
@export var mountain_height: float = 650.0
@export var tree_count: int = 250
@export var rock_count: int = 180


func _ready() -> void:
	Server.register_layer_manager(LAYER_ID, self)
	_generate_mountain_terrain()
	_create_raised_test_platforms()
	_scatter_environment_props()
	print("[Layer 1] Ground & Terrain layer initialized.")


## API: Spawn 50 Complex Indestructible Furniture Props on Layer 1 (Key N)
func spawn_furniture_batch(count: int, origin: Vector3) -> void:
	print("[Layer 1 Ground] Spawning batch of ", count, " complex indestructible furniture props via Key 'N'...")
	for i in range(count):
		var grid_x: float = snappedf(origin.x + randf_range(-14.0, 14.0), 1.0)
		var grid_z: float = snappedf(origin.z + randf_range(-14.0, 14.0), 1.0)
		var spawn_height: float = origin.y + randf_range(4.0, 20.0)

		var furniture := IndestructibleFurniture.new()
		add_child(furniture)
		furniture.setup_furniture(Vector3(grid_x, spawn_height, grid_z))


func _generate_mountain_terrain() -> void:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.0018
	noise.fractal_octaves = 4

	var plane_mesh: PlaneMesh = PlaneMesh.new()
	plane_mesh.size = terrain_size
	plane_mesh.subdivide_width = grid_subdivisions
	plane_mesh.subdivide_depth = grid_subdivisions

	var st: SurfaceTool = SurfaceTool.new()
	st.create_from(plane_mesh, 0)
	var array_mesh: ArrayMesh = st.commit()
	var mdt: MeshDataTool = MeshDataTool.new()
	mdt.create_from_surface(array_mesh, 0)

	var half_size_x: float = terrain_size.x * 0.5

	for i in range(mdt.get_vertex_count()):
		var v: Vector3 = mdt.get_vertex(i)
		var dist_from_center: float = Vector2(v.x, v.z).length()

		if dist_from_center < 20.0:
			v.y = 0.0
		else:
			var base_h: float = noise.get_noise_2d(v.x, v.z) * 40.0
			var border_factor: float = clampf((dist_from_center - 20.0) / (half_size_x - 20.0), 0.0, 1.0)
			border_factor = pow(border_factor, 1.2)

			var raw_n: float = noise.get_noise_2d(v.x * 0.8, v.z * 0.8)
			var smooth_mountain: float = pow((raw_n * 0.5 + 0.5), 2.2) * mountain_height

			v.y = base_h + (smooth_mountain * border_factor)

		mdt.set_vertex(i, v)

	array_mesh.clear_surfaces()
	mdt.commit_to_surface(array_mesh)
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.create_from(array_mesh, 0)
	st.generate_normals()
	var temp_mesh: ArrayMesh = st.commit()

	mdt.clear()
	mdt.create_from_surface(temp_mesh, 0)

	var grass_color: Color = Color(0.22, 0.52, 0.24)
	var dirt_rock_color: Color = Color(0.46, 0.38, 0.30)
	var snow_color: Color = Color(0.92, 0.95, 1.0)

	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for i in range(mdt.get_face_count()):
		for j in range(3):
			var vertex_idx: int = mdt.get_face_vertex(i, j)
			var v: Vector3 = mdt.get_vertex(vertex_idx)
			var normal: Vector3 = mdt.get_vertex_normal(vertex_idx)

			var final_color: Color = grass_color
			var height: float = v.y
			var slope_flatness: float = normal.y

			if height > 220.0:
				var snow_blend: float = clampf((height - 220.0) / 120.0, 0.0, 1.0)
				final_color = dirt_rock_color.lerp(snow_color, snow_blend)
			elif height > 45.0 or slope_flatness < 0.78:
				var dirt_blend: float = clampf((height - 45.0) / 80.0, 0.0, 1.0)
				if slope_flatness < 0.78:
					dirt_blend = maxf(dirt_blend, 1.0 - slope_flatness)
				final_color = grass_color.lerp(dirt_rock_color, dirt_blend)
			else:
				final_color = grass_color

			st.set_color(final_color)
			st.set_normal(normal)
			st.set_uv(Vector2(v.x * 0.02, v.z * 0.02))
			st.add_vertex(v)

	var final_terrain_mesh: ArrayMesh = st.commit()

	var noise_tex: NoiseTexture2D = NoiseTexture2D.new()
	noise_tex.noise = noise
	noise_tex.seamless = true

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = noise_tex
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.04, 0.04, 0.04)
	mat.roughness = 0.85

	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	mesh_inst.name = "TerrainMesh"
	mesh_inst.mesh = final_terrain_mesh
	mesh_inst.material_override = mat
	add_child(mesh_inst)

	var static_body: StaticBody3D = StaticBody3D.new()
	static_body.name = "TerrainCollision"
	static_body.collision_layer = CollisionUtils.get_layer_bitmask(CollisionUtils.LayerIndex.GROUND)

	var col_shape: CollisionShape3D = CollisionShape3D.new()
	col_shape.shape = final_terrain_mesh.create_trimesh_shape()
	static_body.add_child(col_shape)
	add_child(static_body)


func _create_raised_test_platforms() -> void:
	var platform_container: Node3D = Node3D.new()
	platform_container.name = "RaisedTestPlatforms"
	add_child(platform_container)

	_build_box_platform(platform_container, Vector3(25.0, 1.25, -22.0), Vector3(16.0, 2.5, 16.0), Color(0.55, 0.52, 0.48))
	_build_ramp(platform_container, Vector3(25.0, 1.25, -11.0), Vector3(5.0, 0.2, 11.0), deg_to_rad(18.0), Color(0.5, 0.48, 0.45))

	_build_box_platform(platform_container, Vector3(-32.0, 2.5, -32.0), Vector3(20.0, 5.0, 20.0), Color(0.48, 0.45, 0.42))
	_build_ramp(platform_container, Vector3(-32.0, 2.5, -18.0), Vector3(6.0, 0.2, 14.0), deg_to_rad(22.0), Color(0.45, 0.42, 0.40))


func _build_box_platform(parent: Node3D, platform_pos: Vector3, size: Vector3, color: Color) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = platform_pos
	body.collision_layer = CollisionUtils.get_layer_bitmask(CollisionUtils.LayerIndex.GROUND)

	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = size
	mesh_inst.mesh = box_mesh

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.7
	mesh_inst.material_override = mat
	body.add_child(mesh_inst)

	var col: CollisionShape3D = CollisionShape3D.new()
	var platform_box_shape: BoxShape3D = BoxShape3D.new()
	platform_box_shape.size = size
	col.shape = platform_box_shape
	body.add_child(col)

	parent.add_child(body)


func _build_ramp(parent: Node3D, ramp_pos: Vector3, size: Vector3, angle_rad: float, color: Color) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = ramp_pos
	body.rotation.x = angle_rad
	body.collision_layer = CollisionUtils.get_layer_bitmask(CollisionUtils.LayerIndex.GROUND)

	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = size
	mesh_inst.mesh = box_mesh

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.7
	mesh_inst.material_override = mat
	body.add_child(mesh_inst)

	var col: CollisionShape3D = CollisionShape3D.new()
	var ramp_box_shape: BoxShape3D = BoxShape3D.new()
	ramp_box_shape.size = size
	col.shape = ramp_box_shape
	body.add_child(col)

	parent.add_child(body)


func _scatter_environment_props() -> void:
	var props_container: Node3D = Node3D.new()
	props_container.name = "EnvironmentProps"
	add_child(props_container)

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1337

	for i in range(tree_count):
		var pos_x: float = rng.randf_range(-600.0, 600.0)
		var pos_z: float = rng.randf_range(-600.0, 600.0)
		if Vector2(pos_x, pos_z).length() < 40.0:
			continue

		var tree: Node3D = _create_tree_mesh(rng)
		tree.position = Vector3(pos_x, 0.0, pos_z)
		props_container.add_child(tree)

	for i in range(rock_count):
		var pos_x: float = rng.randf_range(-620.0, 620.0)
		var pos_z: float = rng.randf_range(-620.0, 620.0)
		if Vector2(pos_x, pos_z).length() < 35.0:
			continue

		var rock: Node3D = _create_rock_mesh(rng)
		rock.position = Vector3(pos_x, 0.0, pos_z)
		props_container.add_child(rock)


func _create_tree_mesh(rng: RandomNumberGenerator) -> Node3D:
	var tree_node: Node3D = Node3D.new()
	tree_node.name = "Tree"

	var trunk: MeshInstance3D = MeshInstance3D.new()
	var trunk_mesh: CylinderMesh = CylinderMesh.new()
	trunk_mesh.top_radius = 0.35
	trunk_mesh.bottom_radius = 0.55
	trunk_mesh.height = 3.5
	trunk.mesh = trunk_mesh

	var trunk_mat: StandardMaterial3D = StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.35, 0.22, 0.12)
	trunk.material_override = trunk_mat
	trunk.position.y = 1.75

	trunk.visibility_range_end = 350.0
	trunk.visibility_range_end_margin = 40.0
	trunk.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	tree_node.add_child(trunk)

	var leaves: MeshInstance3D = MeshInstance3D.new()
	var leaves_mesh: SphereMesh = SphereMesh.new()
	var scale_factor: float = rng.randf_range(1.8, 2.8)
	leaves_mesh.radius = scale_factor
	leaves_mesh.height = scale_factor * 2.0
	leaves.mesh = leaves_mesh

	var leaves_mat: StandardMaterial3D = StandardMaterial3D.new()
	leaves_mat.albedo_color = Color(0.12, 0.42, 0.18)
	leaves.material_override = leaves_mat
	leaves.position.y = 4.0

	leaves.visibility_range_end = 350.0
	leaves.visibility_range_end_margin = 40.0
	leaves.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	tree_node.add_child(leaves)

	var col_body: StaticBody3D = StaticBody3D.new()
	col_body.collision_layer = CollisionUtils.get_layer_bitmask(CollisionUtils.LayerIndex.GROUND)
	var col_shape: CollisionShape3D = CollisionShape3D.new()
	var cyl_shape: CylinderShape3D = CylinderShape3D.new()
	cyl_shape.radius = 0.5
	cyl_shape.height = 3.5
	col_shape.shape = cyl_shape
	col_shape.position.y = 1.75
	col_body.add_child(col_shape)
	tree_node.add_child(col_body)

	return tree_node


func _create_rock_mesh(rng: RandomNumberGenerator) -> Node3D:
	var rock_node: Node3D = Node3D.new()
	rock_node.name = "Rock"

	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	var size_x: float = rng.randf_range(1.2, 2.8)
	var size_y: float = rng.randf_range(0.8, 1.8)
	var size_z: float = rng.randf_range(1.2, 2.8)
	sphere.radius = size_x
	sphere.height = size_y * 2.0
	mesh_inst.mesh = sphere

	var rock_mat: StandardMaterial3D = StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.48, 0.49, 0.52)
	rock_mat.roughness = 0.9
	mesh_inst.material_override = rock_mat
	mesh_inst.position.y = size_y * 0.5

	mesh_inst.visibility_range_end = 350.0
	mesh_inst.visibility_range_end_margin = 40.0
	mesh_inst.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	rock_node.add_child(mesh_inst)

	var col_body: StaticBody3D = StaticBody3D.new()
	col_body.collision_layer = CollisionUtils.get_layer_bitmask(CollisionUtils.LayerIndex.GROUND)
	var col_shape: CollisionShape3D = CollisionShape3D.new()
	var rock_box_shape: BoxShape3D = BoxShape3D.new()
	rock_box_shape.size = Vector3(size_x * 2.0, size_y * 2.0, size_z * 2.0)
	col_shape.shape = rock_box_shape
	col_shape.position.y = size_y * 0.5
	col_body.add_child(col_shape)
	rock_node.add_child(col_body)

	return rock_node


# ==============================================================================
# SUB-CLASS: INDESTRUCTIBLE COMPLEX FURNITURE PROP (Layer 1 Ground Object)
# ==============================================================================
# Assigned to Collision Layer 1 (GROUND). Part of the permanent environment.
# Multi-mesh composite furniture prop (table, chair, pillar, multi-shape cabinet)
# - Indestructible: Ignores take_damage() (cannot be destroyed by projectiles, only Key M reset)
# - Falls & Stacks: Falls straight down along Y-axis and locks onto terrain/blocks
# ==============================================================================
class IndestructibleFurniture extends StaticBody3D:
	var is_falling: bool = true
	var fall_speed: float = 16.0
	var col_shape: CollisionShape3D = null

	func setup_furniture(start_pos: Vector3) -> void:
		global_position = start_pos

		collision_layer = CollisionUtils.get_layer_bitmask(CollisionUtils.LayerIndex.GROUND)
		collision_mask = CollisionUtils.combine_masks([
			CollisionUtils.LayerIndex.GROUND,
			CollisionUtils.LayerIndex.WALL,
			CollisionUtils.LayerIndex.BLOCK
		])

		# Pick a random furniture archetype (0: Table, 1: Chair, 2: Pillar, 3: Cabinet/Counter)
		var archetype: int = randi() % 4
		_assemble_complex_furniture_mesh(archetype)

		# Combined Collision Shape
		col_shape = CollisionShape3D.new()
		var furniture_box_shape := BoxShape3D.new()
		furniture_box_shape.size = Vector3(1.2, 1.2, 1.2)
		col_shape.shape = furniture_box_shape
		add_child(col_shape)

		Server.register_furniture(self)

	func _assemble_complex_furniture_mesh(archetype: int) -> void:
		var root_holder := Node3D.new()
		add_child(root_holder)

		# Palette of vibrant colors
		var color_palette: Array[Color] = [
			Color(0.45, 0.26, 0.12), # Mahogany Wood
			Color(0.72, 0.52, 0.32), # Oak Wood
			Color(0.85, 0.20, 0.20), # Ruby Red
			Color(0.20, 0.70, 0.40), # Emerald Green
			Color(0.25, 0.45, 0.90), # Royal Blue
			Color(0.90, 0.75, 0.20), # Gold
			Color(0.55, 0.25, 0.75)  # Purple
		]
		var main_color: Color = color_palette[randi() % color_palette.size()]
		var accent_color: Color = color_palette[randi() % color_palette.size()]

		match archetype:
			0: # TABLE (Top surface + 4 legs)
				_add_primitive_part(root_holder, BoxMesh.new(), Vector3(1.4, 0.15, 1.0), Vector3(0.0, 0.5, 0.0), main_color)
				var leg_offsets: Array[Vector3] = [
					Vector3(-0.55, 0.0, -0.38),
					Vector3(0.55, 0.0, -0.38),
					Vector3(-0.55, 0.0, 0.38),
					Vector3(0.55, 0.0, 0.38)
				]
				for offset in leg_offsets:
					_add_primitive_part(root_holder, CylinderMesh.new(), Vector3(0.12, 0.85, 0.12), offset, accent_color)

			1: # CHAIR (Seat + Backrest + 4 Legs)
				_add_primitive_part(root_holder, BoxMesh.new(), Vector3(0.7, 0.1, 0.7), Vector3(0.0, 0.2, 0.0), main_color)
				_add_primitive_part(root_holder, BoxMesh.new(), Vector3(0.7, 0.7, 0.1), Vector3(0.0, 0.6, -0.3), main_color)
				var leg_offsets: Array[Vector3] = [
					Vector3(-0.28, -0.2, -0.28),
					Vector3(0.28, -0.2, -0.28),
					Vector3(-0.28, -0.2, 0.28),
					Vector3(0.28, -0.2, 0.28)
				]
				for offset in leg_offsets:
					_add_primitive_part(root_holder, CylinderMesh.new(), Vector3(0.08, 0.6, 0.08), offset, accent_color)

			2: # PILLAR / MONUMENT (Base + Cylinder Column + Top Sphere Cap)
				_add_primitive_part(root_holder, BoxMesh.new(), Vector3(0.9, 0.2, 0.9), Vector3(0.0, -0.4, 0.0), accent_color)
				_add_primitive_part(root_holder, CylinderMesh.new(), Vector3(0.5, 1.2, 0.5), Vector3(0.0, 0.2, 0.0), main_color)
				_add_primitive_part(root_holder, SphereMesh.new(), Vector3(0.65, 0.65, 0.65), Vector3(0.0, 0.9, 0.0), accent_color)

			3: # CABINET / COUNTER (Body + Top Shelf + Handles)
				_add_primitive_part(root_holder, BoxMesh.new(), Vector3(1.1, 1.0, 0.6), Vector3(0.0, 0.1, 0.0), main_color)
				_add_primitive_part(root_holder, BoxMesh.new(), Vector3(1.2, 0.1, 0.7), Vector3(0.0, 0.65, 0.0), accent_color)
				_add_primitive_part(root_holder, SphereMesh.new(), Vector3(0.12, 0.12, 0.12), Vector3(-0.25, 0.2, 0.32), Color.GOLD)
				_add_primitive_part(root_holder, SphereMesh.new(), Vector3(0.12, 0.12, 0.12), Vector3(0.25, 0.2, 0.32), Color.GOLD)

	func _add_primitive_part(parent: Node3D, primitive_mesh: Mesh, size: Vector3, local_pos: Vector3, color: Color) -> void:
		var part := MeshInstance3D.new()
		if primitive_mesh is BoxMesh:
			(primitive_mesh as BoxMesh).size = size
		elif primitive_mesh is CylinderMesh:
			(primitive_mesh as CylinderMesh).top_radius = size.x * 0.5
			(primitive_mesh as CylinderMesh).bottom_radius = size.z * 0.5
			(primitive_mesh as CylinderMesh).height = size.y
		elif primitive_mesh is SphereMesh:
			(primitive_mesh as SphereMesh).radius = size.x * 0.5
			(primitive_mesh as SphereMesh).height = size.y

		part.mesh = primitive_mesh
		part.position = local_pos
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		var part_mat := StandardMaterial3D.new()
		part_mat.albedo_color = color
		part_mat.roughness = 0.4
		part.material_override = part_mat
		parent.add_child(part)

	func _physics_process(delta: float) -> void:
		if not is_falling:
			return

		var space_state := get_world_3d().direct_space_state
		if space_state:
			var ray_from := global_position
			var check_dist: float = (fall_speed * delta) + 0.65
			var ray_to := global_position + Vector3.DOWN * check_dist
			var query := PhysicsRayQueryParameters3D.create(ray_from, ray_to)
			query.collision_mask = CollisionUtils.combine_masks([
				CollisionUtils.LayerIndex.GROUND,
				CollisionUtils.LayerIndex.WALL,
				CollisionUtils.LayerIndex.BLOCK
			])
			query.exclude = [get_rid()]

			var hit := space_state.intersect_ray(query)
			if not hit.is_empty():
				is_falling = false # Stop falling & lock in place on Layer 1 Ground!
				var hit_pos: Vector3 = hit.get("position", ray_to)
				global_position = Vector3(
					snappedf(global_position.x, 1.0),
					snappedf(hit_pos.y + 0.6, 1.0),
					snappedf(global_position.z, 1.0)
				)
				return

		global_position.y -= fall_speed * delta

	## INDESTRUCTIBLE DAMAGE RESPONSE (Ignores damage completely!)
	func take_damage(_damage: float = 1.0) -> void:
		print("[IndestructibleFurniture] Ground furniture hit by projectile (Layer 1 GROUND - ignored damage):", global_position)
		Server.spawn_effect("sparks", global_position)
