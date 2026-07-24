# ==============================================================================
# THIRD-PERSON PLAYER CONTROLLER (scripts/client/player/player.gd)
# ==============================================================================
# Controls player character:
# - 3X Fly Speed (72.0 m/s) toggled via Key E
# - 8 Switchable Weapons (Slot 1: Sword, 2: Bow, 3: Spear, 4: Hammer, 5: Dagger, 6: Axe, 7: Crossbow, 8: Wand)
# - First-Person (FPS) Bow Aiming via Right-Click toggle
# - Hotkeys:
#   • Key R: Spawn single mob
#   • Key X: Spawn 50 random trait mobs (Layer 6)
#   • Key C: Spawn 200 blue falling building blocks that stack on a 1.0m grid (Layer 3)
#   • Key V: Spawn 50 interactable green cubes (Layer 4, turns Orange when near)
#   • Key B: Spawn 50 block debris particle explosions (Layer 9)
#   • Key N: Spawn 50 complex indestructible furniture props on Layer 1 Ground (Tables, Chairs, Pillars, Cabinets)
#   • Key M: Clear all world entities (Mobs, Blocks, Interactables, Furniture)
# ==============================================================================
extends CharacterBody3D

signal weapon_slot_changed(slot_idx: int)

@export var move_speed: float = 9.0
@export var fly_speed: float = 72.0
@export var jump_velocity: float = 12.0
@export var high_jump_velocity: float = 32.0
@export var rotation_speed: float = 15.0

@export var gravity: float = 32.0
@export var fall_multiplier: float = 1.6

var is_flying: bool = false

enum WeaponType { SWORD = 0, BOW = 1, SPEAR = 2, HAMMER = 3, DAGGER = 4, AXE_1H = 5, CROSSBOW = 6, WAND = 7 }
var current_weapon: WeaponType = WeaponType.SWORD

var is_charging_bow: bool = false
var bow_charge_time: float = 0.0
var attack_cooldown: float = 0.0

@onready var camera_rig: SpringArm3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var weapon_mount: Node3D = $WeaponMount
@onready var offhand_mount: Node3D = get_node_or_null("OffhandMount")
@onready var held_arrow: Node3D = get_node_or_null("CameraRig/Camera3D/HeldArrow")

var character_model: Node3D = null
var anim_player: AnimationPlayer = null

var prop_models: Dictionary = {}
var active_prop: Node3D = null
var shield_prop: Node3D = null

var default_mount_rot: Vector3 = Vector3(-15, 20, 15)
var default_mount_pos: Vector3 = Vector3(0.35, 0.75, -0.25)
var active_swing_tween: Tween = null
var is_fps_aim_toggled: bool = false
var is_aiming_bow: bool = false
var camera_pan_tween: Tween = null
var mount_aim_tween: Tween = null


func _ready() -> void:
	collision_layer = CollisionUtils.get_layer_bitmask(CollisionUtils.LayerIndex.HERO)
	collision_mask = CollisionUtils.combine_masks([
		CollisionUtils.LayerIndex.GROUND,
		CollisionUtils.LayerIndex.WALL,
		CollisionUtils.LayerIndex.BLOCK
	])

	# Preload 3D Prop Scenes
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

	for child in get_children():
		if child != camera_rig and child != weapon_mount and child != offhand_mount and child != held_arrow and child is Node3D and not child is AnimationPlayer and not child is CollisionShape3D:
			character_model = child
			break

	if character_model:
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

	if character_model and anim_player:
		anim_player.root_node = anim_player.get_path_to(character_model)

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
				if temp_anim_player.has_animation_library(lib_name):
					var lib: AnimationLibrary = temp_anim_player.get_animation_library(lib_name)
					if lib:
						var target_lib: AnimationLibrary = null
						if anim_player.has_animation_library(""):
							target_lib = anim_player.get_animation_library("")
						else:
							target_lib = AnimationLibrary.new()
							anim_player.add_animation_library("", target_lib)
						for anim_name in lib.get_animation_list():
							var anim: Animation = lib.get_animation(anim_name)
							if not target_lib.has_animation(anim_name):
								target_lib.add_animation(anim_name, anim)
		temp_instance.queue_free()

	Server.register_player(self)

	if camera:
		camera.h_offset = 0.0
		camera.v_offset = 0.65

	_update_held_weapon_prop()
	emit_signal("weapon_slot_changed", int(current_weapon))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fly"):
		is_flying = !is_flying
		velocity = Vector3.ZERO
		print("[Player] Fly Mode Toggled:", "ON" if is_flying else "OFF")

	elif event.is_action_pressed("spawn_mob_manual"):
		_spawn_manual_random_mob()

	elif event.is_action_pressed("attack_axe"):
		is_fps_aim_toggled = !is_fps_aim_toggled
		if is_fps_aim_toggled:
			_start_bow_aim_camera_pan()
		else:
			_stop_bow_aim_camera_pan()
		get_viewport().set_input_as_handled()

	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M:
			Server.clear_all_entities()
		elif event.keycode == KEY_N:
			_spawn_batch_furniture(50) # Key N: Spawns 50 Complex Indestructible Furniture Props on Layer 1 Ground!
		elif event.keycode == KEY_X:
			_spawn_batch_random_mobs(50)
		elif event.keycode == KEY_C:
			_spawn_batch_blue_blocks(200)
		elif event.keycode == KEY_V:
			_spawn_batch_interactable_cubes(50)
		elif event.keycode == KEY_B:
			_spawn_batch_block_explosions(50)
		elif event.keycode == KEY_1: _select_weapon_slot(WeaponType.SWORD)
		elif event.keycode == KEY_2: _select_weapon_slot(WeaponType.BOW)
		elif event.keycode == KEY_3: _select_weapon_slot(WeaponType.SPEAR)
		elif event.keycode == KEY_4: _select_weapon_slot(WeaponType.HAMMER)
		elif event.keycode == KEY_5: _select_weapon_slot(WeaponType.DAGGER)
		elif event.keycode == KEY_6: _select_weapon_slot(WeaponType.AXE_1H)
		elif event.keycode == KEY_7: _select_weapon_slot(WeaponType.CROSSBOW)
		elif event.keycode == KEY_8: _select_weapon_slot(WeaponType.WAND)

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


