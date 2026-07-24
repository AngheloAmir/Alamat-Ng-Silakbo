# ==============================================================================
# SPEAR ATTACK (SLOT 3 - FORWARD BOX STAB)
# ==============================================================================
# Forward box thrust attack:
# - Spawns collision box extending 4.5m in front of player
# - Sweeps spear mesh straight forward along local Z-axis (0.25s duration)
# - Guarantees 100% immediate hit detection on any mob in front of player
# ==============================================================================
extends Area3D

@export var thrust_length: float = 4.5 # Forward reach distance (meters)
var attack_timer: float = 0.0
var total_duration: float = 0.25

@onready var shaft_mesh: MeshInstance3D = $ShaftMesh
@onready var tip_mesh: MeshInstance3D = $SpearTipMesh


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # Detect enemy layer
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	attack_timer += delta
	if attack_timer >= total_duration:
		queue_free()
		return

	# Sine-based forward thrust & retract animation
	var progress: float = attack_timer / total_duration
	var thrust_offset: float = sin(progress * PI) * thrust_length
	
	if shaft_mesh:
		shaft_mesh.position.z = -1.0 - thrust_offset
	if tip_mesh:
		tip_mesh.position.z = -2.2 - thrust_offset


func _on_body_entered(body: Node3D) -> void:
	if body is EnemyBase:
		print("[SpearAttack] Forward Box Thrust struck enemy mob:", body.name)
		(body as EnemyBase).take_damage(1)
