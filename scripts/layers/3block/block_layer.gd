# ==============================================================================
# LAYER 3: BLOCK LAYER (scripts/layers/3block/block_layer.gd)
# ==============================================================================
# Minecraft-Style Falling & Stacking Destructible Building Block Layer:
# - Blocks fall straight down along Y-axis.
# - Lands & stacks neatly on top of terrain, walls, and other blocks on a 1.0m grid.
# - Registers blocks with Server hub for HUD tracking.
# - Responds to projectile damage: triggers Layer 9 particle debris & destroys block.
# ==============================================================================
extends Node3D

const LAYER_ID: int = 3
const MAX_BLOCKS: int = 10000

var multimesh_instance: MultiMeshInstance3D = null
var static_body: StaticBody3D = null
var placed_block_transforms: Array[Transform3D] = []


func _ready() -> void:
	Server.register_layer_manager(LAYER_ID, self)
	_setup_multimesh()
	print("[Layer 3] Destructible Building Block Layer initialized.")


func _setup_multimesh() -> void:
	multimesh_instance = MultiMeshInstance3D.new()
	multimesh_instance.name = "BlockMultiMesh"

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.instance_count = MAX_BLOCKS
	mm.visible_instance_count = 0

	# Standard 1x1x1 Building Cube Mesh
	var cube_mesh := BoxMesh.new()
	cube_mesh.size = Vector3(1.0, 1.0, 1.0)

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.6
	cube_mesh.material = mat

	mm.mesh = cube_mesh
	multimesh_instance.multimesh = mm
	add_child(multimesh_instance)

	# StaticBody3D container for static collisions
	static_body = StaticBody3D.new()
	static_body.name = "BlockStaticBody"
	static_body.collision_layer = CollisionUtils.get_layer_bitmask(CollisionUtils.LayerIndex.BLOCK)
	static_body.collision_mask = 0
	add_child(static_body)


## API: Place 1x1x1 building block
func place_block(target_pos: Vector3, color_tint: Color = Color(0.8, 0.55, 0.3)) -> void:
	var snapped_pos := Vector3(
		snappedf(target_pos.x, 1.0),
		target_pos.y,
		snappedf(target_pos.z, 1.0)
	)
	spawn_falling_destructible_block(snapped_pos, color_tint)


## API: Spawn Grid Stacking Falling Block (Key C)
func spawn_falling_destructible_block(spawn_pos: Vector3, color_tint: Color = Color(0.2, 0.5, 0.95)) -> void:
	var block_body := DestructiblePhysicsBlock.new()
	add_child(block_body)
	block_body.setup_block(spawn_pos, color_tint)


# ==============================================================================
# SUB-CLASS: MINECRAFT-STYLE GRID STACKING BLOCK (Destructible)
# ==============================================================================
class DestructiblePhysicsBlock extends StaticBody3D:
	var mesh_inst: MeshInstance3D = null
	var mat: StandardMaterial3D = null
	var is_falling: bool = true
	var fall_speed: float = 16.0
	var is_destroyed: bool = false

	func setup_block(start_pos: Vector3, color_tint: Color) -> void:
		global_position = start_pos

		collision_layer = CollisionUtils.get_layer_bitmask(CollisionUtils.LayerIndex.BLOCK)
		collision_mask = CollisionUtils.combine_masks([
			CollisionUtils.LayerIndex.GROUND,
			CollisionUtils.LayerIndex.WALL,
			CollisionUtils.LayerIndex.BLOCK
		])

		# 1x1x1 Cube Visual Mesh
		mesh_inst = MeshInstance3D.new()
		var cube := BoxMesh.new()
		cube.size = Vector3(1.0, 1.0, 1.0)
		mesh_inst.mesh = cube

		# GPU Shadow Optimization: Disable per-cube shadow map draw calls for 120+ FPS
		mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		mat = StandardMaterial3D.new()
		mat.albedo_color = color_tint
		mat.roughness = 0.4
		mesh_inst.material_override = mat
		add_child(mesh_inst)

		# Collision Shape
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.0, 1.0, 1.0)
		col.shape = shape
		add_child(col)

		Server.register_block(self)

	func _physics_process(delta: float) -> void:
		if not is_falling or is_destroyed:
			return

		# Raycast down to detect ground, wall, or another block below
		var space_state := get_world_3d().direct_space_state
		if space_state:
			var ray_from := global_position
			var check_dist: float = (fall_speed * delta) + 0.55
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
				is_falling = false # Stop falling & stack!
				var hit_pos: Vector3 = hit.get("position", ray_to)
				global_position = Vector3(
					snappedf(global_position.x, 1.0),
					snappedf(hit_pos.y + 0.5, 1.0),
					snappedf(global_position.z, 1.0)
				)
				return

		global_position.y -= fall_speed * delta

	## Destructible Environment Damage Response (Hit by Arrow / Fireball / Slash / Bolt)
	func take_damage(_damage: float = 1.0) -> void:
		if is_destroyed:
			return
		is_destroyed = true
		Server.unregister_block(self)
		print("[DestructibleBlock] Block destroyed by projectile at:", global_position)
		Server.spawn_effect("block_explosion", global_position)
		queue_free()
