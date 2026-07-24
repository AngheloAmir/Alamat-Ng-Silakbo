# ==============================================================================
# BASE ENEMY CLASS (scripts/layers/6mobs/enemy_base.gd)
# ==============================================================================
# Base script for all enemy mobs in the game:
# - High-Performance Physics: Skips `move_and_slide()` when stationary on floor.
# - High-Performance GPU Rendering: Disables shadow pass draw calls on high-density mob meshes.
# - Distance-based Physics Throttling for mobs >45m away.
# - Despawns beyond 120m simulation distance.
# ==============================================================================
class_name EnemyBase
extends CharacterBody3D

@export var move_speed: float = 4.0
@export var enemy_name: String = "Dummy"
@export var despawn_distance: float = 120.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 19.6)
var is_dead: bool = false
var current_queued_action: Dictionary = {}

@onready var mesh_node: MeshInstance3D = get_node_or_null("CapsuleMesh")


func _ready() -> void:
	collision_layer = CollisionUtils.get_layer_bitmask(CollisionUtils.LayerIndex.MOBS)
	collision_mask = CollisionUtils.combine_masks([
		CollisionUtils.LayerIndex.GROUND,
		CollisionUtils.LayerIndex.WALL,
		CollisionUtils.LayerIndex.BLOCK
	])
	Server.register_mob(self)

	# --- GPU RENDER OPTIMIZATION FOR MASS MOB DENSITY ---
	if mesh_node:
		mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh_node.visibility_range_end = 120.0
		mesh_node.visibility_range_end_margin = 20.0
		mesh_node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF

	_setup_ai()


func _setup_ai() -> void:
	pass


func _process_ai(_delta: float) -> void:
	pass


func apply_queued_action(action_data: Dictionary) -> void:
	current_queued_action = action_data


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Distance-based Despawn (120m) and Physics Throttling (45m)
	var player: Node3D = Server.get_player()
	if player and is_instance_valid(player):
		var dist_to_player: float = (player.global_position - global_position).length()
		if dist_to_player > despawn_distance:
			print("[EnemyBase] Mob despawned beyond 120m simulation radius (%.1fm): %s" % [dist_to_player, name])
			Server.unregister_mob(self)
			queue_free()
			return
		elif dist_to_player > 45.0 and (Engine.get_physics_frames() % 2 != 0):
			# Skip alternate physics frames for distant mobs (>45m)
			return

	if not is_on_floor():
		velocity.y -= gravity * delta

	_process_ai(delta)

	# HIGH PERFORMANCE OPTIMIZATION:
	# Only execute expensive Jolt Physics 3D move_and_slide() when falling or moving!
	if not is_on_floor() or velocity.length_squared() > 0.01:
		move_and_slide()


func take_damage(_damage: float = 1.0) -> void:
	if is_dead:
		return

	is_dead = true
	print("[EnemyBase] Mob destroyed:", name, " (Hit Response)")
	Server.unregister_mob(self)

	# Disable collision shape immediately on hit so Jolt Physics stops evaluating collisions
	var col_shape: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col_shape:
		col_shape.set_deferred("disabled", true)

	var target_visual: Node3D = (mesh_node as Node3D) if mesh_node else (self as Node3D)
	var tween: Tween = create_tween()
	if target_visual != self:
		tween.tween_property(target_visual, "scale", Vector3(1.4, 0.2, 1.4), 0.12)
		tween.tween_property(target_visual, "scale", Vector3(0.01, 0.01, 0.01), 0.15)
	tween.tween_callback(queue_free)
