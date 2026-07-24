# ==============================================================================
# LAYER 6: MOB MANAGER (scripts/layers/6mobs/mob_manager.gd)
# ==============================================================================
# Layer 6 Mob Execution & MultiMesh Batching Manager.
# 1. Registers as Layer 6 with Server hub.
# 2. Receives decision action queues computed by Layer 12 (`12botdecision`).
# 3. Features MultiMesh Batch Renderer for high-density mobs (1,000+ mobs in 1 Draw Call).
# ==============================================================================
extends Node3D

const LAYER_ID: int = 6
const MAX_MULTIMESH_MOBS: int = 2000

var multimesh_instance: MultiMeshInstance3D = null
var active_multimesh_mobs: Array[Dictionary] = []


func _ready() -> void:
	Server.register_layer_manager(LAYER_ID, self)
	_setup_mob_multimesh()
	print("[Layer 6] Mob Manager execution & MultiMesh layer initialized.")


func _setup_mob_multimesh() -> void:
	multimesh_instance = MultiMeshInstance3D.new()
	multimesh_instance.name = "MobMultiMesh"

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.instance_count = MAX_MULTIMESH_MOBS
	mm.visible_instance_count = 0

	# Capsule mesh matching mob visual shape
	var cap_mesh := CapsuleMesh.new()
	cap_mesh.radius = 0.4
	cap_mesh.height = 1.6

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.5
	cap_mesh.material = mat

	mm.mesh = cap_mesh
	multimesh_instance.multimesh = mm
	add_child(multimesh_instance)


## Called by Layer 12 to pass computed AI decision queues to target mob
func receive_mob_action_queue(mob: Node3D, decision: Dictionary) -> void:
	if mob and is_instance_valid(mob) and mob.has_method("apply_queued_action"):
		mob.call("apply_queued_action", decision)


## High-Performance MultiMesh Mob Batch Update
func update_multimesh_mob_batch(mobs_data: Array[Dictionary]) -> void:
	if not multimesh_instance or not multimesh_instance.multimesh:
		return

	var count: int = min(mobs_data.size(), MAX_MULTIMESH_MOBS)
	var mm: MultiMesh = multimesh_instance.multimesh

	for i in range(count):
		var data: Dictionary = mobs_data[i]
		var pos: Vector3 = data.get("position", Vector3.ZERO)
		var rot_y: float = data.get("rotation_y", 0.0)
		var color: Color = data.get("color", Color(0.9, 0.25, 0.25))

		var t := Transform3D(Basis(Vector3.UP, rot_y), pos)
		mm.set_instance_transform(i, t)
		mm.set_instance_color(i, color)

	mm.visible_instance_count = count
