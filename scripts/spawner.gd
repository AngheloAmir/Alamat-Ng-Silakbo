# ==============================================================================
# MOB SPAWNER SYSTEM
# ==============================================================================
# 1. Spawns 8 initial dummy enemies near player spawn with random AI traits.
# 2. Runs a 20-second timer to spawn new mobs up to max mob cap of 16.
# 3. Uses thread-optimized deferred calls and checks GameManager server state.
# ==============================================================================
extends Node3D

@export var spawn_radius: float = 16.0 # Radius around spawner position to spawn mobs
@export var initial_mob_count: int = 8  # Initial spawn count (8 mobs)

# Preload enemy scenes
var static_scene: PackedScene = preload("res://scenes/enemy_static.tscn")
var wander_scene: PackedScene = preload("res://scenes/enemy_wander.tscn")
var chase_scene: PackedScene = preload("res://scenes/enemy_chase.tscn")

@onready var spawn_timer: Timer = $SpawnTimer


func _ready() -> void:
	# 1. Spawn Initial 8 Dummy Enemies near spawn point with random traits
	call_deferred("_spawn_initial_dummies")
	
	# 2. Setup 20-second Respawn Timer
	spawn_timer.wait_time = GameManager.RESPAWN_INTERVAL
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	spawn_timer.start()


func _spawn_initial_dummies() -> void:
	print("[Spawner] Spawning initial ", initial_mob_count, " dummy enemies with random traits...")
	
	var enemy_types: Array[PackedScene] = [static_scene, wander_scene, chase_scene]
	
	for i in range(initial_mob_count):
		# Pick random enemy AI trait scene
		var chosen_scene: PackedScene = enemy_types[randi() % enemy_types.size()]
		
		# Pick random position around spawn radius
		var rand_offset: Vector3 = Vector3(
			randf_range(-spawn_radius, spawn_radius),
			0.0,
			randf_range(-spawn_radius, spawn_radius)
		)
		# Avoid spawning right on player center
		if rand_offset.length() < 3.0:
			rand_offset = rand_offset.normalized() * 5.0
			
		var spawn_pos: Vector3 = global_position + rand_offset
		_instantiate_mob(chosen_scene, spawn_pos)


func _on_spawn_timer_timeout() -> void:
	# Check if GameManager server layer allows spawning (Max mob cap = 16)
	if GameManager.can_spawn_mob():
		print("[Spawner] 20s Timer Triggered -> Spawning replacement mob...")
		
		# Pick random enemy type (Static, Wander, or Chase)
		var enemy_types: Array[PackedScene] = [static_scene, wander_scene, chase_scene]
		var chosen_scene: PackedScene = enemy_types[randi() % enemy_types.size()]
		
		# Pick random position around spawn radius
		var rand_offset: Vector3 = Vector3(
			randf_range(-spawn_radius, spawn_radius),
			0.0,
			randf_range(-spawn_radius, spawn_radius)
		)
		var spawn_pos: Vector3 = global_position + rand_offset
		
		_instantiate_mob(chosen_scene, spawn_pos)
	else:
		print("[Spawner] 20s Timer Triggered -> Mob cap reached (16/16). Skipping spawn.")


func _instantiate_mob(scene: PackedScene, pos: Vector3) -> void:
	var mob_inst: Node3D = scene.instantiate() as Node3D
	get_parent().add_child(mob_inst)
	mob_inst.global_position = pos
