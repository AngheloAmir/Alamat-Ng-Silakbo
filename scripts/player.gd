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
enum WeaponType { SWORD = 0, BOW = 1, SPEAR = 2, HAMMER = 3, DAGGER = 4, AXE_1H = 5, CROSSBOW = 6, WAND = 7 }
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

@onready var camera_rig: SpringArm3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var weapon_mount: Node3D = $WeaponMount
@onready var offhand_mount: Node3D = get_node_or_null("OffhandMount")
@onready var held_arrow: Node3D = $CameraRig/Camera3D/HeldArrow

var character_model: Node3D = null
var anim_player: AnimationPlayer = null

# 3D Visual Held Prop Models loaded from res://assets/kaykit/props/
var prop_models: Dictionary = {}
var active_prop: Node3D = null
var shield_prop: Node3D = null

var default_mount_rot: Vector3 = Vector3(-15, 20, 15)
var default_mount_pos: Vector3 = Vector3(0.35, 0.75, -0.25)
var active_swing_tween: Tween = null


func _ready() -> void:
	sword_scene = load("res://scenes/weapons/sword/sword_attack.tscn")
	bow_scene = load("res://scenes/weapons/bow/arrow_projectile.tscn")
	spear_scene = load("res://scenes/weapons/spear/spear_attack.tscn")
	hammer_scene = load("res://scenes/weapons/hammer/hammer_slam.tscn")
	axe_scene = load("res://scenes/thrown_axe.tscn")

	static_scene = load("res://scenes/enemy_static.tscn")
	wander_scene = load("res://scenes/enemy_wander.tscn")
	chase_scene = load("res://scenes/enemy_chase.tscn")

	# Preload All KayKit 3D Prop Scenes
	var sword_prop_scene: PackedScene = load("res://assets/kaykit/props/sword_2handed.gltf") as PackedScene
	var bow_prop_scene: PackedScene = load("res://assets/kaykit/props/bow_withString.gltf") as PackedScene
	var spear_prop_scene: PackedScene = load("res://assets/kaykit/props/staff.gltf") as PackedScene
	var hammer_prop_scene: PackedScene = load("res://assets/kaykit/props/axe_2handed.gltf") as PackedScene
	var dagger_prop_scene: PackedScene = load("res://assets/kaykit/props/dagger.gltf") as PackedScene
	var axe1h_prop_scene: PackedScene = load("res://assets/kaykit/props/axe_1handed.gltf") as PackedScene
	var crossbow_prop_scene: PackedScene = load("res://assets/kaykit/props/crossbow_1handed.gltf") as PackedScene
	var wand_prop_scene: PackedScene = load("res://assets/kaykit/props/wand.gltf") as PackedScene
	var shield_prop_scene: PackedScene = load("res://assets/kaykit/props/shield_round_barbarian.gltf") as PackedScene

	if sword_prop_scene: prop_models[WeaponType.SWORD] = sword_prop_scene.instantiate()
	if bow_prop_scene: prop_models[WeaponType.BOW] = bow_prop_scene.instantiate()
	if spear_prop_scene: prop_models[WeaponType.SPEAR] = spear_prop_scene.instantiate()
	if hammer_prop_scene: prop_models[WeaponType.HAMMER] = hammer_prop_scene.instantiate()
	if dagger_prop_scene: prop_models[WeaponType.DAGGER] = dagger_prop_scene.instantiate()
	if axe1h_prop_scene: prop_models[WeaponType.AXE_1H] = axe1h_prop_scene.instantiate()
	if crossbow_prop_scene: prop_models[WeaponType.CROSSBOW] = crossbow_prop_scene.instantiate()
	if wand_prop_scene: prop_models[WeaponType.WAND] = wand_prop_scene.instantiate()
	
	if weapon_mount:
		weapon_mount.visible = true
		for w_type in prop_models.keys():
			var p: Node3D = prop_models[w_type]
			p.position = Vector3.ZERO
			p.rotation = Vector3.ZERO
			p.scale = Vector3.ONE
			weapon_mount.add_child(p)
			_set_node_visible_recursive(p, false)

	if shield_prop_scene:
		shield_prop = shield_prop_scene.instantiate()
		var mount_target: Node3D = offhand_mount if offhand_mount else weapon_mount
		if mount_target:
			mount_target.visible = true
			mount_target.add_child(shield_prop)
			shield_prop.position = Vector3.ZERO
			shield_prop.rotation_degrees = Vector3(0, -90, 0)
			shield_prop.scale = Vector3.ONE
			_set_node_visible_recursive(shield_prop, true)

	# Find character model node dynamically (e.g. Barbarian, Knight, CharacterModel)
	for child in get_children():
		if child != camera_rig and child != weapon_mount and child != offhand_mount and child != held_arrow and child is Node3D and not child is AnimationPlayer and not child is CollisionShape3D:
			character_model = child
			break

	if character_model:
		# Find internal AnimationPlayer or setup root_node
		var model_anim: AnimationPlayer = character_model.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if not model_anim:
			for child in character_model.get_children():
				if child is AnimationPlayer:
					model_anim = child
					break
		if model_anim:
			anim_player = model_anim

	if not anim_player:
		anim_player = get_node_or_null("AnimationPlayer") as AnimationPlayer
	if not anim_player:
		anim_player = AnimationPlayer.new()
		anim_player.name = "AnimationPlayer"
		add_child(anim_player)

	# Set exact root_node on AnimationPlayer to character_model root
	if character_model and anim_player:
		anim_player.root_node = anim_player.get_path_to(character_model)

	# Load KayKit animation GLB scene dynamically without displaying mannequin
	var anim_glb_scene: PackedScene = load("res://assets/kaykit/animations/Rig_Medium_MovementBasic.glb") as PackedScene
	if anim_glb_scene:
		var temp_instance: Node = anim_glb_scene.instantiate()
		var temp_anim_player: AnimationPlayer = temp_instance.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if not temp_anim_player:
			for child in temp_instance.get_children():
				if child is AnimationPlayer:
					temp_anim_player = child
					break
		if temp_anim_player:
			var lib_names: Array = temp_anim_player.get_animation_library_list()
			for lib_name in lib_names:
				var lib: AnimationLibrary = temp_anim_player.get_animation_library(lib_name)
				if lib:
					var target_lib: AnimationLibrary = anim_player.get_animation_library("")
					if not target_lib:
						target_lib = AnimationLibrary.new()
						anim_player.add_animation_library("", target_lib)
					for anim_name in lib.get_animation_list():
						var anim: Animation = lib.get_animation(anim_name)
						if not target_lib.has_animation(anim_name):
							target_lib.add_animation(anim_name, anim)
		temp_instance.queue_free()

	# Register self with GameManager singleton safely
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("register_player"):
		gm.call("register_player", self)

	if camera:
		camera.h_offset = 0.0
		camera.v_offset = 0.65

	_update_held_weapon_prop()
	emit_signal("weapon_slot_changed", int(current_weapon))


