# ==============================================================================
# BASE ENEMY CLASS (Red Capsule Dummy)
# ==============================================================================
# Base script for all enemy mobs in the game:
# - Manages 1-hit kill destruction logic
# - Minecraft-style Simulation Distance despawning (>140m from player)
# - Registers / Unregisters with GameManager
# - Provides clean virtual functions for child AI scripts (Static, Wander, Chase)
# ==============================================================================
extends CharacterBody3D
class_name EnemyBase

@export var move_speed: float = 4.0        # Movement speed
@export var enemy_name: String = "Dummy"   # Descriptive mob label
@export var despawn_distance: float = 140.0 # Minecraft-style despawn radius (meters)

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 19.6)
var is_dead: bool = false

@onready var mesh_node: MeshInstance3D = $CapsuleMesh


func _ready() -> void:
	# Set collision layer to 2 (Enemy layer)
	collision_layer = 2
	collision_mask = 3
	
	# Register with GameManager Singleton
	GameManager.register_mob(self)
	
	# Custom setup for inherited child classes
	_setup_ai()


# --- VIRTUAL AI SETUP & PROCESS (Overridden by children) ---
func _setup_ai() -> void:
	pass

func _process_ai(_delta: float) -> void:
	pass


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# 1. Minecraft-style Simulation Distance Despawn Check (>140m from player)
	var player: Node3D = GameManager.get_player()
	if player and is_instance_valid(player):
		var dist_to_player: float = (player.global_position - global_position).length()
		if dist_to_player > despawn_distance:
			print("[EnemyBase] Mob despawned beyond simulation radius (%.1fm): %s" % [dist_to_player, name])
			GameManager.unregister_mob(self)
			queue_free()
			return

	# 2. Apply Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# 3. Execute specific AI movement logic
	_process_ai(delta)

	move_and_slide()


# --- DAMAGE & DESTRUCTION MECHANICS ---
func take_damage(_damage: int = 1) -> void:
	# 1-hit kill requirement
	if is_dead:
		return

	is_dead = true
	print("[EnemyBase] Mob destroyed:", name, " (1-Hit Kill)")

	# Unregister mob count in GameManager server layer
	GameManager.unregister_mob(self)

	# Visual destruction effect: Shrink & flash red, then free node
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector3(1.4, 0.2, 1.4), 0.12)
	tween.tween_property(self, "scale", Vector3.ZERO, 0.15)
	tween.tween_callback(queue_free)