func _start_bow_aim_camera_pan() -> void:
	if is_aiming_bow:
		return
	is_aiming_bow = true

	if character_model:
		character_model.visible = false

	if weapon_mount and camera and weapon_mount.get_parent() != camera:
		weapon_mount.reparent(camera)
	if offhand_mount and camera and offhand_mount.get_parent() != camera:
		offhand_mount.reparent(camera)

	if camera_pan_tween and camera_pan_tween.is_running():
		camera_pan_tween.kill()
	camera_pan_tween = create_tween().set_parallel(true)
	if camera_rig:
		camera_pan_tween.tween_property(camera_rig, "spring_length", 0.1, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if camera:
		camera_pan_tween.tween_property(camera, "position", Vector3(0.0, 0.1, -0.4), 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		camera_pan_tween.tween_property(camera, "h_offset", 0.0, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		camera_pan_tween.tween_property(camera, "v_offset", 0.0, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

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

	if character_model:
		character_model.visible = true

	if weapon_mount and weapon_mount.get_parent() != self:
		weapon_mount.reparent(self)
	if offhand_mount and offhand_mount.get_parent() != self:
		offhand_mount.reparent(self)

	if camera_pan_tween and camera_pan_tween.is_running():
		camera_pan_tween.kill()
	camera_pan_tween = create_tween().set_parallel(true)
	if camera_rig:
		camera_pan_tween.tween_property(camera_rig, "spring_length", 4.0, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if camera:
		camera_pan_tween.tween_property(camera, "position", Vector3.ZERO, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		camera_pan_tween.tween_property(camera, "h_offset", 0.0, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		camera_pan_tween.tween_property(camera, "v_offset", 0.65, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

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
	var avail: Array = anim_player.get_animation_list()
	var target_anim: String = ""

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
	if attack_cooldown > 0.0:
		attack_cooldown -= delta

	if is_flying:
		var fly_move: Vector3 = Vector3.ZERO
		var fly_input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if fly_input_dir.length() > 0.1:
			var cam_basis: Basis = camera.global_transform.basis
			fly_move = (cam_basis.x * fly_input_dir.x + cam_basis.z * fly_input_dir.y).normalized()
		if Input.is_action_pressed("jump"):
			fly_move.y += 1.0
		elif Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_CTRL):
			fly_move.y -= 1.0

		velocity = fly_move.normalized() * fly_speed
		move_and_slide()
		_update_character_animation(fly_move.length() > 0.1)
		_handle_weapon_attacks(delta)
		return

	if not is_on_floor():
		if velocity.y < 0.0:
			velocity.y -= gravity * fall_multiplier * delta
		else:
			velocity.y -= gravity * delta

	if is_on_floor():
		if Input.is_action_just_pressed("high_jump"):
			velocity.y = high_jump_velocity
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
	_handle_weapon_attacks(delta)


func _handle_weapon_attacks(_delta: float) -> void:
	if current_weapon == WeaponType.CROSSBOW:
		if attack_cooldown <= 0.0 and Input.is_action_pressed("attack_slash"):
			_perform_active_weapon_attack()
	else:
		if attack_cooldown <= 0.0 and Input.is_action_just_pressed("attack_slash"):
			_perform_active_weapon_attack()


# --- WEAPON ATTACK EXECUTION & SERVER DISPATCHING ---
func _perform_active_weapon_attack() -> void:
	var spawn_origin: Vector3 = camera.global_position if is_fps_aim_toggled else global_position + Vector3(0.0, 1.3, 0.0)
	var shoot_dir: Vector3 = _calculate_aim_direction(spawn_origin)

	match current_weapon:
		WeaponType.SWORD:
			attack_cooldown = 0.3
			_animate_weapon_slash()
			Server.spawn_projectile_from_player("slash", 10.0, 20.0, 0.0, spawn_origin, shoot_dir)
		WeaponType.BOW:
			attack_cooldown = 0.35
			Server.spawn_projectile_from_player("arrow", 8.0, 120.0, 100.0, spawn_origin, shoot_dir)
		WeaponType.SPEAR:
			attack_cooldown = 0.35
			_animate_weapon_thrust()
			Server.spawn_projectile_from_player("fireball", 15.0, 85.0, 110.0, spawn_origin, shoot_dir)
		WeaponType.HAMMER:
			attack_cooldown = 0.6
			_animate_weapon_slam()
			Server.spawn_projectile_from_player("hammer", 20.0, 10.0, 0.0, global_position, Vector3.FORWARD)
		WeaponType.DAGGER:
			attack_cooldown = 0.2
			_animate_weapon_thrust()
			Server.spawn_projectile_from_player("dagger", 6.0, 30.0, 0.0, spawn_origin, shoot_dir)
		WeaponType.AXE_1H:
			attack_cooldown = 0.45
			_animate_weapon_slash()
			Server.spawn_projectile_from_player("axe", 12.0, 75.0, 140.0, spawn_origin, shoot_dir)
		WeaponType.CROSSBOW:
			attack_cooldown = 0.18
			Server.spawn_projectile_from_player("bolt", 5.0, 140.0, 60.0, spawn_origin, shoot_dir)
		WeaponType.WAND:
			attack_cooldown = 0.25
			_animate_weapon_thrust()
			Server.spawn_projectile_from_player("bolt", 9.0, 200.0, 0.0, spawn_origin, shoot_dir)


func _calculate_aim_direction(origin: Vector3) -> Vector3:
	var target_point: Vector3
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if space_state and camera:
		var cam_from: Vector3 = camera.global_position
		var cam_to: Vector3 = cam_from + (-camera.global_transform.basis.z * 200.0)
		var query := PhysicsRayQueryParameters3D.create(cam_from, cam_to)
		query.collision_mask = CollisionUtils.combine_masks([
			CollisionUtils.LayerIndex.GROUND,
			CollisionUtils.LayerIndex.WALL,
			CollisionUtils.LayerIndex.BLOCK,
			CollisionUtils.LayerIndex.MOBS
		])
		query.exclude = [get_rid()]

		var hit_res: Dictionary = space_state.intersect_ray(query)
		if not hit_res.is_empty():
			target_point = hit_res.get("position", cam_to)
		else:
			target_point = cam_to
	else:
		target_point = camera.global_position + (-camera.global_transform.basis.z * 200.0)

	return (target_point - origin).normalized()


func _animate_weapon_slash() -> void:
	if not weapon_mount: return
	if active_swing_tween and active_swing_tween.is_running(): active_swing_tween.kill()
	active_swing_tween = create_tween()
	active_swing_tween.tween_property(weapon_mount, "rotation_degrees", Vector3(-10.0, 95.0, 30.0), 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	active_swing_tween.tween_property(weapon_mount, "rotation_degrees", Vector3(-15.0, -85.0, -40.0), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	active_swing_tween.tween_property(weapon_mount, "rotation_degrees", default_mount_rot, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _animate_weapon_thrust() -> void:
	if not weapon_mount: return
	if active_swing_tween and active_swing_tween.is_running(): active_swing_tween.kill()
	active_swing_tween = create_tween()
	var thrust_pos: Vector3 = default_mount_pos + Vector3(0.0, 0.0, -0.6)
	active_swing_tween.tween_property(weapon_mount, "position", thrust_pos, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	active_swing_tween.tween_property(weapon_mount, "position", default_mount_pos, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _animate_weapon_slam() -> void:
	if not weapon_mount: return
	if active_swing_tween and active_swing_tween.is_running(): active_swing_tween.kill()
	active_swing_tween = create_tween()
	active_swing_tween.tween_property(weapon_mount, "rotation_degrees", Vector3(45.0, 0.0, 0.0), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	active_swing_tween.tween_property(weapon_mount, "rotation_degrees", Vector3(-85.0, 0.0, 0.0), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	active_swing_tween.tween_property(weapon_mount, "rotation_degrees", default_mount_rot, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _spawn_manual_random_mob() -> void:
	var static_scene: PackedScene = load("res://scenes/enemy_static.tscn")
	var wander_scene: PackedScene = load("res://scenes/enemy_wander.tscn")
	var chase_scene: PackedScene = load("res://scenes/enemy_chase.tscn")
	var enemy_types: Array[PackedScene] = [static_scene, wander_scene, chase_scene]

	var chosen_scene: PackedScene = enemy_types[randi() % enemy_types.size()]
	if chosen_scene:
		var mob_inst: Node3D = chosen_scene.instantiate() as Node3D
		get_parent().add_child(mob_inst)
		mob_inst.global_position = global_position + (transform.basis.z * -2.2) + Vector3.UP * 0.2
		print("[Player] Manually spawned random mob via Key 'R' at:", mob_inst.global_position)


## Key 'X' Action: Spawns batch of 50 random trait mobs (Layer 6)
func _spawn_batch_random_mobs(count: int = 50) -> void:
	var static_scene: PackedScene = load("res://scenes/enemy_static.tscn")
	var wander_scene: PackedScene = load("res://scenes/enemy_wander.tscn")
	var chase_scene: PackedScene = load("res://scenes/enemy_chase.tscn")
	var enemy_types: Array[PackedScene] = [static_scene, wander_scene, chase_scene]

	var parent_node: Node = get_parent()
	if not parent_node:
		return

	print("[Player] Spawning batch of ", count, " random trait mobs via Key 'X'...")
	for i in range(count):
		var chosen_scene: PackedScene = enemy_types[randi() % enemy_types.size()]
		if chosen_scene:
			var mob_inst: Node3D = chosen_scene.instantiate() as Node3D
			var rand_offset := Vector3(
				randf_range(-22.0, 22.0),
				0.2,
				randf_range(-22.0, 22.0)
			)
			if rand_offset.length() < 3.0:
				rand_offset = rand_offset.normalized() * 4.0

			parent_node.add_child(mob_inst)
			mob_inst.global_position = global_position + rand_offset


## Key 'C' Action: Spawns 200 Blue Building Blocks that fall and stack on a 1.0m Grid
func _spawn_batch_blue_blocks(count: int = 200) -> void:
	var layer3: Node = Server.get_layer_manager(3)
	if not layer3:
		layer3 = get_node_or_null("../BlockLayer")
	if layer3 and layer3.has_method("place_block"):
		print("[Player] Spawning batch of ", count, " blue grid stacking blocks via Key 'C'...")
		for i in range(count):
			var grid_x: float = snappedf(global_position.x + randf_range(-10.0, 10.0), 1.0)
			var grid_z: float = snappedf(global_position.z + randf_range(-10.0, 10.0), 1.0)
			var spawn_height: float = global_position.y + randf_range(3.0, 25.0)

			layer3.call("place_block", Vector3(grid_x, spawn_height, grid_z), Color(0.2, 0.5, 0.95))
	else:
		print("[Player] Layer 3 BlockLayer not found!")


## Key 'N' Action: Spawns 50 Complex Indestructible Furniture Props on Layer 1 Ground
func _spawn_batch_furniture(count: int = 50) -> void:
	var layer1: Node = Server.get_layer_manager(1)
	if not layer1:
		layer1 = get_node_or_null("../Terrain")
	if layer1 and layer1.has_method("spawn_furniture_batch"):
		layer1.call("spawn_furniture_batch", count, global_position)
	else:
		print("[Player] Layer 1 Terrain layer not found!")


## Key 'V' Action: Spawns 50 Green Interactable Cubes (Layer 4, turns Orange when near)
func _spawn_batch_interactable_cubes(count: int = 50) -> void:
	var layer4: Node = Server.get_layer_manager(4)
	if not layer4:
		layer4 = get_node_or_null("../InteractableLayer")
	if layer4 and layer4.has_method("spawn_interactable_batch"):
		layer4.call("spawn_interactable_batch", count, global_position)
	else:
		print("[Player] Layer 4 InteractableLayer not found!")


## Key 'B' Action: Spawns 50 Block Debris Explosions (Layer 9)
func _spawn_batch_block_explosions(count: int = 50) -> void:
	var layer9: Node = Server.get_layer_manager(9)
	if not layer9:
		layer9 = get_node_or_null("../EffectManager")
	if layer9 and layer9.has_method("spawn_block_explosion_batch"):
		layer9.call("spawn_block_explosion_batch", count, global_position)
	else:
		print("[Player] Layer 9 EffectManager not found!")