var is_fps_aim_toggled: bool = false


func _unhandled_input(event: InputEvent) -> void:
	# Key 'E' -> Toggle Fly Mode ON / OFF
	if event.is_action_pressed("toggle_fly"):
		is_flying = !is_flying
		velocity = Vector3.ZERO
		print("[Player] Fly Mode Toggled:", "ON" if is_flying else "OFF")

	# Key 'R' -> Manually spawn a random-trait mob at player position (Unlimited)
	elif event.is_action_pressed("spawn_mob_manual"):
		_spawn_manual_random_mob()

	# Right Click -> Toggle FPS Aim Mode for Bow / Crossbow
	elif event.is_action_pressed("attack_axe"):
		if current_weapon == WeaponType.BOW or current_weapon == WeaponType.CROSSBOW:
			is_fps_aim_toggled = !is_fps_aim_toggled
			if is_fps_aim_toggled:
				_start_bow_aim_camera_pan()
			else:
				_stop_bow_aim_camera_pan()
			get_viewport().set_input_as_handled()

	# Weapon Slot Hotkey Selection (Keys 1-8)
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_1: _select_weapon_slot(WeaponType.SWORD)
		elif event.keycode == KEY_2: _select_weapon_slot(WeaponType.BOW)
		elif event.keycode == KEY_3: _select_weapon_slot(WeaponType.SPEAR)
		elif event.keycode == KEY_4: _select_weapon_slot(WeaponType.HAMMER)
		elif event.keycode == KEY_5: _select_weapon_slot(WeaponType.DAGGER)
		elif event.keycode == KEY_6: _select_weapon_slot(WeaponType.AXE_1H)
		elif event.keycode == KEY_7: _select_weapon_slot(WeaponType.CROSSBOW)
		elif event.keycode == KEY_8: _select_weapon_slot(WeaponType.WAND)

	# Mouse Wheel Weapon Slot Scrolling
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			var prev_slot: int = (int(current_weapon) - 1 + 8) % 8
			_select_weapon_slot(prev_slot as WeaponType)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var next_slot: int = (int(current_weapon) + 1) % 8
			_select_weapon_slot(next_slot as WeaponType)


