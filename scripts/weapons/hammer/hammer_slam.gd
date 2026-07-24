# ==============================================================================
# HAMMER GROUND SLAM SHOCKWAVE (SLOT 4)
# ==============================================================================
# Ground Slam Shockwave AOE Attack:
# - Slams heavy warhammer down into the ground
# - Spawns expanding ring shockwave on ground (6.0m radius AOE)
# - Hits and destroys all mobs in the blast area (1-hit kill)
# ==============================================================================
extends Area3D

@export var max_radius: float = 6.5     # Shockwave AOE max radius
var total_duration: float = 0.35
var timer: float = 0.0

@onready var col_shape: CollisionShape3D = $CollisionShape3D
@onready var shockwave_mesh: MeshInstance3D = $ShockwaveRingMesh


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # Detect enemy layer
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	timer += delta
	if timer >= total_duration:
		queue_free()
		return

	var progress: float = timer / total_duration
	var current_r: float = lerpf(0.5, max_radius, progress)
	
	# Expand collision cylinder radius
	if col_shape and col_shape.shape is CylinderShape3D:
		(col_shape.shape as CylinderShape3D).radius = current_r
		
	# Scale visual shockwave ring
	if shockwave_mesh:
		shockwave_mesh.scale = Vector3(current_r * 0.5, 1.0, current_r * 0.5)
		# Fade opacity/emission
		var mat: StandardMaterial3D = shockwave_mesh.get_surface_override_material(0) as StandardMaterial3D
		if mat:
			mat.albedo_color.a = 1.0 - progress


func _on_body_entered(body: Node3D) -> void:
	if body is EnemyBase:
		print("[HammerSlam] Shockwave obliterated enemy mob:", body.name)
		(body as EnemyBase).take_damage(1)
