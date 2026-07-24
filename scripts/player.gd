# ==============================================================================
# THIRD-PERSON PLAYER CONTROLLER (FPS BOW AIM & CAMERA FIX)
# ==============================================================================
# Controls player character (Capsule Mesh):
# - 3X Fly Speed (72.0 m/s) toggled via Key E
# - 4 Switchable Weapons (Slot 1: Sword, Slot 2: Bow, Slot 3: Spear, Slot 4: Hammer)
# - First-Person (FPS) Bow Aiming: Lerps camera.position to eye level (-0.4m),
#   hides player body mesh, and renders Held Arrow on the right side of the screen!
# - Fixed Spear Forward Box Sweep attached to weapon mount
# - Straight Cursor-Aimed Thrown Axe (Right Click) starting high above head (2.2m)
# ==============================================================================
extends CharacterBody3D

signal weapon_slot_changed(slot_idx: int)

@export var move_speed: float = 9.0         # Player movement speed (m/s)
@export var fly_speed: float = 72.0         # 3X Fly mode speed (72.0 m/s)
@export var jump_velocity: float = 12.0      # Standard jump velocity
@export var high_jump_velocity: float = 32.0 # Key Q Super High Jump velocity
@export var rotation_speed: float = 15.0    # Speed of turning towards movement direction

# Realistic Physics & Gravity settings
@export var gravity: float = 32.0           # Realistic gravity (m/s^2)
@export var fall_multiplier: float = 1.6    # Snappy descent multiplier when falling

var is_flying: bool = false                 # Toggle Fly Mode state

# Weapon System Enum & Selection
enum WeaponType { SWORD = 0, BOW = 1, SPEAR = 2, HAMMER = 3 }
var current_weapon: WeaponType = WeaponType.SWORD

# Bow Aiming & Attack Cooldown State
var is_charging_bow: bool = false
var bow_charge_time: float = 0.0
var attack_cooldown: float = 0.0

# Weapon scenes loaded dynamically at runtime
var sword_scene: PackedScene
var bow_scene: PackedScene
var spear_scene: PackedScene
var hammer_scene: PackedScene
var axe_scene: PackedScene

# Enemy scenes for Key 'R' manual spawning
var static_scene: PackedScene
var wander_scene: PackedScene
var chase_scene: PackedScene

@onready var capsule_mesh: MeshInstance3D = $CapsuleMesh
@onready var camera_rig: SpringArm3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var weapon_mount: Node3D = $WeaponMount
@onready var held_arrow: Node3D = $CameraRig/Camera3D/HeldArrow


func _ready() -> void:
	sword_scene = load("res://scenes/weapons/sword/sword_attack.tscn")
	bow_scene = load("res://scenes/weapons/bow/arrow_projectile.tscn")
	spear_scene = load("res://scenes/weapons/spear/spear_attack.tscn")
	hammer_scene = load("res://scenes/weapons/hammer/hammer_slam.tscn")
	axe_scene = load("res://scenes/thrown_axe.tscn")

	static_scene = load("res://scenes/enemy_static.tscn")
	wander_scene = load("res://scenes/enemy_wander.tscn")
	chase_scene = load("res://scenes/enemy_chase.tscn")

	# Register self with GameManager singleton safely
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("register_player"):
		gm.call("register_player", self)

	emit_signal("weapon_slot_changed", int(current_weapon))


func _unhandled_input(event: InputEvent) -> void:
	# Key 'E' -> Toggle Fly Mode ON / OFF
	if event.is_action_pressed("toggle_fly"):
		is_flying = !is_flying
		velocity = Vector3.ZERO
		print("[Player] Fly Mode Toggled:", "ON" if is_flying else "OFF")

	# Key 'R' -> Manually spawn a random-trait mob at player position (Unlimited)
	elif event.is_action_pressed("spawn_mob_manual"):
		_spawn_manual_random_mob()

	# Weapon Slot Hotkey Selection (Keys 1, 2, 3, 4)
	elif event.is_action_pressed("weapon_1"):
		_select_weapon_slot(WeaponType.SWORD)
	elif event.is_action_pressed("weapon_2"):
		_select_weapon_slot(WeaponType.BOW)
	elif event.is_action_pressed("weapon_3"):
		_select_weapon_slot(WeaponType.SPEAR)
	elif event.is_action_pressed("weapon_4"):
		_select_weapon_slot(WeaponType.HAMMER)

	# Mouse Wheel Weapon Slot Scrolling
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			var prev_slot: int = (int(current_weapon) - 1 + 4) % 4
			_select_weapon_slot(prev_slot as WeaponType)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var next_slot: int = (int(current_weapon) + 1) % 4
			_select_weapon_slot(next_slot as WeaponType)