func _select_weapon_slot(slot: WeaponType) -> void:
	if current_weapon != slot:
		if is_fps_aim_toggled:
			is_fps_aim_toggled = false
			_stop_bow_aim_camera_pan()
		current_weapon = slot
		_update_held_weapon_prop()
		print("[Player] Weapon Switched to Slot:", current_weapon)
		emit_signal("weapon_slot_changed", int(current_weapon))


func _update_held_weapon_prop() -> void:
	for w_type in prop_models.keys():
		var p: Node3D = prop_models[w_type]
		if p:
			var show_p: bool = (w_type == current_weapon)
			p.visible = show_p
			_set_node_visible_recursive(p, show_p)


func _set_node_visible_recursive(node: Node, is_vis: bool) -> void:
	if "visible" in node:
		node.visible = is_vis
	for child in node.get_children():
		_set_node_visible_recursive(child, is_vis)


var is_aiming_bow: bool = false
var camera_pan_tween: Tween = null
var mount_aim_tween: Tween = null


func _reset_bow_aim() -> void:
	is_charging_bow = false
	bow_charge_time = 0.0
	if held_arrow:
		held_arrow.visible = false
	if character_model:
		character_model.visible = true
	_stop_bow_aim_camera_pan()


func _start_bow_aim_camera_pan() -> void:
	if is_aiming_bow:
		return
	is_aiming_bow = true
	
	# Hide character body so it doesn't block screen vision
	if character_model:
		character_model.visible = false

	# Reparent weapon and offhand mounts to camera for static screen-view placement
	if weapon_mount and camera and weapon_mount.get_parent() != camera:
		weapon_mount.reparent(camera)
	if offhand_mount and camera and offhand_mount.get_parent() != camera:
		offhand_mount.reparent(camera)

	# 0.1s Smooth Camera Pan to Eye Level FPS Aim
	if camera_pan_tween and camera_pan_tween.is_running():
		camera_pan_tween.kill()
	camera_pan_tween = create_tween().set_parallel(true)
	if camera_rig:
		camera_pan_tween.tween_property(camera_rig, "spring_length", 0.1, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if camera:
		camera_pan_tween.tween_property(camera, "position", Vector3(0.0, 0.1, -0.4), 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		camera_pan_tween.tween_property(camera, "h_offset", 0.0, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		camera_pan_tween.tween_property(camera, "v_offset", 0.0, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Position Bow and Shield static to camera view (pushed to screen edges & rotated 180 deg)
	if mount_aim_tween and mount_aim_tween.is_running():
		mount_aim_tween.kill()
	mount_aim_tween = create_tween().set_parallel(true)
	if weapon_mount:
		mount_aim_tween.tween_property(weapon_mount, "position", Vector3(0.55, -0.32, -0.75), 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		mount_aim_tween.tween_property(weapon_mount, "rotation_degrees", Vector3(-5.0, 0.0, -10.0), 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if offhand_mount:
		mount_aim_tween.tween_property(offhand_mount, "position", Vector3(-0.65, -0.40, -0.75), 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		mount_aim_tween.tween_property(offhand_mount, "rotation_degrees", Vector3(-10.0, 0.0, 15.0), 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _stop_bow_aim_camera_pan() -> void:
	if not is_aiming_bow:
		return
	is_aiming_bow = false
	
	# Show character body again
	if character_model:
		character_model.visible = true

	# Reparent weapon and offhand mounts back to Player root
	if weapon_mount and weapon_mount.get_parent() != self:
		weapon_mount.reparent(self)
	if offhand_mount and offhand_mount.get_parent() != self:
		offhand_mount.reparent(self)

	# 0.1s Smooth Camera Pan back to 3rd Person View
	if camera_pan_tween and camera_pan_tween.is_running():
		camera_pan_tween.kill()
	camera_pan_tween = create_tween().set_parallel(true)
	if camera_rig:
		camera_pan_tween.tween_property(camera_rig, "spring_length", 4.0, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if camera:
		camera_pan_tween.tween_property(camera, "position", Vector3.ZERO, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		camera_pan_tween.tween_property(camera, "h_offset", 0.0, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		camera_pan_tween.tween_property(camera, "v_offset", 0.65, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Return weapon mount and offhand mount to standard ready stance
	if mount_aim_tween and mount_aim_tween.is_running():
		mount_aim_tween.kill()
	mount_aim_tween = create_tween().set_parallel(true)
	if weapon_mount:
		mount_aim_tween.tween_property(weapon_mount, "position", default_mount_pos, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		mount_aim_tween.tween_property(weapon_mount, "rotation_degrees", default_mount_rot, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if offhand_mount:
		mount_aim_tween.tween_property(offhand_mount, "position", Vector3(-0.35, 0.75, -0.25), 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		mount_aim_tween.tween_property(offhand_mount, "rotation_degrees", Vector3(0, 90, 0), 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _update_character_animation(moving: bool) -> void:
	if not anim_player:
		return

	var target_anim: String = ""
	
	# Check animation names available in KayKit libraries
	var avail: Array = anim_player.get_animation_list()
	
	if is_flying:
		target_anim = _find_matching_anim(avail, ["Flying", "Running_A", "Walking_A", "Idle"])
	elif not is_on_floor():
		target_anim = _find_matching_anim(avail, ["Jump_Start", "Jump_Idle", "Jump_Full_Long", "Running_A", "Idle"])
	elif moving:
		target_anim = _find_matching_anim(avail, ["Running_A", "Walking_A", "Walk", "Idle"])
	else:
		target_anim = _find_matching_anim(avail, ["Idle", "T-Pose"])

	if target_anim != "" and anim_player.current_animation != target_anim:
		anim_player.play(target_anim)


func _find_matching_anim(available_anims: Array, candidates: Array[String]) -> String:
	for cand in candidates:
		for anim_name in available_anims:
			if cand in anim_name or anim_name.ends_with(cand):
				return anim_name
	return ""


func _physics_process(delta: float) -> void:
	# Update attack cooldowns
	if attack_cooldown > 0.0:
		attack_cooldown -= delta

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
		_update_character_animation(fly_move.length() > 0.1)
		
		if attack_cooldown <= 0.0:
			if Input.is_action_just_pressed("attack_slash"):
				_perform_active_weapon_attack()
			elif Input.is_action_just_pressed("attack_axe"):
				if current_weapon != WeaponType.BOW and current_weapon != WeaponType.CROSSBOW:
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
	
	var is_moving: bool = raw_dir.length() > 0.1
	if is_moving:
		var move_dir: Vector3 = raw_dir.rotated(Vector3.UP, cam_y_rot).normalized()
		velocity.x = move_dir.x * move_speed
		velocity.z = move_dir.z * move_speed
		
		var target_angle: float = atan2(-move_dir.x, -move_dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle, rotation_speed * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed)
		velocity.z = move_toward(velocity.z, 0, move_speed)

	move_and_slide()
	_update_character_animation(is_moving)

	# Handle Weapon Attacks & Secondary Thrown Axe
	if attack_cooldown <= 0.0:
		if Input.is_action_just_pressed("attack_slash"):
			_perform_active_weapon_attack()
		elif Input.is_action_just_pressed("attack_axe"):
			if current_weapon != WeaponType.BOW and current_weapon != WeaponType.CROSSBOW:
				_perform_axe_attack()


func _animate_weapon_slash() -> void:
	if not weapon_mount:
		return
	if active_swing_tween and active_swing_tween.is_running():
		active_swing_tween.kill()
	active_swing_tween = create_tween()
	# Quick windup right, then slice horizontally from right (+95 deg) to left (-85 deg) across front
	active_swing_tween.tween_property(weapon_mount, "rotation_degrees", Vector3(-10.0, 95.0, 30.0), 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	active_swing_tween.tween_property(weapon_mount, "rotation_degrees", Vector3(-15.0, -85.0, -40.0), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	active_swing_tween.tween_property(weapon_mount, "rotation_degrees", default_mount_rot, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _animate_weapon_thrust() -> void:
	if not weapon_mount:
		return
	if active_swing_tween and active_swing_tween.is_running():
		active_swing_tween.kill()
	active_swing_tween = create_tween()
	var thrust_pos: Vector3 = default_mount_pos + Vector3(0.0, 0.0, -0.6)
	active_swing_tween.tween_property(weapon_mount, "position", thrust_pos, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	active_swing_tween.tween_property(weapon_mount, "position", default_mount_pos, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _animate_weapon_slam() -> void:
	if not weapon_mount:
		return
	if active_swing_tween and active_swing_tween.is_running():
		active_swing_tween.kill()
	active_swing_tween = create_tween()
	active_swing_tween.tween_property(weapon_mount, "rotation_degrees", Vector3(45.0, 0.0, 0.0), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	active_swing_tween.tween_property(weapon_mount, "rotation_degrees", Vector3(-85.0, 0.0, 0.0), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	active_swing_tween.tween_property(weapon_mount, "rotation_degrees", default_mount_rot, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


# --- WEAPON ATTACK EXECUTION ---
func _perform_active_weapon_attack() -> void:
	match current_weapon:
		WeaponType.SWORD, WeaponType.DAGGER, WeaponType.AXE_1H:
			_perform_sword_attack()
		WeaponType.BOW, WeaponType.CROSSBOW:
			_perform_bow_attack_charged(0.8)
		WeaponType.SPEAR, WeaponType.WAND:
			_perform_spear_attack()
		WeaponType.HAMMER:
			_perform_hammer_attack()


func _perform_sword_attack() -> void:
	if not sword_scene:
		return
	attack_cooldown = 0.3
	_animate_weapon_slash()
	print("[Player] Executing Slot 1: Sword Slash!")
	var slash_inst: Node3D = sword_scene.instantiate() as Node3D
	weapon_mount.add_child(slash_inst)


func _perform_bow_attack_charged(charge_time: float) -> void:
	if not bow_scene:
		return
	attack_cooldown = 0.35
	var charge_ratio: float = clampf(charge_time / 1.2, 0.3, 1.0)
	var launch_speed: float = lerpf(85.0, 115.0, charge_ratio)
	print("[Player] Released Bow Arrow! Power:", charge_ratio, "Speed:", launch_speed)

	var arrow_inst: Node3D = bow_scene.instantiate() as Node3D
	get_parent().add_child(arrow_inst)
	
	# 1. Determine spawn origin (player body in 3rd person, camera in FPS)
	var spawn_origin: Vector3
	if is_fps_aim_toggled:
		spawn_origin = camera.global_position
	else:
		spawn_origin = global_position + Vector3(0.0, 1.3, 0.0)

	# 2. 3D Crosshair Target Convergence Raycast
	var target_point: Vector3
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if space_state and camera:
		var cam_from: Vector3 = camera.global_position
		var cam_to: Vector3 = cam_from + (-camera.global_transform.basis.z * 200.0)
		var ray_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(cam_from, cam_to)
		ray_query.collision_mask = 3 # Terrain & Enemies
		ray_query.exclude = [self]
		if is_instance_valid(self):
			ray_query.exclude.append(get_rid())

		var hit_res: Dictionary = space_state.intersect_ray(ray_query)
		if not hit_res.is_empty():
			target_point = hit_res.get("position", cam_to)
		else:
			target_point = cam_to
	else:
		target_point = camera.global_position + (-camera.global_transform.basis.z * 200.0)

	# 3. Calculate exact shooting direction from spawn_origin to target_point
	var shoot_dir: Vector3 = (target_point - spawn_origin).normalized()
	arrow_inst.global_position = spawn_origin + (shoot_dir * 1.2)

	if "launch_speed" in arrow_inst:
		arrow_inst.set("launch_speed", launch_speed)
	if arrow_inst.has_method("setup_direction"):
		arrow_inst.call("setup_direction", shoot_dir)


func _perform_spear_attack() -> void:
	if not spear_scene:
		return
	attack_cooldown = 0.35
	_animate_weapon_thrust()
	print("[Player] Executing Slot 3: Spear Forward Box Thrust!")
	var spear_inst: Node3D = spear_scene.instantiate() as Node3D
	weapon_mount.add_child(spear_inst)


func _perform_hammer_attack() -> void:
	if not hammer_scene:
		return
	attack_cooldown = 0.6
	_animate_weapon_slam()
	print("[Player] Executing Slot 4: Hammer Ground Slam Shockwave!")
	var hammer_inst: Node3D = hammer_scene.instantiate() as Node3D
	get_parent().add_child(hammer_inst)
	hammer_inst.global_position = global_position + Vector3(0.0, 0.05, 0.0)


func _perform_axe_attack() -> void:
	if not axe_scene:
		return
	attack_cooldown = 0.45
	_animate_weapon_slash()
	print("[Player] Executing Right-Click 3D Crosshair Converged Thrown Axe!")
	var axe_inst: Node3D = axe_scene.instantiate() as Node3D
	get_parent().add_child(axe_inst)
	
	var spawn_origin: Vector3 = global_position + Vector3(0.0, 1.8, 0.0)
	var target_point: Vector3
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if space_state and camera:
		var cam_from: Vector3 = camera.global_position
		var cam_to: Vector3 = cam_from + (-camera.global_transform.basis.z * 200.0)
		var ray_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(cam_from, cam_to)
		ray_query.collision_mask = 3
		ray_query.exclude = [self]
		if is_instance_valid(self):
			ray_query.exclude.append(get_rid())

		var hit_res: Dictionary = space_state.intersect_ray(ray_query)
		if not hit_res.is_empty():
			target_point = hit_res.get("position", cam_to)
		else:
			target_point = cam_to
	else:
		target_point = camera.global_position + (-camera.global_transform.basis.z * 200.0)

	var throw_dir: Vector3 = (target_point - spawn_origin).normalized()
	axe_inst.global_position = spawn_origin + (throw_dir * 0.8)
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
