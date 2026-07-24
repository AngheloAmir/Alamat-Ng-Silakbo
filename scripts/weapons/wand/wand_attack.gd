# ==============================================================================
# WAND ZIGZAG LIGHTNING BEAM STRIKE (Slot 8 Attack)
# ==============================================================================
# Jagged 3D electric zigzag lightning bolt connecting player wand to targeted area:
# - Unaffected by gravity (100% instant beam strike).
# - 7 connected jittering electric segments forming a sharp zigzag lightning arc.
# - High-frequency crackle jittering, electric cyan emission & OmniLight3D flash.
# ==============================================================================
extends Node3D

@export var beam_lifetime: float = 0.18 # Duration of lightning crackle flash (seconds)

var time_alive: float = 0.0
var control_points: Array[Vector3] = []
var segment_nodes: Array[MeshInstance3D] = []
var base_positions: Array[Vector3] = []
var start_p: Vector3 = Vector3.ZERO
var target_p: Vector3 = Vector3.ZERO

@onready var light: OmniLight3D = $OmniLight3D


func setup_beam(start_pos: Vector3, target_pos: Vector3) -> void:
	start_p = start_pos
	target_p = target_pos
	global_position = start_pos
	
	var dir: Vector3 = (target_pos - start_pos)
	var dist: float = dir.length()
	var forward_dir: Vector3 = dir.normalized() if dist > 0.05 else Vector3.FORWARD
	
	# Calculate 2 perpendicular vectors for 3D zigzag offsets
	var up_vec: Vector3 = Vector3.UP if abs(forward_dir.y) < 0.9 else Vector3.RIGHT
	var right_vec: Vector3 = forward_dir.cross(up_vec).normalized()
	var perp_up: Vector3 = right_vec.cross(forward_dir).normalized()

	# Create 8 control points for 7 zigzag segments
	var num_segments: int = 7
	control_points.clear()
	base_positions.clear()
	
	for i in range(num_segments + 1):
		var t: float = float(i) / float(num_segments)
		var base_pos: Vector3 = start_pos.lerp(target_pos, t)
		base_positions.append(base_pos)
		
		if i == 0 or i == num_segments:
			control_points.append(base_pos)
		else:
			var offset_r: float = randf_range(-0.45, 0.45)
			var offset_u: float = randf_range(-0.45, 0.45)
			var point: Vector3 = base_pos + (right_vec * offset_r) + (perp_up * offset_u)
			control_points.append(point)

	# Shared electric cyan glowing material
	var seg_mat: StandardMaterial3D = StandardMaterial3D.new()
	seg_mat.albedo_color = Color(0.25, 0.85, 1.0)
	seg_mat.emission_enabled = true
	seg_mat.emission = Color(0.35, 0.95, 1.0)
	seg_mat.emission_energy_multiplier = 6.0

	var seg_mesh: BoxMesh = BoxMesh.new()
	seg_mesh.size = Vector3(0.18, 0.18, 1.0)

	# Build segment mesh instances
	for i in range(num_segments):
		var seg: MeshInstance3D = MeshInstance3D.new()
		seg.mesh = seg_mesh
		seg.material_override = seg_mat
		add_child(seg)
		segment_nodes.append(seg)

	_update_segment_transforms(right_vec, perp_up)

	if light:
		light.position = target_pos - start_pos
		light.light_energy = 9.0
		light.omni_range = 12.0

	# Perform immediate 3D raycast & shape sweep along lightning path to damage enemies
	_perform_lightning_damage_sweep(start_pos, target_pos)


func _update_segment_transforms(_right_v: Vector3, _up_v: Vector3) -> void:
	for i in range(segment_nodes.size()):
		var p_from: Vector3 = control_points[i]
		var p_to: Vector3 = control_points[i + 1]
		var seg_dir: Vector3 = (p_to - p_from)
		var seg_len: float = seg_dir.length()
		var seg_node: MeshInstance3D = segment_nodes[i]
		
		seg_node.global_position = (p_from + p_to) * 0.5
		if seg_len > 0.01:
			seg_node.look_at(p_to, Vector3.UP if abs(seg_dir.normalized().y) < 0.9 else Vector3.RIGHT)
			seg_node.scale = Vector3(1.0, 1.0, seg_len)


func _perform_lightning_damage_sweep(from_p: Vector3, to_p: Vector3) -> void:
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if not space_state:
		return
		
	var shape_query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	var ray_shape: BoxShape3D = BoxShape3D.new()
	var length: float = from_p.distance_to(to_p)
	ray_shape.size = Vector3(1.4, 1.4, length)
	shape_query.shape = ray_shape
	
	var mid_point: Vector3 = (from_p + to_p) * 0.5
	var b: Basis = Basis()
	var forward_dir: Vector3 = (to_p - from_p).normalized()
	if forward_dir.length() > 0.1:
		b = Transform3D().looking_at(forward_dir, Vector3.UP).basis
	shape_query.transform = Transform3D(b, mid_point)
	shape_query.collision_mask = 2 # Enemies
	
	var player: Node3D = GameManager.get_player()
	var results: Array[Dictionary] = space_state.intersect_shape(shape_query)
	var hit_mobs: Array[Node] = []
	
	for res in results:
		var collider: Object = res.get("collider")
		if collider and collider != player and collider.has_method("take_damage"):
			var mob: Node = collider as Node
			if not hit_mobs.has(mob):
				hit_mobs.append(mob)
				print("[WandZigzagLightning] Instant lightning beam struck enemy:", mob.name)
				mob.call("take_damage", 1)


func _process(delta: float) -> void:
	time_alive += delta
	if time_alive >= beam_lifetime:
		queue_free()
		return

	var alpha: float = 1.0 - (time_alive / beam_lifetime)
	if light:
		light.light_energy = (9.0 * alpha) + randf_range(-1.5, 1.5)
	
	# Rapid electric crackle jittering of control points
	var dir: Vector3 = (target_p - start_p).normalized()
	var up_v: Vector3 = Vector3.UP if abs(dir.y) < 0.9 else Vector3.RIGHT
	var right_v: Vector3 = dir.cross(up_v).normalized()
	var perp_u: Vector3 = right_v.cross(dir).normalized()

	for i in range(1, control_points.size() - 1):
		var base_p: Vector3 = base_positions[i]
		control_points[i] = base_p + (right_v * randf_range(-0.55, 0.55)) + (perp_u * randf_range(-0.55, 0.55))

	_update_segment_transforms(right_v, perp_u)

	for seg in segment_nodes:
		if is_instance_valid(seg):
			seg.scale.x = (1.0 + randf_range(-0.3, 0.3)) * alpha
			seg.scale.y = (1.0 + randf_range(-0.3, 0.3)) * alpha
