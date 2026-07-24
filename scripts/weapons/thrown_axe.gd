# ==============================================================================
# THROWN AXE PROJECTILE (Right-Click Attack - Cursor Aimed Straight Throw)
# ==============================================================================
# Composite primitive mesh (Rectangular handle + Eclipse blade head).
# Launches high above player head (2.2m elevation) and flies fast & straight
# towards the exact 3D direction aimed by the player's crosshair cursor.
# ==============================================================================
extends Node3D

# --- CURSOR-AIMED STRAIGHT THROW PARAMETERS ---
@export var throw_speed: float = 38.0   # Fast straight throw velocity (m/s)
@export var drop_gravity: float = 8.0    # Slight natural gravity drop
@export var spin_speed: float = 24.0     # Rotation speed of axe in flight
@export var max_lifetime: float = 4.0    # Maximum seconds before cleanup

var velocity: Vector3 = Vector3.ZERO
var hit_mobs: Array[Node] = []
var time_alive: float = 0.0

@onready var axe_model: Node3D = $AxeModel
@onready var area: Area3D = $Area3D


func _ready() -> void:
	area.body_entered.connect(_on_body_entered)


func setup_direction(throw_dir: Vector3) -> void:
	# Fires straight in the exact direction aimed by crosshair/cursor
	var aim_dir: Vector3 = throw_dir.normalized()
	velocity = aim_dir * throw_speed
	if aim_dir.length() > 0.1:
		look_at(global_position + aim_dir, Vector3.UP)


func _physics_process(delta: float) -> void:
	time_alive += delta
	if time_alive >= max_lifetime:
		queue_free()
		return
		
	# 1. Apply slight gravity drop
	velocity.y -= drop_gravity * delta
	
	# 2. Move projectile position straight forward
	global_position += velocity * delta
	
	# 3. Spin axe visually in flight
	if axe_model:
		axe_model.rotate_x(spin_speed * delta)


func _on_body_entered(body: Node) -> void:
	# Ignore player
	if body == GameManager.get_player() or hit_mobs.has(body):
		return
		
	# Check if body is an enemy
	if body.has_method("take_damage"):
		hit_mobs.append(body)
		print("[ThrownAxe] Straight Cursor-Aimed Axe struck enemy:", body.name)
		body.take_damage(1)
		queue_free()
	elif not body is CharacterBody3D and time_alive > 0.05:
		# Hit terrain or obstacle -> destroy axe
		queue_free()
