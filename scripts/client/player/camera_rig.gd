# ==============================================================================
# THIRD-PERSON CAMERA RIG (scripts/client/player/camera_rig.gd)
# ==============================================================================
# Controls 3D camera orbit around player using SpringArm3D for collision avoidance.
# ==============================================================================
extends SpringArm3D

@export var mouse_sensitivity: float = 0.003
@export var min_pitch: float = -75.0
@export var max_pitch: float = 75.0

var target_node: Node3D = null


func _ready() -> void:
	set_as_top_level(true)
	target_node = get_parent() as Node3D
	if target_node:
		add_excluded_object(target_node.get_rid())
		global_position = target_node.global_position + Vector3(0, 2.4, 0)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(_delta: float) -> void:
	if target_node and is_instance_valid(target_node):
		global_position = target_node.global_position + Vector3(0, 2.4, 0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * mouse_sensitivity
		rotation.x -= event.relative.y * mouse_sensitivity
		rotation.x = clamp(rotation.x, deg_to_rad(min_pitch), deg_to_rad(max_pitch))

	if event.is_action_pressed("toggle_mouse"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