func _select_weapon_slot(slot: WeaponType) -> void:
	if current_weapon != slot:
		if is_charging_bow:
			_reset_bow_aim()
		current_weapon = slot
		print("[Player] Weapon Switched to Slot:", current_weapon)
		emit_signal("weapon_slot_changed", int(current_weapon))


func _reset_bow_aim() -> void:
	is_charging_bow = false
	bow_charge_time = 0.0
	if held_arrow:
		held_arrow.visible = false
	if capsule_mesh:
		capsule_mesh.visible = true


func _physics_process(delta: float) -> void:
	# Update attack cooldowns
	if attack_cooldown > 0.0:
		attack_cooldown -= delta

	# --- FPS BOW AIMING & HOLDING ARROW ON RIGHT SIDE ---
	if current_weapon == WeaponType.BOW:
		if Input.is_action_pressed("attack_slash"):
			is_charging_bow = true
			bow_charge_time = minf(bow_charge_time + delta, 1.2)
			
			# Hide player capsule body mesh so it doesn't block FPS vision
			if capsule_mesh:
				capsule_mesh.visible = false
				
			# Show Held Arrow on right side of FPS view
			if held_arrow:
				held_arrow.visible = true
				var pull_back: float = (bow_charge_time / 1.2) * 0.15
				held_arrow.position = Vector3(0.38, -0.22, -0.65 + pull_back)

			# Lerp camera position from 4.0m 3rd-person offset to -0.4m FPS eye-level position
			camera.position = camera.position.lerp(Vector3(0.0, 0.1, -0.4), delta * 18.0)

		elif Input.is_action_just_released("attack_slash") and is_charging_bow:
			_perform_bow_attack_charged(bow_charge_time)
			_reset_bow_aim()

	if not is_charging_bow:
		if held_arrow and held_arrow.visible:
			held_arrow.visible = false
		if capsule_mesh and not capsule_mesh.visible:
			capsule_mesh.visible = true
		# Return camera position smoothly to standard 3rd person 4.0m offset
		camera.position = camera.position.lerp(Vector3(0.0, 0.0, 4.0), delta * 8.0)

	# --- FLY MODE CONTROLS (TOGGLED VIA KEY 'E' - 72 m/s) ---
	if is_flying:
		var fly_move: Vector3 = Vector3.ZERO
		var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		
		if input_dir.length() > 0.1:
			var cam_basis: Basis = camera.global_transform.basis
			fly_move = (cam_basis.x * input_dir.x + cam_basis.z * input_dir.y).normalized()
			
		if Input.is_action_pressed("jump"):
			fly_move.y += 1.0
		elif Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_CTRL):
			fly_move.y -= 1.0
			
		velocity = fly_move.normalized() * fly_speed
		move_and_slide()
		
		if attack_cooldown <= 0.0 and current_weapon != WeaponType.BOW:
			if Input.is_action_just_pressed("attack_slash"):
				_perform_active_weapon_attack()
			elif Input.is_action_just_pressed("attack_axe"):
				_perform_axe_attack()
		return

	# --- GROUNDED & JUMP PHYSICS ---
	if not is_on_floor():
		if velocity.y < 0.0:
			velocity.y -= gravity * fall_multiplier * delta
		else:
			velocity.y -= gravity * delta

	if is_on_floor():
		if Input.is_action_just_pressed("high_jump"):
			velocity.y = high_jump_velocity
			print("[Player] Executing Key 'Q' Super High Jump!")
		elif Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity

	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var cam_y_rot: float = camera_rig.rotation.y
	var raw_dir: Vector3 = Vector3(input_dir.x, 0.0, input_dir.y)
	
	if raw_dir.length() > 0.1:
		var move_dir: Vector3 = raw_dir.rotated(Vector3.UP, cam_y_rot).normalized()
		velocity.x = move_dir.x * move_speed
		velocity.z = move_dir.z * move_speed
		
		var target_angle: float = atan2(-move_dir.x, -move_dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle, rotation_speed * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed)
		velocity.z = move_toward(velocity.z, 0, move_speed)

	move_and_slide()

	# Handle Non-Bow Attacks & Secondary Axe Attack
	if attack_cooldown <= 0.0:
		if current_weapon != WeaponType.BOW and Input.is_action_just_pressed("attack_slash"):
			_perform_active_weapon_attack()
		elif Input.is_action_just_pressed("attack_axe"):
			_perform_axe_attack()


