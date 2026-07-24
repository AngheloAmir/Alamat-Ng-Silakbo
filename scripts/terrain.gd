# ==============================================================================
# OPEN WORLD TERRAIN, MULTI-BIOME SHADING & LOD GENERATOR (SMOOTH MOUNTAINS)
# ==============================================================================
# 1. 8X Map Size (1400m x 1400m) for immense open-world scale.
# 2. Smooth Rounded Alpine Mountains (650m height, smooth bell curve - ZERO spiky needles).
# 3. Multi-Biome Height Shading: Snow (peaks >220m), Dirt/Rock (slopes), Grass (valleys).
# 4. Object LOD & Distance Culling for trees and rocks beyond 350m.
# ==============================================================================
extends Node3D

@export var terrain_size: Vector2 = Vector2(1400.0, 1400.0) # 8X Map dimensions (meters)
@export var grid_subdivisions: int = 220                     # High mesh resolution for vast map
@export var mountain_height: float = 650.0                   # 650m Smooth Alpine Mountain Height
@export var tree_count: int = 250                            # Tree props count across 8x map
@export var rock_count: int = 180                            # Rock props count across 8x map


func _ready() -> void:
	_generate_mountain_terrain()
	_create_raised_test_platforms()
	_scatter_environment_props()


func _generate_mountain_terrain() -> void:
	# 1. Setup Noise Generator for Smooth Wide Rounded Alpine Mountain Ranges
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.0018 # Wide smooth mountain ridges (no sharp spikes!)
	noise.fractal_octaves = 4
	
	# 2. Create Plane Mesh with vertex resolution
	var plane_mesh: PlaneMesh = PlaneMesh.new()
	plane_mesh.size = terrain_size
	plane_mesh.subdivide_width = grid_subdivisions
	plane_mesh.subdivide_depth = grid_subdivisions
	
	# Extract mesh vertex data to deform Y height (heightmap generation)
	var st: SurfaceTool = SurfaceTool.new()
	st.create_from(plane_mesh, 0)
	var array_mesh: ArrayMesh = st.commit()
	var mdt: MeshDataTool = MeshDataTool.new()
	mdt.create_from_surface(array_mesh, 0)
	
	var half_size_x: float = terrain_size.x * 0.5
	
	# Pass 1: Heightmap Deformation (650m Smooth Rounded Alpine Domes)
	for i in range(mdt.get_vertex_count()):
		var v: Vector3 = mdt.get_vertex(i)
		var dist_from_center: float = Vector2(v.x, v.z).length()
		
		# Keep spawn center (radius < 20m) flat for clean gameplay start
		if dist_from_center < 20.0:
			v.y = 0.0
		else:
			# Base rolling hill height (wide, smooth waves)
			var base_h: float = noise.get_noise_2d(v.x, v.z) * 40.0
			
			# Edge mountain multiplier (smooth gradual slope elevation towards borders)
			var border_factor: float = clampf((dist_from_center - 20.0) / (half_size_x - 20.0), 0.0, 1.0)
			border_factor = pow(border_factor, 1.2) # Smooth wide mountain body
			
			# Smooth power curve instead of sharp abs() to eliminate all spiky needles!
			var raw_n: float = noise.get_noise_2d(v.x * 0.8, v.z * 0.8)
			var smooth_mountain: float = pow((raw_n * 0.5 + 0.5), 2.2) * mountain_height
			
			v.y = base_h + (smooth_mountain * border_factor)
			
		mdt.set_vertex(i, v)
	
	# Rebuild deformed mesh to calculate vertex normals for slope & biome shading
	array_mesh.clear_surfaces()
	mdt.commit_to_surface(array_mesh)
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.create_from(array_mesh, 0)
	st.generate_normals()
	var temp_mesh: ArrayMesh = st.commit()
	
	mdt.clear()
	mdt.create_from_surface(temp_mesh, 0)
	
	# Pass 2: Multi-Biome Color Assignment per Vertex (Grass, Dirt/Rock, Snow)
	var grass_color: Color = Color(0.22, 0.52, 0.24)     # Valleys: Lush Emerald Green
	var dirt_rock_color: Color = Color(0.46, 0.38, 0.30) # Slopes: Earthy Dirt & Granite Rock
	var snow_color: Color = Color(0.92, 0.95, 1.0)        # Alpine Peaks (>220m): Pure White Snow
	
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	for i in range(mdt.get_face_count()):
		for j in range(3):
			var vertex_idx: int = mdt.get_face_vertex(i, j)
			var v: Vector3 = mdt.get_vertex(vertex_idx)
			var normal: Vector3 = mdt.get_vertex_normal(vertex_idx)
			
			# Multi-Biome Blending Logic based on Height (Y) and Slope (Normal.Y)
			var final_color: Color = grass_color
			var height: float = v.y
			var slope_flatness: float = normal.y # 1.0 is flat horizontal, <0.75 is slope
			
			if height > 220.0:
				# Towering Alpine Mountain Peaks (>220m) -> Snow
				var snow_blend: float = clampf((height - 220.0) / 120.0, 0.0, 1.0)
				final_color = dirt_rock_color.lerp(snow_color, snow_blend)
			elif height > 45.0 or slope_flatness < 0.78:
				# Mountain Slopes & Foothills -> Dirt / Rock
				var dirt_blend: float = clampf((height - 45.0) / 80.0, 0.0, 1.0)
				if slope_flatness < 0.78:
					dirt_blend = maxf(dirt_blend, 1.0 - slope_flatness)
				final_color = grass_color.lerp(dirt_rock_color, dirt_blend)
			else:
				# Flat Valleys & Lowlands -> Lush Grass
				final_color = grass_color
				
			st.set_color(final_color)
			st.set_normal(normal)
			st.set_uv(Vector2(v.x * 0.02, v.z * 0.02))
			st.add_vertex(v)
			
	var final_terrain_mesh: ArrayMesh = st.commit()
	
	# 3. Build Procedural Terrain Material with Triplanar Noise
	var noise_tex: NoiseTexture2D = NoiseTexture2D.new()
	noise_tex.noise = noise
	noise_tex.seamless = true
	
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true # Enable Grass/Dirt/Snow vertex color blending!
	mat.albedo_texture = noise_tex
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.04, 0.04, 0.04)
	mat.roughness = 0.85
	
	# Create Mesh Instance
	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	mesh_inst.name = "TerrainMesh"
	mesh_inst.mesh = final_terrain_mesh
	mesh_inst.material_override = mat
	add_child(mesh_inst)
	
	# 4. Generate Physics Trimesh Collision (Smooth Walkable Slope Geometry)
	var static_body: StaticBody3D = StaticBody3D.new()
	static_body.name = "TerrainCollision"
	
	var col_shape: CollisionShape3D = CollisionShape3D.new()
	col_shape.shape = final_terrain_mesh.create_trimesh_shape()
	static_body.add_child(col_shape)
	add_child(static_body)


