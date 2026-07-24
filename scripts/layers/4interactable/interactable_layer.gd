# ==============================================================================
# LAYER 4: INTERACTABLES LAYER (scripts/layers/4interactable/interactable_layer.gd)
# ==============================================================================
# Manages static interactable objects (stoves, crafting stations, chests).
# Features Green-to-Orange proximity interaction trigger when player approaches.
# Registers interactables with Server hub for HUD tracking.
# Collision Layer 4.
# ==============================================================================
extends Node3D

const LAYER_ID: int = 4


func _ready() -> void:
	Server.register_layer_manager(LAYER_ID, self)
	print("[Layer 4] Interactables layer initialized.")


## API: Spawn 50 Green Interactable Cubes near position
func spawn_interactable_batch(count: int, origin: Vector3) -> void:
	print("[Layer 4] Spawning batch of ", count, " interactable green cubes via Key 'V'...")
	for i in range(count):
		var offset := Vector3(
			randf_range(-25.0, 25.0),
			0.5,
			randf_range(-25.0, 25.0)
		)
		if offset.length() < 3.0:
			offset = offset.normalized() * 4.0

		var cube := InteractableCube.new()
		add_child(cube)
		cube.global_position = origin + offset

	print("[Layer 4] Batch interactable cubes spawned successfully.")


# ==============================================================================
# SUB-CLASS: INTERACTABLE CUBE (Green -> Orange proximity change)
# ==============================================================================
class InteractableCube extends Area3D:
	var mesh_inst: MeshInstance3D = null
	var mat: StandardMaterial3D = null
	var is_highlighted: bool = false
	const INTERACT_RADIUS: float = 3.2

	func _ready() -> void:
		collision_layer = CollisionUtils.get_layer_bitmask(CollisionUtils.LayerIndex.INTERACTABLE)
		collision_mask = 0 # Proximity query

		# Box Mesh
		mesh_inst = MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.9, 0.9, 0.9)
		mesh_inst.mesh = box

		# GPU Shadow Optimization
		mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.85, 0.35) # Initial Green
		mat.roughness = 0.5
		mesh_inst.material_override = mat
		add_child(mesh_inst)

		# Collision Shape
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(0.9, 0.9, 0.9)
		col.shape = shape
		add_child(col)

		Server.register_interactable(self)

	func _process(_delta: float) -> void:
		var player: Node3D = Server.get_player()
		if not player or not is_instance_valid(player):
			return

		var dist: float = (player.global_position - global_position).length()
		if dist <= INTERACT_RADIUS and not is_highlighted:
			is_highlighted = true
			mat.albedo_color = Color(1.0, 0.55, 0.0) # Highlight Orange
		elif dist > INTERACT_RADIUS and is_highlighted:
			is_highlighted = false
			mat.albedo_color = Color(0.2, 0.85, 0.35) # Revert Green
