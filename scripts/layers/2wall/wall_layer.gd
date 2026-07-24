# ==============================================================================
# LAYER 2: WALL LAYER (scripts/layers/2wall/wall_layer.gd)
# ==============================================================================
# High-Performance MultiMesh Wall Placement Layer:
# - Renders 5,000+ placed wall structures in 1 SINGLE GPU DRAW CALL via MultiMeshInstance3D.
# - Manages static collision shapes in Layer 2 collision mask.
# ==============================================================================
extends Node3D

const LAYER_ID: int = 2
const MAX_WALLS: int = 5000

var multimesh_instance: MultiMeshInstance3D = null
var static_body: StaticBody3D = null
var placed_wall_transforms: Array[Transform3D] = []


func _ready() -> void:
	Server.register_layer_manager(LAYER_ID, self)
	_setup_multimesh()
	print("[Layer 2] MultiMesh Wall layer initialized. Capacity:", MAX_WALLS)


func _setup_multimesh() -> void:
	multimesh_instance = MultiMeshInstance3D.new()
	multimesh_instance.name = "WallMultiMesh"

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = false
	mm.instance_count = MAX_WALLS
	mm.visible_instance_count = 0

	# Standard Wall Mesh (Box)
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(2.0, 3.0, 0.4)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.48, 0.52)
	mat.roughness = 0.8
	box_mesh.material = mat

	mm.mesh = box_mesh
	multimesh_instance.multimesh = mm
	add_child(multimesh_instance)

	# Single StaticBody3D for physics collisions
	static_body = StaticBody3D.new()
	static_body.name = "WallStaticBody"
	static_body.collision_layer = CollisionUtils.get_layer_bitmask(CollisionUtils.LayerIndex.WALL)
	static_body.collision_mask = 0 # Static environment object
	add_child(static_body)


## API to place a wall with 1 GPU Draw Call performance
func place_wall(position: Vector3, rotation_y_deg: float = 0.0) -> void:
	if placed_wall_transforms.size() >= MAX_WALLS:
		print("[Layer 2] Max wall placement capacity reached!")
		return

	var wall_idx: int = placed_wall_transforms.size()
	var t := Transform3D(Basis(Vector3.UP, deg_to_rad(rotation_y_deg)), position)
	placed_wall_transforms.append(t)

	var mm: MultiMesh = multimesh_instance.multimesh
	mm.set_instance_transform(wall_idx, t)
	mm.visible_instance_count = placed_wall_transforms.size()

	# Add Static Collision Box
	var col_shape := CollisionShape3D.new()
	var box_shape := BoxMesh.new().get_faces() # Or BoxShape3D
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.0, 3.0, 0.4)
	col_shape.shape = shape
	col_shape.transform = t
	static_body.add_child(col_shape)

	print("[Layer 2] Placed wall #%d at %s (Total Draw Calls: 1)" % [wall_idx + 1, position])