func _create_raised_test_platforms() -> void:
	var platform_container: Node3D = Node3D.new()
	platform_container.name = "RaisedTestPlatforms"
	add_child(platform_container)
	
	# Platform 1: Low Raised Terrace (Y = 2.5m)
	_build_box_platform(platform_container, Vector3(25.0, 1.25, -22.0), Vector3(16.0, 2.5, 16.0), Color(0.55, 0.52, 0.48))
	_build_ramp(platform_container, Vector3(25.0, 1.25, -11.0), Vector3(5.0, 0.2, 11.0), deg_to_rad(18.0), Color(0.5, 0.48, 0.45))
	
	# Platform 2: High Raised Fortress Floor (Y = 5.0m)
	_build_box_platform(platform_container, Vector3(-32.0, 2.5, -32.0), Vector3(20.0, 5.0, 20.0), Color(0.48, 0.45, 0.42))
	_build_ramp(platform_container, Vector3(-32.0, 2.5, -18.0), Vector3(6.0, 0.2, 14.0), deg_to_rad(22.0), Color(0.45, 0.42, 0.40))


func _build_box_platform(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = pos
	
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
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = size
	col.shape = box_shape
	body.add_child(col)
	
	parent.add_child(body)


func _build_ramp(parent: Node3D, pos: Vector3, size: Vector3, angle_rad: float, color: Color) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = pos
	body.rotation.x = angle_rad
	
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
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = size
	col.shape = box_shape
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
	
	# --- LOD & DISTANCE CULLING (Cull beyond 350m) ---
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
	
	# --- LOD & DISTANCE CULLING ---
	leaves.visibility_range_end = 350.0
	leaves.visibility_range_end_margin = 40.0
	leaves.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	tree_node.add_child(leaves)
	
	var col_body: StaticBody3D = StaticBody3D.new()
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
	
	# --- LOD & DISTANCE CULLING ---
	mesh_inst.visibility_range_end = 350.0
	mesh_inst.visibility_range_end_margin = 40.0
	mesh_inst.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	rock_node.add_child(mesh_inst)
	
	var col_body: StaticBody3D = StaticBody3D.new()
	var col_shape: CollisionShape3D = CollisionShape3D.new()
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = Vector3(size_x * 2.0, size_y * 2.0, size_z * 2.0)
	col_shape.shape = box_shape
	col_shape.position.y = size_y * 0.5
	col_body.add_child(col_shape)
	rock_node.add_child(col_body)
	
	return rock_node