# --- WEAPON ATTACK EXECUTION ---
func _perform_active_weapon_attack() -> void:
	match current_weapon:
		WeaponType.SWORD:
			_perform_sword_attack()
		WeaponType.BOW:
			pass # Handled via hold/release mechanics
		WeaponType.SPEAR:
			_perform_spear_attack()
		WeaponType.HAMMER:
			_perform_hammer_attack()


func _perform_sword_attack() -> void:
	if not sword_scene:
		return
	attack_cooldown = 0.3
	print("[Player] Executing Slot 1: Sword Slash!")
	var slash_inst: Node3D = sword_scene.instantiate() as Node3D
	weapon_mount.add_child(slash_inst)


func _perform_bow_attack_charged(charge_time: float) -> void:
	if not bow_scene:
		return
	attack_cooldown = 0.35
	var charge_ratio: float = clampf(charge_time / 1.2, 0.3, 1.0)
	var launch_speed: float = lerpf(25.0, 55.0, charge_ratio)
	print("[Player] Released Charged Bow Arrow! Power:", charge_ratio, "Speed:", launch_speed)

	var arrow_inst: Node3D = bow_scene.instantiate() as Node3D
	get_parent().add_child(arrow_inst)
	arrow_inst.global_position = camera.global_position + -camera.global_transform.basis.z * 0.8
	var shoot_dir: Vector3 = -camera.global_transform.basis.z
	if arrow_inst.has_method("setup_direction"):
		arrow_inst.call("setup_direction", shoot_dir)
		if "launch_speed" in arrow_inst:
			arrow_inst.set("launch_speed", launch_speed)


func _perform_spear_attack() -> void:
	if not spear_scene:
		return
	attack_cooldown = 0.35
	print("[Player] Executing Slot 3: Spear Forward Box Thrust!")
	var spear_inst: Node3D = spear_scene.instantiate() as Node3D
	weapon_mount.add_child(spear_inst)


func _perform_hammer_attack() -> void:
	if not hammer_scene:
		return
	attack_cooldown = 0.6
	print("[Player] Executing Slot 4: Hammer Ground Slam Shockwave!")
	var hammer_inst: Node3D = hammer_scene.instantiate() as Node3D
	get_parent().add_child(hammer_inst)
	hammer_inst.global_position = global_position + Vector3(0.0, 0.05, 0.0)


func _perform_axe_attack() -> void:
	if not axe_scene:
		return
	attack_cooldown = 0.45
	print("[Player] Executing Right-Click Straight Cursor-Aimed Thrown Axe from 2.2m height!")
	var axe_inst: Node3D = axe_scene.instantiate() as Node3D
	get_parent().add_child(axe_inst)
	axe_inst.global_position = global_position + Vector3.UP * 2.2 + transform.basis.z * -0.5
	var throw_dir: Vector3 = -camera.global_transform.basis.z
	if axe_inst.has_method("setup_direction"):
		axe_inst.call("setup_direction", throw_dir)


func _spawn_manual_random_mob() -> void:
	var enemy_types: Array[PackedScene] = [static_scene, wander_scene, chase_scene]
	var valid_types: Array[PackedScene] = []
	for t in enemy_types:
		if t != null:
			valid_types.append(t)
	if valid_types.size() == 0:
		return
	var chosen_scene: PackedScene = valid_types[randi() % valid_types.size()]
	var mob_inst: Node3D = chosen_scene.instantiate() as Node3D
	get_parent().add_child(mob_inst)
	mob_inst.global_position = global_position + (transform.basis.z * -2.2) + Vector3.UP * 0.2
	print("[Player] Manually spawned random mob via Key 'R' at:", mob_inst.global_position)
