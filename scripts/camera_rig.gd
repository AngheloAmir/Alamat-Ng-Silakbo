# ==============================================================================
# THIRD-PERSON CAMERA RIG
# ==============================================================================
# Controls camera orbit around player using SpringArm3D for collision avoidance.
# Handles mouse cursor capture & ESC key toggling.
# Uses top_level = true to decouple camera orientation from player rotation!
# ==============================================================================
extends SpringArm3D

@export var mouse_sensitivity: float = 0.003  # Mouse orbit sensitivity
@export var min_pitch: float = -75.0          # Maximum look down angle (degrees)
@export var max_pitch: float = 75.0           # Maximum look up angle (degrees)

var target_node: Node3D = null

func _ready() -> void:
	# Decouple camera rotation from parent player rotation to prevent feedback loop
	set_as_top_level(true)
	
	target_node = get_parent() as Node3D
	if target_node:
		add_excluded_object(target_node.get_rid())
		global_position = target_node.global_position + Vector3(0, 1.6, 0)

	# Lock mouse cursor into center for smooth 3D camera orbit
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(_delta: float) -> void:
	# Follow player position without inheriting player rotation
	if target_node and is_instance_valid(target_node):
		global_position = target_node.global_position + Vector3(0, 1.6, 0)


func _unhandled_input(event: InputEvent) -> void:
	# Mouse Motion -> Orbit Camera
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Rotate horizontal yaw (around Y axis)
		rotation.y -= event.relative.x * mouse_sensitivity
		# Rotate vertical pitch (around X axis)
		rotation.x -= event.relative.y * mouse_sensitivity
		# Clamp vertical pitch to prevent camera flipping upside down
		rotation.x = clamp(rotation.x, deg_to_rad(min_pitch), deg_to_rad(max_pitch))
		
	# Toggle Mouse Cursor Lock with ESC key
	if event.is_action_pressed("toggle_mouse"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
